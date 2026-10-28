registry_path <- file.path(root, "registry", "sources.csv")

test_that("the registry covers every year from 2003 without gaps (BUG-020)", {
  s <- read_sources(registry_path)
  expect_identical(s$year, seq(2003L, max(s$year)))
})

test_that("every source has a recorded URL, hash and boundary (BUG-025)", {
  s <- read_sources(registry_path)
  expect_false(anyNA(s$url))
  expect_true(all(startsWith(s$url, "https://www.bka.de/")))
  expect_true(all(grepl("^[0-9a-f]{64}$", s$sha256)))
  expect_false(anyNA(s$boundary_year))
  expect_true(all(s$boundary_year <= s$year))
  expect_false(anyNA(s$pages[s$format == "pdf"]))
})

test_that("URLs are not built from a template (BUG-025)", {
  s <- read_sources(registry_path)
  # The 2025 file has v=2 where the legacy template assumed v=4
  expect_match(s$url[s$year == 2025], "v=2$")
})

test_that("page ranges are parsed strictly", {
  expect_identical(parse_pages("253-259"), 253:259)
  expect_error(parse_pages("253"), "Invalid page range")
})
