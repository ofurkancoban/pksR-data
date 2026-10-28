# Regression guards on the pipeline definition (BUG-008, BUG-009).

manifest <- function() {
  withr::with_dir(root, targets::tar_manifest(fields = c("name", "pattern", "format"), callr_function = NULL))
}

test_that("raw files are tracked by content, not by existence (BUG-008)", {
  m <- manifest()
  expect_identical(m$format[m$name == "raw_file"], "file")
  expect_identical(m$format[m$name == "sources_file"], "file")
  expect_identical(m$format[m$name == "bbsr_file"], "file")
  expect_identical(m$format[m$name == "boundary_map_file"], "file")
  expect_identical(m$format[m$name == "offence_map_file"], "file")
  expect_identical(m$format[m$name == "bund_raw_file"], "file")
})

test_that("each registry row is its own branch with declared inputs (BUG-009)", {
  m <- manifest()
  expect_identical(m$pattern[m$name == "raw_file"], "map(sources)")
  expect_identical(m$pattern[m$name == "canonical"], "map(sources, raw_file)")
  expect_identical(m$pattern[m$name == "canonical_file"], "map(canonical)")
})

test_that("no stage skips work because an output file exists (BUG-008)", {
  code <- unlist(lapply(list.files(file.path(root, "R"), full.names = TRUE), readLines))
  expect_false(any(grepl("should_skip|file\\.exists\\(.*output", code)))
})

test_that("pipeline code is ASCII so regexes work in any locale", {
  # A literal umlaut in a regex is invalid when R runs in the C locale (e.g.
  # with an unsupported LANG); use \u escapes. Comments may contain umlauts.
  files <- c(list.files(file.path(root, "R"), pattern = "\\.R$", full.names = TRUE),
             file.path(root, "_targets.R"))
  non_ascii <- files[vapply(files, function(f) {
    code <- grep("^\\s*#", readLines(f, warn = FALSE), value = TRUE, invert = TRUE)
    any(grepl("[^\\x01-\\x7F]", code, perl = TRUE, useBytes = TRUE))
  }, logical(1))]
  expect_identical(basename(non_ascii), character(0))
})
