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
  csv <- unlist(lapply(split(panel, panel$year), function(d) {
    write_year_csv(d, file.path(dir, sprintf("pks_kreis_%d", unique(d$year))))
  }))
  unname(c(parquet, csv))
}

# One year as two CSV files: `<stem>.csv.gz` with the columns pksR 0.1.0
# reads, and `<stem>_details.csv.gz` with the row key and the detail columns
# (R/schema.R). Rows are in the same order in both.
write_year_csv <- function(d, stem) {
  main <- paste0(stem, ".csv.gz")
  details <- paste0(stem, "_details.csv.gz")
  readr::write_csv(d[setdiff(names(d), detail_columns)], main, na = "")
  readr::write_csv(d[c(detail_key, detail_columns)], details, na = "")
  c(main, details)
}
