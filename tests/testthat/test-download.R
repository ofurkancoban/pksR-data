test_that("a file whose hash differs from the registry is rejected (BUG-025)", {
  path <- withr::local_tempfile()
  writeLines("not the BKA file", path)
  expect_error(verify_sha256(path, strrep("0", 64)), "differs from the registry")
  expect_identical(verify_sha256(path, sha256_file(path)), sha256_file(path))
})

test_that("extraction refuses a raw file that is not the registered one", {
  path <- fixture("2003_p253.pdf")
  src <- fixture_source(2003, basename(path), "pdf", pages = "1-1")
  src$sha256 <- strrep("0", 64)
  expect_error(extract_source(src, path), "differs from the registry")
})

test_that("requests identify the pipeline", {
  expect_match(pksr_user_agent, "pksR-data")
})

test_that("a download with another hash never replaces the registered file", {
  dir <- withr::local_tempdir()
  good <- file.path(dir, "a.txt")
  writeLines("registered", good)
  inv <- tibble::tibble(registry = "sources", label = "2099", url = "https://example.invalid/a",
                        sha256 = sha256_file(good), path = good)
  republished <- function(url, path) writeLines("republished", path)
  res <- fetch_raw(inv, refresh = TRUE, drift_dir = file.path(dir, "drift"), get = republished)
  expect_equal(res$status, "changed")
  expect_identical(readLines(good), "registered")
  expect_true(file.exists(file.path(dir, "drift", "a.txt")))
  # Present with the right hash: no download at all
  res <- fetch_raw(inv, get = function(url, path) stop("must not download"))
  expect_equal(res$status, "present")
  # Unreachable source: reported, not fatal inside fetch_raw()
  unlink(good)
  res <- fetch_raw(inv, get = function(url, path) stop("HTTP 404"))
  expect_equal(res$status, "failed")
  expect_match(res$message, "404")
})

test_that("every registry row has a URL, a hash and its own raw file path", {
  inv <- raw_inventory(file.path(root, "registry"), "data-raw")
  expect_setequal(unique(inv$registry), c("sources", "bund_sources", "destatis_sources", "reference_sources"))
  expect_equal(sum(inv$registry == "reference_sources"), 1)
  expect_false(anyDuplicated(inv$path) > 0)
})

test_that("connection failures are retried, not only transient HTTP statuses", {
  req <- pksr_request("https://example.invalid/a")
  expect_true(req$policies$retry_on_failure)
  expect_equal(req$policies$retry_max_tries, 5)
  expect_equal(req$options$connecttimeout, 60)
})
