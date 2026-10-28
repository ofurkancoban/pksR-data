test_that("offence keys are read from each year's header (BUG-011)", {
  expect_identical(
    unique(pdf_fixture(2003, "2003_p253.pdf")$offence_key),
    c("------", "2200", "435*", "*50*", "6740", "7300", "8990")
  )
  # The legacy extractor labelled this column 220000
  expect_identical(
    unique(pdf_fixture(2010, "2010_p264.pdf")$offence_key),
    c("------", "222000", "435*00", "*50*00", "674000", "730000", "899000")
  )
})

test_that("PDF years never report derived counts as published counts (BUG-015)", {
  d <- pdf_fixture(2003, "2003_p253.pdf")
  expect_true(all(is.na(d$cases)))
  expect_true(all(is.na(d$cleared)))
  expect_true(all(is.na(d$derived_population)))
  expect_false(anyNA(d$population))
  expect_false(anyNA(d$hz))
})

test_that("PDF derived counts sit in their own flagged columns (Q1)", {
  d <- pdf_fixture(2003, "2003_p253.pdf")
  hh <- d[d$ags == "02000" & d$offence_key == "------", ]
  expect_equal(hh$cases_derived, 15698 * 1728806 / 1e5)
  expect_equal(hh$cleared_derived, hh$cases_derived * 43.7 / 100)
  expect_true(all(d$estimated))
  expect_true(all(is.na(xls_fixture(2020)$cases_derived)))
})

test_that("published values are parsed exactly", {
  # 2003: thousands separated by spaces ("1 728 806"), Hilfs-Nr column
  hh <- pdf_fixture(2003, "2003_p253.pdf")
  hh <- hh[hh$ags == "02000" & hh$offence_key == "------", ]
  expect_equal(hh$population, 1728806)
  expect_equal(hh$hz, 15698)
  expect_equal(hh$clearance_rate, 43.7)

  # 2012: "." as thousands separator
  fl <- pdf_fixture(2012, "2012_p315.pdf")
  fl <- fl[fl$ags == "01001" & fl$offence_key == "------", ]
  expect_equal(fl$population, 89357)
  expect_equal(fl$hz, 10630)
  expect_equal(fl$clearance_rate, 51.0)
})

test_that("a published '-' becomes NA without shifting columns", {
  d <- pdf_fixture(2010, "2010_p264.pdf")
  row <- d[d$ags == "09185", ]
  kfz <- row[row$offence_key == "*50*00", ]
  expect_equal(kfz$hz, 30)
  expect_true(is.na(kfz$clearance_rate))
  sach <- row[row$offence_key == "674000", ]
  expect_equal(sach$hz, 447)
  expect_equal(sach$clearance_rate, 21.8)
})

test_that("fragments, footnote markers and footer rules do not corrupt rows (BUG-021, BUG-022)", {
  d <- pdf_fixture(2007, "2007_p254.pdf")
  bl <- d[d$ags == "15084" & d$offence_key == "------", ]
  expect_identical(bl$region_name, "LK Burgenland*)")
  expect_equal(bl$population, 205097)
  expect_equal(bl$hz, 8150)

  d12 <- pdf_fixture(2012, "2012_p315.pdf")
  expect_false(any(grepl("_", d12$region_name)))
  for (x in list(d, d12)) {
    expect_true(all(grepl("^\\(?(SK|LK|KfS|K|RV)\\)? ", x$region_name)))
    expect_false(any(grepl("HZ|Berichtszeitraum|Einwohner", x$region_name)))
  }
})

test_that("a page without the table is an error, not an empty result (BUG-020, BUG-021)", {
  expect_error(pdf_fixture(2003, "2003_p001.pdf"), "header row")
})

test_that("every district row on a page is extracted (BUG-021)", {
  d <- pdf_fixture(2003, "2003_p253.pdf")
  words <- pdftools::pdf_data(fixture("2003_p253.pdf"))[[1]]
  keys_on_page <- unique(words$text[grepl("^[0-9]{5}$", words$text)])
  expect_setequal(unique(d$ags), keys_on_page)
  expect_identical(nrow(d), length(keys_on_page) * 7L)
})
