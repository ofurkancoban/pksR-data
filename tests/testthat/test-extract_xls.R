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

test_that("detail columns are read in every Excel layout", {
  # Flensburg, all offences, as printed in the tables
  expected <- list(
    `2013` = c(15, 12, 2761, 838, 835), `2014` = c(18, 12, 2939, 952, 1256),
    `2020` = c(11, 5, 2786, 832, 1233), `2025` = c(9, 10, 2682, 968, 1306)
  )
  for (year in c(2013, 2014, 2015, 2020, 2025)) {
    d <- xls_fixture(year)
    expect_false(anyNA(d[detail_columns]), label = paste(year, "detail NA"))
    expect_true(all(d$suspects_male + d$suspects_female == d$suspects), label = paste(year, "male + female"))
    fl <- d[d$ags == "01001" & d$offence_key == "------", ]
    expect_identical(fl$district_type, "KfS", label = paste(year, "type"))
    if (as.character(year) %in% names(expected)) {
      got <- unlist(fl[c("firearm_threatened", "firearm_fired", "suspects_male", "suspects_female", "suspects_non_german")])
      expect_equal(unname(got), expected[[as.character(year)]], label = paste(year, "counts"))
    }
  }
})

test_that("an empty district type takes the type of the same district", {
  ags <- c("01001", "01001", "01051", "01051")
  expect_message(out <- xls_district_type(ags, c("KfS", NA, "K", "K"), "t.xlsx"), "1 empty district type")
  expect_identical(out, c("KfS", "KfS", "K", "K"))
  expect_error(xls_district_type(ags, c("KfS", "K", "K", "K"), "t.xlsx"), "several types")
  expect_error(xls_district_type(ags, c(NA, NA, "K", "K"), "t.xlsx"), "no district type")
})
