# Phase 0 audit

Date: 2026-10-27. Scope: Section 11, Phase 0 of `CLAUDE.md`. No pipeline code was written. Findings are in `notes/bug_register.md`; this file holds the context, the year table and the proposed mapping.

## 1. Method

1. Cloned `https://github.com/ofurkancoban/ImmigrationCrimeGermany_AppliedEconResearchProj` (HEAD `45525ea`, 2026-06-22, 10 commits) to `../legacy/ImmigrationCrimeGermany_AppliedEconResearchProj/`. Treated as read-only (see section 10 for one incident).
2. Read every in-scope script line by line (`setup_environment.R`, `00_` to `05_`, `04_tools/utils.R`) and `12_`, `13_`, `11_` in full. Scripts `06_` to `10_` and `14_` to `30_` were reviewed for data flow only (which PKS variables they consume, joins, filters, skips), not line by line.
3. Ran the legacy outputs, not the legacy pipeline: all checks read the committed CSVs and raw files.
4. Verified extraction independently:
   1. PDF years: a separate position-based parser (`notes/audit/verify_pdf.R`) re-extracted every district row of all 10 PDFs and compared every cell with the legacy output.
   2. Excel years: every raw workbook compared with the converted CSV cell by cell (`notes/audit/verify_xls.R`).
   3. Harmonization: national totals per year and key before and after `04_`.
   4. Crosswalk: cell-by-cell diff of the original and `_fixed` BBSR workbooks (`notes/audit/diff_inkar.R`) and a weight-sum scan of every sheet.

The brief asks for a sample of at least 5 districts x 3 offence keys per year. Instead every cell was compared, which gives the error rate directly.

## 2. Inputs found

| Item | Location | Notes |
|---|---|---|
| Legacy repository | `../legacy/ImmigrationCrimeGermany_AppliedEconResearchProj/` | Scripts, processed outputs, 12 raw Excel files, BBSR workbooks. Raw PDFs are not in the repository. |
| Local project `PKS` | `../PKS/` | Not the "later project" described in the brief. It contains `Code/pks.R` (PDF and Excel extraction of `------` only: Einwohner and HZ) and `Code/harmonize.R`, the 10 raw PDFs 2003 to 2012, the same 12 Excel files (byte-identical to the legacy copies), and a `_fixed` BBSR workbook with identical cell content to the legacy `_fixed` file (different file hash, same values). Included in the audit as a third reference. |
| Later project (`02_PKS_extract_and_translate.R`, `03-codebook/offense_codebook.csv`, 2013 to 2025) | not provided | Not found next to the repository. Audit continues with the public repository as instructed. |
| 2025 raw file | not available locally | See section 4. |

## 3. Script inventory: what each in-scope script does

| Script | Inputs | Outputs | Hard-coded paths and settings | Verdict |
|---|---|---|---|---|
| `01_setup/setup_environment.R` | CLI `--stage=` | runs all stages via `source()` in one global environment | `here::here()` paths; requires `quarto`, `curl`; installs TinyTeX at runtime | Replaced by `_targets.R`. Global-environment sourcing makes every stage depend on objects left by earlier stages. |
| `00_import.R` | none | loads 31 packages, installs missing ones (including from GitHub), defines `ensure_dir()`, `should_skip()`, creates folders | folder list L116 to L125 | `ensure_dir()` is the only reusable helper; `should_skip()` is replaced by `targets` (BUG-008). |
| `01_PKS_Dataset_Downloader.R` | bka.de | `raw/PKS/old_datasets/{year}_pks{year}.pdf` (2003 to 2012), `raw/PKS/{year}_{file}.xls(x)` (2013 to 2024) | URL templates L104 to L148, `v=` pinned, `force_download` | Its URLs seed `registry/sources.csv`, after verification (BUG-025). |
| `01b_Geodata_Downloader.R` | BKG | geometries | | Out of scope now (roadmap `pks_geometry()`). |
| `02_PKS_Old_Datasets_PDF2CSV.R` | the PDFs | `processed/PKS/01-converted/{year}_pks{year}.csv` | page filter `"kreis-"`, gap 3, y-tolerance 5, 15 numeric columns, 2008 name patch | Extraction values are correct; key labelling for 2010 to 2012 is wrong (BUG-011); counts are derived (BUG-015). Port to `extract_pdf.R` with header-driven columns. |
| `03_PKS_New_Datasets_EXCEL2CSV.R` | the Excel files | `processed/PKS/01-converted/{year}_{file}.csv` | 18 positional names, first sheet, skip detection on `------` | Values are cell-exact; the layout handling is fragile (BUG-023). Port to `extract_xls.R`. |
| `04_PKS_Spatial_Harmonization.R` | `01-converted/*.csv`, BBSR `_fixed` workbook | `02-harmonized/{year}_PKS_harmonized.csv` | target 2023, `effective_start_year` special cases, 0.95 threshold, creates `_fixed` file if missing | Chain-of-sheets approach and conservation are sound; population handling (BUG-014), schema loss (BUG-007) and silent-drop patterns (BUG-016 to BUG-019) need fixing. Port to `harmonize_space.R`. |
| `05_PKS_Translation.R` | `02-harmonized` | `03-translated` | label dictionary | Replace by key-based `registry/offence_map.csv` (BUG-024). |
| `04_tools/utils.R` | | | | `prepare_panel_data()` and table styling are analysis code (out of scope). Nothing generic beyond `ensure_dir()`. |

Out-of-scope scripts, data-flow review only:

| Script | PKS input used | Finding |
|---|---|---|
| `06_` to `10_` | none | INKAR and capital stock; no PKS dependence. `10_` handles Berlin and Hamburg explicitly. |
| `11_Capital_Stock_Harmonization.R` | none | Reuses the `04_` crosswalk logic (same 0.95 threshold, same fallback). Adds `fill_missing_with_predecessors()`, which back-fills new districts from predecessor values; potentially reusable idea for split handling, but it sums per-capita values (BUG-030). |
| `12_Data_Merge.R` | keys `------`, `890000`, `220000`, `222000`, `224000`, `674000`, `730000`, `899000` | BUG-012, BUG-013, BUG-004. |
| `13_Feature_Engineering.R` | `*_reported` | Recomputes all crime rates with INKAR census-corrected population (so BKA HZ is not used downstream). |
| `14_` to `21b_`, `15_` main model | property damage only (`log_property_damage_l1`), key `674000` | `674000` is present in every year under the same key. Main results are not affected by BUG-011 to BUG-013. PDF-era counts are derived (BUG-015), small rounding noise only. |
| `17_` | street crime `899000` | consistent key across years. |
| `22_`, `26_`, `27_`, `28_` | total crime | affected by BUG-012. |
| `24_` | drugs `730000` | consistent key across years. |
| `25_`, `26_`, `28_`, paper appendix model "(4) Bodily" | bodily harm | affected by BUG-011 and BUG-013. |
| `29_`, `30_` | property damage 2021 | reference for a future `pks_map()`. |

## 4. Years 2003 to 2025

| Year | Format | Source file (local name) | SHA-256 (first 16) | Kreis-table pages / sheet | Districts published | Boundary of publication | Offence keys | Legacy extraction status |
|---|---|---|---|---|---|---|---|---|
| 2003 | pdf | `2003_pks2003.pdf` | `e5015b0ba1234bfd` | p. 253 to 259 | 439 | 31.12.2003 | 7 groups | extracted, cell-exact; counts derived |
| 2004 | pdf | `2004_pks2004.pdf` | `3a30aa1f06aed514` | p. 253 to 259 | 439 | 31.12.2004 | 7 | same |
| 2005 | pdf | `2005_pks2005.pdf` | `745bdccb8da5eed6` | p. 253 to 259 | 439 | 31.12.2005 | 7 | same |
| 2006 | pdf | `2006_pks2006.pdf` | `a922c6872541ea55` | p. 249 to 255 | 439 | 31.12.2006 | 7 | same |
| 2007 | pdf | `2007_pks2007.pdf` | `018ef0b9ab3c558e` | p. 249 to 255 | 429 | 31.12.2007 (Sachsen-Anhalt reform 1.7.2007 applied) | 7 | same |
| 2008 | pdf | `2008_pks2008.pdf` | `278659038365a325` | p. 249 to 255 | 429 | 31.12.2007 (Sachsen reform 1.8.2008 not applied) | 7 | same |
| 2009 | pdf | `2009_pks2009.pdf` | `a86da82c51988059` | p. 249 to 254 | 413 | 31.12.2008 (Aachen 21.10.2009 not applied) | 7 | same |
| 2010 | pdf | `2010_pks2010.pdf` | `9942d8c595f9bf12` | p. 261 to 266 | 412 | 31.12.2010 | 7, bodily harm = `222000` | extracted, cell-exact; key mislabelled (BUG-011) |
| 2011 | pdf | `2011_pks2011.pdf` | `484452abbaf051f0` | p. 267 to 272 | 412 | 31.12.2010 (Mecklenburg-Vorpommern 4.9.2011 not applied) | 7, `222000` | same as 2010 |
| 2012 | pdf | `2012_pks2012Jahrbuch.pdf` | `07123fe321b55e13` | p. 315 to 320 | 402 | 31.12.2012 | 7, `222000` | same as 2010 |
| 2013 | xls | `2013_tb01_FaelleKriminalitaetsbetrachtungAufKreisebene_excel.xls` | `124ba73361725fee` | `Fälle_Kreisdaten_div-SZ` | 402 | 31.12.2013 | 18 | cell-exact |
| 2014 | xlsx | `2014_tb01_FaelleGrundtabelleKreise_excel.xlsx` | `daba0465af6a6b11` | `Fälle_Kreisdaten_div-SZ` | 402 | 31.12.2014 | 40 | cell-exact |
| 2015 | xlsx | `2015_tb01_FaelleGrundtabelleKreise_excel.xlsx` | `4cad1173ceb0a9d0` | `T01_Kreise` | 402 | 31.12.2015 | 41 | cell-exact |
| 2016 | xlsx | `2016_BKA-LKS-F-03-T01-Kreise_excel.xlsx` | `053c62beedf9cb93` | `T01_Kreise` | 402 | 31.12.2015 (Göttingen 1.11.2016 not applied) | 41 | cell-exact |
| 2017 | xlsx | `2017_BKA-LKS-F-03-T01-Kreise_excel.xlsx` | `2ff6d1a5fd5965d4` | `T01_Kreise` | 401 | 31.12.2017 | 41 | cell-exact |
| 2018 | xlsx | `2018_BKA-LKS-F-03-T01-Kreise_excel.xlsx` | `1bfc2897baef627b` | `T01_Kreise` | 401 | 31.12.2018 | 42 | cell-exact |
| 2019 | xlsx | `2019_KR-F-01-T01-Kreise-Faelle-HZ_xls.xlsx` | `a29b5b05c15457d9` | `T01_Kreise` | 401 | 31.12.2019 | 42 | cell-exact |
| 2020 | xlsx | `2020_KR-F-01-T01-Kreise-Faelle-HZ_xls.xlsx` | `e8b6a7c4e0ca78c2` | `T01_Kreise` | 401 | 31.12.2020 | 42 | cell-exact |
| 2021 | xlsx | `2021_KR-F-01-T01-Kreise-Faelle-HZ_xls.xlsx` | `a412faa5108d579a` | `T01_Kreise` | 401 | 31.12.2020 (Eisenach 1.7.2021 not applied) | 41 | cell-exact |
| 2022 | xlsx | `2022_KR-F-01-T01-Kreise-Faelle-HZ_xls.xlsx` | `113a4385703a6ef4` | `T01_Kreise` | 400 | 31.12.2022 | 41 | cell-exact |
| 2023 | xlsx | `2023_KR-F-01-T01-Kreise-Faelle-HZ_xls.xlsx` | `53a5bf6270dc6b8c` | `T01_Kreise` | 400 | 31.12.2023 | 42 | cell-exact (no harmonization needed) |
| 2024 | xlsx | `2024_KR-F-01-T01-Kreise-Faelle-HZ_xls.xlsx` | `4bf37306f29f06d0` | `T01_Kreise` | 400 | 31.12.2024 (= 2023 territory, BBSR 2023-2024) | 41 | cell-exact; not harmonized |
| 2025 | xlsx | `2025_KR-F-01-T01-Kreise-Faelle-HZ_xls.xlsx` (downloaded 2026-10-27 to the audit scratch folder, not into the repo) | `fca60de9477566bb` | `T01_Kreise` | 400 | 31.12.2025 (= 2023 territory, BBSR 2024-2025) | 41 | not extracted by legacy code; layout identical to 2021 to 2024 (18 columns, version "V1.1"); column-number row 9 is misnumbered (`8, 9, 16, 17, 12`) |

"Boundary of publication" is inferred from matching the published district count and district set to the BBSR sheet that the legacy rule selects; it agrees in every year. It is a draft for `registry/sources.csv` (`boundary_year`) and needs your confirmation.

Offence key universe in the Excel era: 46 distinct keys 2013 to 2024. Keys appearing or disappearing: `220000` only 2013; `890000` from 2015; `621020`/`621021` until 2017, `621100`/`621110`/`621120` from 2018; `980100` 2014 to 2020; `972500` 2014 to 2023; `*26*00` from 2023; 2013 has only 18 keys. The full presence matrix goes into `notes/offence_key_changes.md` in Phase 2.

## 5. Schema per year (raw source)

| Years | Columns | Layout |
|---|---|---|
| 2003 to 2006 PDF | Hilfs-Nr, Kreisschlüssel, Kreis (with `SK`/`LK` prefix), Einwohner am 01.01., then HZ and AQ for `----`, `2200`, `435*`, `*50*`, `6740`, `7300`, `8990` | HZ integer, AQ one decimal, thousands separated by a space; `-` for missing |
| 2007 to 2009 PDF | as above without Hilfs-Nr; keys written with six digits from 2008 | text fragments split inside numbers and keys (for example `0345` + `2`) |
| 2010 to 2012 PDF | as above, second group `222000` | 2012 uses `.` as thousands separator and `KfS`/`K`/`RV` prefixes |
| 2013 xls | 18 columns; col 4 = type, col 5 = name; "HZ nach Zensus 2011" | data from row 10, column numbers in row 9 (`1 2 . . . 3 4 5 6 12 ... 20`) |
| 2014 xlsx | 18 columns; col 4 = name, col 5 = type | same rows |
| 2015 xlsx | 19 columns (extra `Sort`) | columns numbered 1 to 18 |
| 2016 to 2019 xlsx | 18 columns | |
| 2020 xlsx | 23 columns: 18 + `Sort`, empty, `GemSchl.`, `Gem`, `EW 31.12.2019` (official population) | |
| 2021 to 2023 xlsx | 18 columns | |
| 2024 xlsx | 18 columns, "HZ nach Zensus 2022" | |

All Excel years contain the same 18 data fields (offence key, label, AGS, name, type, cases, HZ, attempts n and percent, firearm threatened and fired, cleared n and AQ, suspects total, male, female, non-German n and percent). The PDF years contain population, HZ and AQ only.

Legacy output schemas: see BUG-007 (four different schemas).

## 6. Verification results

### 6.1 PDF extraction (2003 to 2012)

Independent re-extraction found 4,253 district rows (439 x 4, 429 x 2, 413, 412 x 2, 402), identical to the legacy row set. Compared cells: population, HZ and AQ for 7 groups = 15 values per row, 63,795 cells. Confirmed legacy errors: 0. One disagreement (2010, `09185`) was an artifact of the audit parser; the legacy value matches the PDF text. Observed error rate: 0 of 63,795.

Caveat: the comparison checks extraction of published values. The case counts in the legacy output are not published values (BUG-015).

### 6.2 Excel extraction (2013 to 2024)

All rows present in both directions, 0 mismatches in 2,460,744 numeric cells (13 numeric fields per row), 0 name, type or label mismatches.

### 6.3 Harmonization

National totals of `Erfasste_Faelle`, `Einwohner` and `Aufklaerung_Faelle` per offence key are conserved in every year (largest relative difference 3.6e-16). Every harmonized year has 400 districts, including Berlin and Hamburg. Problems are population and rates (BUG-014), schema (BUG-007), and latent silent-drop patterns.

### 6.4 BBSR crosswalk: original vs `_fixed`

Cell-by-cell diff after whitespace and numeric normalization: exactly 6 changed cells, all in row 151 (`7137000` Mayen-Koblenz to `7137000`):

| Sheet | Column | Original | Fixed |
|---|---|---|---|
| 2014-2015 | area-proportional key | 0.03833706055 | 1 |
| 2014-2015 | population-proportional key | 0.01715135597 | 1 |
| 2014-2015 | employment-proportional key | 0.003877737226 | 1 |
| 2015-2016 | area-proportional key | 0.03833706055 | 1 |
| 2015-2016 | population-proportional key | 0.01715135597 | 1 |
| 2015-2016 | employment-proportional key | 0.003877737226 | 1 |

Each becomes a `registry/boundary_map.csv` row with `source = "manual"` in Phase 2 (draft). Context needed for the reason field: in the same two sheets `7135000` Cochem-Zell maps only to itself with weight 0.98284864, i.e. 1 minus the Mayen-Koblenz value. That pattern suggests BBSR intended a transfer of about 1.7 percent of Cochem-Zell's population to Mayen-Koblenz and wrote the share on the wrong row. The legacy fix keeps Mayen-Koblenz whole and renormalizes Cochem-Zell to 1, so the transfer is ignored. This is a research decision (question Q5).

Correction (2026-10-28): the interpretation above is wrong; see the correction under Q5 in section 9.

Other weight sums different from 1 in the original file: sheet 2011-2012 `7231000` (0.9907) and `7235000` (1.0093). All other source districts in 2002-2003 to 2022-2023 sum to 1. The script that would recreate `_fixed` from the original (`04_` L57 to L81) produces exactly these 6 edits.

### 6.5 Newest BBSR crosswalk (`ref-kreise-1990-2024.xlsx`)

Downloaded 2026-10-27 from `https://www.bbsr.bund.de/BBSR/DE/forschung/raumbeobachtung/Raumabgrenzungen/umstiegsschluessel/ref-kreise-1990-2024.xlsx?__blob=publicationFile&v=3` (landing page: `https://www.bbsr.bund.de/BBSR/DE/forschung/raumbeobachtung/Raumabgrenzungen/umstiegsschluessel/umsteigeschluessel.html`, labelled "Jahrestabelle 1990 bis 2025"; the file name says 2024). HTTP 200, 994,135 bytes, SHA-256 `b7250207cae01268667426ba416312577ba207f0acd8df8048d80db8206a01af`. Stored in the audit scratch folder, not in the repo.

1. 35 sheets: the 33 sheets of the 2023 file plus `2023-2024` and `2024-2025` (target 31.12.2025).
2. The 33 shared sheets are cell-identical to the original `INKAR_ref-kreise-1990-2023.xlsx` (0 differences after normalization). BBSR has therefore not corrected the Mayen-Koblenz weight (0.01715) in 2014-2015 and 2015-2016, nor the 2011-2012 weight sums. The manual fix stays necessary.
3. `2022-2023`, `2023-2024` and `2024-2025`: 400 to 400 districts, every weight 1, no code changes. The only change is a renaming in 2025: `03403` "Oldenburg (Oldenburg), Stadt" becomes "Oldenburg (Oldb), Stadt".
4. From sheet `2022-2023` on, the employment-proportional weight column is absent (only area and population weights). This doesn't matter for `pksR`, which uses population (default) or area weights.
5. The district sets of PKS 2024 and PKS 2025 match the 31.12.2025 crosswalk codes exactly (400 = 400, no code on either side alone).

Consequence: the default target boundary (brief 6.1.1, "the most recent boundary year covered by the crosswalk") becomes 2025. For PKS data it is territorially identical to 2023 and 2024, so legacy results harmonized to 2023 remain comparable. 2024 and 2025 PKS data need no harmonization (question Q6 answered by the data).

## 7. Status of the 10 known issues

| Known issue | Register id | Status in the public repository |
|---|---|---|
| 1 AGS format | BUG-001 | Handled per script, currently correct, fragile. |
| 2 Derived population | BUG-002, BUG-014 | Present. Derivation is exact for Excel years; zero-case rows break merges. |
| 3 Berlin and Hamburg dropped | BUG-003 | Not found in code or history; both present everywhere. |
| 4 `inner_join` dropping years | BUG-004 | Pattern present in `12_`; no loss with current inputs. |
| 5 BBSR missing mappings | BUG-005 | Not confirmed: the mappings are in the BBSR file. |
| 6 400 districts | BUG-006 | Holds in outputs; no check exists. |
| 7 Schema mismatch | BUG-007 | Present (four schemas). |
| 8 `should_skip()` | BUG-008 | Present in every stage. |
| 9 Shared output folder | BUG-009 | Present; no collision in this repository. |
| 10 Implausible medians | BUG-010 | Not reproduced; medians 148k to 155k. |

## 8. Conflicts between the brief and what I found

Per Section 12.2 I am stopping on these rather than guessing:

1. Layout note 1 ("2013 ... no clearance rate column, shifted suspect columns") is not true for the 2013 file in the repository: it has `Aufklärung Fälle` and `AQ` and the same 18 fields as later years. What differs in 2013 is that columns 4 and 5 are swapped (type, then name).
2. Layout note 5 ("column 4 district name, column 5 district type") holds for 2014 to 2024, not 2013.
3. Layout note 3 says "18 to 23 columns" for 2015 to 2024; only 2015 (19) and 2020 (23) deviate from 18.
4. Known issue 5: the three mappings are present in `INKAR_ref-kreise-1990-2023.xlsx` (sheets 2015-2016 and 2020-2021).
5. Known issue 2 says PKS Kreis tables do not contain population. True for 2013 to 2019 and 2021 to 2024; the 2020 file contains official population (`EW 31.12.2019`), and the PDF years publish population but no case counts.
6. Section 5.2 defines `cases` as "recorded cases". For 2003 to 2012 no case counts are published (BUG-015).

## 9. Proposed mapping onto the new structure

| Legacy | New | Change |
|---|---|---|
| `setup_environment.R`, `Makefile` | `pksR-data/_targets.R` | one target per (year, source file), extraction, harmonization, validation, publication |
| `00_import.R` | `pksR-data/R/utils.R` | keep only `ensure_dir()`-like helpers; no auto-install, no global `library()` |
| `01_` | `R/discover.R`, `R/download.R`, `registry/sources.csv` | URLs only from the registry; SHA-256 and ETag; descriptive User-Agent |
| `02_` | `R/extract_pdf.R` | header-driven keys and columns; page ranges from registry; `cases = NA`, published population kept; derived counts only in an explicitly flagged form |
| `03_` | `R/extract_xls.R` | layout detected from the column-number row; one fixture per layout; 2020 `EW` column captured as official population |
| (new) | `R/schema.R` | `as_canonical()`, `normalize_ags()`, type assertions |
| `04_` | `R/harmonize_space.R`, `registry/boundary_map.csv` | counts only; population handled once per district; `boundary_year` per source year from the registry; unmatched codes warned; weights asserted |
| `05_` | `R/harmonize_offence.R`, `registry/offence_map.csv` | key-based, `status = "draft"` until you review |
| (new) | `R/validate.R`, `registry/known_breaks.csv` | Section 7 gate; breaks for `220000`/`222000`, `890000`, census rebasing |
| `11_` | none | idea of predecessor back-filling noted for split handling, no code reused |
| `12_`, `13_` | none in `pksR-data` | merge logic belongs to your analysis; `pksR::pks_rates()` replaces the rate recomputation |

The targets proposed in the brief's inventory table are confirmed for every in-scope script, with one addition: `schema.R` absorbs the AGS normalization from `02_`, `04_` and `12_`.

Design questions for you (also listed in the summary):

- Q1. PDF years: should `cases` stay `NA` with a separate derived column (my recommendation), or should derived counts be stored in `cases` with `estimated = TRUE`?
- Q2. Where did BUG-003 and BUG-010 occur (later project?), so I can write regression tests against the real failure?
- Q3. Known issue 5: were the missing mappings observed in a different BBSR file version or the `ags` package? Should they still become explicit rows (with `source = "bbsr"`)?
- Q4. Total crime: keep `------` and `890000` as separate series (my recommendation), and which one should the thesis use?
- Q5. Mayen-Koblenz/Cochem-Zell 2014-2016: keep the legacy fix (ignore the 1.7 percent transfer), or model the transfer from Cochem-Zell to Mayen-Koblenz? This needs Gemeinde-level confirmation.
  - Correction (2026-10-28): the hypothesis was wrong. There is no transfer between Cochem-Zell and Mayen-Koblenz. The 1.7 percent is the transfer of Lahr, Moersdorf and Zilshausen from Cochem-Zell to 07140 Rhein-Hunsrueck-Kreis on 01.07.2014 (Destatis 07/2014/0003-R), modelled correctly in BBSR sheet 2013-2014 and copied by mistake into the next two sheets. The legacy fix is correct (`notes/decisions.md`, 2026-10-27 and 2026-10-28).
- Q6. Resolved by the newest BBSR file (section 6.5): no territorial change 2023 to 2025; proposed default target boundary 2025.

## 10. Unverified items and incidents

1. BKA URLs: HEAD requests to all 23 legacy URL patterns (2003 to 2025) returned HTTP 400 from bka.de, which probably means the server rejects HEAD. A GET with a browser-like User-Agent was blocked by my tool permissions, and I did not work around that. The 2025 file was then found by following the BKA pages: PKS 2025 node, then `pksTabellen_Interpretationshilfen`, then "Kreise - Falltabellen". It was downloaded with a plain GET and an honest User-Agent (HTTP 200, 2,124,347 bytes, SHA-256 `fca60de9477566bb2ab3b800a2d812a14b0f44f27467325bccbf29ad7c852974`) from `https://www.bka.de/SharedDocs/Downloads/DE/Publikationen/PolizeilicheKriminalstatistik/2025/Kreis/Faelle/KR-F-01-T01-Kreise-Faelle-HZ_xls.xlsx?__blob=publicationFile&v=2`. The legacy template would have requested `v=4` for 2025, which confirms BUG-025. Landing page: `https://www.bka.de/DE/AktuelleInformationen/StatistikenLagebilder/PolizeilicheKriminalstatistik/PKS2025/pksTabellen_Interpretationshilfen/KreisFalltabellen/kreisfalltabellen.html`. URLs for 2003 to 2024 were then verified the same way (one plain GET each, 2 s apart, honest User-Agent): all 22 legacy URLs from `01_` L104 to L171 return HTTP 200 with the expected content type. For 21 files the SHA-256 equals the local copy. The 2013 `.xls` differs in bytes (1,675,264 vs 1,674,240) but all 7,245 x 18 cells are identical, so it is the same table re-serialized by the server; `registry/sources.csv` must therefore not rely on byte hashes alone for legacy `.xls` files (content hash as fallback). These URLs go into `registry/sources.csv` in Phase 1.
2. `available::available("pksR")` (run 2026-10-27; the `available` package was installed for this): name valid; available on CRAN, Bioconductor and GitHub. The unrelated CRAN package `pks` exists, as noted in the brief, so titles must say "German Police Crime Statistics".
3. Running `Rscript` from the legacy repository root triggered its `.Rprofile`, which bootstrapped `renv` and created the gitignored `renv/library/` folder. No tracked file changed (`git status` clean). I removed that folder again; the clone is back to its cloned state. All later R calls ran from outside the clone.
4. Boundary-of-publication per year (section 4) is inferred, not taken from BKA documentation.
5. National totals (validation check 7.4) could not be checked because Bund tables are not in the inputs. For PDF years the Kreis tables came from "a separate query to the 16 LKA" (2003 PDF text), so an exact match with the Bund total is not expected.
6. Environment: R 4.6.0, pdftools 3.8.0, readxl 1.4.5, pdftotext 26.08.0, macOS.
