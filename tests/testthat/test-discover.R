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
  s <- tibble::tibble(registry = "sources", label = "2025", url = registered_2025, landing_page = landing)
  expect_equal(nrow(check_landing_pages(s, fake_fetch)), 0)
  s$url <- sub("v=2$", "v=1", s$url)
  r <- check_landing_pages(s, fake_fetch)
  expect_equal(r$status, "republished")
  expect_identical(r$linked, registered_2025)
})

test_that("an unreachable host is given up after three pages, not retried for every file", {
  calls <- 0
  dead <- function(url) { calls <<- calls + 1; stop("timeout") }
  files <- tibble::tibble(
    registry = "bund_sources", label = as.character(2013:2020),
    url = paste0("https://www.bka.de/file", 1:8, ".xlsx"),
    landing_page = paste0("https://www.bka.de/page", 1:8, ".html")
  )
  r <- check_landing_pages(files, dead)
  expect_equal(calls, 3)
  expect_equal(sum(r$status == "landing page unreachable"), 3)
  expect_equal(sum(r$status == "not checked (host unreachable)"), 5)
})

test_that("a landing page shared by several files is fetched once", {
  calls <- 0
  landing <- "https://www.bka.de/DE/AktuelleInformationen/StatistikenLagebilder/PolizeilicheKriminalstatistik/PKS2025/pksTabellen_Interpretationshilfen/KreisFalltabellen/kreisfalltabellen.html"
  counting <- function(url) { calls <<- calls + 1; fake_fetch(url) }
  files <- tibble::tibble(registry = "sources", label = c("a", "b"), url = registered_2025, landing_page = landing)
  expect_equal(nrow(check_landing_pages(files, counting)), 0)
  expect_equal(calls, 1)
})

test_that("landing pages left after the time budget are marked, not fetched", {
  calls <- 0
  slow <- function(url) { calls <<- calls + 1; fake_fetch(url) }
  files <- tibble::tibble(registry = "sources", label = c("a", "b"), url = registered_2025,
                          landing_page = c("https://www.bka.de/x.html", "https://www.bka.de/y.html"))
  r <- check_landing_pages(files, slow, budget = -1)
  expect_equal(calls, 0)
  expect_true(all(r$status == "not checked (time budget used up)"))
})

test_that("page requests have a short per-attempt timeout", {
  expect_match(gsub("[[:space:]]+", " ", paste(deparse(body(fetch_html)), collapse = " ")), "timeout = 60", fixed = TRUE)
})
