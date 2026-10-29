# Validation: a per-year check of each extraction, and the gate of brief
# Section 7 on the harmonized panel.

validate_extraction <- function(data, expected_codes) {
  assert_canonical(data)
  year <- unique(data$year)
  if (length(year) != 1) {
    cli::cli_abort("One extraction must hold exactly one year.")
  }

  # Coverage: the published district set equals the crosswalk set of the
  # declared boundary year (known issues 3 and 6, BUG-019).
  codes <- unique(data$ags)
  missing <- setdiff(expected_codes, codes)
  unknown <- setdiff(codes, expected_codes)
  if (length(missing) > 0 || length(unknown) > 0) {
    cli::cli_abort(c(
      "{year}: district set differs from boundary {unique(data$boundary_year)}.",
      "x" = "Missing: {.val {missing}}",
      "x" = "Unknown: {.val {unknown}}"
    ))
  }
  if (!all(c("11000", "02000") %in% codes)) {
    cli::cli_abort("{year}: Berlin or Hamburg missing.")
  }

  # Every offence key covers every district: a key missing for some
  # districts would mean rows were lost during parsing.
  per_key <- table(data$offence_key)
  if (any(per_key != length(codes))) {
    cli::cli_abort("{year}: offence keys {.val {names(per_key)[per_key != length(codes)]}} do not cover all districts.")
  }

  # Plausibility
  counts <- c("cases", "attempts", "cleared", "suspects")
  if (any(vapply(data[counts], function(x) any(x < 0, na.rm = TRUE), logical(1)))) {
    cli::cli_abort("{year}: negative counts.")
  }
  if (any(data$attempts > data$cases, na.rm = TRUE)) {
    cli::cli_abort("{year}: attempts exceed cases.")
  }
  # Cleared cases may exceed recorded cases (AQ > 100): PKS counts cases
  # cleared this year that were recorded in earlier years. The published
  # tables contain such values (2003: LK Haßberge, key 7300, AQ 105.0).
  if (any(data$clearance_rate < 0, na.rm = TRUE)) {
    cli::cli_abort("{year}: negative clearance rate.")
  }
  pop <- dplyr::coalesce(data$population, data$derived_population)
  district_pop <- tapply(pop, data$ags, function(x) stats::median(x, na.rm = TRUE))
  med <- stats::median(district_pop, na.rm = TRUE)
  if (is.na(med) || med < 5e4 || med > 4e5) {
    cli::cli_warn("{year}: median district population {format(med, big.mark = ',')} is outside 50,000 to 400,000 (known issue 10).")
  }
  invisible(data)
}

# Every year in the registry must produce output (brief Section 7.7).
assert_year_completeness <- function(sources, files) {
  produced <- as.integer(sub("^pks_kreis_([0-9]{4})\\.parquet$", "\\1", basename(files)))
  missing <- setdiff(sources$year, produced)
  if (length(missing) > 0) {
    cli::cli_abort("No output for registry year{?s} {.val {missing}}.")
  }
  invisible(TRUE)
}

# --- Gate on the harmonized panel (brief Section 7) -------------------------

# Each check returns NULL when it passes, or a character vector of problems.
gate_checks <- list(
  schema = function(panel, ctx) {
    problems <- vapply(split(panel, panel$year), function(d) {
      msg <- tryCatch({ assert_harmonized(d); "" }, error = function(e) conditionMessage(e))
      msg
    }, character(1))
    problems <- problems[problems != ""]
    if (length(problems)) paste0(names(problems), ": ", problems)
  },
  uniqueness = function(panel, ctx) {
    dup <- duplicated(panel[c("year", "ags", "offence_key")])
    if (any(dup)) sprintf("%d duplicate year, ags, offence_key rows", sum(dup))
  },
  coverage = function(panel, ctx) {
    out <- character(0)
    for (y in sort(unique(panel$year))) {
      codes <- unique(panel$ags[panel$year == y])
      if (!setequal(codes, ctx$target_codes)) {
        out <- c(out, sprintf("%d: %d districts, expected %d for boundary %d", y, length(codes), length(ctx$target_codes), ctx$target_year))
      }
      if (!all(c("11000", "02000") %in% codes)) out <- c(out, sprintf("%d: Berlin or Hamburg missing", y))
      per_key <- table(panel$offence_key[panel$year == y])
      if (any(per_key != length(codes))) out <- c(out, sprintf("%d: keys not covering all districts: %s", y, paste(names(per_key)[per_key != length(codes)], collapse = ", ")))
    }
    if (length(out)) out
  },
  aggregation = function(panel, ctx) {
    # Published keys only: a derived key (890000 in 2014) has no Bund row.
    # Bound: Bund minus cases with unknown place minus a small slack <=
    # districts <= Bund (R/national.R).
    if (is.null(ctx$national)) return(structure("no Bund source registered", skipped = TRUE))
    sums <- dplyr::summarise(
      dplyr::group_by(panel[panel$offence_key_published == panel$offence_key, ], year, offence_key),
      districts = sum(dplyr::coalesce(cases, cases_derived)), .groups = "drop"
    )
    sums <- sums[sums$year %in% ctx$national$year, ]
    m <- dplyr::left_join(sums, ctx$national, by = c("year", "offence_key"))
    out <- character(0)
    missing <- m[is.na(m$cases), ]
    if (nrow(missing)) out <- sprintf("%d %s: key not in the Bund table", missing$year, missing$offence_key)
    m <- m[!is.na(m$cases), ]
    slack <- national_slack(m$cases)
    bad <- m[m$districts > m$cases + 1e-9 | m$districts < m$cases - m$cases_unknown_place - slack, ]
    if (nrow(bad)) {
      out <- c(out, sprintf("%d %s: districts %.0f outside [%.0f, %.0f]", bad$year, bad$offence_key,
                            bad$districts, bad$cases - bad$cases_unknown_place, bad$cases))
    }
    if (length(out)) out
  },
  conservation = function(panel, ctx) {
    out <- character(0)
    for (d in ctx$canonical) {
      y <- unique(d$year)
      h <- panel[panel$year == y & panel$offence_key_published %in% unique(d$offence_key), ]
      a <- dplyr::summarise(dplyr::group_by(d, offence_key), dplyr::across(dplyr::all_of(harmonized_counts), ~ sum(as.numeric(.x))), .groups = "drop")
      b <- dplyr::summarise(dplyr::group_by(h, offence_key = offence_key_published), dplyr::across(dplyr::all_of(harmonized_counts), ~ sum(.x)), .groups = "drop")
      ab <- dplyr::full_join(a, b, by = "offence_key", suffix = c("", "_h"))
      for (col in harmonized_counts) {
        x <- ab[[col]]; z <- ab[[paste0(col, "_h")]]
        bad <- xor(is.na(x), is.na(z)) | (!is.na(x) & !is.na(z) & abs(x - z) > 1e-9 * pmax(abs(x), 1))
        if (any(bad)) out <- c(out, sprintf("%d %s %s: %s before, %s after", y, ab$offence_key[bad], col, x[bad], z[bad]))
      }
    }
    if (length(out)) out
  },
  plausibility = function(panel, ctx) {
    out <- character(0)
    tol <- 1e-9
    for (col in harmonized_counts) {
      n <- sum(panel[[col]] < -tol, na.rm = TRUE)
      if (n) out <- c(out, sprintf("%s: %d negative values", col, n))
    }
    n <- sum(panel$attempts > panel$cases + tol, na.rm = TRUE)
    if (n) out <- c(out, sprintf("%d rows with attempts above cases", n))
    n <- sum(panel$hz < 0 | panel$clearance_rate < 0, na.rm = TRUE)
    if (n) out <- c(out, sprintf("%d rows with negative rates", n))
    if (length(out)) out
  },
  population = function(panel, ctx) {
    pop <- unique(panel[c("year", "ags", "population", "derived_population")])
    pop$value <- dplyr::coalesce(pop$population, pop$derived_population)
    med <- tapply(pop$value, pop$year, stats::median, na.rm = TRUE)
    bad <- med[is.na(med) | med < 5e4 | med > 4e5]
    if (length(bad)) structure(sprintf("%s: median district population %s", names(bad), format(bad, big.mark = ",")), warning_only = TRUE)
  },
  # Census-corrected population (R/population.R): present for every row and
  # within 15 percent of the population behind the HZ. The largest census
  # corrections of single districts are below 10 percent.
  corrected_population = function(panel, ctx) {
    pop <- unique(panel[c("year", "ags", "population", "derived_population", "population_corrected")])
    base <- dplyr::coalesce(pop$population, pop$derived_population)
    out <- character(0)
    n <- sum(is.na(pop$population_corrected) | pop$population_corrected <= 0)
    if (n) out <- sprintf("%d district-years without a positive corrected population", n)
    far <- which(abs(pop$population_corrected / base - 1) > 0.15)
    if (length(far)) out <- c(out, sprintf("%d %s: corrected %.0f, population %.0f", pop$year[far], pop$ags[far], pop$population_corrected[far], base[far]))
    if (length(out)) out
  },
  year_completeness = function(panel, ctx) {
    missing <- setdiff(ctx$years, unique(panel$year))
    if (length(missing)) sprintf("no output for registry year %d", missing)
  }
)

# Run every check, write a machine-readable report, stop on failure. A
# population median outside 50,000 to 400,000 only warns (Section 7.6).
validation_gate <- function(panel, ctx, report_path) {
  results <- lapply(names(gate_checks), function(name) {
    res <- gate_checks[[name]](panel, ctx)
    status <- if (is.null(res)) "pass" else if (isTRUE(attr(res, "skipped"))) "skipped" else if (isTRUE(attr(res, "warning_only"))) "warn" else "fail"
    list(check = name, status = status, problems = if (is.null(res)) list() else as.list(as.character(res)))
  })
  report <- list(
    weights = unique(panel$weight_type[panel$weight_type != "none"]),
    target_boundary_year = ctx$target_year,
    years = range(panel$year),
    rows = nrow(panel),
    # Years whose district sums were compared with a Bund table (Section 7.4)
    national_years = if (is.null(ctx$national)) list() else as.list(sort(unique(ctx$national$year))),
    checks = results
  )
  ensure_dir(dirname(report_path))
  jsonlite::write_json(report, report_path, auto_unbox = TRUE, pretty = TRUE)
  status <- vapply(results, `[[`, "", "status")
  for (r in results[status == "warn"]) cli::cli_warn(c("Validation warning: {r$check}", unlist(r$problems)))
  if (any(status == "fail")) {
    failed <- results[status == "fail"]
    cli::cli_abort(c(
      "Validation gate failed: {.val {vapply(failed, `[[`, '', 'check')}}. Report: {.file {report_path}}",
      unlist(lapply(failed, function(r) utils::head(unlist(r$problems), 5)))
    ))
  }
  report_path
}

read_known_breaks <- function(path) {
  b <- readr::read_csv(path, col_types = readr::cols(.default = "c"), na = "")
  needed <- c("break_id", "first_year", "offence_key", "variable", "type", "comparable", "description", "evidence", "status")
  if (!identical(names(b), needed) || anyDuplicated(b$break_id) || !all(b$status %in% c("draft", "reviewed")) ||
      !all(b$comparable %in% c("yes", "likely", "no", "unknown"))) {
    cli::cli_abort("{.file {path}} does not follow the known_breaks layout.")
  }
  b$first_year <- as.integer(b$first_year)
  b
}
