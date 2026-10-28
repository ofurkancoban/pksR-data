test_that("every Excel layout yields the same fields (BUG-023)", {
  for (year in c(2013, 2014, 2015, 2020, 2025)) {
    d <- xls_fixture(year)
    fl <- d[d$ags == "01001" & d$offence_key == "------", ]
    expect_identical(fl$region_name, "Flensburg", label = paste(year, "name"))
    expect_identical(fl$offence_label, "Straftaten insgesamt", label = paste(year, "label"))
    expect_false(anyNA(d[c("cases", "hz", "attempts", "cleared", "clearance_rate", "suspects")]))
  }
})

test_that("2013 name and type columns are not confused (BUG-023, BUG-032)", {
  d <- xls_fixture(2013)
  expect_false(any(d$region_name %in% district_types))
  fl <- d[d$ags == "01001" & d$offence_key == "------", ]
  expect_equal(fl$cases, 8876L)
  expect_equal(fl$cleared, 4650L)
  expect_equal(fl$clearance_rate, 52.4, tolerance = 1e-9)
  expect_equal(fl$suspects, 3599L)
})

test_that("2025 is read by header text despite the misnumbered column row", {
  fl <- xls_fixture(2025)
  fl <- fl[fl$ags == "01001" & fl$offence_key == "------", ]
  expect_equal(fl$cases, 8723L)
  expect_equal(fl$cleared, 5661L)
  expect_equal(fl$suspects, 3650L)
})

test_that("derived population equals the published 2020 population (BUG-002)", {
  d <- xls_fixture(2020)
  ok <- !is.na(d$derived_population)
  expect_true(any(ok))
  expect_equal(d$derived_population[ok], d$population[ok], tolerance = 1e-9)
})

test_that("zero-case rows carry no derived population (BUG-014)", {
  d <- xls_fixture(2014)
  expect_true(all(is.na(d$derived_population[d$cases == 0])))
})

test_that("population is only filled where it is published", {
  expect_true(all(is.na(xls_fixture(2014)$population)))
  expect_false(anyNA(xls_fixture(2020)$population))
})

test_that("header drift stops the pipeline (BUG-023)", {
  path <- withr::local_tempfile(fileext = ".xlsx")
  raw <- suppressMessages(readxl::read_excel(fixture("2014_head.xlsx"), col_names = FALSE, col_types = "text"))
  raw[[7]][5:8] <- c("Something else", NA, NA, NA)
  names(raw) <- paste0("c", seq_along(raw))
  writexl::write_xlsx(list(T = raw), path, col_names = FALSE)
  src <- fixture_source(2014, basename(path), "xlsx", sheet = "T")
  expect_error(extract_xls(path, src), "layout drift")
})

test_that("a non-empty row without a district code is an error (BUG-020)", {
  path <- withr::local_tempfile(fileext = ".xlsx")
  raw <- suppressMessages(readxl::read_excel(fixture("2014_head.xlsx"), col_names = FALSE, col_types = "text"))
  raw[nrow(raw) + 1, 1] <- "Quelle: BKA"
  names(raw) <- paste0("c", seq_along(raw))
  writexl::write_xlsx(list(T = raw), path, col_names = FALSE)
  src <- fixture_source(2014, basename(path), "xlsx", sheet = "T")
  expect_error(extract_xls(path, src), "without a district code")
})
