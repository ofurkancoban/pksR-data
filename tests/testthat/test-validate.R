fake_year <- function(codes, keys = c("------", "220000"), population = 150000) {
  grid <- expand.grid(ags = codes, offence_key = keys, stringsAsFactors = FALSE)
  as_canonical(data.frame(
    year = 2020L, ags = grid$ags, offence_key = grid$offence_key,
    cases = 10L, attempts = 1L, cleared = 5L, clearance_rate = 50,
    hz = 10 / population * 1e5, population = population, boundary_year = 2020L
  ))
}
codes <- c("01001", "02000", "11000", "16063")

test_that("a complete year passes", {
  expect_silent(validate_extraction(fake_year(codes), codes))
})

test_that("dropping Berlin or Hamburg fails the gate (BUG-003)", {
  expect_error(validate_extraction(fake_year(setdiff(codes, "11000")), codes), "Missing")
  expect_error(validate_extraction(fake_year(setdiff(codes, "02000")), codes), "Missing")
})

test_that("district count must match the declared boundary (BUG-006, BUG-019)", {
  expect_error(validate_extraction(fake_year(codes[-4]), codes), "district set differs")
  expect_error(validate_extraction(fake_year(c(codes, "16056")), codes), "Unknown")
})

test_that("an offence key missing for some districts fails (BUG-021)", {
  d <- fake_year(codes)
  d <- d[!(d$offence_key == "220000" & d$ags == "16063"), ]
  expect_error(validate_extraction(d, codes), "do not cover all districts")
})

test_that("implausible population medians are flagged (BUG-010)", {
  expect_warning(validate_extraction(fake_year(codes, population = 3500), codes), "median district population")
})

test_that("negative counts and attempts above cases fail", {
  d <- fake_year(codes)
  d$cases[1] <- 0L
  expect_error(validate_extraction(d, codes), "attempts exceed cases")
})

test_that("clearance rates above 100 are allowed (published in PKS)", {
  d <- fake_year(codes)
  d$clearance_rate[1] <- 105
  d$cleared[1] <- 12L
  expect_silent(validate_extraction(d, codes))
})

test_that("a registry year without output fails (BUG-020)", {
  sources <- data.frame(year = 2019:2021)
  files <- c("out/pks_kreis_2019.parquet", "out/pks_kreis_2021.parquet")
  expect_error(assert_year_completeness(sources, files), "2020")
  expect_true(assert_year_completeness(sources, c(files, "out/pks_kreis_2020.parquet")))
})

# --- Gate on the harmonized panel -------------------------------------------

gate_input <- function() {
  d <- toy_year()
  h <- as_harmonized(cbind(harmonize_space(d, toy_map(), 2021)[, -match("offence_key_published", names(harmonized_spec))], offence_key_published = "------"))
  ctx <- list(target_year = 2021L, target_codes = boundary_codes(toy_map(), 2021),
              canonical = list(d), years = 2019L, national = NULL)
  list(panel = h, ctx = ctx)
}

test_that("a correct panel passes the gate and aggregation is reported as skipped", {
  g <- gate_input()
  path <- withr::local_tempfile(fileext = ".json")
  expect_identical(validation_gate(g$panel, g$ctx, path), path)
  r <- jsonlite::read_json(path)
  status <- vapply(r$checks, `[[`, "", "status")
  names(status) <- vapply(r$checks, `[[`, "", "check")
  expect_identical(status[["aggregation"]], "skipped")
  expect_true(all(status[names(status) != "aggregation"] == "pass"))
})

test_that("the gate stops and writes a report when Berlin is missing (BUG-003)", {
  g <- gate_input()
  path <- withr::local_tempfile(fileext = ".json")
  expect_error(validation_gate(g$panel[g$panel$ags != "11000", ], g$ctx, path), "coverage")
  r <- jsonlite::read_json(path)
  failed <- vapply(Filter(function(x) x$status == "fail", r$checks), `[[`, "", "check")
  expect_true(all(c("coverage", "conservation") %in% failed))
})

test_that("the gate catches a lost year and changed totals (BUG-004, BUG-020)", {
  g <- gate_input()
  g$ctx$years <- c(2019L, 2020L)
  g$panel$cases[1] <- g$panel$cases[1] + 1
  path <- withr::local_tempfile(fileext = ".json")
  expect_error(validation_gate(g$panel, g$ctx, path), "year_completeness")
  expect_error(validation_gate(g$panel, g$ctx, path), "conservation")
})

test_that("district sums must lie between Bund minus unknown place and Bund (Section 7.4)", {
  g <- gate_input()
  path <- withr::local_tempfile(fileext = ".json")
  # Districts sum to 900
  g$ctx$national <- data.frame(year = 2019L, offence_key = "------", cases = 950, cases_unknown_place = 60)
  expect_identical(validation_gate(g$panel, g$ctx, path), path)
  expect_identical(unlist(jsonlite::read_json(path)$national_years), 2019L)
  g$ctx$national$cases_unknown_place <- 40  # bound 910, slack 5
  expect_error(validation_gate(g$panel, g$ctx, path), "aggregation")
  g$ctx$national <- data.frame(year = 2019L, offence_key = "------", cases = 899, cases_unknown_place = 0)
  expect_error(validation_gate(g$panel, g$ctx, path), "aggregation")
  g$ctx$national$offence_key <- "730000"
  expect_error(validation_gate(g$panel, g$ctx, path), "not in the Bund table")
})

test_that("implausible median population warns in the gate (BUG-010)", {
  g <- gate_input()
  g$panel$derived_population <- 3500
  g$panel$population_corrected <- 3500
  path <- withr::local_tempfile(fileext = ".json")
  expect_warning(validation_gate(g$panel, g$ctx, path), "median district population")
})

test_that("a missing or implausible corrected population fails the gate", {
  g <- gate_input()
  path <- withr::local_tempfile(fileext = ".json")
  g$panel$population_corrected[g$panel$ags == "01001"] <- NA
  expect_error(validation_gate(g$panel, g$ctx, path), "corrected_population")
  g <- gate_input()
  g$panel$population_corrected[g$panel$ags == "01001"] <- 2 * g$panel$derived_population[g$panel$ags == "01001"]
  expect_error(validation_gate(g$panel, g$ctx, path), "corrected_population")
})
