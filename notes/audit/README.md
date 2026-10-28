# Phase 0 audit scripts

Evidence for `notes/bug_register.md` and `notes/phase0_audit.md`. These are audit tools, not pipeline code, and are not meant to be ported.

| Script | Purpose | Usage |
|---|---|---|
| `verify_pdf.R` | Independent position-based re-extraction of the PDF Kreis tables 2003 to 2012, compared cell by cell with the legacy `01-converted` CSVs | `Rscript verify_pdf.R <pdf_dir> <legacy_01-converted_dir> <out.csv>` |
| `verify_xls.R` | Cell-by-cell comparison of the raw Excel workbooks 2013 to 2024 with the legacy `01-converted` CSVs | `Rscript verify_xls.R <legacy_01_datasets_dir>` |
| `diff_inkar.R` | Cell-by-cell diff of two BBSR workbooks after whitespace and numeric normalization | `Rscript diff_inkar.R <original.xlsx> <fixed.xlsx>` |
| `pdf_verify_result.csv` | Output of `verify_pdf.R` on 2026-10-27 | |

Run them from a directory outside the legacy repository (its `.Rprofile` bootstraps `renv`) and in a UTF-8 locale.
