# Dispatch from a registry row to its extractor. The raw file must be the
# one recorded in the registry, so a silently replaced file never feeds the
# pipeline.

extract_source <- function(source, path) {
  verify_sha256(path, source$sha256)
  parser <- switch(source$parser,
    extract_pdf = extract_pdf,
    extract_xls = extract_xls,
    cli::cli_abort("Unknown parser {.val {source$parser}}")
  )
  data <- parser(path, source)
  if (!identical(unique(data$year), source$year)) {
    cli::cli_abort("Extractor returned the wrong year for {.file {basename(path)}}.")
  }
  data
}

write_canonical <- function(data, dir) {
  path <- file.path(ensure_dir(dir), sprintf("pks_kreis_%d.parquet", unique(data$year)))
  arrow::write_parquet(data, path)
  path
}

# Notes a reader must see when loading the panel. They are stored in the
# Parquet metadata (key "pksR_notes") so that pksR::pks_get() can print them.
panel_notes <- c(
  clearance_rate_zero_cases = paste(
    "clearance_rate is 0 where cases are 0. This follows the BKA tables and is",
    "not a real rate: some of these rows have cleared > 0 (cases recorded in",
    "earlier years). The 2022 table leaves these cells empty; they are set to 0",
    "for consistency."
  )
)

# Harmonized panel: one Parquet file per weighting, plus one CSV.gz per year.
write_panel <- function(panel, weights, dir) {
  dir <- ensure_dir(file.path(dir, weights))
  panel <- panel[order(panel$year, panel$offence_key, panel$ags), ]
  parquet <- file.path(dir, "pks_kreis_panel.parquet")
  table <- arrow::arrow_table(panel)
  table$metadata$pksR_notes <- jsonlite::toJSON(as.list(panel_notes), auto_unbox = TRUE)
  arrow::write_parquet(table, parquet)
  csv <- vapply(split(panel, panel$year), function(d) {
    path <- file.path(dir, sprintf("pks_kreis_%d.csv.gz", unique(d$year)))
    readr::write_csv(d, path, na = "")
    path
  }, character(1))
  unname(c(parquet, csv))
}
