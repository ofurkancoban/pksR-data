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
