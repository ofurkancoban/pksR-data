# Download every raw file of the four registries and compare its SHA-256
# with the registry. Changed or unreachable files stop the run: the
# pipeline only ever runs on registered files (brief Section 9.1.5).
source("ci/common.R")

res <- fetch_raw(raw_inventory(), refresh = isTRUE(as.logical(Sys.getenv("PKSR_REFRESH", "true"))))
write_ci(res, "fetch")
bad <- res[res$status %in% c("changed", "failed"), ]
cli::cli_inform("{sum(res$status %in% c('present', 'downloaded'))} of {nrow(res)} raw files match the registry.")
if (nrow(bad) > 0) {
  cli::cli_abort(c("Raw files differ from the registry or could not be fetched:", paste(bad$registry, bad$label, bad$status, bad$message)))
}
