test_that("normalize_ags handles PKS and BBSR code formats (BUG-001)", {
  expect_identical(
    normalize_ags(c("1001", "01001", "1001000", "01001000", "11000", "2000")),
    c("01001", "01001", "01001", "01001", "11000", "02000")
  )
  expect_identical(normalize_ags(1001), "01001")
  expect_error(normalize_ags("7137001"), "not a district code")
  expect_error(normalize_ags("01A01"), "digits only")
  expect_error(normalize_ags("123"), "Unexpected AGS length")
})

test_that("PDF and Excel years share one schema (BUG-007)", {
  pdf <- pdf_fixture(2003, "2003_p253.pdf")
  xls <- xls_fixture(2020)
  expect_identical(names(pdf), names(canonical_spec))
  expect_identical(names(xls), names(canonical_spec))
  expect_identical(vapply(pdf, typeof, ""), vapply(xls, typeof, ""))
  expect_silent(assert_canonical(pdf))
  expect_silent(assert_canonical(xls))
})

test_that("as_canonical refuses columns outside the schema", {
  expect_error(as_canonical(data.frame(ags = "01001", extra = 1)), "outside the canonical schema")
})

test_that("as_canonical refuses fractional counts", {
  expect_error(as_canonical(data.frame(ags = "01001", cases = 1.5)), "non-integer")
})

test_that("assert_canonical detects duplicate rows", {
  d <- as_canonical(data.frame(year = 2020L, ags = c("01001", "01001"), offence_key = "------"))
  expect_error(assert_canonical(d), "duplicate")
})

test_that("hz is per 100,000 inhabitants (BUG-033)", {
  d <- xls_fixture(2020)
  flensburg <- d[d$ags == "01001" & d$offence_key == "------", ]
  expect_equal(flensburg$hz, flensburg$cases / flensburg$population * 1e5, tolerance = 1e-9)
})
