# Discovery of new PKS years and of republished files (brief Section 9.1.1).
#
# Nothing here builds a URL from a template: a new year is found by following
# the links of the BKA PKS entry page, and a Kreis table only by a link on a
# page of that year. Discovery reports; it never edits the registry, because
# a new year needs a layout check before its row is added (issue opened by
# CI, notes/decisions.md).

# Entry page of the PKS on bka.de (verified 2026-10-28: links the page of
# the latest reporting year, PKS2025/pks2025_node.html).
bka_pks_index_url <- "https://www.bka.de/DE/AktuelleInformationen/StatistikenLagebilder/PolizeilicheKriminalstatistik/pks_node.html"

fetch_html <- function(url) {
  resp <- httr2::req_perform(pksr_request(url))
  xml2::read_html(httr2::resp_body_string(resp))
}

# Absolute link targets of a page, without fragments.
page_links <- function(doc, base) {
  href <- xml2::xml_attr(xml2::xml_find_all(doc, "//a[@href]"), "href")
  href <- href[!is.na(href) & !grepl("^(mailto|javascript):", href)]
  unique(sub("#.*$", "", xml2::url_absolute(href, base)))
}

# Reporting years linked from the entry page, with their year page.
linked_years <- function(links) {
  m <- regmatches(links, regexec("/PolizeilicheKriminalstatistik/PKS([0-9]{4})/[^?]*_node\\.html$", links))
  hit <- lengths(m) == 2
  out <- tibble::tibble(year = as.integer(vapply(m[hit], `[`, "", 2)), year_page = links[hit])
  out[!duplicated(out$year), ]
}

# Breadth-first walk over the pages of one reporting year (URL path contains
# /PKS<year>/), at most `max_pages` pages. Returns every download link that
# looks like a Kreis case table, with the page that links it.
# On 2026-10-28 the 2025 table was linked from the 14th of 29 pages.
find_kreis_tables <- function(year, start_url, fetch = fetch_html, max_pages = 40) {
  scope <- paste0("/PKS", year, "/")
  queue <- start_url
  seen <- character(0)
  found <- tibble::tibble(url = character(0), landing_page = character(0))
  while (length(queue) > 0 && length(seen) < max_pages) {
    page <- queue[1]
    queue <- queue[-1]
    if (page %in% seen) next
    seen <- c(seen, page)
    links <- tryCatch(page_links(fetch(page), page), error = function(e) character(0))
    downloads <- links[grepl("__blob=publicationFile", links, fixed = TRUE)]
    # Case tables only: 2025 also links Kreis suspect (KR-TV) and victim
    # (KR-O) tables below /Kreis/.
    kreis <- downloads[grepl(paste0("/", year, "/Kreis/Faelle/"), downloads, fixed = TRUE) | grepl("/KR-F-[0-9]", downloads)]
    if (length(kreis)) found <- dplyr::bind_rows(found, tibble::tibble(url = kreis, landing_page = page))
    pages <- sub("\\?.*$", "", links[grepl(scope, links, fixed = TRUE) & grepl("\\.html(\\?|$)", links)])
    queue <- c(queue, setdiff(unique(pages), c(seen, queue)))
  }
  found[!duplicated(found$url), ]
}

# New years: linked from the entry page but not in the registry.
discover_new_years <- function(registry_years, fetch = fetch_html, index_url = bka_pks_index_url) {
  years <- linked_years(page_links(fetch(index_url), index_url))
  new <- years[!years$year %in% registry_years, ]
  if (nrow(new) == 0) {
    return(tibble::tibble(year = integer(0), year_page = character(0), url = character(0), landing_page = character(0)))
  }
  dplyr::bind_rows(lapply(seq_len(nrow(new)), function(i) {
    t <- find_kreis_tables(new$year[i], new$year_page[i], fetch)
    if (nrow(t) == 0) t <- tibble::tibble(url = NA_character_, landing_page = NA_character_)
    tibble::tibble(year = new$year[i], year_page = new$year_page[i], url = t$url, landing_page = t$landing_page)
  }))
}

# Registered files whose landing page no longer links them. A link to the
# same file with another query (BKA: "&v=3" instead of "&v=2") means the
# file was republished.
check_landing_pages <- function(sources, fetch = fetch_html) {
  s <- sources[!is.na(sources$landing_page), ]
  rows <- lapply(seq_len(nrow(s)), function(i) {
    links <- tryCatch(page_links(fetch(s$landing_page[i]), s$landing_page[i]), error = function(e) NULL)
    if (is.null(links)) {
      return(tibble::tibble(year = s$year[i], status = "landing page unreachable", url = s$url[i], linked = NA_character_))
    }
    if (s$url[i] %in% links) return(NULL)
    same_file <- links[sub("\\?.*$", "", links) == sub("\\?.*$", "", s$url[i])]
    tibble::tibble(
      year = s$year[i],
      status = if (length(same_file)) "republished" else "no longer linked",
      url = s$url[i],
      linked = if (length(same_file)) paste(same_file, collapse = " ") else NA_character_
    )
  })
  dplyr::bind_rows(tibble::tibble(year = integer(0), status = character(0), url = character(0), linked = character(0)), rows)
}
