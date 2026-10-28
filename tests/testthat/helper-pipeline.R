# Load the pipeline functions; pksR-data is not a package.
root <- normalizePath(test_path("..", ".."))
for (f in list.files(file.path(root, "R"), pattern = "\\.R$", full.names = TRUE)) {
  source(f, local = FALSE)
}

fixture <- function(name) test_path("fixtures", name)

# A registry row for a fixture file (the fixture holds one PDF page).
fixture_source <- function(year, file, format, pages = NA, boundary_year = year,
                           sheet = NA, skip_rows = 9L) {
  tibble::tibble(
    year = as.integer(year), table_id = "fixture", format = format, url = NA,
    landing_page = NA, encoding = NA, skip_rows = as.integer(skip_rows),
    sheet = sheet, sha256 = NA, etag = NA, retrieved_at = NA,
    parser = if (format == "pdf") "extract_pdf" else "extract_xls",
    notes = NA, file_name = file, pages = pages, boundary_year = as.integer(boundary_year)
  )
}

pdf_fixture <- function(year, file) {
  extract_pdf(fixture(file), fixture_source(year, file, "pdf", pages = "1-1"))
}

xls_fixture <- function(year) {
  file <- paste0(year, "_head.xlsx")
  sheet <- readxl::excel_sheets(fixture(file))[1]
  extract_xls(fixture(file), fixture_source(year, file, "xlsx", sheet = sheet))
}

registry_path <- function(name) file.path(root, "registry", name)

# The BBSR crosswalk the registry points at (the file name changes with each
# edition, ci/update_crosswalk.R)
registered_bbsr_path <- function() {
  ref <- readr::read_csv(registry_path("reference_sources.csv"), col_types = readr::cols(.default = "c"))
  file.path(root, "data-raw", "bbsr", ref$file_name[ref$label == "bbsr_ref_kreise"])
}

# A small crosswalk: 2019 to 2020 merges 01002 into 01001 and splits 03001
# into 03001 (70 percent) and 03002 (30 percent); 2020 to 2021 changes nothing.
toy_map <- function() {
  row <- function(id, period, from, to, wp, wa = wp) {
    tibble::tibble(id = id, period = as.integer(period), from_ags = from, from_name = from,
                   to_ags = to, to_name = paste("Name", to), weight_population = wp,
                   weight_area = wa, source = "bbsr", replaces = NA_character_,
                   status = "official", reason = NA_character_)
  }
  dplyr::bind_rows(
    row("a", 2019, "01001", "01001", 1), row("b", 2019, "01002", "01001", 1),
    row("c", 2019, "03001", "03001", 0.7, 0.6), row("d", 2019, "03001", "03002", 0.3, 0.4),
    row("e", 2019, "11000", "11000", 1), row("e2", 2019, "02000", "02000", 1),
    row("f", 2020, "01001", "01001", 1), row("g", 2020, "03001", "03001", 1),
    row("h", 2020, "03002", "03002", 1), row("i", 2020, "11000", "11000", 1),
    row("i2", 2020, "02000", "02000", 1)
  )
}

toy_year <- function(cases = c(100L, 50L, 200L, 300L, 250L), zero_key = FALSE) {
  codes <- c("01001", "01002", "03001", "11000", "02000")
  pop <- c(90000, 30000, 200000, 3600000, 1800000)
  d <- data.frame(
    year = 2019L, ags = codes, region_name = codes, offence_key = "------",
    offence_label = "Straftaten insgesamt", cases = cases, attempts = 1L, cleared = 10L,
    suspects = 5L, hz = cases / pop * 1e5, clearance_rate = 10 / cases * 100,
    derived_population = pop, source_format = "xlsx", source_file = "toy.xlsx",
    boundary_year = 2019L, harmonized = FALSE, weight_type = "none", estimated = FALSE
  )
  if (zero_key) {
    z <- d
    z$offence_key <- "219000"
    z$cases <- c(0L, 3L, 1L, 2L, 4L)
    z$hz <- z$cases / pop * 1e5
    z$derived_population <- ifelse(z$cases > 0, pop, NA)
    d <- rbind(d, z)
  }
  as_canonical(d)
}
