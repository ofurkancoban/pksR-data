# Polite downloads of registry sources (BUG-025): URLs only from the
# registries, a descriptive User-Agent, retries, one request per two seconds
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

pksr_request <- function(url) {
  httr2::request(url) |>
    httr2::req_user_agent(pksr_user_agent) |>
    httr2::req_retry(max_tries = 3) |>
    httr2::req_throttle(capacity = 1, fill_time_s = 2)
}

# Every raw file the pipeline reads, from the four registries, with the
# folder it belongs in below `raw_dir`.
raw_inventory <- function(registry_dir = "registry", raw_dir = "data-raw") {
  read <- function(name) readr::read_csv(file.path(registry_dir, name), col_types = readr::cols(.default = "c"), na = "")
  part <- function(d, registry, label, sub) {
    tibble::tibble(
      registry = registry, label = label, url = d$url, sha256 = d$sha256,
      path = file.path(raw_dir, sub, d$file_name)
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
  inv
}

# Makes every file of the inventory available with the registered hash.
# A file already present with the right hash is kept (unless `refresh`).
# A download whose hash differs is never put in place of the registered
# file: it goes to `drift_dir` and is reported, so the pipeline keeps
# running on registered data only and the maintainer decides.
# Returns one row per file: status "present", "downloaded", "changed" or
# "failed".
fetch_raw <- function(inventory, refresh = FALSE, drift_dir = "data-raw/_drift", get = download_file) {
  status <- character(nrow(inventory))
  actual <- rep(NA_character_, nrow(inventory))
  message <- rep(NA_character_, nrow(inventory))
  for (i in seq_len(nrow(inventory))) {
    path <- inventory$path[i]
    if (!refresh && file.exists(path) && identical(sha256_file(path), inventory$sha256[i])) {
      status[i] <- "present"
      actual[i] <- inventory$sha256[i]
      next
    }
    tmp <- tempfile()
    res <- tryCatch(get(inventory$url[i], tmp), error = function(e) e)
    if (inherits(res, "error")) {
      status[i] <- "failed"
      message[i] <- conditionMessage(res)
      next
    }
    actual[i] <- sha256_file(tmp)
    if (identical(actual[i], inventory$sha256[i])) {
      ensure_dir(dirname(path))
      file.copy(tmp, path, overwrite = TRUE)
      status[i] <- "downloaded"
    } else {
      keep <- file.path(ensure_dir(drift_dir), basename(path))
      file.copy(tmp, keep, overwrite = TRUE)
      status[i] <- "changed"
      message[i] <- paste("new file kept in", keep)
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
