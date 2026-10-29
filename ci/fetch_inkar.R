# Refreshes the census-corrected population of the BBSR (INKAR) in
# registry/population_inkar.csv. Usage (repository root, maintainer only):
#   Rscript ci/fetch_inkar.R
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
readr::write_csv(a, path, na = "")
provenance <- tibble::tibble(
  file_name = basename(path),
  indicators = "xbev (M_ID 2): Bevoelkerung gesamt; bev_korr (M_ID 5): Bevoelkerung mit BBSR-Zensuskorrekturen",
  level = "KRE",
  years = paste(range(a$year), collapse = "-"),
  url = "https://www.inkar.de",
  retrieved_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  sha256 = sha256_file(path),
  notes = "Population at 31.12. of each year, Kreise on the INKAR boundary; BBSR, dl-de/by-2-0. Retrieved with the R package inkaR."
)
readr::write_csv(provenance, "registry/inkar_sources.csv", na = "")
cli::cli_inform("{nrow(a)} rows, {length(unique(a$ags))} districts, years {min(a$year)} to {max(a$year)}.")
