# Make every registered raw file available with its registered SHA-256:
# from the source first (bka.de through the Cloudflare Worker when
# PKSR_PROXY_URL and PKSR_PROXY_KEY are set), from the private mirror
# (R/mirror.R) when the source is unreachable. Every run therefore compares
# the source files with the registry. Files fetched from a source and
# missing in the mirror are added to it. A changed source file, or a file
# neither source nor mirror can give, stops the run (brief Section 9.1.5).
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
cli::cli_inform("bka.de requests {if (is.null(proxy_config())) 'go directly' else 'go through the Worker'}.")
fallback <- res[res$status == "mirrored", ]
if (nrow(fallback) > 0) {
  cli::cli_warn(c("Taken from the mirror because the source was unreachable:", paste(fallback$registry, fallback$label)))
}

# mirror_upload() skips files the mirror already holds
new <- res[res$status == "downloaded", ]
if (nrow(new) > 0) {
  tryCatch(mirror_upload(new, repo), error = function(e) cli::cli_warn("Mirror upload failed: {conditionMessage(e)}"))
}
bad <- res[res$status %in% c("changed", "failed"), ]
if (nrow(bad) > 0) {
  cli::cli_abort(c("Raw files differ from the registry or could not be fetched:", paste(bad$registry, bad$label, bad$status, bad$message)))
}
