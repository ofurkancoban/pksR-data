# Polite downloads of registry sources (BUG-025): URLs only from the
# registry, a descriptive User-Agent, retries, one request per two seconds,
# and a SHA-256 check against the registry.

pksr_user_agent <- "pksR-data (R pipeline for German Police Crime Statistics; https://github.com/ofurkancoban)"

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
      "i" = "If the BKA republished the file, record the new hash in registry/sources.csv."
    ))
  }
  invisible(actual)
}

# Downloads one registry row to `dest_dir` and returns what the registry
# should record. The file is only kept when its hash matches, unless
# `accept_new_hash = TRUE` (used when the BKA republishes a file).
download_source <- function(source, dest_dir, accept_new_hash = FALSE) {
  dest <- file.path(ensure_dir(dest_dir), source$file_name)
  tmp <- tempfile(fileext = paste0(".", source$format))
  on.exit(unlink(tmp), add = TRUE)

  resp <- httr2::request(source$url) |>
    httr2::req_user_agent(pksr_user_agent) |>
    httr2::req_retry(max_tries = 3) |>
    httr2::req_throttle(capacity = 1, fill_time_s = 2) |>
    httr2::req_perform(path = tmp)

  sha <- if (accept_new_hash) sha256_file(tmp) else verify_sha256(tmp, source$sha256)
  file.copy(tmp, dest, overwrite = TRUE)
  list(
    file = dest,
    sha256 = sha,
    etag = httr2::resp_header(resp, "etag") %||% NA_character_,
    retrieved_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
}

`%||%` <- function(x, y) if (is.null(x)) y else x
