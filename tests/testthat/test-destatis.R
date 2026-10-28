destatis_dir <- file.path(root, "data-raw", "destatis")
bbsr_path <- file.path(root, "data-raw", "bbsr", "ref-kreise-1990-2024.xlsx")
reg <- read_boundary_map(registry_path("boundary_map.csv"))
eff <- effective_boundary_map(reg)

test_that("changes are assigned to the BBSR period they fall in", {
  # 01.01.2023 lies between 31.12.2022 and 31.12.2023
  expect_identical(destatis_period(as.Date(c("2023-01-01", "2011-12-31", "2014-07-01"))), c(2022L, 2010L, 2013L))
  expect_equal(destatis_date(c("44927", "01.01.2023")), as.Date(c("2023-01-01", "2023-01-01")))
})

test_that("transfers missing in BBSR are added with Destatis inhabitants (BUG-035)", {
  row <- eff[eff$id == "destatis-2022-16064-16061", ]
  expect_equal(nrow(row), 1)
  expect_match(row$reason, "3,881 inhabitants")
  expect_equal(row$weight_population, 3881 / 102256, tolerance = 1e-12)
  # The share is taken off Unstrut-Hainich's own row, so the sum stays 1
  own <- eff[eff$period == 2022 & eff$from_ags == "16064" & eff$to_ags == "16064", ]
  expect_equal(own$weight_population, 1 - 3881 / 102256, tolerance = 1e-12)
  expect_silent(assert_boundary_map(eff))
  expect_true(all(reg$status[reg$source == "destatis"] == "draft"))
})

test_that("transfers implied by BBSR are not added twice", {
  # 13059 to 13062 on 01.01.2011: both districts go to 13075 in the same period
  expect_false(any(grepl("^destatis-2010-13059", reg$id)))
  expect_false(any(reg$source == "destatis" & reg$period == 2011 & reg$from_ags == "07231"))
})

test_that("Destatis rows in the registry must equal the Destatis files", {
  skip_if_not(dir.exists(destatis_dir) && file.exists(bbsr_path), "Destatis or BBSR files not downloaded")
  s <- read_destatis_sources(registry_path("destatis_sources.csv"))
  ch <- suppressMessages(read_destatis_all(s, destatis_dir))
  expect_true(check_boundary_map_destatis(reg, ch, bbsr_path))
  edited <- reg
  edited$weight_population[edited$id == "destatis-2022-16064-16061"] <- 0.01
  expect_error(check_boundary_map_destatis(edited, ch, bbsr_path), "differ")
})

test_that("the area unit is read from each file's header (hectares until 2006)", {
  skip_if_not(dir.exists(destatis_dir), "Destatis files not downloaded")
  s <- read_destatis_sources(registry_path("destatis_sources.csv"))
  ha <- suppressMessages(read_destatis_changes(file.path(destatis_dir, "destatis_gebietsaenderungen_2006.xlsx"), s$sha256[s$label == "2006"]))
  qm <- suppressMessages(read_destatis_changes(file.path(destatis_dir, "destatis_gebietsaenderungen_2023.xlsx"), s$sha256[s$label == "2023"]))
  # Michelbach (Westerwald) keeps 439 ha = 4.39 km2 in 2006
  expect_equal(ha$area_m2[ha$from_gem == "07132070" & ha$to_gem == "07132070"], 439 * 1e4)
  moved <- qm[substr(qm$from_gem, 1, 5) == "16064" & substr(qm$to_gem, 1, 5) == "16061", ]
  expect_equal(sum(moved$area_m2) / 1e6, 48.082517, tolerance = 1e-6)
  expect_identical(sum(moved$inhabitants), 3881)
})

test_that("implausible BBSR denominators are refused", {
  skip_if_not(file.exists(bbsr_path), "BBSR file not downloaded")
  # Sheet 2007-2008 gives target populations on Saxon rows (Plauen 253,672)
  fake <- tibble::tibble(kennziffer = "x", from_gem = "14166000", from_name = "x", change_type = "2",
                         area_m2 = 1e5, inhabitants = 100, to_gem = "12053000", to_name = "x",
                         effective = as.Date("2008-03-01"))
  expect_error(destatis_transfer_rows(fake, apply_manual_rows(reg), bbsr_district_totals(bbsr_path, 2006:2008)), "Implausible")
})
