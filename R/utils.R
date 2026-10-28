# Small helpers shared by the pipeline functions.

# Create a directory if needed and return its path, so it can be used inline.
ensure_dir <- function(path) {
  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE)
  }
  path
}

# Every step that can remove rows must say how many it removed and why
# (brief rule 7). Returns the data unchanged so it can sit in a pipe.
log_rows_removed <- function(n_before, n_after, reason) {
  removed <- n_before - n_after
  if (removed > 0) {
    cli::cli_inform("Removed {removed} row{?s}: {reason}")
  }
  invisible(removed)
}

# Parse numbers as printed by the BKA: "1.234" and "1 234" use a thousands
# separator, "," is the decimal mark, and "-" means "no value".
parse_german_number <- function(x) {
  x <- trimws(x)
  x[x %in% c("-", "")] <- NA_character_
  ok <- is.na(x) | grepl("^[0-9][0-9. ]*(,[0-9]+)?$", x)
  if (!all(ok)) {
    cli::cli_abort("Cannot parse as a German number: {.val {unique(x[!ok])}}")
  }
  x <- gsub("[. ]", "", x)
  as.numeric(sub(",", ".", x, fixed = TRUE))
}

# Numbers stored as spreadsheet text ("1234", "0.5", "1e-04"). Empty cells
# stay NA; any other text aborts, so a footnote marker or a shifted label
# column can never turn silently into NA.
as_number <- function(x, what) {
  x <- trimws(x)
  x[x %in% ""] <- NA_character_
  out <- suppressWarnings(as.numeric(x))
  bad <- !is.na(x) & is.na(out)
  if (any(bad)) {
    cli::cli_abort("{what}: cannot read {sum(bad)} value{?s} as numbers: {.val {utils::head(unique(x[bad]))}}")
  }
  out
}

# Convert to integer only when nothing is lost; counts must be whole numbers.
as_count <- function(x, what) {
  x <- as.numeric(x)
  bad <- !is.na(x) & (x != round(x) | x < 0)
  if (any(bad)) {
    cli::cli_abort("{what} contains {sum(bad)} non-integer or negative value{?s}: {.val {head(x[bad])}}")
  }
  as.integer(round(x))
}

# Inner join that refuses to lose rows of `x` (BUG-004): every row of `x`
# must find at least one partner in `y`. Several partners are allowed, which
# a split district needs.
join_checked <- function(x, y, by, what) {
  key_x <- if (is.null(names(by))) by else ifelse(names(by) == "", by, names(by))
  out <- dplyr::inner_join(x, y, by = by, relationship = "many-to-many")
  matched <- dplyr::semi_join(x, y, by = by)
  if (nrow(matched) != nrow(x)) {
    lost <- dplyr::anti_join(x, y, by = by)
    cli::cli_abort("Join of {what} loses {nrow(lost)} row{?s}; unmatched {.val {unique(do.call(paste, lost[key_x]))}}")
  }
  out
}
