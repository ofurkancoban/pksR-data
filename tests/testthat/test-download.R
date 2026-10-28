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

test_that("requests to one host are at least ten seconds apart", {
  # httr2 keeps the throttle outside the request object, so check the code
  expect_match(gsub("[[:space:]]+", " ", paste(deparse(body(pksr_request)), collapse = " ")), "capacity = 1, fill_time_s = 10)", fixed = TRUE)
})

test_that("the mirror is used first and its copies are checked against the registry", {
  dir <- withr::local_tempdir()
  src <- file.path(dir, "src.txt")
  writeLines("registered", src)
  inv <- tibble::tibble(registry = "sources", label = "2099", url = "https://example.invalid/a",
                        sha256 = sha256_file(src), path = file.path(dir, "raw", "a.txt"), mirror_name = "a.txt")
  no_source <- function(url, path) stop("source must not be contacted")
  from_mirror <- function(name, dest) file.copy(src, dest, overwrite = TRUE)
  res <- fetch_raw(inv, mirror = from_mirror, get = no_source)
  expect_equal(res$status, "mirrored")
  expect_identical(readLines(inv$path), "registered")
  # A corrupt mirror copy is ignored and the source decides
  unlink(inv$path)
  corrupt <- function(name, dest) { writeLines("corrupt", dest); TRUE }
  from_source <- function(url, path) file.copy(src, path, overwrite = TRUE)
  res <- fetch_raw(inv, mirror = corrupt, get = from_source)
  expect_equal(res$status, "downloaded")
  # A file the mirror lacks comes from the source
  unlink(inv$path)
  res <- fetch_raw(inv, mirror = function(name, dest) FALSE, get = from_source)
  expect_equal(res$status, "downloaded")
})

test_that("mirror asset names keep the folder and are unique", {
  expect_identical(mirror_asset_name(c("data-raw/2003_pks2003.pdf", "data-raw/bund/2013_x.xls")),
                   c("2003_pks2003.pdf", "bund__2013_x.xls"))
  inv <- raw_inventory(file.path(root, "registry"), "data-raw")
  expect_false(anyDuplicated(inv$mirror_name) > 0)
  expect_true(all(grepl("^[A-Za-z0-9._-]+$", inv$mirror_name)))
})

test_that("a request gives up after a bounded time, retries included", {
  expect_equal(pksr_request("https://example.invalid/a")$policies$retry_max_wait, 300)
})
