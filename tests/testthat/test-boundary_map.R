map <- read_boundary_map(registry_path("boundary_map.csv"))
eff <- effective_boundary_map(map)

test_that("weights sum to 1 per source district and year (BUG-017)", {
  expect_silent(assert_boundary_map(eff))
  # The raw BBSR rows do not, and are not renormalized silently
  expect_error(assert_boundary_map(map[map$source == "bbsr", ]), "does not sum to 1")
  bad <- toy_map()
  bad$weight_population[bad$id == "d"] <- 0.25
  expect_error(assert_boundary_map(bad), "03001")
})

test_that("missing transition year is an error (BUG-018)", {
  m <- toy_map()
  expect_error(compose_crosswalk(m[m$period == 2019, ], 2019, 2021), "no period 2020")
  gap <- dplyr::bind_rows(m, dplyr::mutate(m[m$period == 2020, ], period = 2022L, id = paste0(id, "2")))
  expect_error(assert_boundary_map(gap), "gaps")
})

test_that("03156, 03152 and 16056 map to 03159 and 16063 (BUG-005)", {
  rows <- eff[eff$from_ags %in% c("03152", "03156", "16056") & eff$from_ags != eff$to_ags, ]
  expect_setequal(rows$to_ags[rows$from_ags %in% c("03152", "03156")], "03159")
  expect_identical(unique(rows$period[rows$from_ags %in% c("03152", "03156")]), 2015L)
  expect_identical(rows$to_ags[rows$from_ags == "16056"], "16063")
  expect_identical(rows$period[rows$from_ags == "16056"], 2020L)
  expect_true(all(rows$weight_population == 1) && all(rows$source == "bbsr"))
})

test_that("manual rows replace BBSR rows visibly and stay draft", {
  manual <- map[map$source == "manual", ]
  expect_true(all(manual$replaces %in% map$id))
  expect_true(all(manual$status == "draft"))
  expect_false(any(eff$id %in% manual$replaces))
  # Q5: Mayen-Koblenz and Cochem-Zell kept whole in 2014 and 2015
  mk <- eff[eff$period %in% 2014:2015 & eff$from_ags %in% c("07135", "07137"), ]
  expect_true(all(mk$to_ags == mk$from_ags & mk$weight_population == 1 & mk$weight_area == 1))
})

test_that("district counts follow the boundary year (BUG-006)", {
  expect_length(boundary_codes(eff, 2025), 400)
  expect_length(boundary_codes(eff, 2003), 439)
  expect_length(boundary_codes(eff, 2016), 401)
  expect_true(all(c("02000", "11000") %in% boundary_codes(eff, 2003)))
})

test_that("BBSR rows in the registry equal the BBSR file", {
  bbsr <- registered_bbsr_path()
  skip_if_not(file.exists(bbsr), "BBSR file not downloaded")
  expect_true(check_boundary_map_source(map, bbsr))
  edited <- map
  edited$weight_population[edited$id == "bbsr-2016-r010"] <- 0.5
  expect_error(check_boundary_map_source(edited, bbsr), "differ")
})

# A newer BBSR edition, simulated: the registry copy lacks the last period of
# the registered file, so the file is one edition ahead of the registry.
crosswalk_update_fixture <- function(edit = identity) {
  bbsr <- registered_bbsr_path()
  destatis_dir <- file.path(root, "data-raw", "destatis")
  skip_if_not(file.exists(bbsr) && dir.exists(destatis_dir), "BBSR or Destatis files not downloaded")
  changes <- read_destatis_all(read_destatis_sources(registry_path("destatis_sources.csv")), destatis_dir)
  m <- read_boundary_map_raw(registry_path("boundary_map.csv"))
  m <- edit(m[m$period < max(m$period), ])
  path <- withr::local_tempfile(fileext = ".csv", .local_envir = parent.frame())
  readr::write_csv(m, path, na = "")
  list(bbsr = bbsr, path = path, changes = changes, old = m)
}

test_that("a newer BBSR edition adds its periods and moves the target year", {
  f <- crosswalk_update_fixture()
  r <- update_boundary_map(f$bbsr, f$path, f$changes)
  last <- max(f$old$period) + 1L
  expect_equal(r$new_periods, last)
  expect_equal(c(r$previous_target_year, r$target_year), c(last, last + 1L))
  expect_equal(r$target_districts, length(boundary_codes(effective_boundary_map(read_boundary_map(registry_path("boundary_map.csv"))), last + 1L)))
  expect_gt(r$bbsr$added, 0)
  expect_equal(c(r$bbsr$removed, r$bbsr$changed), c(0L, 0L))
  expect_equal(r$manual_rows_kept, sum(f$old$source == "manual"))
  # The result is the registered map again, row for row
  expect_identical(readLines(f$path), readLines(registry_path("boundary_map.csv")))
})

test_that("a manual row is never kept on a BBSR row that now means another transition", {
  f <- crosswalk_update_fixture(function(m) {
    id <- m$replaces[m$source == "manual"][1]
    m$to_ags[m$id == id] <- "99999"
    m
  })
  expect_error(update_boundary_map(f$bbsr, f$path, f$changes), "another transition")
})

test_that("reviewed Destatis rows stay reviewed and drafts stay draft", {
  f <- crosswalk_update_fixture(function(m) {
    m$status[which(m$source == "destatis")[1]] <- "draft"
    m
  })
  draft_id <- f$old$id[which(f$old$source == "destatis")[1]]
  r <- update_boundary_map(f$bbsr, f$path, f$changes)
  expect_equal(r$destatis_reviewed_kept, sum(f$old$source == "destatis" & f$old$status == "reviewed"))
  new <- read_boundary_map_raw(f$path)
  expect_identical(new$status[new$id == draft_id], "draft")
  expect_true(all(new$status[new$source == "destatis" & new$id != draft_id] == "reviewed"))
})

test_that("the reference registry is pointed at the new file", {
  path <- withr::local_tempfile(fileext = ".csv")
  file.copy(registry_path("reference_sources.csv"), path)
  update_reference_source(path, "bbsr_ref_kreise", "https://example.org/ref-kreise-1990-2025.xlsx", "abc", "ref-kreise-1990-2025.xlsx", "2027-01-15")
  ref <- readr::read_csv(path, col_types = readr::cols(.default = "c"))
  expect_identical(ref$file_name, "ref-kreise-1990-2025.xlsx")
  expect_identical(ref$retrieved_at, "2027-01-15")
  expect_error(update_reference_source(path, "nope", "u", "s", "f"), "no single row")
})
