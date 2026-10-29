# Territorial harmonization (brief Section 6.1).
#
# Counts are moved from the published boundary to the target boundary with
# the crosswalk weights; rates are never weighted but recomputed afterwards.
# Population is one value per district and year, harmonized once and joined
# back, so zero-case rows cannot shrink a merged population (BUG-014).

# Compose the yearly BBSR steps into one map from the boundary of
# `from_year` to the boundary of `to_year` (forward only).
compose_crosswalk <- function(map, from_year, to_year, weights = c("population", "area")) {
  weights <- match.arg(weights)
  if (to_year < from_year) {
    cli::cli_abort("Only forward harmonization is supported ({from_year} to {to_year}).")
  }
  w_col <- paste0("weight_", weights)
  codes <- boundary_codes(map, from_year)
  cw <- tibble::tibble(from_ags = codes, to_ags = codes, weight = 1)
  for (p in seq_len(to_year - from_year) + from_year - 1L) {
    step <- map[map$period == p, c("from_ags", "to_ags", w_col)]
    if (nrow(step) == 0) {
      cli::cli_abort("The crosswalk has no period {p}-{p + 1} (BUG-018).")
    }
    names(step) <- c("mid_ags", "next_ags", "w")
    names(cw)[2] <- "mid_ags"
    cw <- join_checked(cw, step, by = "mid_ags", what = paste("crosswalk period", p))
    cw <- dplyr::summarise(
      dplyr::group_by(cw, from_ags, to_ags = next_ags),
      weight = sum(weight * w), .groups = "drop"
    )
  }
  cw
}

# One population value per district: the published population where it
# exists, otherwise the derived population of the total-crime row, which has
# the most cases and therefore the least rounding in HZ.
district_population <- function(data) {
  by_ags <- split(data, data$ags)
  rows <- lapply(by_ags, function(d) {
    pop <- unique(d$population)
    if (length(pop) != 1) {
      cli::cli_abort("District {d$ags[1]}: published population differs between offence keys.")
    }
    corrected <- unique(d$population_corrected)
    if (length(corrected) != 1) {
      cli::cli_abort("District {d$ags[1]}: corrected population differs between offence keys.")
    }
    total <- d$derived_population[d$offence_key %in% c("------", "----")]
    derived <- if (length(total) == 1 && !is.na(total)) total else stats::median(d$derived_population, na.rm = TRUE)
    tibble::tibble(ags = d$ags[1], population = pop, derived_population = if (is.na(derived)) NA_real_ else derived,
                   population_corrected = corrected)
  })
  dplyr::bind_rows(rows)
}

# Weighted sum that keeps NA as NA: a missing value in one source district
# must not turn into an undercount of the target district.
sum_weighted <- function(x, w) {
  if (anyNA(x)) NA_real_ else sum(x * w)
}

harmonize_space <- function(data, map, target, weights = c("population", "area")) {
  weights <- match.arg(weights)
  from_year <- unique(data$boundary_year)
  if (length(from_year) != 1) {
    cli::cli_abort("Data to harmonize must have one boundary year.")
  }
  cw <- compose_crosswalk(map, from_year, target, weights)

  unmatched <- setdiff(unique(data$ags), cw$from_ags)
  if (length(unmatched) > 0) {
    # Never silent (Section 6.1.7): the validation gate then fails on
    # conservation, so the pipeline stops.
    cli::cli_warn("{unique(data$year)}: {length(unmatched)} AGS code{?s} not in the crosswalk at {from_year}: {.val {unmatched}}")
    n <- nrow(data)
    data <- data[!data$ags %in% unmatched, ]
    log_rows_removed(n, nrow(data), "AGS codes without crosswalk row")
  }

  # A target district is unchanged when it has exactly one source, that
  # source is itself, and the weight is 1.
  tol <- 1e-9
  status <- dplyr::summarise(
    dplyr::group_by(cw, to_ags),
    identity = dplyr::n() == 1 & from_ags[1] == to_ags[1] & abs(weight[1] - 1) < tol,
    split = any(abs(weight - 1) >= tol),
    .groups = "drop"
  )

  pop <- district_population(data)
  pop <- join_checked(pop, cw, by = c(ags = "from_ags"), what = "population and crosswalk")
  pop <- dplyr::summarise(
    dplyr::group_by(pop, ags = to_ags),
    population = sum_weighted(population, weight),
    derived_population = sum_weighted(derived_population, weight),
    population_corrected = sum_weighted(population_corrected, weight),
    .groups = "drop"
  )

  joined <- join_checked(data, cw, by = c(ags = "from_ags"), what = "data and crosswalk")
  out <- dplyr::summarise(
    dplyr::group_by(joined, offence_key, ags = to_ags),
    dplyr::across(dplyr::all_of(harmonized_counts), ~ sum_weighted(.x, weight)),
    published_name = if (dplyr::n() == 1) region_name[1] else NA_character_,
    offence_label = offence_label[1],
    hz_published = if (dplyr::n() == 1) hz[1] else NA_real_,
    clearance_rate_published = if (dplyr::n() == 1) clearance_rate[1] else NA_real_,
    source_estimated = any(estimated),
    .groups = "drop"
  )
  out <- join_checked(out, status, by = c(ags = "to_ags"), what = "data and district status")
  out <- join_checked(out, pop, by = "ags", what = "data and population")
  names_target <- boundary_names(map, target)
  out <- join_checked(out, names_target, by = "ags", what = "data and target names")

  cases <- dplyr::coalesce(out$cases, out$cases_derived)
  cleared <- dplyr::coalesce(out$cleared, out$cleared_derived)
  denominator <- dplyr::coalesce(out$population, out$derived_population)
  out$hz <- ifelse(out$identity, out$hz_published, cases / denominator * 1e5)
  # Zero cases: the BKA prints AQ 0 (2022 leaves the cell empty), also where
  # cases from earlier years were cleared. Kept as 0 everywhere and announced
  # by `panel_notes` (notes/decisions.md).
  out$clearance_rate <- ifelse(out$identity, out$clearance_rate_published, cleared / cases * 100)
  out$clearance_rate[!is.na(cases) & cases == 0] <- 0
  out$region_name <- ifelse(out$identity, out$published_name, out$name)

  out$year <- unique(data$year)
  out$source_format <- unique(data$source_format)
  out$source_file <- unique(data$source_file)
  out$boundary_year <- as.integer(target)
  out$harmonized <- !out$identity
  out$weight_type <- ifelse(out$identity, "none", weights)
  out$estimated <- out$split | out$source_estimated
  out$offence_key_published <- out$offence_key
  keep <- intersect(names(harmonized_spec), names(out))
  out <- as_harmonized(out[keep])
  out[order(out$offence_key, out$ags), ]
}

# National totals per offence key must not change (Section 7.5). Population
# is compared once per district.
check_conservation <- function(before, after, tolerance = 1e-9) {
  totals <- function(d) {
    sums <- dplyr::summarise(
      dplyr::group_by(d, offence_key),
      dplyr::across(dplyr::all_of(harmonized_counts), ~ if (all(is.na(.x))) NA_real_ else sum(.x, na.rm = TRUE)),
      .groups = "drop"
    )
    as.data.frame(sums[order(sums$offence_key), ])
  }
  a <- totals(before)
  b <- totals(after[, c("offence_key", harmonized_counts)])
  if (!identical(a$offence_key, b$offence_key)) {
    cli::cli_abort("{unique(before$year)}: offence keys differ before and after harmonization.")
  }
  rel <- abs(as.matrix(b[-1]) - as.matrix(a[-1])) / pmax(abs(as.matrix(a[-1])), 1)
  # Published population where it exists, else the derived one; both must be
  # conserved (an NA sum must not skip the check).
  district_total <- function(p) sum(dplyr::coalesce(p$population, p$derived_population))
  pop_before <- district_total(district_population(before))
  pop_after <- district_total(unique(after[c("ags", "population", "derived_population")]))
  corrected_before <- sum(district_population(before)$population_corrected)
  corrected_after <- sum(unique(after[c("ags", "population_corrected")])$population_corrected)
  changed <- function(x, y) is.na(x) != is.na(y) || isTRUE(abs(x - y) / y > tolerance)
  bad <- which(rel > tolerance | xor(is.na(as.matrix(a[-1])), is.na(as.matrix(b[-1]))), arr.ind = TRUE)
  if (nrow(bad) > 0 || changed(pop_after, pop_before) || changed(corrected_after, corrected_before)) {
    cli::cli_abort("{unique(before$year)}: harmonization changed national totals for {.val {unique(a$offence_key[bad[, 1]])}}.")
  }
  invisible(TRUE)
}
