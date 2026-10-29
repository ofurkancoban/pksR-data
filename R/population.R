# Census-corrected population (BRK-004, BRK-005, BUG-026).
#
# The BKA divides the cases of reporting year t by the population of
# 31.12.(t - 1), each year on the census base of its time: the old
# registers until PKS 2012, Zensus 2011 for PKS 2013 to 2023, Zensus 2022
# from PKS 2024. Rates therefore jump at 2013 and 2024 without any change in
# crime. The BBSR publishes in INKAR a census-corrected population
# (bev_korr): the gap at each census spread back linearly over the years
# before, so the series has no census break (notes/decisions.md).
#
# population_corrected is that population, at 31.12.(t - 1) and on the
# boundary of the row, so pksR::pks_rates() can recompute every year on one
# base. Counts are not touched.

read_population_inkar <- function(path) {
  p <- readr::read_csv(path, col_types = readr::cols(ags = "c", year = "i", population = "d", population_corrected = "d"), na = "")
  if (!identical(names(p), c("ags", "year", "population", "population_corrected")) || anyNA(p) ||
      anyDuplicated(p[c("ags", "year")]) || any(p$population <= 0 | p$population_corrected <= 0)) {
    cli::cli_abort("{.file {path}} does not follow the population_inkar layout.")
  }
  p$ags <- normalize_ags(p$ags)
  p
}

# Share of districts (among the codes INKAR also has) whose population must
# equal the INKAR population of the same date for the two to count as one
# census base. Districts touched by reforms differ because INKAR folds
# dissolved districts into their successors in all years.
same_base_share <- 0.9

# The corrected population of every district of `data` (one PKS year, on the
# published boundary), as a tibble ags, population_corrected. Each district
# is linked to its successors on the INKAR codes (crosswalk to the first
# boundary, from the published one on, whose codes are the INKAR codes), and
# its PKS population is multiplied by a factor of those successors:
#   ratio   PKS and INKAR population agree (same census base): the INKAR
#           correction factor, corrected over uncorrected population. A
#           factor is robust to the territory: it stays right where INKAR
#           folded dissolved districts into their successors.
#   level   another census base (PKS 2012 divides by the population of
#           31.12.2011 before Zensus 2011, PKS 2023 by the Zensus 2011
#           population of 31.12.2022; INKAR has both on the newer base): the
#           INKAR corrected population over the PKS population of all
#           districts that make up the successor, so each predecessor gets
#           its share of the INKAR value.
#   after   reference date after the last INKAR year, which must be after
#           the last census (no correction): the PKS population.
corrected_population <- function(data, inkar, map, min_share = same_base_share) {
  year <- unique(data$year)
  ref_year <- year - 1L
  pop <- district_population(data)
  pop$value <- dplyr::coalesce(pop$population, pop$derived_population)
  if (anyNA(pop$value)) {
    cli::cli_abort("{year}: {sum(is.na(pop$value))} district{?s} without population.")
  }
  last <- max(inkar$year)

  if (ref_year > last) {
    final <- inkar[inkar$year == last, ]
    if (any(abs(final$population_corrected / final$population - 1) > 1e-9)) {
      cli::cli_abort("{year}: INKAR ends in {last}, before the corrected and uncorrected population agree; refresh registry/population_inkar.csv (ci/fetch_inkar.R).")
    }
    return(structure(tibble::tibble(ags = pop$ags, population_corrected = pop$value), method = "after"))
  }

  ref <- inkar[inkar$year == ref_year, ]
  if (nrow(ref) == 0) cli::cli_abort("{year}: registry/population_inkar.csv has no year {ref_year}.")
  from <- unique(data$boundary_year)
  cw <- compose_crosswalk(map, from, inkar_boundary(map, ref$ags, from), "population")
  cw <- join_checked(cw, ref, by = c(to_ags = "ags"), what = paste("crosswalk and INKAR", ref_year))

  # Compared on the codes both have; old codes of reformed districts have no
  # INKAR partner
  i <- match(pop$ags, ref$ags)
  same <- abs(pop$value / ref$population[i] - 1) < 0.001
  method <- if (any(!is.na(i)) && mean(same[!is.na(i)]) >= min_share) "ratio" else "level"
  if (method == "ratio") {
    cw$factor <- cw$population_corrected / cw$population
  } else {
    cw$value <- pop$value[match(cw$from_ags, pop$ags)]
    parts <- dplyr::summarise(dplyr::group_by(cw, to_ags), pks = sum(weight * value), .groups = "drop")
    cw$factor <- cw$population_corrected / parts$pks[match(cw$to_ags, parts$to_ags)]
  }
  f <- dplyr::summarise(dplyr::group_by(cw, ags = from_ags), factor = sum(weight * factor) / sum(weight), .groups = "drop")
  f <- join_checked(pop[c("ags", "value")], f, by = "ags", what = "population and INKAR factors")
  structure(tibble::tibble(ags = f$ags, population_corrected = f$value * f$factor), method = method)
}

# The first boundary year from `from` on whose district codes are the INKAR
# codes, so the crosswalk adds as few later transfers as possible.
inkar_boundary <- function(map, codes, from = min(map$period)) {
  for (y in seq(from, max(map$period) + 1L)) {
    if (setequal(boundary_codes(map, y), codes)) return(y)
  }
  cli::cli_abort("The INKAR district codes match no boundary of the crosswalk from {from} on.")
}

# Adds population_corrected to one canonical year and reports the method and
# the change of the national population.
add_corrected_population <- function(data, inkar, map) {
  corrected <- corrected_population(data, inkar, map)
  n <- nrow(data)
  data$population_corrected <- NULL
  data <- join_checked(data, corrected, by = "ags", what = "data and corrected population")
  if (nrow(data) != n || anyNA(data$population_corrected)) {
    cli::cli_abort("{unique(data$year)}: corrected population missing for some rows.")
  }
  pop <- district_population(data)
  before <- sum(dplyr::coalesce(pop$population, pop$derived_population))
  after <- sum(corrected$population_corrected)
  cli::cli_inform("{unique(data$year)}: census-corrected population ({attr(corrected, 'method')}), national {format(round(after), big.mark = ',')} ({sprintf('%+.2f', 100 * (after / before - 1))} percent).")
  as_canonical(data)
}

# What a new INKAR snapshot changes against the registered one, for the pull
# request the inkar job of the pipeline opens (ci/fetch_inkar.R). The BBSR
# spreads each census gap back over the earlier years, so a new year can
# revise old ones; those revisions are counted, not only the added years.
inkar_snapshot_diff <- function(old, new, tol = 1e-9) {
  key <- c("ags", "year")
  both <- dplyr::inner_join(old, new, by = key, suffix = c("_old", "_new"))
  moved <- function(a, b) abs(b / a - 1) > tol
  changed <- both[moved(both$population_old, both$population_new) |
                    moved(both$population_corrected_old, both$population_corrected_new), ]
  list(
    years_added = sort(setdiff(unique(new$year), unique(old$year))),
    years_removed = sort(setdiff(unique(old$year), unique(new$year))),
    rows_added = nrow(dplyr::anti_join(new, old, by = key)),
    rows_removed = nrow(dplyr::anti_join(old, new, by = key)),
    rows_changed = nrow(changed),
    years_changed = sort(unique(changed$year)),
    max_change_corrected = if (nrow(changed)) max(abs(changed$population_corrected_new / changed$population_corrected_old - 1)) else 0
  )
}
