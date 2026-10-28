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
  bbsr <- file.path(root, "data-raw", "bbsr", "ref-kreise-1990-2024.xlsx")
  skip_if_not(file.exists(bbsr), "BBSR file not downloaded")
  expect_true(check_boundary_map_source(map, bbsr))
  edited <- map
  edited$weight_population[edited$id == "bbsr-2016-r010"] <- 0.5
  expect_error(check_boundary_map_source(edited, bbsr), "differ")
})
