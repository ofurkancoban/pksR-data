# Polite downloads of registry sources (BUG-025): URLs only from the
# registries, a descriptive User-Agent, retries, one request per ten seconds
# per host, and a SHA-256 check against the registry.

pksr_user_agent <- "pksR-data (R pipeline for German Police Crime Statistics; https://github.com/ofurkancoban/pksR-data)"

sha256_file <- function(path) {
  digest::digest(file = path, algo = "sha256")
}

verify_sha256 <- function(path, expected) {
  actual <- sha256_file(path)
  if (!is.na(expected) && nzchar(expected) && !identical(actual, expected)) {
    cli::cli_abort(c(
      "SHA-256 of {.file {basename(path)}} differs from the registry.",
      "i" = "Registry: {expected}",
      "i" = "File:     {actual}",
      "i" = "If the source republished the file, record the new hash in the registry."
    ))
  }
  invisible(actual)
}

# From GitHub runners, bka.de drops connections at random for minutes at a
# time, whatever the pace (runs 40672047901 to 40706798700). Through the
# Cloudflare Worker in ci/proxy/worker.js 8 of 10 requests succeeded, in
# under a second, against 4 of 10 directly (notes/decisions.md). So when
# PKSR_PROXY_URL and PKSR_PROXY_KEY are set, requests to www.bka.de go
# through the Worker; other hosts are asked directly. The Worker passes the
# User-Agent on, and every file is still checked against its registered
# SHA-256.
proxy_hosts <- "www.bka.de"

proxy_config <- function() {
  url <- Sys.getenv("PKSR_PROXY_URL")
  key <- Sys.getenv("PKSR_PROXY_KEY")
  if (!nzchar(url) || !nzchar(key)) return(NULL)
  list(url = trimws(url), key = trimws(key))
}

# The URL to request and the extra headers for `url`.
route_request <- function(url, proxy = proxy_config()) {
  host <- sub("^https?://([^/:]+).*$", "\\1", url)
  if (is.null(proxy) || !host %in% proxy_hosts) return(list(url = url, headers = list()))
  list(url = paste0(sub("/+$", "", proxy$url), "/?url=", utils::URLencode(url, reserved = TRUE)),
       headers = list(`X-Proxy-Key` = proxy$key))
}

# Retried: connection failures (httr2 retries only transient HTTP statuses
# by default), 429, server errors and Cloudflare's 520 to 526 (525: the
# Worker could not complete TLS with bka.de). Backoff 5, 10, 20, 40 s; 60 s
# to connect, `timeout` seconds per attempt, and at most `max_seconds` of
# retrying, so a dead host cannot hold the job until its timeout.
transient_status <- c(429, 500, 502, 503, 504, 520:526)

pksr_request <- function(url, max_seconds = 300, timeout = 600, proxy = proxy_config()) {
  route <- route_request(url, proxy)
  httr2::request(route$url) |>
    httr2::req_headers(!!!route$headers, .redact = "X-Proxy-Key") |>
    httr2::req_user_agent(pksr_user_agent) |>
    httr2::req_retry(
      max_tries = 5, max_seconds = max_seconds, retry_on_failure = TRUE,
      is_transient = function(resp) httr2::resp_status(resp) %in% transient_status,
      backoff = function(i) 5 * 2^(i - 1)
    ) |>
    # req_timeout() resets connecttimeout, so it comes first
    httr2::req_timeout(timeout) |>
    httr2::req_options(connecttimeout = 60) |>
    # Ten seconds between requests to one host
    httr2::req_throttle(capacity = 1, fill_time_s = 10)
}

# Every raw file the pipeline reads, from the four registries, with the
# folder it belongs in below `raw_dir` and the page that links it.
raw_inventory <- function(registry_dir = "registry", raw_dir = "data-raw") {
  read <- function(name) readr::read_csv(file.path(registry_dir, name), col_types = readr::cols(.default = "c"), na = "")
  part <- function(d, registry, label, sub) {
    tibble::tibble(
      registry = registry, label = label, url = d$url, landing_page = d$landing_page,
      sha256 = d$sha256, path = file.path(raw_dir, sub, d$file_name)
    )
  }
  s <- read("sources.csv")
  b <- read("bund_sources.csv")
  d <- read("destatis_sources.csv")
  r <- read("reference_sources.csv")
  inv <- dplyr::bind_rows(
    part(s, "sources", s$year, ""),
    part(b, "bund_sources", b$year, "bund"),
    part(d, "destatis_sources", d$label, "destatis"),
    part(r, "reference_sources", r$label, "bbsr")
  )
  inv$path <- gsub("/+", "/", inv$path)
  if (anyNA(inv$url) || anyNA(inv$sha256) || anyDuplicated(inv$path)) {
    cli::cli_abort("Every registry row needs a URL, a SHA-256 and its own file name.")
  }
  inv$mirror_name <- mirror_asset_name(inv$path, raw_dir)
  inv
}

# Makes every file of the inventory available with the registered hash, in
# this order: the local copy, the source URL (through the Worker for
# bka.de), the mirror (`mirror(name, dest)` returns FALSE when it lacks the
# file). Every copy is checked against the registered SHA-256.
#   "present"     local copy with the registered hash
#   "downloaded"  fetched from the source
#   "mirrored"    source unreachable, taken from the mirror (message: why)
#   "changed"     the source serves another file: kept in `drift_dir`, never
#                 replaced by the mirror copy, so the maintainer decides
#   "failed"      neither source nor mirror
fetch_raw <- function(inventory, refresh = FALSE, drift_dir = "data-raw/_drift", get = download_file, mirror = NULL) {
  status <- character(nrow(inventory))
  actual <- rep(NA_character_, nrow(inventory))
  message <- rep(NA_character_, nrow(inventory))
  put <- function(tmp, path) {
    ensure_dir(dirname(path))
    file.copy(tmp, path, overwrite = TRUE)
  }
  for (i in seq_len(nrow(inventory))) {
    path <- inventory$path[i]
    if (!refresh && file.exists(path) && identical(sha256_file(path), inventory$sha256[i])) {
      status[i] <- "present"
      actual[i] <- inventory$sha256[i]
      next
    }
    tmp <- tempfile()
    res <- tryCatch(get(inventory$url[i], tmp), error = function(e) e)
    if (!inherits(res, "error")) {
      actual[i] <- sha256_file(tmp)
      if (identical(actual[i], inventory$sha256[i])) {
        put(tmp, path)
        status[i] <- "downloaded"
      } else {
        keep <- file.path(ensure_dir(drift_dir), basename(path))
        file.copy(tmp, keep, overwrite = TRUE)
        status[i] <- "changed"
        message[i] <- paste("new file kept in", keep)
      }
      unlink(tmp)
      next
    }
    source_error <- conditionMessage(res)
    got <- !is.null(mirror) && isTRUE(tryCatch(mirror(inventory$mirror_name[i], tmp), error = function(e) FALSE))
    # A mirror copy with another hash is not used
    if (got && identical(sha256_file(tmp), inventory$sha256[i])) {
      put(tmp, path)
      status[i] <- "mirrored"
      actual[i] <- inventory$sha256[i]
      message[i] <- paste("source unreachable:", source_error)
    } else {
      status[i] <- "failed"
      message[i] <- source_error
    }
    unlink(tmp)
  }
  out <- inventory
  out$status <- status
  out$actual_sha256 <- actual
  out$message <- message
  out
}

# Downloads `url` to `path`; returns the ETag (or NA).
download_file <- function(url, path) {
  resp <- httr2::req_perform(pksr_request(url), path = path)
  httr2::resp_header(resp, "etag") %||% NA_character_
}

`%||%` <- function(x, y) if (is.null(x)) y else x
