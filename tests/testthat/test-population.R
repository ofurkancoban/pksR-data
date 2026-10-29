# Census-corrected population (R/population.R, BRK-004, BRK-005, BUG-026)

# INKAR on the 2021 boundary of toy_map(): 01002 is part of 01001, and
# 03001 is split into 03001 and 03002.
toy_inkar <- function(year = 2018L, factors = c(0.95, 0.9, 0.8, 0.97, 1)) {
  codes <- c("01001", "03001", "03002", "11000", "02000")
  pop <- c(120000, 140000, 60000, 3600000, 1800000)
  tibble::tibble(ags = codes, year = as.integer(year), population = pop, population_corrected = pop * factors)
}

test_that("the snapshot is the registered one and covers every district and year", {
  p <- read_population_inkar(registry_path("population_inkar.csv"))
  src <- readr::read_csv(registry_path("inkar_sources.csv"), col_types = readr::cols(.default = "c"))
  expect_identical(sha256_file(registry_path("population_inkar.csv")), src$sha256)
  expect_identical(as.integer(table(p$year)), rep(400L, length(unique(p$year))))
  expect_identical(min(p$year), 2002L)
  # After Zensus 2022 nothing is corrected
  last <- p[p$year == max(p$year), ]
  expect_equal(last$population_corrected, last$population)
})

test_that("the INKAR codes are a boundary of the crosswalk", {
  p <- read_population_inkar(registry_path("population_inkar.csv"))
  map <- read_boundary_map(registry_path("boundary_map.csv"))
  expect_true(inkar_boundary(map, unique(p$ags)) >= 2021L)
  expect_identical(inkar_boundary(map, unique(p$ags), 2023L), 2023L)
})

test_that("same census base: the INKAR factor of the district or its successors", {
  d <- toy_year()
  d$population_corrected <- NA_real_
  # PKS 2019 divides by the population of 31.12.2018
  inkar <- toy_inkar(2018L)
  inkar$population[inkar$ags %in% c("11000", "02000")] <- c(3600000, 1800000)
  r <- corrected_population(d, inkar, toy_map(), min_share = 0.4)
  expect_identical(attr(r, "method"), "ratio")
  got <- stats::setNames(r$population_corrected, r$ags)
  expect_equal(got[["01001"]], 90000 * 0.95)
  expect_equal(got[["01002"]], 30000 * 0.95)              # merged into 01001
  expect_equal(got[["03001"]], 200000 * (0.7 * 0.9 + 0.3 * 0.8)) # split 70/30
  expect_equal(got[["11000"]], 3600000 * 0.97)
  expect_equal(got[["02000"]], 1800000)
})

test_that("another census base: the INKAR level, shared among predecessors", {
  # Like PKS 2012 and 2023: the BKA population is on the older census base
  inkar <- toy_inkar(2020L)
  d <- toy_year()
  d$population_corrected <- NA_real_
  d$year <- 2021L
  r <- corrected_population(d, inkar, toy_map())
  expect_identical(attr(r, "method"), "level")
  got <- stats::setNames(r$population_corrected, r$ags)
  corr <- stats::setNames(inkar$population_corrected, inkar$ags)
  # 01001 and 01002 make up INKAR 01001 and share it by their PKS population
  expect_equal(got[["01001"]], corr[["01001"]] * 90000 / 120000)
  expect_equal(got[["01002"]], corr[["01001"]] * 30000 / 120000)
  # 03001 is all of INKAR 03001 and 03002 (split 70 and 30 percent later)
  expect_equal(got[["03001"]], corr[["03001"]] + corr[["03002"]])
  expect_equal(got[["11000"]], corr[["11000"]])
  # The INKAR total is kept
  expect_equal(sum(got), sum(corr))
})

test_that("after the last INKAR year the population is kept, if no correction is pending", {
  d <- toy_year()
  d$population_corrected <- NA_real_
  d$year <- 2025L
  done <- toy_inkar(2023L, factors = rep(1, 5))
  r <- corrected_population(d, done, toy_map())
  expect_identical(attr(r, "method"), "after")
  expect_equal(r$population_corrected, dplyr::coalesce(d$population, d$derived_population)[match(r$ags, d$ags)])
  expect_error(corrected_population(d, toy_inkar(2023L), toy_map()), "refresh registry/population_inkar.csv")
})

test_that("harmonization moves the corrected population and conserves it", {
  h <- harmonize_space(toy_year(), toy_map(), 2021)
  pop <- unique(h[c("ags", "population_corrected")])
  expect_equal(sum(pop$population_corrected), 0.98 * sum(c(90000, 30000, 200000, 3600000, 1800000)))
  expect_equal(pop$population_corrected[pop$ags == "01001"], 0.98 * 120000)
  expect_equal(pop$population_corrected[pop$ags == "03002"], 0.98 * 0.3 * 200000)
})

test_that("a new INKAR snapshot reports added years and revised rows", {
  old <- rbind(toy_inkar(2022L), toy_inkar(2023L, factors = rep(1, 5)))
  same <- inkar_snapshot_diff(old, old)
  expect_identical(same$rows_changed, 0L)
  expect_length(same$years_added, 0)

  new <- rbind(toy_inkar(2022L, factors = c(0.95, 0.9, 0.8, 0.97, 0.99)), toy_inkar(2023L, factors = rep(1, 5)), toy_inkar(2024L, factors = rep(1, 5)))
  d <- inkar_snapshot_diff(old, new)
  expect_identical(d$years_added, 2024L)
  expect_identical(d$rows_added, 5L)
  expect_identical(d$rows_removed, 0L)
  expect_identical(d$rows_changed, 1L)
  expect_identical(d$years_changed, 2022L)
  expect_equal(d$max_change_corrected, 0.01)

  gone <- inkar_snapshot_diff(old, toy_inkar(2023L, factors = rep(1, 5)))
  expect_identical(gone$years_removed, 2022L)
  expect_identical(gone$rows_removed, 5L)
})

test_that("the INKAR intermediates are used only when they verify against trusted roots", {
  certs <- file.path(root, "ci", "certs", "inkar_intermediates.pem")
  bundle <- inkar_ca_bundle(certs)
  expect_identical(length(openssl::read_cert_bundle(bundle)), length(openssl::ca_bundle()) + 2L)
  # Without the cross certificate the chain ends at a root no store trusts
  broken <- withr::local_tempfile(fileext = ".pem")
  writeLines(openssl::write_pem(openssl::read_cert_bundle(certs)[[1]]), broken)
  expect_error(inkar_ca_bundle(broken), "does not verify")
})
