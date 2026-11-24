# Word gaps in PDF district names (BUG-043). The vocabulary comes from a small
# crosswalk with BBSR spellings; the names are the damaged forms of release
# v2026.1.

names_map <- tibble::tibble(
  from_name = c(
    "Herzogtum Lauenburg", "Mülheim an der Ruhr", "Rhein-Kreis Neuss",
    "Städteregion Aachen", "Breisgau-Hochschwarzwald", "Neustadt a.d.Waldnaab",
    "Neustadt a.d.Aisch-Bad Windsh", "Frankfurt am Main", "Weiden i.d.OPf."
  ),
  to_name = c(
    "Herzogtum Lauenburg", "KS Mülheim a.d.Ruhr", "Rhein-Kreis-Neuss",
    "Aachen", "Breisgau-Hochschwarzwald", "Neustadt a.d.Waldnaab",
    "Neustadt a.d.Aisch-Bad Windsheim", "KS Frankfurt am Main", "KS Weiden i.d.OPf."
  )
)
vocab <- name_vocabulary(names_map)

test_that("a missing word gap is added (BUG-043)", {
  expect_identical(respace_name("LK HerzogtumLauenburg", vocab), "LK Herzogtum Lauenburg")
  expect_identical(respace_name("SK MülheimanderRuhr", vocab), "SK Mülheim an der Ruhr")
  expect_identical(respace_name("SK FrankfurtamMain", vocab), "SK Frankfurt am Main")
  expect_identical(respace_name("LK Neustadta.d.Aisch-BadWindsheim", vocab), "LK Neustadt a.d.Aisch-Bad Windsheim")
  expect_identical(respace_name("SK Weideni.d.OPf.", vocab), "SK Weiden i.d.OPf.")
})

test_that("a word gap is never put in front of a hyphen or comma (BUG-043)", {
  expect_identical(respace_name("LK Rhein-KreisNeuss", vocab), "LK Rhein-Kreis Neuss")
  expect_identical(respace_name("LK Aachen,Städteregion", vocab), "LK Aachen, Städteregion")
})

test_that("a gap inside a word and a line break hyphen are removed (BUG-043)", {
  expect_identical(respace_name("LK Neustadt a.d.Waldn aab", vocab), "LK Neustadt a.d.Waldnaab")
  expect_identical(respace_name("LK Breisgau-Hoch-schwarzwald", vocab), "LK Breisgau-Hochschwarzwald")
})

test_that("correct names and BKA spellings stay as published (BUG-043)", {
  expect_identical(respace_name("LK Herzogtum Lauenburg", vocab), "LK Herzogtum Lauenburg")
  expect_identical(respace_name("LK Rhein-Kreis Neuss", vocab), "LK Rhein-Kreis Neuss")
  expect_identical(respace_name("SK Halle (Salle)*)", vocab), "SK Halle (Salle)*)")
  expect_identical(respace_name(NA_character_, vocab), NA_character_)
})

test_that("repair_region_names() changes PDF years only and reports changes (BUG-043)", {
  pdf <- tibble::tibble(
    year = 2011L, ags = c("01053", "01053"), offence_key = c("------", "2200"),
    region_name = "LK HerzogtumLauenburg", source_format = "pdf"
  )
  expect_message(out <- repair_region_names(pdf, names_map), "repaired in 1 district name")
  expect_identical(out$region_name, rep("LK Herzogtum Lauenburg", 2))

  xls <- pdf
  xls$source_format <- "xlsx"
  expect_identical(repair_region_names(xls, names_map), xls)
})

test_that("a name with a word outside the BBSR names stops the pipeline (BUG-043)", {
  bad <- tibble::tibble(year = 2011L, region_name = "LK Herzogtum Lauenbrug", source_format = "pdf")
  expect_error(check_region_names(bad, vocab), "Lauenbrug")
})

test_that("every PDF year of the pipeline passes the name check (BUG-043)", {
  skip_if_not(dir.exists(file.path(root, "output", "canonical")), "no canonical outputs")
  map <- read_boundary_map(registry_path("boundary_map.csv"))
  vocab_all <- name_vocabulary(map)
  for (year in 2003:2012) {
    path <- file.path(root, "output", "canonical", sprintf("pks_kreis_%d.parquet", year))
    skip_if_not(file.exists(path), paste("no canonical output for", year))
    d <- arrow::read_parquet(path, col_select = c("year", "region_name", "source_format"))
    expect_silent(check_region_names(d, vocab_all))
  }
})
