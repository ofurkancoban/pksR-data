# Reading registry/sources.csv. Every source URL lives in this file; nothing
# is built from templates (brief Section 5.1, BUG-025).

sources_columns <- c(
  "year", "table_id", "format", "url", "landing_page", "encoding",
  "skip_rows", "sheet", "sha256", "etag", "retrieved_at", "parser", "notes",
  # Additions to the brief's contract (listed for review in decisions.md):
  "file_name", "pages", "boundary_year"
)

read_sources <- function(path) {
  s <- readr::read_csv(path, col_types = readr::cols(.default = "c"), na = "")
  missing <- setdiff(sources_columns, names(s))
  if (length(missing) > 0) {
    cli::cli_abort("{.file {path}} lacks columns {.val {missing}}")
  }
  s$year <- as.integer(s$year)
  s$skip_rows <- as.integer(s$skip_rows)
  s$boundary_year <- as.integer(s$boundary_year)
  if (anyDuplicated(s$year)) {
    cli::cli_abort("Duplicate years in {.file {path}}")
  }
  if (!all(s$parser %in% c("extract_pdf", "extract_xls"))) {
    cli::cli_abort("Unknown parser in {.file {path}}")
  }
  s[order(s$year), sources_columns]
}

# "253-259" -> 253:259
parse_pages <- function(pages) {
  if (is.na(pages) || !grepl("^[0-9]+-[0-9]+$", pages)) {
    cli::cli_abort("Invalid page range {.val {pages}}")
  }
  bounds <- as.integer(strsplit(pages, "-", fixed = TRUE)[[1]])
  seq(bounds[1], bounds[2])
}
