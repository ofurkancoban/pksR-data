# Appends the Zenodo DOI of a published release to its release notes.
# Usage (repository root):
#   Rscript ci/zenodo_doi.R          the release of this run (output/ci/release.json)
#   Rscript ci/zenodo_doi.R v2026.1  an earlier release
# Run by the pipeline job after a public release. Waits up to 15 minutes for
# Zenodo to archive the release (R/zenodo.R).
source("ci/common.R")

repo <- Sys.getenv("GITHUB_REPOSITORY", "ofurkancoban/pksR-data")
tag <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(tag)) {
  release <- jsonlite::read_json(file.path(ci_dir, "release.json"))
  if (!isTRUE(release$published) || !identical(release$mode, "publish")) {
    cli::cli_inform("No public release in this run; nothing to do.")
    quit(save = "no")
  }
  tag <- release$tag
}

doi <- zenodo_wait_for_doi(tag, timeout = 900)
r <- github_release_by_tag(repo, tag)
body <- release_body_with_doi(r$body, doi)
if (identical(body, r$body)) {
  cli::cli_inform("Release {.val {tag}} names its DOI {.val {doi}} already.")
} else {
  github_release_update_body(repo, r$id, body)
  cli::cli_inform("Release {.val {tag}}: DOI {.val {doi}} added to the notes.")
}
write_ci(list(tag = tag, doi = doi), "zenodo")
