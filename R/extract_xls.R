# Extraction of the Kreis case tables 2013 onward (xls and xlsx).
#
# All years carry the same 18 fields, but the position of district name and
# type differs (2013 has type before name), and some years add columns
# (2015: Sort; 2020: Sort, municipality code, name, population EW). Fields
# are identified by header text and cell content instead of position alone,
# and anything unexpected stops the pipeline (BUG-023).

# Header text expected above each fixed column (rows 5 to 8, lower case).
xls_header_patterns <- c(
  `1` = "schl", `2` = "straftat", `3` = "schl",
  `6` = "f(\u00e4|ae)lle", `7` = "hz", `8` = "versuch", `9` = "%",
  `10` = "gedroht", `11` = "schossen", `12` = "aufkl|f(\u00e4|ae)lle", `13` = "aq",
  `14` = "tat-? ?verd|tatver|gesamtzahl", `15` = "m(\u00e4|ae)nnlich", `16` = "weiblich",
  `17` = "nichtdeutsch|anzahl", `18` = "%"
)

# Extra columns that are known and either ignored or used.
xls_known_extra <- "^(sort|gemschl\\.?|gem|ew.*)$"

district_types <- c("KfS", "K", "LK", "SK", "RV")

extract_xls <- function(path, source) {
  sheet <- source$sheet
  if (!sheet %in% readxl::excel_sheets(path)) {
    cli::cli_abort("{.file {basename(path)}} has no sheet {.val {sheet}}")
  }
  raw <- suppressMessages(readxl::read_excel(path, sheet = sheet, col_names = FALSE, col_types = "text"))
  first <- source$skip_rows + 1L
  if (!identical(raw[[1]][first], "------")) {
    cli::cli_abort("{.file {basename(path)}}: row {first} does not start the table with {.val ------} (layout drift)")
  }
  header <- xls_header_text(raw, first)
  check_xls_header(header, basename(path))

  data <- raw[first:nrow(raw), ]
  is_row <- !is.na(data[[3]]) & grepl("^[0-9]{5}$", data[[3]])
  other <- data[!is_row, ]
  if (any(rowSums(!is.na(other)) > 0)) {
    cli::cli_abort("{.file {basename(path)}}: {sum(rowSums(!is.na(other)) > 0)} non-empty row{?s} without a district code")
  }
  log_rows_removed(nrow(data), sum(is_row), "empty rows below the table")
  data <- data[is_row, ]

  cols <- xls_name_type_columns(data, basename(path))
  population <- xls_population(data, header, basename(path))

  out <- data.frame(
    year = source$year,
    ags = data[[3]],
    region_name = data[[cols$name]],
    offence_key = data[[1]],
    offence_label = data[[2]],
    cases = as_number(data[[6]], "cases"),
    hz = as_number(data[[7]], "hz"),
    attempts = as_number(data[[8]], "attempts"),
    cleared = as_number(data[[12]], "cleared"),
    clearance_rate = as_number(data[[13]], "clearance_rate"),
    suspects = as_number(data[[14]], "suspects"),
    population = population,
    source_format = source$format,
    source_file = source$file_name,
    boundary_year = source$boundary_year,
    harmonized = FALSE,
    weight_type = "none",
    estimated = FALSE,
    stringsAsFactors = FALSE
  )
  # HZ is stored unrounded, so this reproduces the population behind it
  # exactly (checked against the 2020 EW column). Rows with 0 cases carry
  # no information about population and stay NA (BUG-014).
  has_info <- !is.na(out$hz) & out$hz > 0 & !is.na(out$cases) & out$cases > 0
  out$derived_population <- ifelse(has_info, out$cases / out$hz * 1e5, NA_real_)
  as_canonical(out)
}

xls_header_text <- function(raw, first) {
  rows <- max(1, first - 5):(first - 2)
  vapply(seq_along(raw), function(j) {
    txt <- paste(stats::na.omit(raw[[j]][rows]), collapse = " ")
    tolower(gsub("[[:space:]]+", " ", txt))
  }, character(1))
}

check_xls_header <- function(header, file) {
  for (j in names(xls_header_patterns)) {
    if (!grepl(xls_header_patterns[[j]], header[as.integer(j)])) {
      cli::cli_abort("{.file {file}}: column {j} header {.val {header[as.integer(j)]}} does not match {.val {xls_header_patterns[[j]]}} (layout drift)")
    }
  }
  extra <- header[-seq_len(18)]
  unknown <- extra[extra != "" & !grepl(xls_known_extra, extra)]
  if (length(unknown) > 0) {
    cli::cli_abort("{.file {file}}: unknown extra column{?s} {.val {unknown}}")
  }
}

# Name and type are columns 4 and 5 in some order; the type column holds
# only the abbreviations listed in the table legend.
xls_name_type_columns <- function(data, file) {
  # Empty type cells occur (2014: the block of one offence key), so only
  # non-empty values are checked; the name column is never empty.
  is_type <- vapply(4:5, function(j) {
    v <- data[[j]]
    mean(!is.na(v)) > 0.9 && all(v[!is.na(v)] %in% district_types)
  }, logical(1))
  if (sum(is_type) != 1) {
    cli::cli_abort("{.file {file}}: cannot tell district name from type in columns 4 and 5")
  }
  list(type = (4:5)[is_type], name = (4:5)[!is_type])
}

# Only the 2020 table publishes population (EW 31.12.2019).
xls_population <- function(data, header, file) {
  ew <- which(grepl("^ew", header))
  if (length(ew) == 0) {
    return(rep(NA_real_, nrow(data)))
  }
  code <- which(grepl("^gemschl", header))
  if (length(ew) != 1 || length(code) != 1 || !all(data[[code]] == data[[3]])) {
    cli::cli_abort("{.file {file}}: population column does not line up with the district codes")
  }
  as_number(data[[ew]], "population")
}
