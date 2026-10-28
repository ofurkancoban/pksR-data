# Offence key harmonization (brief Section 6.2) driven by
# registry/offence_map.csv. Every mapping there is a research decision and
# stays status "draft" until reviewed.
#
# `source_keys` lists, per harmonized key, which published key feeds it in
# which years: entries "EXPR@YEARS" separated by ";", YEARS as "2003-2007" or
# "2008-2009,2013", EXPR a published key or "KEY minus KEY". A key is never
# summed with its parent or child implicitly (BUG-013), and every published
# key must be mapped, so unknown keys stop the pipeline (Section 9.1.5).

offence_map_columns <- c(
  "offence_key_harmonized", "label_de", "label_en", "parent_key",
  "valid_from", "valid_to", "source_keys", "status", "notes",
  # Short names for pksR::pks_get(offence = ), drafts like the mappings
  # (notes/decisions.md, 2026-10-28)
  "alias_en", "alias_de"
)

read_offence_map <- function(path) {
  m <- readr::read_csv(path, col_types = readr::cols(.default = "c"), na = "")
  missing <- setdiff(offence_map_columns, names(m))
  if (length(missing) > 0) {
    cli::cli_abort("{.file {path}} lacks columns {.val {missing}}")
  }
  m$valid_from <- as.integer(m$valid_from)
  m$valid_to <- as.integer(m$valid_to)
  if (anyDuplicated(m$offence_key_harmonized)) {
    cli::cli_abort("Duplicate harmonized keys in {.file {path}}.")
  }
  if (!all(m$status %in% c("draft", "reviewed"))) {
    cli::cli_abort("Offence map status must be draft or reviewed.")
  }
  for (col in c("alias_en", "alias_de")) {
    a <- stats::na.omit(m[[col]])
    if (!all(grepl("^[a-z0-9_]+$", a)) || anyDuplicated(a)) {
      cli::cli_abort("{.field {col}} must be unique lowercase ASCII names with underscores.")
    }
  }
  if (!all(stats::na.omit(m$parent_key) %in% m$offence_key_harmonized)) {
    cli::cli_abort("Parent keys must be harmonized keys themselves.")
  }
  spec <- offence_spec(m)
  span <- stats::aggregate(year ~ offence_key_harmonized, spec, range)
  span <- span[match(m$offence_key_harmonized, span$offence_key_harmonized), ]
  if (!identical(unname(span$year[, 1]), m$valid_from) || !identical(unname(span$year[, 2]), m$valid_to)) {
    cli::cli_abort("valid_from and valid_to must match the years in source_keys.")
  }
  m[offence_map_columns]
}

parse_years <- function(x) {
  parts <- strsplit(x, ",", fixed = TRUE)[[1]]
  unlist(lapply(parts, function(p) {
    b <- as.integer(strsplit(p, "-", fixed = TRUE)[[1]])
    if (anyNA(b) || !length(b) %in% 1:2) {
      cli::cli_abort("Invalid year range {.val {p}} in offence map.")
    }
    seq(b[1], b[length(b)])
  }))
}

# Long form: one row per harmonized key and year, with the published key it
# comes from and, for differences, the key subtracted from it.
offence_spec <- function(map) {
  rows <- lapply(seq_len(nrow(map)), function(i) {
    entries <- strsplit(map$source_keys[i], ";", fixed = TRUE)[[1]]
    dplyr::bind_rows(lapply(trimws(entries), function(e) {
      at <- regexpr("@[^@]*$", e)
      if (at < 0) {
        cli::cli_abort("Offence map entry {.val {e}} lacks @YEARS.")
      }
      expr <- strsplit(substr(e, 1, at - 1), " minus ", fixed = TRUE)[[1]]
      if (!length(expr) %in% 1:2) {
        cli::cli_abort("Offence map entry {.val {e}} is not KEY or KEY minus KEY.")
      }
      tibble::tibble(
        offence_key_harmonized = map$offence_key_harmonized[i],
        year = parse_years(substr(e, at + 1, nchar(e))),
        plus_key = expr[1],
        minus_key = if (length(expr) == 2) expr[2] else NA_character_
      )
    }))
  })
  spec <- dplyr::bind_rows(rows)
  if (anyDuplicated(spec[c("offence_key_harmonized", "year")])) {
    cli::cli_abort("A harmonized key is defined twice for the same year.")
  }
  direct <- spec[is.na(spec$minus_key), ]
  if (anyDuplicated(direct[c("plus_key", "year")])) {
    cli::cli_abort("A published key feeds two harmonized keys in the same year.")
  }
  spec
}

harmonize_offences <- function(data, map) {
  year <- unique(data$year)
  spec <- offence_spec(map)
  spec <- spec[spec$year == year, ]
  published <- unique(data$offence_key)
  unknown <- setdiff(published, spec$plus_key[is.na(spec$minus_key)])
  if (length(unknown) > 0) {
    cli::cli_abort("{year}: offence key{?s} {.val {unknown}} not in registry/offence_map.csv.")
  }
  absent <- setdiff(stats::na.omit(c(spec$plus_key, spec$minus_key)), published)
  if (length(absent) > 0) {
    cli::cli_abort("{year}: offence map expects key{?s} {.val {absent}}, which the data lack.")
  }

  direct <- spec[is.na(spec$minus_key), ]
  out <- data[data$offence_key %in% direct$plus_key, ]
  out$offence_key <- direct$offence_key_harmonized[match(out$offence_key, direct$plus_key)]
  derived <- lapply(which(!is.na(spec$minus_key)), function(i) {
    difference_rows(data, spec[i, ], map)
  })
  out <- dplyr::bind_rows(out, derived)
  out <- as_harmonized(out)
  assert_harmonized(out)
  out[order(out$offence_key, out$ags), ]
}

# A key computed as the difference of two published keys (for example 890000
# in 2014 as ------ minus 725000). Case-based counts are additive; suspect
# counts are persons and are not (checked 2015 to 2025), so they become NA.
difference_rows <- function(data, spec_row, map) {
  plus <- data[data$offence_key == spec_row$plus_key, ]
  minus <- data[data$offence_key == spec_row$minus_key, ]
  minus <- minus[match(plus$ags, minus$ags), ]
  if (anyNA(minus$ags)) {
    cli::cli_abort("{spec_row$year}: key {spec_row$minus_key} is missing for some districts.")
  }
  out <- plus
  for (col in setdiff(harmonized_counts, "suspects")) {
    out[[col]] <- plus[[col]] - minus[[col]]
  }
  out$suspects <- NA_real_
  cases <- dplyr::coalesce(out$cases, out$cases_derived)
  cleared <- dplyr::coalesce(out$cleared, out$cleared_derived)
  out$hz <- cases / dplyr::coalesce(out$population, out$derived_population) * 1e5
  out$clearance_rate <- ifelse(cases > 0, cleared / cases * 100, 0)
  out$offence_key <- spec_row$offence_key_harmonized
  out$offence_key_published <- paste(spec_row$plus_key, "minus", spec_row$minus_key)
  out$offence_label <- map$label_de[map$offence_key_harmonized == spec_row$offence_key_harmonized]
  out
}

# Report for notes/offence_key_changes.md: keys per year and every key that
# appears, disappears or changes its published label between years.
offence_key_changes <- function(canonical) {
  d <- dplyr::bind_rows(lapply(canonical, function(x) unique(x[c("year", "offence_key", "offence_label")])))
  d$offence_label <- gsub("[[:space:]]+", " ", d$offence_label)
  years <- sort(unique(d$year))
  lines <- c(
    "# Offence key changes (generated)",
    "",
    "Generated by `offence_key_changes()` from the canonical extraction; do not edit by hand.",
    "Keys are shown as published. PDF years (2003 to 2012) print keys only, so no labels exist there.",
    "",
    "## Keys per year",
    "",
    paste0("| key | ", paste(years, collapse = " | "), " |"),
    paste0("|---|", paste(rep("---", length(years)), collapse = "|"), "|")
  )
  for (k in sort(unique(d$offence_key))) {
    present <- ifelse(years %in% d$year[d$offence_key == k], "x", "")
    lines <- c(lines, paste0("| `", k, "` | ", paste(present, collapse = " | "), " |"))
  }
  lines <- c(lines, "", "## Changes between consecutive years", "")
  for (i in seq_along(years)[-1]) {
    a <- d[d$year == years[i - 1], ]
    b <- d[d$year == years[i], ]
    new <- setdiff(b$offence_key, a$offence_key)
    gone <- setdiff(a$offence_key, b$offence_key)
    both <- intersect(a$offence_key, b$offence_key)
    relabel <- both[a$offence_label[match(both, a$offence_key)] != b$offence_label[match(both, b$offence_key)]]
    relabel <- relabel[!is.na(relabel)]
    if (length(c(new, gone, relabel)) == 0) next
    lines <- c(lines, paste0("### ", years[i - 1], " to ", years[i]), "")
    if (length(new) > 0) lines <- c(lines, paste0("- New: ", paste0("`", new, "`", collapse = ", ")))
    if (length(gone) > 0) lines <- c(lines, paste0("- Dropped: ", paste0("`", gone, "`", collapse = ", ")))
    for (k in relabel) {
      lines <- c(lines, paste0(
        "- Label of `", k, "`: \"", a$offence_label[a$offence_key == k], "\" becomes \"",
        b$offence_label[b$offence_key == k], "\""
      ))
    }
    lines <- c(lines, "")
  }
  lines
}

write_lines_file <- function(lines, path) {
  writeLines(lines, path, useBytes = TRUE)
  path
}
