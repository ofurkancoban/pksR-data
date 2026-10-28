# Canonical long-format schema (brief Section 5.2) and its assertions.
#
# Every extractor ends with as_canonical(), so all years share one column set
# and one set of types (BUG-007). Additions to the brief's schema (listed in
# notes/decisions.md):
#   population       published population (PDF years and 2020); neither a
#                    count nor derived.
#   cases_derived    PDF years only: hz * population / 1e5 (Q1). Published
#   cleared_derived  counts and derived counts never share a column.

canonical_spec <- c(
  year = "integer",
  ags = "character",
  region_name = "character",
  offence_key = "character",
  offence_label = "character",
  cases = "integer",
  attempts = "integer",
  hz = "double",
  cleared = "integer",
  clearance_rate = "double",
  suspects = "integer",
  cases_derived = "double",
  cleared_derived = "double",
  population = "double",
  source_format = "character",
  source_file = "character",
  boundary_year = "integer",
  harmonized = "logical",
  weight_type = "character",
  estimated = "logical",
  derived_population = "double"
)

count_columns <- c("cases", "attempts", "cleared", "suspects")

# Everything that is moved with crosswalk weights during harmonization.
harmonized_counts <- c(count_columns, "cases_derived", "cleared_derived")

# Harmonized panel: offence_key is the harmonized key and the published key
# moves to offence_key_published. Counts become double because splitting a
# district with population or area weights yields fractional cases; rounding
# would break conservation of national totals (Section 7.5).
harmonized_spec <- local({
  spec <- canonical_spec
  spec[count_columns] <- "double"
  at <- match("offence_key", names(spec))
  c(spec[seq_len(at)], offence_key_published = "character", spec[-seq_len(at)])
})

# Normalize district codes to 5-digit, zero-padded character strings
# (known issue 1). BBSR uses 7 or 8 digits (district code plus "000").
normalize_ags <- function(x) {
  x <- trimws(as.character(x))
  if (any(is.na(x)) || !all(grepl("^[0-9]+$", x))) {
    cli::cli_abort("AGS codes must be digits only: {.val {unique(x[is.na(x) | !grepl('^[0-9]+$', x)])}}")
  }
  long <- nchar(x) %in% c(7, 8)
  if (any(long & !endsWith(x, "000"))) {
    cli::cli_abort("A 7 or 8 digit code is not a district code: {.val {unique(x[long & !endsWith(x, '000')])}}")
  }
  x[long] <- substr(x[long], 1, nchar(x[long]) - 3)
  if (!all(nchar(x) %in% c(4, 5))) {
    cli::cli_abort("Unexpected AGS length: {.val {unique(x[!nchar(x) %in% c(4, 5)])}}")
  }
  formatC(as.integer(x), width = 5, flag = "0")
}

# Add missing columns as typed NA, coerce types, order columns. Unknown
# columns are an error: silently carrying them would hide drift.
as_schema <- function(data, spec, what) {
  extra <- setdiff(names(data), names(spec))
  if (length(extra) > 0) {
    cli::cli_abort("Columns outside the {what} schema: {.val {extra}}")
  }
  for (col in names(spec)) {
    type <- spec[[col]]
    if (!col %in% names(data)) {
      data[[col]] <- methods::as(rep(NA, nrow(data)), type)
    } else if (type == "integer") {
      data[[col]] <- as_count(data[[col]], col)
    } else {
      data[[col]] <- methods::as(data[[col]], type)
    }
  }
  data$ags <- normalize_ags(data$ags)
  tibble::as_tibble(data[names(spec)])
}

assert_schema <- function(data, spec, what) {
  if (!identical(names(data), names(spec))) {
    cli::cli_abort("Columns differ from the {what} schema.")
  }
  types <- vapply(data, typeof, character(1))
  bad <- names(types)[types != spec[names(types)]]
  if (length(bad) > 0) {
    cli::cli_abort("Wrong column types: {.val {bad}}")
  }
  if (!all(grepl("^[0-9]{5}$", data$ags))) {
    cli::cli_abort("AGS codes must have exactly 5 digits.")
  }
  dup <- duplicated(data[c("year", "ags", "offence_key")])
  if (any(dup)) {
    cli::cli_abort("{sum(dup)} duplicate year, ags, offence_key row{?s}.")
  }
  invisible(data)
}

as_canonical <- function(data) as_schema(data, canonical_spec, "canonical")
assert_canonical <- function(data) assert_schema(data, canonical_spec, "canonical")
as_harmonized <- function(data) as_schema(data, harmonized_spec, "harmonized")
assert_harmonized <- function(data) assert_schema(data, harmonized_spec, "harmonized")
