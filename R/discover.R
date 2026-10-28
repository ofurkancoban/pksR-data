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

# Pages get 60 s per attempt and two minutes of retrying; a missed check is
# reported, not fatal. (An attempt that connects and then stalls is bounded
# by the attempt timeout, not by the retry limit: run 40724008626.)
fetch_html <- function(url) {
  resp <- httr2::req_perform(pksr_request(url, max_seconds = 120, timeout = 60))
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
# file was republished. This replaces downloading every file each month to
# compare hashes. `files` needs columns registry, label, url, landing_page
# (raw_inventory()). After three unreachable pages in a row on one host the
# remaining pages of that host are marked "not checked", and so is every
# page left when `budget` seconds have passed.
check_landing_pages <- function(files, fetch = fetch_html, give_up_after = 3, budget = Inf) {
  deadline <- Sys.time() + budget
  f <- files[!is.na(files$landing_page), ]
  host <- sub("^https?://([^/]+)/.*$", "\\1", f$landing_page)
  misses <- stats::setNames(integer(0), character(0))
  pages <- list()
  rows <- lapply(seq_len(nrow(f)), function(i) {
    row <- function(status, linked = NA_character_) {
      tibble::tibble(registry = f$registry[i], label = f$label[i], status = status, url = f$url[i], linked = linked)
    }
    h <- host[i]
    if (isTRUE(misses[h] >= give_up_after)) return(row("not checked (host unreachable)"))
    if (Sys.time() > deadline) return(row("not checked (time budget used up)"))
    page <- f$landing_page[i]
    if (is.null(pages[[page]])) {
      pages[[page]] <<- tryCatch(page_links(fetch(page), page), error = function(e) NA_character_)
    }
    links <- pages[[page]]
    if (identical(links, NA_character_)) {
      misses[h] <<- (if (is.na(misses[h])) 0L else misses[h]) + 1L
      return(row("landing page unreachable"))
    }
    misses[h] <<- 0L
    if (f$url[i] %in% links) return(NULL)
    same_file <- links[sub("\\?.*$", "", links) == sub("\\?.*$", "", f$url[i])]
    row(if (length(same_file)) "republished" else "no longer linked",
        if (length(same_file)) paste(same_file, collapse = " ") else NA_character_)
  })
  dplyr::bind_rows(
    tibble::tibble(registry = character(0), label = character(0), status = character(0), url = character(0), linked = character(0)),
    rows
  )
}

# BBSR crosswalk (registry/reference_sources.csv). The file name carries the
# last year it covers (ref-kreise-1990-2024.xlsx, verified 2026-10-28), so a
# new edition comes as a new file name on the same landing page. The
# recalculation file ref-kreise-umrech-* is another product and not matched.
bbsr_crosswalk_pattern <- "/ref-kreise-1990-([0-9]{4})\\.xlsx(\\?|$)"

# Crosswalk editions linked from `landing_page`, newest first.
find_bbsr_crosswalks <- function(landing_page, fetch = fetch_html) {
  links <- page_links(fetch(landing_page), landing_page)
  m <- regmatches(links, regexec(bbsr_crosswalk_pattern, links))
  hit <- lengths(m) == 3
  out <- tibble::tibble(end_year = as.integer(vapply(m[hit], `[`, "", 2)), url = links[hit])
  out <- out[!duplicated(out$end_year), ]
  out[order(-out$end_year), ]
}

# The newest linked edition if it covers more years than `registered_url`,
# otherwise zero rows.
newer_bbsr_crosswalk <- function(registered_url, fetch = fetch_html, landing_page) {
  m <- regmatches(registered_url, regexec(bbsr_crosswalk_pattern, registered_url))[[1]]
  if (length(m) != 3) cli::cli_abort("The registered BBSR URL does not name a ref-kreise-1990-<year> file.")
  found <- find_bbsr_crosswalks(landing_page, fetch)
  found$registered_end_year <- rep(as.integer(m[2]), nrow(found))
  found[found$end_year > as.integer(m[2]), ][seq_len(min(1, sum(found$end_year > as.integer(m[2])))), ]
}
