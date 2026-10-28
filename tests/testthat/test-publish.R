release_fixture <- function() {
  dir <- withr::local_tempdir(.local_envir = parent.frame())
  h <- harmonize_space(toy_year(), toy_map(), 2021)
  can <- file.path(dir, "canonical", "pks_kreis_2019.parquet")
  dir.create(dirname(can))
  arrow::write_parquet(toy_year(), can)
  panel <- write_panel(h, "population", file.path(dir, "harmonized"))
  report <- file.path(dir, "report_population.json")
  jsonlite::write_json(list(weights = "population", target_boundary_year = 2021, years = c(2019, 2019),
                            checks = list(list(check = "schema", status = "pass", problems = list()))),
                       report, auto_unbox = TRUE)
  assets <- build_release_assets(can, c(panel, report), file.path(root, "registry"), file.path(dir, "release"))
  list(dir = file.path(dir, "release"), assets = assets, report = report)
}

test_that("release assets carry the weighting in their names and the notes in the Parquet files", {
  r <- release_fixture()
  expect_setequal(basename(r$assets), c(
    "pks_kreis_published.parquet", "pks_kreis_panel_population.parquet", "pks_kreis_2019_population.csv.gz",
    "validation_population.json", "sources.csv", "boundary_map.csv", "offence_map.csv", "known_breaks.csv"
  ))
  meta <- arrow::read_parquet(file.path(r$dir, "pks_kreis_published.parquet"), as_data_frame = FALSE)$metadata$pksR_notes
  expect_identical(jsonlite::fromJSON(meta), as.list(published_notes))
})

test_that("the manifest describes every asset with hash, size and rows", {
  r <- release_fixture()
  m <- build_manifest(r$dir, "2026.1", "abc123", as.POSIXct("2026-10-28 12:00:00", tz = "UTC"))
  expect_identical(m$created_at, "2026-10-28T12:00:00Z")
  expect_equal(m$target_boundary_year, 2021L)
  names <- vapply(m$files, `[[`, "", "name")
  expect_setequal(names, basename(r$assets))
  f <- m$files[[which(names == "pks_kreis_panel_population.parquet")]]
  expect_identical(f$sha256, sha256_file(file.path(r$dir, f$name)))
  expect_equal(f$rows, 5)
  expect_equal(m$files[[which(names == "pks_kreis_2019_population.csv.gz")]]$rows, 5)
  path <- write_manifest(m, r$dir)
  back <- jsonlite::read_json(path)
  expect_null(back$zenodo_doi)
  expect_false(data_changed(back, m))
})

test_that("no manifest without a passed validation gate", {
  r <- release_fixture()
  bad <- jsonlite::read_json(file.path(r$dir, "validation_population.json"))
  bad$checks[[1]]$status <- "fail"
  jsonlite::write_json(bad, file.path(r$dir, "validation_population.json"), auto_unbox = TRUE)
  expect_error(build_manifest(r$dir, "2026.1", "abc"), "validation gate")
})

test_that("a rerun on the same data is not released again", {
  r <- release_fixture()
  m <- build_manifest(r$dir, "2026.1", "abc")
  expect_true(data_changed(m, NULL))
  expect_false(data_changed(m, m))
  m2 <- m
  m2$content_sha256$pks_kreis_panel_population <- "0"
  expect_true(data_changed(m2, m))
})

test_that("data versions count up within a year and ignore test tags", {
  expect_identical(next_data_version(character(0), 2026L), "2026.1")
  expect_identical(next_data_version(c("v2026.1", "v2026.3", "v2025.9", "test-2026.4-run2"), 2026L), "2026.4")
  expect_identical(next_data_version(c("v2025.2"), 2026L), "2026.1")
})

test_that("an existing tag is never overwritten", {
  # The pipeline is not a package: replace the function where it lives
  orig <- github_releases
  assign("github_releases", function(repo, token = NULL) tibble::tibble(tag_name = "v2026.1"), envir = globalenv())
  withr::defer(assign("github_releases", orig, envir = globalenv()))
  expect_error(publish_release(withr::local_tempdir(), "o/r", "v2026.1", "body"), "immutable")
})
