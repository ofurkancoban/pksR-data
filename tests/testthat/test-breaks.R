breaks <- read_known_breaks(registry_path("known_breaks.csv"))

test_that("known_breaks contains census rebasing rows (BUG-026)", {
  census <- breaks[breaks$type == "denominator", ]
  expect_setequal(census$first_year, c(2013L, 2024L))
})

test_that("the PDF to Excel source change is documented (BUG-015)", {
  expect_true(any(breaks$type == "source" & breaks$first_year == 2013L))
})

test_that("the 2012 vehicle theft redefinition is a non-comparable break", {
  b <- breaks[breaks$offence_key %in% "*50*00", ]
  expect_identical(b$first_year, 2012L)
  expect_identical(b$comparable, "no")
})

test_that("every break key is a harmonized key", {
  omap <- read_offence_map(registry_path("offence_map.csv"))
  keys <- unlist(strsplit(stats::na.omit(breaks$offence_key), ";", fixed = TRUE))
  expect_true(all(keys %in% omap$offence_key_harmonized))
})
