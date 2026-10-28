test_that("join helper errors when rows are lost (BUG-004)", {
  x <- data.frame(id = c("a", "b", "c"), v = 1:3)
  y <- data.frame(id = c("a", "b"), w = 1:2)
  expect_error(join_checked(x, y, by = "id", what = "test"), "loses 1 row")
  y2 <- data.frame(id = c("a", "a", "b", "c"), w = 1:4)
  expect_identical(nrow(join_checked(x, y2, by = "id", what = "test")), 4L)
})

test_that("removed rows are reported (rule 7)", {
  expect_message(log_rows_removed(10, 7, "test"), "Removed 3 rows")
  expect_silent(log_rows_removed(10, 10, "test"))
})

test_that("spreadsheet text that is not a number aborts instead of becoming NA", {
  expect_equal(as_number(c("12", "0.5", "1e-04", NA, " ", "3 "), "x"), c(12, 0.5, 1e-04, NA, NA, 3))
  expect_error(as_number(c("12", "12*"), "cases"), "cases")
  expect_error(as_number("n.a.", "hz"), "hz")
})
