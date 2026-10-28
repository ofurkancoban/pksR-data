omap <- read_offence_map(registry_path("offence_map.csv"))
spec <- offence_spec(omap)
breaks <- read_known_breaks(registry_path("known_breaks.csv"))

test_that("------ and 890000 are never coalesced into one series (BUG-012)", {
  total <- spec[spec$offence_key_harmonized == "------", ]
  expect_true(all(total$plus_key == "------" & is.na(total$minus_key)))
  excl <- spec[spec$offence_key_harmonized == "890000", ]
  expect_identical(min(excl$year), 2014L)
  expect_true(all(excl$plus_key[excl$year >= 2015] == "890000"))
  expect_identical(excl$minus_key[excl$year == 2014], "725000")
})

test_that("no harmonized key mixes source keys across years without a documented break (BUG-013)", {
  # 4-digit notation until 2007 is the same key (BRK-001)
  six <- function(k) ifelse(nchar(k) == 4, paste0(k, "00"), k)
  six_digit <- spec
  six_digit$source <- ifelse(is.na(spec$minus_key), six(spec$plus_key), paste(spec$plus_key, spec$minus_key))
  n_sources <- tapply(six_digit$source, six_digit$offence_key_harmonized, function(x) length(unique(x)))
  mixed <- names(n_sources)[n_sources > 1]
  documented <- unlist(strsplit(stats::na.omit(breaks$offence_key), ";", fixed = TRUE))
  expect_true(all(mixed %in% documented))
  expect_identical(spec$plus_key[spec$offence_key_harmonized == "220000" & spec$year == 2003], "2200")
  expect_false(any(spec$offence_key_harmonized == "220000" & spec$year %in% 2010:2012))
})

test_that("unknown offence keys stop the pipeline (Section 9.1.5)", {
  d <- toy_year()
  d$year <- 2025L
  d$offence_key <- "999999"
  expect_error(harmonize_offences(as_harmonized(cbind(d, offence_key_published = "999999")), omap), "not in registry")
})

test_that("890000 for 2014 is ------ minus 725000 with suspects NA", {
  d <- dplyr::bind_rows(lapply(c("------", "725000"), function(k) {
    x <- toy_year()
    x$offence_key <- k
    x
  }))
  d$year <- 2014L
  d$cases[d$offence_key == "725000"] <- 10L
  m <- omap
  m$source_keys[m$offence_key_harmonized == "------"] <- "------@2014"
  m$source_keys[m$offence_key_harmonized == "725000"] <- "725000@2014"
  m <- m[m$offence_key_harmonized %in% c("------", "725000", "890000"), ]
  m$source_keys[m$offence_key_harmonized == "890000"] <- "------ minus 725000@2014"
  m$parent_key <- NA
  h <- harmonize_offences(as_harmonized(cbind(d, offence_key_published = d$offence_key)), m)
  excl <- h[h$offence_key == "890000", ]
  full <- h[h$offence_key == "------", ]
  expect_equal(excl$cases, full$cases - 10)
  expect_true(all(is.na(excl$suspects)))
  expect_identical(unique(excl$offence_key_published), "------ minus 725000")
})

test_that("*50*00 is theft from vehicles, not theft of cars (BUG-024)", {
  expect_match(omap$label_en[omap$offence_key_harmonized == "*50*00"], "from")
  expect_false(grepl("motor cars", omap$label_en[omap$offence_key_harmonized == "*50*00"]))
})

test_that("every mapping is a draft until reviewed (rule 9)", {
  expect_true(all(omap$status %in% c("draft", "reviewed")))
  expect_true(all(omap$parent_key %in% c(NA, omap$offence_key_harmonized)))
})

test_that("parent keys hold in the data: child cases never exceed parent cases", {
  panel_path <- file.path(root, "output", "harmonized", "population", "pks_kreis_panel.parquet")
  skip_if_not(file.exists(panel_path), "panel not built")
  p <- arrow::read_parquet(panel_path, col_select = c("year", "ags", "offence_key", "cases"))
  p <- p[p$year >= 2013, ]
  x <- merge(p, omap[!is.na(omap$parent_key), c("offence_key_harmonized", "parent_key")],
             by.x = "offence_key", by.y = "offence_key_harmonized")
  x <- merge(x, p, by.x = c("year", "ags", "parent_key"), by.y = c("year", "ags", "offence_key"), suffixes = c("", "_parent"))
  expect_gt(nrow(x), 150000)
  expect_identical(sum(x$cases > x$cases_parent), 0L)
})
