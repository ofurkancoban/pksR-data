# Builds the small test fixtures from the raw BKA files in data-raw/.
# Run from the repository root: Rscript tests/testthat/fixtures/make_fixtures.R
# The raw files are not committed; the fixtures are (a few KB each).

out <- "tests/testthat/fixtures"

# One table page per PDF layout variant
pdf_pages <- list(
  # intro text above the table, Hilfs-Nr column, thousands separated by spaces
  "2003_p253.pdf" = list(file = "2003_pks2003.pdf", page = 253),
  # numbers and keys split into fragments, footnote marker "*)"
  "2007_p254.pdf" = list(file = "2007_pks2007.pdf", page = 254),
  # second group 222000, a missing value "-" (09185, *50*00, AQ)
  "2010_p264.pdf" = list(file = "2010_pks2010.pdf", page = 264),
  # "." thousands separator, footer rule on the last row, KfS/K prefixes
  "2012_p315.pdf" = list(file = "2012_pks2012Jahrbuch.pdf", page = 315),
  # a yearbook page without the Kreis table
  "2003_p001.pdf" = list(file = "2003_pks2003.pdf", page = 1)
)
for (name in names(pdf_pages)) {
  p <- pdf_pages[[name]]
  qpdf::pdf_subset(file.path("data-raw", p$file), pages = p$page, output = file.path(out, name))
}

# Header rows 1 to 9 plus the first 25 data rows, one file per Excel layout.
# Cells are written as text, which is how extract_xls() reads them anyway.
xls_years <- c(
  "2013" = "2013_tb01_FaelleKriminalitaetsbetrachtungAufKreisebene_excel.xls",
  "2014" = "2014_tb01_FaelleGrundtabelleKreise_excel.xlsx",
  "2015" = "2015_tb01_FaelleGrundtabelleKreise_excel.xlsx",
  "2020" = "2020_KR-F-01-T01-Kreise-Faelle-HZ_xls.xlsx",
  "2025" = "2025_KR-F-01-T01-Kreise-Faelle-HZ_xls.xlsx"
)
for (year in names(xls_years)) {
  path <- file.path("data-raw", xls_years[[year]])
  sheet <- readxl::excel_sheets(path)[1]
  raw <- suppressMessages(readxl::read_excel(path, sheet = sheet, col_names = FALSE, col_types = "text"))
  small <- raw[1:34, ]
  names(small) <- paste0("c", seq_along(small))
  sheets <- stats::setNames(list(small), sheet)
  writexl::write_xlsx(sheets, file.path(out, paste0(year, "_head.xlsx")), col_names = FALSE)
}
