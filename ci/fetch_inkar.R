# Refreshes the census-corrected population of the BBSR (INKAR) in
# registry/population_inkar.csv. Usage (repository root):
#   Rscript ci/fetch_inkar.R
# Run by the inkar job of the pipeline workflow, which opens a pull request
# when the snapshot changed (step outputs `changed` and `tag`, summary in
# output/ci/inkar.json), or by the maintainer.
#
# The INKAR interface answers POST requests with JSON, so its data cannot be
# a raw file with a fixed URL and hash like the BKA tables. The pipeline reads
# a committed snapshot instead, and registry/inkar_sources.csv records when it
# was retrieved and its SHA-256 (checked by test-population.R). Two downloads
# must agree, as for every raw file. Uses the CRAN package inkaR.
source("ci/common.R")

indicators <- c(population = "2", population_corrected = "5")   # M_ID: xbev, bev_korr
first_year <- 2002L   # PKS 2003 divides by the population of 31.12.2002

fetch <- function(m_id) {
  d <- inkaR::get_inkar_data(m_id, level = "KRE", year = first_year:as.integer(format(Sys.Date(), "%Y")), lang = "de", format = "long")
  if (is.null(d) || nrow(d) == 0) cli::cli_abort("INKAR returned no data for M_ID {m_id}.")
  tibble::tibble(ags = normalize_ags(d$Kennziffer), year = as.integer(d$Zeit), value = as.numeric(d$Wert))
}
download <- function() {
  parts <- lapply(names(indicators), function(n) stats::setNames(fetch(indicators[[n]]), c("ags", "year", n)))
  out <- join_checked(parts[[1]], parts[[2]], by = c("ags", "year"), what = "INKAR population and corrected population")
  out[order(out$year, out$ags), ]
}
a <- download()
b <- download()
if (!identical(a, b)) cli::cli_abort("Two INKAR downloads differ; try again later.")
if (anyNA(a) || anyDuplicated(a[c("ags", "year")])) cli::cli_abort("INKAR data have missing or duplicate rows.")

path <- "registry/population_inkar.csv"
src_path <- "registry/inkar_sources.csv"
tmp <- tempfile(fileext = ".csv")
readr::write_csv(a, tmp, na = "")
sha <- sha256_file(tmp)
old_sha <- if (file.exists(src_path)) readr::read_csv(src_path, col_types = readr::cols(.default = "c"))$sha256 else NA_character_

# Unchanged data: keep the registered snapshot and its retrieval date, so a
# scheduled run leaves no diff
if (identical(sha, old_sha)) {
  write_ci(list(changed = FALSE, sha256 = sha), "inkar")
  set_output("changed", "false")
  cli::cli_inform("INKAR data unchanged ({nrow(a)} rows, years {min(a$year)} to {max(a$year)}).")
  quit(save = "no")
}

old <- if (file.exists(path)) read_population_inkar(path) else a[0, ]
file.copy(tmp, path, overwrite = TRUE)
provenance <- tibble::tibble(
  file_name = basename(path),
  indicators = "xbev (M_ID 2): Bevoelkerung gesamt; bev_korr (M_ID 5): Bevoelkerung mit BBSR-Zensuskorrekturen",
  level = "KRE",
  years = paste(range(a$year), collapse = "-"),
  url = "https://www.inkar.de",
  retrieved_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  sha256 = sha,
  notes = "Population at 31.12. of each year, Kreise on the INKAR boundary; BBSR, dl-de/by-2-0. Retrieved with the R package inkaR."
)
readr::write_csv(provenance, src_path, na = "")
diff <- inkar_snapshot_diff(old, read_population_inkar(path))
write_ci(c(list(changed = TRUE, sha256 = sha, previous_sha256 = old_sha, years = range(a$year)), diff), "inkar")
set_output("changed", "true")
set_output("tag", sprintf("%d-%s", max(a$year), substr(sha, 1, 12)))
cli::cli_inform(c(
  "{nrow(a)} rows, {length(unique(a$ags))} districts, years {min(a$year)} to {max(a$year)}.",
  "i" = "Years added: {if (length(diff$years_added)) diff$years_added else 'none'}; rows revised: {diff$rows_changed}."
))
