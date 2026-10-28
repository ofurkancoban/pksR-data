# Run locally by the maintainer (needs GITHUB_PAT or GITHUB_TOKEN with
# repository write access): uploads every raw file in data-raw/ whose hash
# matches the registry and that the private mirror lacks. Use it after
# registering a new or republished file that CI could not download.
#   Rscript ci/mirror.R
source("ci/common.R")

repo <- Sys.getenv("GITHUB_REPOSITORY", "ofurkancoban/pksR-data")
inv <- raw_inventory()
missing <- inv$path[!file.exists(inv$path)]
if (length(missing)) cli::cli_warn("Not in data-raw/, so not uploaded: {.file {missing}}")
done <- mirror_upload(inv, repo)
cli::cli_inform("Uploaded {length(done)} file{?s} to the {.val {mirror_tag}} draft release of {repo}.")
