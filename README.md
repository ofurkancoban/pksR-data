# pksR-data

Data pipeline behind the `pksR` R package for German Police Crime Statistics (Polizeiliche Kriminalstatistik, PKS) at district (Kreis) level.

The pipeline downloads the district tables published by the Bundeskriminalamt (BKA), extracts them from their original formats (PDF for 2003 to 2012, XLS/XLSX from 2013), harmonizes them to one territorial boundary and one offence classification, and validates every output before anything is published. Users do not run this pipeline: they read the published data releases with the `pksR` package (in development).

## Status

| Phase | Content | State |
|---|---|---|
| 0 | Audit of the legacy scripts, bug register | done |
| 1 | Registry, canonical schema, extractors for 2003 to 2025 | done |
| 2 | Territorial and offence harmonization, validation gate | done |
| 3 | Release mechanics (manifest, Parquet and CSV.gz, GitHub releases, CI) | in review |

Offence key mappings, manual territorial rows and known methodological breaks are research decisions and remain `status = "draft"` until reviewed.

## How it works

```
registry/sources.csv          one verified URL and SHA-256 per year
        |
        v
extract_pdf() / extract_xls()  one canonical long table per year (as published)
        |
        v
harmonize_space()             BBSR crosswalk + manual rows + Destatis transfers,
        |                     counts moved with population or area weights
        v
harmonize_offences()          registry/offence_map.csv
        |
        v
validation_gate()             stops the pipeline when any check fails
        |
        v
output/harmonized/<weights>/  Parquet panel and one CSV.gz per year
```

The pipeline is defined with [`targets`](https://docs.ropensci.org/targets/), so a year is rebuilt only when its raw file, its registry row or the code it depends on changes.

### Harmonization

1. Target boundary: the latest boundary covered by the crosswalk (currently 31.12.2025, 400 districts); configurable in `_targets.R`.
2. Forward only. Mergers are exact; splits use population (default) or area weights and are flagged `estimated = TRUE`.
3. Counts are harmonized, never rates. HZ and clearance rates are recomputed after harmonization.
4. Crosswalk: BBSR Umsteigeschlüssel (`ref-kreise`), reproduced cell by cell in `registry/boundary_map.csv`. Deviations are explicit rows: `manual` rows replace a BBSR row and state their evidence; `destatis` rows add territorial transfers that BBSR omits, derived from the Destatis lists of municipal territorial changes and recomputed from those files on every run.

### Validation gate

Every harmonized panel must pass: schema, uniqueness (`year`, `ags`, `offence_key`), coverage (expected district count, Berlin and Hamburg every year), aggregation against the national (Bund) tables 2013 to 2025, conservation of national totals through harmonization, plausibility (no negative counts, attempts not above cases, plausible derived population), and year completeness. A failed check writes `output/validation/report_<weights>.json` and nothing is written to `output/harmonized/`.

### Data notes

1. PDF years (2003 to 2012) publish population, HZ and clearance rates only. Case counts for those years are back-calculated (`cases_derived`, `cleared_derived`) and flagged `estimated = TRUE`.
2. The Kreis tables 2013 to 2025 publish no population except 2020; `derived_population` is computed as `cases / hz * 1e5` and flagged as derived.
3. `clearance_rate` is 0 where cases are 0. This follows the BKA tables and is not a real rate; the note is stored in the Parquet metadata (`pksR_notes`) and printed by `pksR` on load.
4. Known methodological breaks (offence key changes, census-based population revisions, the 2024 cannabis law) are listed in `registry/known_breaks.csv`.

## Releases and automation

Data releases are GitHub releases of this repository, tagged `v<year>.<n>` (for example `v2026.1`). Published releases are never changed; a correction is a new version. Each release holds:

| Asset | Content |
|---|---|
| `pks_kreis_published.parquet` | All years as published (canonical schema) |
| `pks_kreis_<year>_published.csv.gz` | The same, one file per year |
| `pks_kreis_panel_<weights>.parquet` | Harmonized panel, `population` or `area` weights |
| `pks_kreis_<year>_<weights>.csv.gz` | The same, one file per year |
| `validation_<weights>.json` | Validation gate report |
| `sources.csv`, `bund_sources.csv`, `reference_sources.csv`, `destatis_sources.csv`, `boundary_map.csv`, `offence_map.csv`, `known_breaks.csv` | Registries used for the release |
| `ATTRIBUTION.txt` | Source notes and licences of all sources |
| `manifest.json` | SHA-256, size and rows of every asset, pipeline commit, data notes |

`.github/workflows/pipeline.yml` runs monthly, weekly from March to May, and on demand. It downloads every registered raw file from its source (bka.de through a Cloudflare Worker, because bka.de drops many connections from GitHub runners) and checks its hash, falls back to a private mirror (a draft release) when a source is unreachable, checks the landing pages for republished files, looks for new reporting years on bka.de, builds and validates the panel, runs the tests, and releases when the data changed. Changed source files, failed checks and new years open an issue instead of a release. A newer BBSR crosswalk edition (a new `ref-kreise-1990-<year>.xlsx` on the BBSR page) starts a second job: it points `registry/reference_sources.csv` at the new file, regenerates `registry/boundary_map.csv`, runs a trial build and the tests, pushes the result to a branch `auto/bbsr-<file>` and opens a pull request and an issue with the summary. The new mapping reaches `main` only when the maintainer merges it. Public releases are enabled with the repository variable `PUBLISH_ENABLED`; manual runs with `release = test` create a draft prerelease to check the mechanics.

## Layout

| Path | Content |
|---|---|
| `_targets.R` | Pipeline definition |
| `R/` | Pipeline functions: download, extraction, schema, harmonization, validation |
| `registry/sources.csv` | One row per year: verified URL, SHA-256, page range or sheet, published boundary |
| `registry/boundary_map.csv` | Territorial crosswalk 2003 to 2025 in long form (BBSR, manual and Destatis rows) |
| `registry/destatis_sources.csv` | Destatis lists of municipal territorial changes 2003 to 2025 |
| `registry/offence_map.csv` | Offence key harmonization (draft) |
| `registry/known_breaks.csv` | Methodological breaks with comparability assessment (draft) |
| `registry/bund_sources.csv` | National case tables 2013 to 2025, used only by the validation gate |
| `registry/reference_sources.csv` | BBSR crosswalk file |
| `ci/` | Scripts run by the workflows: fetch, discovery, crosswalk update, release, status, issue text |
| `.github/workflows/` | `pipeline.yml`, `keepalive.yml`, `tests.yml` |
| `tests/testthat/` | Regression tests, offline, on small fixtures |
| `notes/` | Audit, bug register, design decisions, legacy comparison |

## Running

Tested with R 4.6.0. Requires `targets`, `readxl`, `pdftools`, `arrow`, `readr`, `dplyr`, `tibble`, `cli`, `httr2`, `digest`, `jsonlite`, `testthat` and `withr`. Run from the repository root in a UTF-8 locale.

```r
# Raw files are not committed. `Rscript ci/fetch.R` fetches them (source
# first, mirror as fallback) and checks them against the recorded SHA-256;
# `Rscript ci/mirror.R` uploads local files to the mirror:
#   data-raw/                      PKS Kreis tables (registry/sources.csv)
#   data-raw/bbsr/                 BBSR crosswalk (registry/reference_sources.csv)
#   data-raw/bund/                 Bund tables (registry/bund_sources.csv)
#   data-raw/destatis/             Destatis change lists (registry/destatis_sources.csv)
targets::tar_make()
testthat::test_dir("tests/testthat")
```

Output:

- `output/canonical/pks_kreis_<year>.parquet`: one file per year 2003 to 2025, as published.
- `output/harmonized/<weights>/pks_kreis_panel.parquet` and `pks_kreis_<year>.csv.gz`: harmonized panel for population and area weights.
- `output/validation/report_<weights>.json`: result of the validation gate.
- `output/release/`: the assets of the next release (uploaded by `ci/release.R`).

## Sources and attribution

- Bundeskriminalamt (BKA), Polizeiliche Kriminalstatistik, district tables (Kreise) and national tables (Bund), <https://www.bka.de>.
- [Bundesinstitut für Bau-, Stadt- und Raumforschung](https://www.bbsr.bund.de) (BBSR), Umsteigeschlüssel für Kreise (`ref-kreise`).
- Statistisches Bundesamt (Destatis), Gemeindeverzeichnis, yearly lists of changes to municipal names and boundaries (URLs in `registry/destatis_sources.csv`).

### Terms of reuse

The code in this repository is MIT licensed. The data keep the terms of their sources (checked on 2026-10-28, see `notes/decisions.md`):

| Source | Terms | Required source note |
|---|---|---|
| BKA, PKS tables | Datenlizenz Deutschland, Namensnennung, Version 2.0 ([dl-de/by-2-0](https://www.govdata.de/dl-de/by-2-0)), stated on the PKS pages of every reporting year from 2012 to 2025 | "PKS Bundeskriminalamt", reporting year, version |
| BKA, PKS yearbooks 2003 to 2011 (PDF) | Printed notice: reprint and copying only with the BKA named as source (the 2003 and 2004 editions also mention the BKA's permission); releases contain figures extracted from them, not the PDFs | "Bundeskriminalamt" |
| BBSR, Umsteigeschlüssel | Datenlizenz Deutschland, Namensnennung, Version 2.0, per the BBSR Nutzungshinweise | "BBSR Bonn [year]", with a note on changes |
| Destatis, Gemeindeverzeichnis | Copying and distribution with a source note | "Statistisches Bundesamt (Destatis)" |

The licence asks for a note when data are changed. The data in a release are changed: extracted from the published tables, harmonized to one boundary year and offence classification, with derived columns added. They are not official BKA figures. Each release names all three sources, their licences and the changes made, in `ATTRIBUTION.txt` and in `manifest.json` (`license`, `attribution`, `license_note`). The registries in the release (`sources.csv`, `bund_sources.csv`, `reference_sources.csv`, `destatis_sources.csv`) give the URL of every source file. Anyone who passes the data on should keep these notes.

Suggested citation for a release: *Source: PKS Bundeskriminalamt, reporting years 2003 to 2025; BBSR Bonn; Statistisches Bundesamt (Destatis), Gemeindeverzeichnis; Datenlizenz Deutschland, Namensnennung, Version 2.0; changed and processed with pksR-data, data version `<version>`.*

## Author

Ömer Furkan Çoban
