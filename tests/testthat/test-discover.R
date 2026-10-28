# Links of the 29 bka.de pages visited on 2026-10-28, starting at the PKS
# entry page (fixtures/bka_links_2025.rds). A fake fetch serves them offline.
links_2025 <- readRDS(fixture("bka_links_2025.rds"))
fake_fetch <- function(url) {
  links <- links_2025[[url]]
  if (is.null(links)) stop("not recorded: ", url)
  xml2::read_html(paste0("<html><body>", paste0('<a href="', gsub("&", "&amp;", links, fixed = TRUE), '">x</a>', collapse = ""), "</body></html>"))
}
registered_2025 <- "https://www.bka.de/SharedDocs/Downloads/DE/Publikationen/PolizeilicheKriminalstatistik/2025/Kreis/Faelle/KR-F-01-T01-Kreise-Faelle-HZ_xls.xlsx?__blob=publicationFile&v=2"

test_that("a year linked from bka.de but missing in the registry is found with its Kreis case table", {
  new <- discover_new_years(2003:2024, fetch = fake_fetch)
  expect_equal(new$year, 2025L)
  # Only the case table, not the suspect (KR-TV) or victim (KR-O) tables
  expect_identical(new$url, registered_2025)
  expect_match(new$landing_page, "KreisFalltabellen/kreisfalltabellen\\.html$")
})

test_that("nothing is reported when the registry covers every linked year", {
  expect_equal(nrow(discover_new_years(2003:2025, fetch = fake_fetch)), 0)
})

test_that("a republished file (new ?v= on the landing page) is reported", {
  landing <- "https://www.bka.de/DE/AktuelleInformationen/StatistikenLagebilder/PolizeilicheKriminalstatistik/PKS2025/pksTabellen_Interpretationshilfen/KreisFalltabellen/kreisfalltabellen.html"
  s <- tibble::tibble(year = 2025L, url = registered_2025, landing_page = landing)
  expect_equal(nrow(check_landing_pages(s, fake_fetch)), 0)
  s$url <- sub("v=2$", "v=1", s$url)
  r <- check_landing_pages(s, fake_fetch)
  expect_equal(r$status, "republished")
  expect_identical(r$linked, registered_2025)
})
