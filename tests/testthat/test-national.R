bund_file <- function(year) {
  f <- list.files(file.path(root, "data-raw", "bund"), pattern = paste0("^", year, "_"), full.names = TRUE)
  skip_if(length(f) != 1, "Bund table not downloaded")
  f
}

test_that("Bund columns are found by header text in old and new layouts", {
  for (y in c(2014, 2024)) {
    b <- extract_bund(bund_file(y), list(year = y, sha256 = NA, sheet = NA))
    expect_identical(names(b), c("year", "offence_key", "cases", "cases_unknown_place"))
    total <- b[b$offence_key == "------", ]
    expect_true(total$cases > 5e6 && total$cases_unknown_place > 0)
  }
})

test_that("district sums lie within the documented bound (Section 7.4)", {
  y <- 2024
  b <- extract_bund(bund_file(y), list(year = y, sha256 = NA, sheet = NA))
  canonical <- file.path(root, "output", "canonical", "pks_kreis_2024.parquet")
  skip_if_not(file.exists(canonical), "canonical output not built")
  k <- arrow::read_parquet(canonical)
  s <- tapply(k$cases, k$offence_key, sum)
  m <- merge(data.frame(offence_key = names(s), districts = as.numeric(s)), b, by = "offence_key")
  expect_identical(nrow(m), length(s))
  expect_true(all(m$districts <= m$cases & m$districts >= m$cases - m$cases_unknown_place - national_slack(m$cases)))
})

test_that("the slack is small: 5 cases or 0.1 percent", {
  expect_equal(national_slack(c(100, 26713, 5e6)), c(5, 26.713, 5000))
})

test_that("a Bund file with a changed hash is refused", {
  f <- bund_file(2024)
  expect_error(extract_bund(f, list(year = 2024L, sha256 = strrep("0", 64), sheet = NA)), "SHA-256")
})

test_that("the Bund registry has one row per year with URL and hash", {
  s <- read_bund_sources(registry_path("bund_sources.csv"))
  expect_false(anyDuplicated(s$year) > 0)
  expect_true(all(grepl("^https://www\\.bka\\.de/", s$url)))
  expect_true(all(nchar(s$sha256) == 64))
})
