# Usage: Rscript ci/release.R test|publish
#   test     draft prerelease "test-<version>-run<n>", visible only to
#            maintainers; checks the release mechanics end to end
#   publish  public release "v<version>", only when the data differ from the
#            latest published release
# Runs after targets::tar_make(), which builds output/release/ only when the
# validation gate passed.
source("ci/common.R")

mode <- commandArgs(trailingOnly = TRUE)[1]
if (!mode %in% c("test", "publish")) cli::cli_abort("Mode must be {.val test} or {.val publish}.")
repo <- Sys.getenv("GITHUB_REPOSITORY", "ofurkancoban/pksR-data")
commit <- Sys.getenv("GITHUB_SHA", system("git rev-parse HEAD", intern = TRUE))
dir <- "output/release"

version <- next_data_version(github_releases(repo)$tag_name)
manifest <- build_manifest(dir, version, commit)
result <- list(mode = mode, data_version = version, pipeline_commit = commit, tag = NA, published = FALSE)

if (mode == "publish" && !data_changed(manifest, latest_manifest(repo))) {
  result$reason <- "data identical to the latest published release"
  cli::cli_inform("No release: {result$reason}.")
} else {
  tag <- if (mode == "test") sprintf("test-%s-run%s", version, Sys.getenv("GITHUB_RUN_NUMBER", "local")) else paste0("v", version)
  if (mode == "test") manifest$data_version <- tag
  write_manifest(manifest, dir)
  body <- paste0(
    if (mode == "test") "Dry run of the release mechanics. Not a data release.\n\n" else "",
    "Data version: ", manifest$data_version, "\n",
    "Pipeline commit: ", commit, "\n",
    "Years: ", paste(manifest$years, collapse = " to "), ", target boundary: ", manifest$target_boundary_year, "\n",
    "Validation: ", paste(names(manifest$validation), unlist(manifest$validation), sep = " ", collapse = ", "), "\n\n",
    "Source: Bundeskriminalamt, Polizeiliche Kriminalstatistik. See README for attribution."
  )
  publish_release(dir, repo, tag, body, draft = mode == "test", prerelease = mode == "test", commit = commit)
  result$tag <- tag
  result$published <- TRUE
}
write_ci(result, "release")
