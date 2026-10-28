# Moves the registry to a newer BBSR crosswalk edition. Usage:
#   Rscript ci/update_crosswalk.R <url>
# Run by the crosswalk job of the pipeline workflow on a fresh checkout after
# ci/fetch.R. Downloads the edition, points registry/reference_sources.csv at
# it, regenerates registry/boundary_map.csv (update_boundary_map()) and
# writes the summary to output/ci/crosswalk.json. The workflow then builds
# and tests on the result and opens a pull request: the new rows are a
# territorial mapping and need the maintainer's review (brief Section 2,
# rule 9), so nothing reaches main without a merge.
source("ci/common.R")

url <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(url) || !nzchar(url)) cli::cli_abort("Usage: Rscript ci/update_crosswalk.R <url>")
file_name <- basename(sub("\\?.*$", "", url))
if (!grepl(bbsr_crosswalk_pattern, paste0("/", file_name))) cli::cli_abort("{.val {file_name}} is not a ref-kreise-1990-<year> file.")

ref_path <- "registry/reference_sources.csv"
ref <- readr::read_csv(ref_path, col_types = readr::cols(.default = "c"), na = "")
old_file <- ref$file_name[ref$label == "bbsr_ref_kreise"]
dest <- file.path(ensure_dir("data-raw/bbsr"), file_name)

# The same rule as for every raw file: two downloads must agree, so a cut-off
# transfer is not registered as the new edition
tmp1 <- tempfile(fileext = ".xlsx")
tmp2 <- tempfile(fileext = ".xlsx")
download_file(url, tmp1)
download_file(url, tmp2)
sha <- sha256_file(tmp1)
if (!identical(sha, sha256_file(tmp2))) cli::cli_abort("Two downloads of {.val {file_name}} differ; try again later.")
file.copy(tmp1, dest, overwrite = TRUE)

changes <- read_destatis_all(read_destatis_sources("registry/destatis_sources.csv"), "data-raw/destatis")
summary <- update_boundary_map(dest, "registry/boundary_map.csv", changes)
update_reference_source(ref_path, "bbsr_ref_kreise", url, sha, file_name)

summary$previous_file <- old_file
summary$file <- file_name
summary$url <- url
summary$sha256 <- sha
write_ci(summary, "crosswalk")
cli::cli_inform(c(
  "Crosswalk {.val {old_file}} -> {.val {file_name}}.",
  "i" = "Periods {summary$periods[1]} to {summary$periods[2]}, target boundary {summary$previous_target_year} -> {summary$target_year} ({summary$target_districts} districts).",
  "i" = "BBSR rows: {summary$bbsr$added} added, {summary$bbsr$changed} changed, {summary$bbsr$removed} removed."
))
