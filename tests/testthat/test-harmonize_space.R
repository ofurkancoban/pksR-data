test_that("mergers are exact and splits are estimated", {
  h <- harmonize_space(toy_year(), toy_map(), 2021)
  expect_setequal(h$ags, c("01001", "02000", "03001", "03002", "11000"))
  merged <- h[h$ags == "01001", ]
  expect_equal(merged$cases, 150)
  expect_true(merged$harmonized)
  expect_false(merged$estimated)
  expect_equal(h$cases[h$ags == "03002"], 60)
  expect_true(all(h$estimated[h$ags %in% c("03001", "03002")]))
  expect_identical(h$boundary_year, rep(2021L, 5))
  expect_identical(h$weight_type[h$ags == "11000"], "none")
  expect_identical(h$weight_type[h$ags == "03002"], "population")
})

test_that("area weights are used when asked for", {
  h <- harmonize_space(toy_year(), toy_map(), 2021, "area")
  expect_equal(h$cases[h$ags == "03002"], 80)
  expect_identical(h$weight_type[h$ags == "03002"], "area")
})

test_that("counts are harmonized and rates recomputed, never weighted (Section 6.1.5)", {
  h <- harmonize_space(toy_year(), toy_map(), 2021)
  merged <- h[h$ags == "01001", ]
  expect_equal(merged$derived_population, 120000)
  expect_equal(merged$hz, 150 / 120000 * 1e5)
  expect_equal(merged$clearance_rate, 20 / 150 * 100)
  # Unchanged districts keep the published rate
  d <- toy_year()
  expect_identical(h$hz[h$ags == "11000"], d$hz[d$ags == "11000"])
})

test_that("national totals are conserved", {
  d <- toy_year()
  for (w in c("population", "area")) {
    expect_true(check_conservation(d, harmonize_space(d, toy_map(), 2021, w)))
  }
})

test_that("zero-case rows do not shrink a merged population (BUG-014)", {
  h <- harmonize_space(toy_year(zero_key = TRUE), toy_map(), 2021)
  row <- h[h$ags == "01001" & h$offence_key == "219000", ]
  # Legacy: 30,000 (the NA population of 01001 dropped), HZ 10 instead of 2.5
  expect_equal(row$derived_population, 120000)
  expect_equal(row$hz, 3 / 120000 * 1e5)
})

test_that("unmatched AGS codes are reported, not dropped silently (BUG-016)", {
  d <- toy_year()
  d$ags[d$ags == "01002"] <- "01099"
  expect_warning(h <- harmonize_space(d, toy_map(), 2021), "01099")
  expect_error(check_conservation(d, h), "changed national totals")
})

test_that("a missing value in a source district stays missing", {
  d <- toy_year()
  d$suspects[d$ags == "01002"] <- NA
  h <- harmonize_space(d, toy_map(), 2021)
  expect_true(is.na(h$suspects[h$ags == "01001"]))
  expect_equal(h$suspects[h$ags == "11000"], 5)
})

test_that("harmonization runs forward only", {
  expect_error(compose_crosswalk(toy_map(), 2021, 2019), "forward")
})

test_that("the clearance rate of zero cases is 0 in identity and merged districts", {
  d <- toy_year(zero_key = TRUE)
  z <- d$offence_key == "219000"
  # 01001 and 01002 merge with 0 cases; 01002 cleared a case from an earlier
  # year, so cleared / cases would be infinite
  d$cases[z & d$ags %in% c("01001", "01002", "11000")] <- 0L
  d$cleared[z] <- ifelse(d$ags[z] == "01002", 1L, 0L)
  d$clearance_rate[z] <- 0
  # Berlin left empty as in the 2022 table
  d$clearance_rate[z & d$ags == "11000"] <- NA_real_
  h <- harmonize_space(d, toy_map(), 2021)
  zero <- h[h$offence_key == "219000" & h$cases == 0, ]
  expect_setequal(zero$ags, c("01001", "11000"))
  expect_equal(zero$clearance_rate, c(0, 0))
  expect_false(anyNA(h$clearance_rate))
})

test_that("the panel file carries the notes for pks_get()", {
  dir <- withr::local_tempdir()
  h <- harmonize_space(toy_year(), toy_map(), 2021)
  path <- write_panel(h, "population", dir)[1]
  meta <- arrow::read_parquet(path, as_data_frame = FALSE)$metadata$pksR_notes
  expect_identical(jsonlite::fromJSON(meta), as.list(panel_notes))
})

test_that("conservation covers the derived population when none is published", {
  d <- toy_year()
  h <- harmonize_space(d, toy_map(), 2021)
  expect_true(all(is.na(d$population)))
  h$derived_population[h$ags == "01001"] <- h$derived_population[h$ags == "01001"] + 1000
  expect_error(check_conservation(d, h), "national totals")
})
