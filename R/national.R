# National (Bund) case tables, used only by the validation gate (brief
# Section 7.4). Registry: registry/bund_sources.csv, one row per year.
#
# The Kreis tables do not add up to the Bund table exactly: cases whose place
# of offence is unknown are counted nationally but mostly not in a district.
# The documented tolerance is therefore a bound: national total minus the
# "unbekannt" column of the Tatortverteilung <= sum over districts <= national
# total. Verified for all 538 key-years 2013 to 2025: the upper bound always
# holds; the lower bound misses by at most 17 cases (2021, 630000: 0.064
# percent) in 6 key-years, so it gets the slack below (notes/decisions.md).

national_slack <- function(bund_cases) pmax(5, 0.001 * bund_cases)

bund_sources_columns <- c(
  "year", "table_id", "format", "url", "landing_page", "sha256", "etag",
  "retrieved_at", "file_name", "sheet", "notes"
)

read_bund_sources <- function(path) {
  s <- readr::read_csv(path, col_types = readr::cols(.default = "c"), na = "")
  if (!identical(names(s), bund_sources_columns)) {
    cli::cli_abort("{.file {path}} does not follow the bund_sources layout.")
  }
  s$year <- as.integer(s$year)
  if (anyDuplicated(s$year) || anyNA(s$url) || anyNA(s$sha256)) {
    cli::cli_abort("{.file {path}}: one row per year with URL and hash required.")
  }
  s[order(s$year), ]
}

# Columns are found by header text below the title rows; the row of column
# numbers (1, 2, 3, ...) ends the header.
extract_bund <- function(path, source) {
  verify_sha256(path, source$sha256)
  sheet <- if (is.na(source$sheet)) 1 else source$sheet
  raw <- suppressMessages(readxl::read_excel(path, sheet = sheet, col_names = FALSE, col_types = "text"))
  numbers <- which(raw[[1]] == "1" & raw[[2]] == "2")
  if (length(numbers) != 1) {
    cli::cli_abort("{.file {basename(path)}}: cannot find the column-number row.")
  }
  header <- vapply(seq_along(raw), function(j) {
    txt <- tolower(gsub("[[:space:]]+", " ", paste(stats::na.omit(raw[[j]][3:(numbers - 1)]), collapse = " ")))
    # Words split across header rows ("unbe-" / "kannt" in 2014)
    gsub("([[:lower:]])- ([[:lower:]])", "\\1\\2", txt)
  }, character(1))
  find <- function(pattern) {
    j <- which(grepl(pattern, header))
    if (length(j) != 1) {
      cli::cli_abort("{.file {basename(path)}}: {length(j)} columns match {.val {pattern}} (layout drift).")
    }
    j
  }
  j_cases <- find("erfasste f(\u00e4|ae)lle$|^(anzahl )?erfasste f(\u00e4|ae)lle( anzahl)?$")
  j_unknown <- find("unbekannt")
  data <- raw[(numbers + 1):nrow(raw), ]
  keep <- !is.na(data[[1]]) & !is.na(data[[j_cases]])
  log_rows_removed(nrow(data), sum(keep), "rows without offence key or case count (footnotes)")
  data <- data[keep, ]
  tibble::tibble(
    year = source$year,
    offence_key = data[[1]],
    cases = as_count(as_number(data[[j_cases]], "national cases"), "national cases"),
    cases_unknown_place = as_count(as_number(data[[j_unknown]], "national cases with unknown place"), "national cases with unknown place")
  )
}
