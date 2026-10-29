# Evidence for notes/legacy_vs_new.md: cell-by-cell comparison of the legacy
# harmonized tables (processed/PKS/02-harmonized, boundary 2023) with the new
# panel (population weights, boundary 2025, territorially identical to 2023).
# Audit only, not pipeline code. Run from pksR-data/ with the legacy clone in
# ../../legacy/.

legacy_dir <- "../../legacy/ImmigrationCrimeGermany_AppliedEconResearchProj/01_datasets/processed/PKS/02-harmonized"
new <- arrow::read_parquet("output/harmonized/population/pks_kreis_panel.parquet")

legacy <- dplyr::bind_rows(lapply(list.files(legacy_dir, pattern = "^20[0-9]{2}_PKS_harmonized\\.csv$", full.names = TRUE), function(f) {
  d <- readr::read_csv(f, col_types = readr::cols(.default = "c"))
  d$year <- as.integer(substr(basename(f), 1, 4))
  d
}))
legacy <- dplyr::transmute(
  legacy, year,
  ags = formatC(as.integer(Kreisschluessel), width = 5, flag = "0"),
  # BUG-011: legacy labels the 2010 to 2012 PDF column 222000 as 220000
  offence_key = ifelse(year %in% 2010:2012 & Schluesselzahl == "220000", "222000", Schluesselzahl),
  cases_legacy = as.numeric(Erfasste_Faelle),
  population_legacy = as.numeric(Einwohner),
  hz_legacy = as.numeric(Straftaten_HZ),
  cleared_legacy = as.numeric(Aufklaerung_Faelle)
)
new <- dplyr::transmute(
  new, year, ags, offence_key, harmonized, estimated,
  pdf = source_format == "pdf",
  cases_new = dplyr::coalesce(cases, cases_derived),
  population_new = dplyr::coalesce(population, derived_population),
  hz_new = hz,
  cleared_new = dplyr::coalesce(cleared, cleared_derived)
)

key <- c("year", "ags", "offence_key")
only_legacy <- dplyr::anti_join(legacy, new, by = key)
only_new <- dplyr::anti_join(new[new$year <= max(legacy$year), ], legacy, by = key)
both <- dplyr::inner_join(legacy, new, by = key)

rel <- function(a, b) abs(a - b) / pmax(abs(b), 1)
tol <- 1e-6
vars <- c("cases", "population", "hz", "cleared")
summary_by <- function(d, group) {
  out <- lapply(vars, function(v) {
    r <- rel(d[[paste0(v, "_legacy")]], d[[paste0(v, "_new")]])
    na_diff <- xor(is.na(d[[paste0(v, "_legacy")]]), is.na(d[[paste0(v, "_new")]]))
    dplyr::summarise(
      dplyr::group_by(dplyr::mutate(d, r = r, na_diff = na_diff), dplyr::across(dplyr::all_of(group))),
      variable = v, cells = dplyr::n(),
      changed = sum(r > tol, na.rm = TRUE) + sum(na_diff),
      max_rel = suppressWarnings(max(r, na.rm = TRUE)),
      median_rel_changed = suppressWarnings(stats::median(r[r > tol], na.rm = TRUE)),
      .groups = "drop"
    )
  })
  dplyr::bind_rows(out)
}

by_year <- summary_by(both, "year")
by_status <- summary_by(dplyr::mutate(both, status = dplyr::case_when(!harmonized ~ "unchanged district", estimated & !pdf ~ "split", pdf & harmonized ~ "harmonized PDF year", TRUE ~ "merger")), "status")
# Ranked by the exact ratio: rel() floors the denominator at 1, which hides
# large relative errors in cells with an HZ below 1 (most BUG-014 cells)
largest <- both |>
  dplyr::mutate(r_hz = rel(hz_legacy, hz_new), hz_ratio = hz_legacy / hz_new) |>
  dplyr::filter(is.finite(hz_ratio)) |>
  dplyr::arrange(dplyr::desc(hz_ratio)) |>
  utils::head(15)

# BUG-014 measured on the legacy data alone: an offence row whose population
# differs from the population of the total-crime row of the same district-year
bug014 <- legacy[legacy$year >= 2013 & !is.na(legacy$population_legacy), ]
bug014 <- dplyr::inner_join(bug014, dplyr::transmute(bug014[bug014$offence_key == "------", ], year, ags, district_pop = population_legacy), by = c("year", "ags"))
bug014$factor <- bug014$district_pop / bug014$population_legacy
bug014 <- bug014[abs(bug014$factor - 1) > 1e-6, ]

saveRDS(list(only_legacy = only_legacy, only_new = only_new, by_year = by_year, by_status = by_status, largest = largest, bug014 = bug014, n_both = nrow(both)),
        file.path(Sys.getenv("OUT", "."), "legacy_vs_new.rds"))
print(nrow(both)); print(nrow(only_legacy)); print(nrow(only_new))
print(dplyr::count(only_new, year, offence_key), n = 60)
print(dplyr::count(only_legacy, year, offence_key), n = 60)
print(as.data.frame(by_status))
print(as.data.frame(by_year[by_year$variable %in% c("cases", "hz"), ]))
print(as.data.frame(largest))
print(as.data.frame(dplyr::summarise(dplyr::group_by(bug014, year), rows = dplyr::n(), max_factor = max(factor))))
