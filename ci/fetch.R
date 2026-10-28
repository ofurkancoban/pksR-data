# Make every registered raw file available with its registered SHA-256:
# from the private mirror first (R/mirror.R), from the source URL only for
# files the mirror lacks. Files fetched from a source are added to the
# mirror. Changed or unreachable files stop the run: the pipeline only ever
# runs on registered files (brief Section 9.1.5). Republished files are
# detected by ci/discover.R through the landing pages.
source("ci/common.R")

repo <- Sys.getenv("GITHUB_REPOSITORY", "ofurkancoban/pksR-data")
inv <- raw_inventory()
mirror <- tryCatch(mirror_fetcher(repo), error = function(e) {
  cli::cli_warn("Mirror not available: {conditionMessage(e)}")
  NULL
})
res <- fetch_raw(inv, mirror = mirror)
write_ci(res, "fetch")
cli::cli_inform("Raw files: {paste(names(table(res$status)), table(res$status), collapse = ', ')}.")

new <- res[res$status == "downloaded", ]
if (nrow(new) > 0) {
  tryCatch(mirror_upload(new, repo), error = function(e) cli::cli_warn("Mirror upload failed: {conditionMessage(e)}"))
}
bad <- res[res$status %in% c("changed", "failed"), ]
if (nrow(bad) > 0) {
  cli::cli_abort(c("Raw files differ from the registry or could not be fetched:", paste(bad$registry, bad$label, bad$status, bad$message)))
}
