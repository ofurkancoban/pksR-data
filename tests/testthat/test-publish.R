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
    "pks_kreis_published.parquet", "pks_kreis_2019_published.csv.gz", "pks_kreis_panel_population.parquet", "pks_kreis_2019_population.csv.gz",
    "validation_population.json", "sources.csv", "bund_sources.csv", "destatis_sources.csv",
    "reference_sources.csv", "boundary_map.csv", "offence_map.csv", "known_breaks.csv",
    "population_inkar.csv", "inkar_sources.csv", "ATTRIBUTION.txt"
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
  # A file without rows gets null, not the string "NA" (dry run test-2026.1-run7)
  report <- back$files[[which(vapply(back$files, `[[`, "", "name") == "validation_population.json")]]
  expect_null(report$rows)
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

test_that("no release when the branch moved during the run", {
  expect_true(assert_branch_unchanged("o/r", "main", "abc", head = "abc"))
  expect_error(assert_branch_unchanged("o/r", "main", "abc1234", head = "def5678"), "moved during the run")
})

test_that("every release names all sources, their licences and the changes made", {
  r <- release_fixture()
  m <- build_manifest(r$dir, "2026.1", "abc")
  expect_identical(m$license, "dl-de/by-2-0")
  expect_identical(m$license_url, "https://www.govdata.de/dl-de/by-2-0")
  notes <- vapply(m$attribution, `[[`, "", "source_note")
  expect_match(notes[1], sprintf("^PKS Bundeskriminalamt, reporting years %d to %d", min(m$years), max(m$years)))
  expect_match(notes[2], "^BBSR Bonn [0-9]{4}$")
  expect_match(notes[3], "^Statistisches Bundesamt \\(Destatis\\)")
  expect_match(notes[4], "^INKAR, BBSR Bonn [0-9]{4}$")
  expect_match(m$license_note, "not official figures", fixed = TRUE)
  # Every registry an attribution points to ships with the release
  expect_true(all(file.exists(file.path(r$dir, unlist(lapply(m$attribution, `[[`, "registry"))))))
  txt <- readLines(file.path(r$dir, "ATTRIBUTION.txt"), encoding = "UTF-8")
  expect_true(any(grepl("BBSR Bonn", txt)) && any(grepl("dl-de/by-2-0", txt)))
  expect_true(any(grepl("Changes made by", paste(txt, collapse = " "))))
})
