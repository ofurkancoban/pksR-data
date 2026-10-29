# Bug register (Phase 0)

Legacy code: `ofurkancoban/ImmigrationCrimeGermany_AppliedEconResearchProj`, commit `45525ea` (2026-06-22), cloned read-only to `../legacy/`.
Local reference project: `../PKS/Code/` (`pks.R`, `harmonize.R`), see `phase0_audit.md` section 2.
Audit date: 2026-10-27. Statuses updated at the end of Phase 1 and Phase 2 (2026-10-27, 2026-10-28). Entries are ordered by severity, then id.

Severity scale (from the brief): `critical` = wrong numbers in the output, `major` = data loss or wrong years, `minor` = fragile but currently correct, `cosmetic`.

Fix and test columns name the location in `pksR-data` (Phase 1 and Phase 2).

Paths: `02_` to `05_` mean `02_scripts/02_data_preprocessing/<nn>_*.R`. Line numbers refer to commit `45525ea`.

Evidence scripts are kept in `notes/audit/` (audit only, not pipeline code).

---

## Summary

| id | severity | script | short description | status |
|---|---|---|---|---|
| BUG-011 | critical | `02_` L436 | PDF 2010 to 2012 bodily harm column is `222000`, labelled `220000` | fixed |
| BUG-012 | critical | `12_` L117 to L131 | "Total crime" switches from `------` to `890000` in 2015 | fixed |
| BUG-034 | critical | BBSR `ref-kreise` sheet 2011-2012, used by `04_` | Code typo in a BBSR transfer row; legacy renormalization hid it | fixed (manual row, verified by Destatis) |
| BUG-035 | critical | BBSR `ref-kreise` sheets 2022-2023, 2023-2024 and smaller cases | Territory transfers without weights in the crosswalk (Eichsfeld, Unstrut-Hainich, Wartburgkreis) | fixed (Destatis rows, reviewed 2026-10-29) |
| BUG-014 | critical | `03_` L213 to L222, `04_` L156 to L165 | NA population on zero-case rows inflates HZ after merges (up to 94x) | fixed |
| BUG-007 | major | `02_`, `03_`, `04_` | Four different column schemas across years; percentage columns lost 2003 to 2022 | fixed |
| BUG-008 | major | `00_` L106, all stages | `should_skip()` file-existence caching | fixed |
| BUG-013 | major | `12_` L138 | Bodily harm uses three different definitions across the panel | fixed |
| BUG-015 | major | `02_` L451 to L457 | PDF-era cases and cleared cases are back-calculated from rounded rates, not flagged | fixed (Q1 answered) |
| BUG-001 | minor | `04_` L125, `02_` L405, `12_` L98 | AGS normalization scattered across scripts, not at ingestion | fixed |
| BUG-002 | minor | `03_` L213 to L222 | Population back-calculated, not flagged as derived | fixed |
| BUG-004 | minor | `12_` L149 to L150 | `inner_join` without row-count assertions (no loss in current data) | fixed |
| BUG-006 | minor | none | No district-count check per boundary year | fixed |
| BUG-009 | minor | `02_` L40, `03_` L39, `04_` L179 | Both extractors write into one folder; `04_` globs it | fixed |
| BUG-016 | minor | `04_` L148 | Unmatched AGS codes dropped without warning (no loss in current data) | fixed |
| BUG-017 | minor | `04_` L118 to L123 | Weight renormalization only when total weight >= 0.95 | fixed |
| BUG-018 | minor | `04_` L100 to L101, L145 | Locale-dependent weight column regex with fallback to column 1; silent chain break | fixed |
| BUG-019 | minor | `04_` L134 to L139 | Mid-year reform handling hard-coded and undocumented | fixed |
| BUG-020 | minor | `01_`, `02_`, `03_` | Errors swallowed, years can disappear while success is reported | fixed |
| BUG-021 | minor | `02_` L175, L299 to L305 | PDF page detection by `"kreis-"`, rows truncated or dropped by token count | fixed |
| BUG-022 | minor | `02_` L189, L226 to L258 | Name-continuation logic does not reset `last_y` per page | fixed |
| BUG-023 | minor | `03_` L50 to L180 | Positional column names plus a swap heuristic | fixed |
| BUG-024 | minor | `05_` L60 to L134 | Translation by label substring; `*50*00` mislabelled; misses pass through silently | fixed |
| BUG-025 | minor | `01_` L100 to L171 | Templated URLs, no checksums, retries or User-Agent | fixed (discovery of new years in Phase 3) |
| BUG-026 | minor | `03_` | Census-based HZ denominator changes (Zensus 2011, Zensus 2022) not flagged | fixed |
| BUG-029 | minor | `12_` L98, `11_` L106 | `sprintf("%05s")` pads with spaces, not zeros (latent) | fixed |
| BUG-030 | minor | `11_` L114 to L117 (out of scope) | Per-capita capital stock summed with weights during harmonization (latent) | wontfix (out-of-scope analysis script; brief: report only) |
| BUG-032 | minor | `../PKS/Code/pks.R` L244 to L249 | 2013 district names replaced by the type code (`KfS`, `LK`, ...) | fixed |
| BUG-033 | minor | `../PKS/Code/pks.R`, `harmonize.R` | `distinct()` dedup, HZ stored as proportion, silent 0 fallbacks | fixed |
| BUG-027 | cosmetic | `01_`, `02_` L17 | Raw PDFs not in repository; header comment names a wrong folder | fixed |
| BUG-028 | cosmetic | `02_` L354 to L389 | Hard-coded 2008 Sachsen-Anhalt names; `15083` named "Bördekreis" | fixed |
| BUG-031 | cosmetic | `03_analysis/15_*_Backup.R` | Byte-identical duplicate of script 15 | wontfix (out-of-scope analysis script; brief: report only) |
| BUG-036 | minor | new code: `extract_xls.R`, `national.R`, `destatis.R`, `boundary_map.R` | `as.numeric()` on spreadsheet text turns unreadable cells into NA silently (no loss in current data) | fixed |
| BUG-037 | minor | new code: `harmonize_space.R`, `harmonize_offence.R` | Clearance rate of zero-case rows is 0 in unchanged districts, NA in recomputed ones and in 2022 | fixed (0 everywhere, with a load note) |
| BUG-038 | minor | new code: `harmonize_space.R` `check_conservation()` | Population conservation skipped when no population is published (2013 to 2025 except 2020) | fixed |
| BUG-039 | minor | new code: `boundary_map.R` | Registry checks miss NA area weights; two names for one code would duplicate join rows | fixed |
| BUG-040 | minor | new code: `boundary_map.R` `update_boundary_map()` | Keeping reviewed Destatis rows rewrote the map from parsed numbers; 21 weights changed in their last digit | fixed |
| BUG-041 | minor | new code: `ci/fetch_inkar.R`, `pipeline.yml` job `inkar` | INKAR server omits its intermediate certificates; the job failed on its first CI run and opened no issue | fixed |
| BUG-042 | major | new code: `boundary_map.R` `update_boundary_map()` | Boundary map compared as text; on Linux 14 weights differ in their last digit, so the CI tests failed and crosswalk updates would show spurious changes | fixed |
| BUG-003 | not reproduced | none found | City-state filter on codes ending in `000` | fixed |
| BUG-005 | not reproduced | `04_` | BBSR missing mappings for Osterode, Göttingen old code, Eisenach | fixed |
| BUG-010 | not reproduced | none found | Implausible derived population medians | fixed |

---

## Critical

### BUG-011
| Field | Content |
|---|---|
| id | BUG-011 |
| script and line | `02_PKS_Old_Datasets_PDF2CSV.R` L436 (`Straftat_Typ == "Koerperverletzung" ~ "220000"`), L327 to L346 (fixed column names) |
| category | Translation and offence grouping; PDF extraction correctness |
| severity | critical |
| description | The second offence group in the PDF Kreis table is `2200`/`220000` (Körperverletzung insgesamt) in 2003 to 2009, but `222000` (gefährliche und schwere Körperverletzung insgesamt) in 2010, 2011 and 2012. The extractor assigns key `220000` to all ten years, so 2010 to 2012 values are published under the wrong key. |
| evidence | PDF table headers: 2003 to 2007 `2200`, 2008 to 2009 `220000`, 2010 `222000` (p. 261), 2011 introduction text "gefährliche und schwere Körperverletzung insgesamt (222000)" (p. 267), 2012 `222000` (p. 315). National sum of legacy key `220000`: 2009 = 544,651, 2010 = 142,894, 2011 = 139,067, 2012 = 136,059 (a 74 percent drop in one year). The 2013 Excel table carries both: `220000` = 533,432 and `222000` = 127,833. |
| affected_output | 2010 to 2012, all 412/412/402 districts, key `220000` in `01-converted`, `02-harmonized`, `03-translated`; master panel column `PKS_bodily_harm_*` 2010 to 2012; analysis scripts `25_`, `26_`, `28_`, and the "(4) Bodily" model in `04_paper/paper.qmd` L1697. |
| fix | `pksR-data/R/extract_pdf.R`: read the offence key of each column from the table header row instead of a fixed list; store it in `offence_key` as published. |
| test | `test-extract_pdf.R`: "offence keys are read from each year's header (BUG-011)" |
| status | fixed |

### BUG-012
| Field | Content |
|---|---|
| id | BUG-012 |
| script and line | `12_Data_Merge.R` L117, L123, L130 (`coalesce(..._total_crime_clean, ..._total_crime_raw)`) |
| category | Translation and offence grouping |
| severity | critical |
| description | `PKS_total_crime_*` is key `890000` (all offences excluding offences against residence, asylum and EU freedom of movement law) where it exists, otherwise `------` (all offences). `890000` first appears in the Kreis tables in 2015, so the series is "all offences" for 2003 to 2014 and "excluding immigration-law offences" for 2015 to 2021. The switch coincides with the 2015/2016 refugee influx, and the excluded offences are geographically concentrated, so year fixed effects do not absorb it. |
| evidence | Key presence: `890000` absent 2003 to 2014, present 2015 to 2024. National sums: 2015 `------` = 6,258,642 vs `890000` = 5,857,257 (6.41 percent excluded); 2016: 6,292,069 vs 5,805,438 (7.73 percent); 2017 to 2021: 2.80 to 3.15 percent. Panel total crime falls from 6,031,393 (2014) to 5,857,257 (2015) although `------` rose to 6,258,642. |
| affected_output | Master panel `PKS_total_crime_*` 2015 to 2021, all 400 districts; `22_`, `23_`, `26_`, `27_`, `28_`, and the "(1) Total" subtype model in the paper appendix. |
| fix | `registry/offence_map.csv`: `------` covers 2003 to 2025; `890000` is published 2015 to 2025 and computed for 2014 as `------` minus `725000` (your decision Q4; identity exact in all 4,409 district rows 2015 to 2025). `R/harmonize_offence.R` (`offence_spec()`, `difference_rows()`); `registry/known_breaks.csv` BRK-006. |
| test | `test-harmonize_offence.R`: "------ and 890000 are never coalesced into one series (BUG-012)", "890000 for 2014 is ------ minus 725000 with suspects NA" |
| status | fixed (offence map rows reviewed 2026-10-28) |

### BUG-034
| Field | Content |
|---|---|
| id | BUG-034 |
| script and line | BBSR `ref-kreise-1990-2023.xlsx` and `ref-kreise-1990-2024.xlsx`, sheet 2011-2012, Excel row 160; consumed by `04_` L118 to L123 |
| category | Harmonization logic |
| severity | critical |
| description | The row names Bernkastel-Wittlich as the source district and carries the complement weight of `07231` (0.0093 population, 0.0086 area) to Trier-Saarburg, but its source code is `7235000` (Trier-Saarburg) instead of `7231000`. Weight sums become 0.9907 for `07231` and 1.0093 for `07235`. The legacy renormalization (BUG-017) scaled both back to 1, so the transfer of about 0.9 percent of Bernkastel-Wittlich to Trier-Saarburg was ignored for every year harmonized through this sheet. |
| evidence | Destatis 07/2012/0001-R: Trittenheim moves from `07231` to `07235` on 01.01.2012. Area: the 10.1 km2 piece leaves `07231` (1,177.75 to 1,167.57 km2) and joins `07235` (1,091.36 to 1,101.47 km2). Sheet rows 157, 160 and 161 (`registry/boundary_map.csv` ids `bbsr-2011-r157`, `bbsr-2011-r160`, `bbsr-2011-r161`). Effect in `notes/legacy_vs_new.md`: 126 cells, 2011 Bernkastel-Wittlich population 111,073 (legacy) vs 110,035 (new), Trier-Saarburg 141,646 vs 142,684. |
| affected_output | PKS 2003 to 2011 (published boundaries up to 2010), districts `07231` and `07235`, all offence keys; master panel and all analysis scripts using these district-years (effect about 1 percent for two districts). |
| fix | `registry/boundary_map.csv` row `manual-2011-07231` (reviewed 2026-10-29) replaces `bbsr-2011-r160` with source `07231`. Verified by area conservation and by Destatis, not by the name. |
| test | `test-boundary_map.R`: "weights sum to 1 per source district and year (BUG-017)" fails without the manual row; "manual rows replace BBSR rows visibly and are reviewed" |
| status | fixed (manual row reviewed 2026-10-29) |

### BUG-035
| Field | Content |
|---|---|
| id | BUG-035 |
| script and line | BBSR `ref-kreise-1990-2024.xlsx`, sheets 2022-2023 and 2023-2024 (and smaller cases), used by `04_` and by `R/harmonize_space.R` |
| category | Harmonization logic |
| severity | critical (wrong numbers by the brief's definition; size unknown, at most a few percent of three Thuringian districts) |
| description | Some territory moves between districts without any weight in the BBSR crosswalk (all weights 1). Harmonizing earlier years forward therefore leaves the moved area in its old district. |
| evidence | Area conservation check (`notes/audit/bbsr_area_check.R`): 31.12.2022 to 31.12.2023, `16061` Eichsfeld +48.08 km2 and `16064` Unstrut-Hainich-Kreis -48.08 km2; 31.12.2023 to 31.12.2024, `16061` +11.17 km2, `16064` -7.19 km2, `16063` Wartburgkreis -3.96 km2. Smaller exact pairs: Bavaria `09363`/`09374` (2006, 2.0 km2), `09182`/`09184` (2010, 2.8 km2), `09372`/`09376` (2012, 8.0 km2; 2017, 6.7 km2); Bremen `04011`/`04012` (about 8 km2, several years, back and forth). The population moved cannot be measured from BBSR: the 2022 population figures also carry the Zensus 2022 revision (`16064` -5.7 percent, `16061` +2.6 percent in one year). |
| affected_output | Harmonized panel 2003 to 2022 (and 2003 to 2023 for the 2023-2024 change) for `16061`, `16063`, `16064`; the Bavarian and Bremen pairs are probably sparsely populated. Same in the legacy panel. |
| fix | `R/destatis.R`, `R/boundary_map.R`: the 65 transfers that BBSR omits are derived from the Destatis lists of municipal territorial changes 2003 to 2025 (`registry/destatis_sources.csv`) and stored as `source = "destatis"` rows in `registry/boundary_map.csv`; the pipeline recomputes them (`check_boundary_map_destatis()`). Destatis gives the moved inhabitants (for example 3,881 from `16064` to `16061` on 01.01.2023), so no weight is estimated. |
| test | `test-destatis.R`: "transfers missing in BBSR are added with Destatis inhabitants (BUG-035)", "Destatis rows in the registry must equal the Destatis files", "the area unit is read from each file's header (hectares until 2006)", "implausible BBSR denominators are refused" |
| status | fixed (rows reviewed 2026-10-29) |

### BUG-014
| Field | Content |
|---|---|
| id | BUG-014 |
| script and line | `03_PKS_New_Datasets_EXCEL2CSV.R` L213 to L222 (population only where `HZ > 0`); `04_PKS_Spatial_Harmonization.R` L156 to L158 (`sum(x, na.rm = TRUE)`), L165 (HZ recomputed) |
| category | Harmonization logic; Silent data loss |
| severity | critical |
| description | For a district and offence key with 0 cases, HZ is 0, so the back-calculated population is `NA`. When harmonization merges that district with another one (full merger or a partial transfer), the NA population is dropped by `na.rm = TRUE`, so the merged population is too small and the recomputed HZ is too large. |
| evidence | 70 harmonized rows in 2013 to 2021 have an offence-row population different from the district population (districts `03159`, `07140`, `16054`, `16063`, `16066`, `16072`). Maximum HZ inflation factor per year: 2013: 93.8, 2014: 25.9, 2015: 25.9, 2016: 26.0, 2017: 37.9, 2018: 38.1, 2019: 1.3, 2020: 3.8, 2021: 3.8. Example: 2020, `16063` Wartburgkreis, key `219000`: 3 cases, population 42,250 instead of 161,224, HZ 7.10 instead of 1.86. |
| affected_output | `02-harmonized` and `03-translated`, columns `Straftaten_HZ` and `Einwohner`, 70 rows, rare offence keys (`211000`, `212000`, `216000`, `217000`, `219000`, `892500`, ...). The master panel is not affected for its 8 keys because `13_` recomputes rates with INKAR population. |
| fix | `R/harmonize_space.R`: `district_population()` takes one population per district and year (published, else the derived population of the total-crime row), harmonized once and joined back; counts harmonized, HZ and AQ recomputed. Quantified in `notes/legacy_vs_new.md` (148 merged or split cells, 7,851 zero-case cells). |
| test | `test-extract_xls.R`: "zero-case rows carry no derived population (BUG-014)"; `test-harmonize_space.R`: "zero-case rows do not shrink a merged population (BUG-014)" |
| status | fixed |

## Major

### BUG-007
| Field | Content |
|---|---|
| id | BUG-007 |
| script and line | `02_` L459 to L495 (9 all-NA columns), `03_` L189 to L227, `04_` L150 to L159 (only numeric, non-rate columns survive `summarise`) |
| category | Type and parsing errors; Silent data loss |
| severity | major |
| description | Four schemas coexist. PDF years: 19 columns, 9 of them always NA. Harmonized PDF years: 10 columns. Harmonized 2013 to 2022: 17 columns (`Versuche_Anteil_Prozent` and `Nichtdeutsche_Tatverdaechtige_Prozent` silently dropped). Harmonized 2023 and 2024: 19 columns (no loop runs, so nothing is dropped). |
| evidence | Column counts per file in `02-harmonized`: 2003 to 2012: 10; 2013 to 2022: 17; 2023 to 2024: 19. |
| affected_output | All years. Downstream readers must special-case years. |
| fix | `R/schema.R`: `canonical_spec` for every extractor, `harmonized_spec` for the panel; the validation gate checks the schema of every year. |
| test | `test-schema.R`: "PDF and Excel years share one schema (BUG-007)" |
| status | fixed |

### BUG-008
| Field | Content |
|---|---|
| id | BUG-008 |
| script and line | `00_import.R` L106 to L113; used in `01_` L63, `02_` L164, `03_` L83, `04_` L191, `05_` L148, `12_` L39, `13_` L39, `utils.R` L188 |
| category | Reproducibility hazards |
| severity | major |
| description | A stage is skipped when its output file exists, regardless of code or input changes. After a fix, stale outputs are kept unless `force_process` is edited by hand in each script (`TRUE` only in `12_` and `13_`). |
| evidence | Code inspection. Your report of stale outputs in the later project. Not demonstrable from the committed repository state alone. |
| affected_output | Any stage after an upstream change. |
| fix | `pksR-data/_targets.R`: `targets` tracks code and file hashes. |
| test | `test-pipeline.R`: "raw files are tracked by content, not by existence (BUG-008)", "no stage skips work because an output file exists (BUG-008)" |
| status | fixed |

### BUG-013
| Field | Content |
|---|---|
| id | BUG-013 |
| script and line | `12_Data_Merge.R` L117, L138 |
| category | Translation and offence grouping |
| severity | major |
| description | `PKS_bodily_harm_*` is `220000` in 2003 to 2009, `222000` mislabelled as `220000` in 2010 to 2012 (BUG-011), and `222000 + 224000` in 2013 to 2021. Three different definitions in one series. |
| evidence | 2013 bridge year contains all three: `220000` = 533,432; `222000 + 224000` = 506,474 (5.1 percent lower); `222000` alone = 127,833. |
| affected_output | Master panel `PKS_bodily_harm_*` all years; `25_`, `26_`, `28_`, paper appendix model "(4) Bodily". |
| fix | `registry/offence_map.csv`: `220000`, `222000` and `224000` are separate harmonized keys; `registry/known_breaks.csv` BRK-002. A key is never summed with its parent or child. |
| test | `test-harmonize_offence.R`: "no harmonized key mixes source keys across years without a documented break (BUG-013)" |
| status | fixed (offence map rows reviewed 2026-10-28) |

### BUG-015
| Field | Content |
|---|---|
| id | BUG-015 |
| script and line | `02_` L451 to L457 |
| category | Statistical plausibility; Type and parsing errors |
| severity | major |
| description | The PDF Kreis tables publish population, HZ (integer) and AQ (one decimal), but no case counts. Cases are computed as `round(HZ * Einwohner / 1e5)` and cleared cases as `round(cases * AQ / 100)`. These are estimates, stored in the same columns as published counts without a flag. |
| evidence | 2003 header: "Einwohner am 01.01.03, HZ, AQ" only. Rounding bound per cell: plus or minus `0.5 * Einwohner / 1e5` cases (Flensburg 2003: plus or minus 0.4; Berlin: plus or minus 17), plus the AQ rounding for cleared cases. Extraction itself is correct (BUG-free cell comparison, see audit section 6.1). |
| affected_output | 2003 to 2012, all districts, all 7 offence groups, `Erfasste_Faelle` and `Aufklaerung_Faelle`. |
| fix | Canonical schema: `cases` stays `NA` for PDF years unless published; a derived column with an `estimated`/derived flag is added (your decision, see audit section 9). |
| test | `test-extract_pdf.R`: "PDF years never report derived counts (BUG-015)" |
| status | fixed (your decision Q1: `cases` stays NA, derived counts in `cases_derived` and `cleared_derived` with `estimated = TRUE`) |

## Minor

### BUG-001
| Field | Content |
|---|---|
| id | BUG-001 |
| script and line | `02_` L405 (`str_pad`), `04_` L112 and L125 to L129 (`as.integer` then `sprintf("%08d")`, `substr(1, 5)`), `12_` L98 |
| category | Type and parsing errors |
| severity | minor |
| description | Code normalization happens separately in each script. Currently correct: every output id has 5 characters. Fragile: `%08d` then `substr(1, 5)` is only correct for 7 or 8 digit BBSR codes ending in `000`. |
| evidence | All files in `01-converted`, `02-harmonized`, `03-translated`, `final/`: id length 5 only. |
| affected_output | None currently. |
| fix | `pksR-data/R/schema.R`: `normalize_ags()` at ingestion, assert `^[0-9]{5}$`. |
| test | `test-schema.R`: "normalize_ags handles PKS and BBSR code formats (BUG-001)" |
| status | fixed |

### BUG-002
| Field | Content |
|---|---|
| id | BUG-002 |
| script and line | `03_` L207 to L222 |
| category | Statistical plausibility |
| severity | minor |
| description | Population is back-calculated as `cases / HZ * 1e5` and stored as `Einwohner` without a flag. For Excel years this is exact because HZ is stored unrounded. Rows with 0 cases get `NA` (see BUG-014). |
| evidence | 2020: derived population equals the official `EW 31.12.2019` column of the same workbook for all 401 districts (max relative difference 0). Within-district variation of derived population across offence keys: 0. NA rows: 42 (2013), 639 (2016), 757 (2020), 791 (2024). |
| affected_output | 2013 to 2024 `Einwohner`. |
| fix | `derived_population` column per Section 5.2; official population preferred. |
| test | `test-extract_xls.R`: "derived population equals the published 2020 population (BUG-002)" |
| status | fixed |

### BUG-004
| Field | Content |
|---|---|
| id | BUG-004 |
| script and line | `12_Data_Merge.R` L148 to L151 |
| category | Silent data loss |
| severity | minor (latent in this repository) |
| description | Two `inner_join` calls without row-count checks. In the current repository state nothing is lost; the drop of 11 of 13 years you reported is not reproducible from these inputs (likely the later project). |
| evidence | Final panel: 7,600 rows = 400 districts x 19 years; INKAR, capital stock and PKS inputs all 400 districts 2003 to 2021. |
| affected_output | None currently. |
| fix | `R/utils.R`: `join_checked()` refuses joins that lose rows and is used for every join in `harmonize_space()`; the gate checks conservation and year completeness. The merge step itself belongs to your analysis. |
| test | `test-utils.R`: "join helper errors when rows are lost (BUG-004)"; `test-validate.R`: "the gate catches a lost year and changed totals (BUG-004, BUG-020)" |
| status | fixed |

### BUG-006
| Field | Content |
|---|---|
| id | BUG-006 |
| script and line | none (missing check) |
| category | Statistical plausibility |
| severity | minor |
| description | No script asserts the expected district count. The legacy outputs happen to have 400 districts in every harmonized year. |
| evidence | Converted: 439 (2003 to 2006), 429 (2007 to 2008), 413 (2009), 412 (2010 to 2011), 402 (2012 to 2016), 401 (2017 to 2021), 400 (2022 to 2024). Harmonized: 400 every year. |
| affected_output | None currently. |
| fix | `R/boundary_map.R`: `boundary_codes()` gives the expected district set for any boundary year; `validate_extraction()` uses it per published boundary, the gate's coverage check per target boundary. |
| test | `test-boundary_map.R`: "district counts follow the boundary year (BUG-006)"; `test-validate.R`: "district count must match the declared boundary (BUG-006, BUG-019)" |
| status | fixed |

### BUG-009
| Field | Content |
|---|---|
| id | BUG-009 |
| script and line | `02_` L40, `03_` L39, `04_` L179 to L180 |
| category | Reproducibility hazards |
| severity | minor (in this repository) |
| description | Both extractors write into `processed/PKS/01-converted/`; `04_` processes every CSV whose name starts with `20`. A second file for the same year would be harmonized twice and both would write the same output name. In this repository the file names do not collide. |
| evidence | 22 files, one per year, in `01-converted`. Your report of half-empty columns and missing years in the later project. |
| affected_output | None currently. |
| fix | One `targets` target per year and extractor, downstream reads declared targets only. |
| test | `test-pipeline.R`: "each registry row is its own branch with declared inputs (BUG-009)" |
| status | fixed |

### BUG-016
| Field | Content |
|---|---|
| id | BUG-016 |
| script and line | `04_` L148 (`filter(!is.na(new_id))`) |
| category | Silent data loss |
| severity | minor (latent) |
| description | Codes without a crosswalk row are dropped without a message. |
| evidence | National totals of cases, population and cleared cases are conserved to 1e-15 relative error in every year, so no rows were lost with the current inputs. |
| affected_output | None currently. |
| fix | `R/harmonize_space.R`: unmatched codes raise a warning listing every code and the removed rows are logged; `check_conservation()` then stops the pipeline. |
| test | `test-harmonize_space.R`: "unmatched AGS codes are reported, not dropped silently (BUG-016)" |
| status | fixed |

### BUG-017
| Field | Content |
|---|---|
| id | BUG-017 |
| script and line | `04_` L118 to L123 |
| category | Harmonization logic |
| severity | minor (one open research question) |
| description | Weights are renormalized per source district only when their sum is >= 0.95; sums below 0.95 are used unchanged (counts shrink), sums above 1 are scaled down silently. With the unmodified BBSR file this would have cut Mayen-Koblenz (`07137`) to 1.7 percent of its counts for 2014 and 2015 data. The manual fix avoids that; the 1.7 percent is a copy of the 2013-2014 Cochem-Zell to Rhein-Hunsrueck weights (Destatis 07/2014/0003-R), so weight 1 is correct. Two BBSR inconsistencies remain hidden by renormalization: 2011-2012 `07231` sums to 0.9907 and `07235` to 1.0093; 2014-2015 and 2015-2016 `07135` (Cochem-Zell) sums to 0.9828. |
| evidence | Weight-sum scan of all sheets 2002-2003 to 2022-2023 (audit section 6.4). |
| affected_output | None in current outputs beyond the renormalization itself (conservation holds). |
| fix | `R/boundary_map.R`: `assert_boundary_map()` requires weight sums of 1 (1e-6) per source district and period without renormalization; the 6 deviating source districts are corrected by 5 documented manual rows in `registry/boundary_map.csv` (Q5 legacy fix for Mayen-Koblenz and Cochem-Zell, BUG-034 for 2011-2012). |
| test | `test-boundary_map.R`: "weights sum to 1 per source district and year (BUG-017)" |
| status | fixed (manual rows reviewed 2026-10-29) |

### BUG-018
| Field | Content |
|---|---|
| id | BUG-018 |
| script and line | `04_` L100 to L101, L145; same pattern in `11_` |
| category | Reproducibility hazards |
| severity | minor |
| description | The weight column is found with the regex `"bevölkerungs.*Umsteige"`. If it does not match (encoding or locale issue, renamed column), the first column (the district code) silently becomes the weight. If a transition sheet is missing, `break` stops the chain and the data stay at an intermediate boundary without a message. |
| evidence | Code inspection; all 21 sheets from 2002-2003 to 2022-2023 currently contain the expected columns (scan run in a UTF-8 locale). |
| affected_output | None currently. |
| fix | `R/boundary_map.R`: `read_bbsr_sheet()` matches every column by its header exactly once and errors otherwise; a missing sheet or period is an error in `read_bbsr_sheet()`, `assert_boundary_map()` and `compose_crosswalk()`. |
| test | `test-boundary_map.R`: "missing transition year is an error (BUG-018)" |
| status | fixed |

### BUG-019
| Field | Content |
|---|---|
| id | BUG-019 |
| script and line | `04_` L134 to L139 (`effective_start_year`) |
| category | Harmonization logic |
| severity | minor |
| description | The boundary that each PKS year is published on is encoded as five undocumented special cases. They are empirically correct, but BKA practice is not uniform: PKS 2007 already reflects the Sachsen-Anhalt reform of 1 July 2007, while PKS 2008 does not reflect the Sachsen reform of 1 August 2008, and PKS 2016 and 2021 do not reflect the November 2016 and July 2021 changes. |
| evidence | District counts per PDF/Excel year match the BBSR counts of the sheet chosen by the rule (439, 429, 429, 413, 412, 412, 402, 402, 401, 401). |
| affected_output | None currently. |
| fix | `registry/sources.csv` gets the published boundary (`boundary_year`) per year, documented in `notes/decisions.md`; validated by matching the district set to the crosswalk. |
| test | `test-validate.R`: "district count must match the declared boundary (BUG-006, BUG-019)"; all 23 years pass against `registry/sources.csv` `boundary_year` |
| status | fixed |

### BUG-020
| Field | Content |
|---|---|
| id | BUG-020 |
| script and line | `01_` L69 to L79 and L173; `02_` L180 to L183, L539 to L549; `03_` L87 and L238 to L240 |
| category | Silent data loss; Reproducibility hazards |
| severity | minor (latent) |
| description | Failed downloads return `FALSE` and the script still prints "ALL DOWNLOADS COMPLETED SUCCESSFULLY". A PDF without matching pages or with a column-count mismatch is skipped with a message only. `tryCatch` in `03_` turns any error into a message, so a year can vanish while the pipeline continues. |
| evidence | Code inspection. All 22 years are present in the committed outputs. |
| affected_output | None currently. |
| fix | Errors propagate; `validate.R` year-completeness check (Section 7.7). |
| test | `test-extract_pdf.R`: "a page without the table is an error, not an empty result"; `test-extract_xls.R`: "a non-empty row without a district code is an error (BUG-020)"; `test-validate.R`: "a registry year without output fails (BUG-020)" |
| status | fixed |

### BUG-021
| Field | Content |
|---|---|
| id | BUG-021 |
| script and line | `02_` L174 to L178 (page filter), L299 to L305 (truncate to 15 or drop) |
| category | PDF extraction correctness; Positional fragility |
| severity | minor |
| description | Pages are selected by the substring `"kreis-"`; rows with more than 15 numeric tokens are truncated, rows with fewer are dropped, with no count. |
| evidence | Independent position-based re-extraction (`notes/audit/verify_pdf.R`) finds the same 4,253 district rows and identical values in all cells (one disagreement traced to the audit parser, legacy value correct). So currently correct. |
| affected_output | None currently. |
| fix | `extract_pdf.R`: page range from `registry/sources.csv`, column assignment by header x-positions, row count asserted against the crosswalk. |
| test | `test-extract_pdf.R`: "every district row on a page is extracted (BUG-021)"; `test-validate.R`: "an offence key missing for some districts fails (BUG-021)" |
| status | fixed |

### BUG-022
| Field | Content |
|---|---|
| id | BUG-022 |
| script and line | `02_` L189, L226 to L258 |
| category | PDF extraction correctness |
| severity | minor (latent) |
| description | `last_y` is initialized once per file, not per page. On a new page, a single-token text line at the top can satisfy `current_y - last_y < 15` (the difference is negative) and be appended to the last district name of the previous page. |
| evidence | No damaged names found: the only district name longer than 32 characters is the genuine "Niederschles. Oberlausitzkreis" (`14284`, 2003 to 2008). |
| affected_output | None currently. |
| fix | Replaced by the header-position parser in `extract_pdf.R`. |
| test | `test-extract_pdf.R`: "fragments, footnote markers and footer rules do not corrupt rows (BUG-021, BUG-022)" |
| status | fixed |

### BUG-023
| Field | Content |
|---|---|
| id | BUG-023 |
| script and line | `03_` L50 to L69, L101 to L121, L131 to L180 |
| category | Positional fragility |
| severity | minor |
| description | Columns are named by position (18 names), extra columns are cut, and a majority-vote heuristic swaps name and type. The brief's layout notes are partly wrong (see audit section 8): 2013 has column 4 = type and column 5 = name; 2014 onward the reverse; 2015 has a 19th column `Sort`; 2020 has 23 columns including official population `EW 31.12.2019`. |
| evidence | Cell-by-cell comparison of every raw workbook with the converted CSV (`notes/audit/verify_xls.R`): 0 mismatches in about 2.4 million numeric cells, 0 name or type mismatches. Currently correct. |
| affected_output | None currently. |
| fix | `extract_xls.R`: map columns by header text (rows 5 to 8) checked against the column-number row (row 9); row 9 alone is not reliable (the 2025 file numbers its columns `8, 9, 16, 17, 12`); unknown layouts are an error (schema drift). |
| test | `test-extract_xls.R`: "every Excel layout yields the same fields (BUG-023)", "header drift stops the pipeline (BUG-023)", "2025 is read by header text despite the misnumbered column row" |
| status | fixed |

### BUG-024
| Field | Content |
|---|---|
| id | BUG-024 |
| script and line | `05_` L60 to L134 |
| category | Translation and offence grouping |
| severity | minor (labels only, numbers unaffected) |
| description | Translation is keyed on German labels with exact then substring matching in dictionary order, not on offence keys. The legacy PDF group `DiebstahlKfz` (key `*50*00`, "Diebstahl in/aus Kraftfahrzeugen", theft from motor vehicles) is translated as "Theft of Motor Cars incl. unauthorized use" (L106), which is a different offence. `Koerperverletzung` becomes "Bodily Harm" even for the `222000` years. Unmatched labels pass through in German without a message. |
| evidence | PDF introduction texts (2003: "Diebstahl in/aus Kraftfahrzeugen (*50*)"); dictionary L106. |
| affected_output | `03-translated` `offense` column, 2003 to 2012. |
| fix | `registry/offence_map.csv`: labels per key, not by label substring; `*50*00` is theft from vehicles. Unknown keys stop the pipeline (`harmonize_offences()`). |
| test | `test-harmonize_offence.R`: "*50*00 is theft from vehicles, not theft of cars (BUG-024)", "unknown offence keys stop the pipeline (Section 9.1.5)" |
| status | fixed (English labels reviewed 2026-10-28) |

### BUG-025
| Field | Content |
|---|---|
| id | BUG-025 |
| script and line | `01_` L100 to L171 |
| category | Reproducibility hazards |
| severity | minor |
| description | URLs are built from templates with a pinned `v=` parameter, no checksums, no retries, no User-Agent, a 5,000-byte size check as the only validation, and the full yearbooks (up to 483 pages) are downloaded for a 6 to 7 page table. |
| evidence | Code inspection. The verified 2025 URL ends in `v=2`, while the template in L123 to L127 would request `v=4` for 2025 (audit section 10). bka.de answered HTTP 400 to HEAD requests, but plain GETs of all 22 legacy URLs (2003 to 2024) return the same files as the local copies (21 byte-identical, 2013 content-identical), so the URLs currently work; the template simply fails for 2025. |
| affected_output | Reproducibility of raw inputs. |
| fix | `registry/sources.csv` with verified URLs, `download.R` with SHA-256, ETag, retries and a descriptive User-Agent. |
| test | `test-registry.R`: "every source has a recorded URL, hash and boundary (BUG-025)", "URLs are not built from a template (BUG-025)"; `test-download.R`: "a file whose hash differs from the registry is rejected (BUG-025)" |
| status | fixed (discovery of new years in Phase 3) |

### BUG-026
| Field | Content |
|---|---|
| id | BUG-026 |
| script and line | `03_` (header text ignored) |
| category | Statistical plausibility |
| severity | minor |
| description | The HZ denominator changes: PDF years use the population update of 1 January; Excel headers say "HZ nach Zensus 2011" (2013), "HZ nach Zensus" (2015 to 2019) and "HZ nach Zensus 2022" (2024). Derived population and HZ therefore have level breaks that are not recorded. |
| evidence | Excel header row 5/6 per year (audit section 5). |
| affected_output | Derived population and HZ across 2012/2013 and 2023/2024. |
| fix | `registry/known_breaks.csv` BRK-004 (Zensus 2011, 2013) and BRK-005 (Zensus 2022, 2024), reviewed 2026-10-29. Since 2026-10-29 also column `population_corrected` (`R/population.R`): the census-corrected population of the BBSR (INKAR) at 31.12. of the year before, on the boundary of each row, so `pksR::pks_rates(population = "corrected")` puts all years on one census base. |
| test | `test-breaks.R`: "known_breaks contains census rebasing rows (BUG-026)"; `test-population.R` |
| status | fixed (break rows reviewed 2026-10-29) |

### BUG-029
| Field | Content |
|---|---|
| id | BUG-029 |
| script and line | `12_` L98; `11_` L106 |
| category | Type and parsing errors |
| severity | minor (latent) |
| description | `sprintf("%05s", x)` pads character input with spaces, not zeros. Correct only because the input already has 5 characters. |
| evidence | Capital stock AGS already `01001`; no spaces after padding. |
| affected_output | None currently. |
| fix | `normalize_ags()` (BUG-001). |
| test | covered by the BUG-001 test (`normalize_ags()` pads with zeros) |
| status | fixed |

### BUG-030
| Field | Content |
|---|---|
| id | BUG-030 |
| script and line | `11_Capital_Stock_Harmonization.R` L113 to L118 of the function block (weighted sum of `Capital_Stock_Per_Capita` and sector shares) |
| category | Harmonization logic (out of scope, report only) |
| severity | minor (latent) |
| description | Per-capita values and shares are multiplied by weights and summed, so a full merger of two districts (weights 1 and 1) would add their per-capita values. |
| evidence | No year-on-year jump above 1.6x or below 0.6x in any district 2003 to 2021, so the case is not triggered with the current source (which appears to be on current boundaries already; not verified). |
| affected_output | None detected. `log_capital` enters the main model in `15_`. |
| fix | Not fixed (out of scope). |
| test | none |
| status | wontfix: out-of-scope analysis script, the brief asks to report, not fix; `pksR-data` does not harmonize per-capita values |

### BUG-032
| Field | Content |
|---|---|
| id | BUG-032 |
| script and line | `../PKS/Code/pks.R` L244 to L249 |
| category | Positional fragility |
| severity | minor |
| description | In the 2013 workbook column 4 is the district type. The guard `^[A-Z]+$` does not match `KfS`, so the type code is taken as the district name. |
| evidence | `../PKS/Data/extracted_pks_data.csv`: 98 rows in 2013 with `Kreis` equal to a type code; first rows `KfS, KfS, KfS, KfS`. |
| affected_output | Local project, 2013 names only. |
| fix | `extract_xls.R` layout mapping (BUG-023). |
| test | `test-extract_xls.R`: "2013 name and type columns are not confused (BUG-023, BUG-032)" |
| status | fixed |

### BUG-033
| Field | Content |
|---|---|
| id | BUG-033 |
| script and line | `../PKS/Code/pks.R` L262 to L265, L305; `../PKS/Code/harmonize.R` L224 to L231, L282 to L289 |
| category | Silent data loss; Statistical plausibility |
| severity | minor |
| description | `distinct()` silently removes identical rows; population is set to 0 when HZ is 0 and cases are set to 0 when population is 0; the harmonized column named `HZ` is a proportion (cases / population), not per 100,000. |
| evidence | Code inspection; harmonized output `HZ = 0.14359416` for Flensburg 2003 (published HZ 14,359). No zero-population rows in the current output. |
| affected_output | Local project output `extracted_pks_data_harmonized.csv`. |
| fix | Canonical schema and `pks_rates()`. |
| test | `test-schema.R`: "hz is per 100,000 inhabitants (BUG-033)" |
| status | fixed |

## Cosmetic

### BUG-027
| Field | Content |
|---|---|
| id | BUG-027 |
| script and line | `01_` L30, `02_` L17, L39 |
| category | Reproducibility hazards |
| severity | cosmetic |
| description | Raw PDFs are not committed (folder `raw/PKS/old_datasets/` absent), so the PDF stage depends on the network; the header comment of `02_` names `old_01_datasets`. |
| evidence | `find 01_datasets/raw/PKS` lists only the 12 Excel files. The PDFs exist locally in `../PKS/Data/`. |
| affected_output | none |
| fix | Raw files with hashes in `registry/sources.csv`; test fixtures from small excerpts. |
| test | `test-registry.R` (hashes recorded); raw files are reproducible from `registry/sources.csv` via `fetch_raw()` |
| status | fixed |

### BUG-028
| Field | Content |
|---|---|
| id | BUG-028 |
| script and line | `02_` L354 to L389 |
| category | PDF extraction correctness |
| severity | cosmetic |
| description | Names and types of 15 Sachsen-Anhalt districts are overwritten by hand for 2008 only. `15083` is set to "Bördekreis"; BBSR names it "Börde" (sheet 2008-2009). Numbers are not touched. |
| evidence | BBSR sheet 2008-2009 row `15083000 Börde`. |
| affected_output | `Kreis` column 2008. |
| fix | Names taken from the source row; a name-to-AGS check against the crosswalk. |
| test | `test-extract_pdf.R`: "fragments, footnote markers and footer rules do not corrupt rows" (names taken from the source; no hard-coded names remain) |
| status | fixed |

### BUG-031
| Field | Content |
|---|---|
| id | BUG-031 |
| script and line | `03_analysis/15_Main_Econometric_Analysis_Backup.R` |
| category | Reproducibility hazards (out of scope) |
| severity | cosmetic |
| description | Byte-identical copy of `15_Main_Econometric_Analysis.R`. |
| evidence | `diff -q` reports no difference. |
| affected_output | none |
| fix | not fixed (out of scope) |
| test | none |
| status | wontfix: out-of-scope analysis script, the brief asks to report, not fix |

## Found in the new code (Phase 2 review, 2026-10-28)

### BUG-036
| Field | Content |
|---|---|
| id | BUG-036 |
| script and line | new code: `R/extract_xls.R` (cases, hz, attempts, cleared, clearance_rate, suspects, population), `R/national.R`, `R/destatis.R`, `R/boundary_map.R` |
| category | Silent data loss |
| severity | minor |
| description | Spreadsheet cells are read as text and converted with `as.numeric()`, which turns any text that is not a number (a footnote marker, a shifted label column) into NA with only a warning. |
| evidence | No such cell exists in the current files: in all 13 Excel years columns 6 to 18 hold only numbers or empty cells. The only NA block is 2022 column 13 (803 cells), which is empty in the source (BUG-037). |
| affected_output | none currently |
| fix | `as_number()` in `R/utils.R`: empty cells stay NA, any other unreadable text aborts; used at every conversion of spreadsheet text. |
| test | `test-utils.R`: "spreadsheet text that is not a number aborts instead of becoming NA" |
| status | fixed |

### BUG-037
| Field | Content |
|---|---|
| id | BUG-037 |
| script and line | new code: `R/harmonize_space.R` `harmonize_space()` |
| category | Statistical plausibility |
| severity | minor |
| description | The clearance rate of 0 cases is undefined. Unchanged districts kept the published value (0 in most years), recomputed districts and derived keys got NA, and the 2022 table leaves the cell empty, so the same situation had two codings in the panel. |
| evidence | Canonical files: every zero-case row prints AQ 0 in 2013 to 2021 and 2023 to 2025 (42 to 837 rows per year), including rows with cleared > 0 (6 to 19 per year); 2022 leaves all 803 cells empty. Harmonized panel before the fix: NA in 2022 and in recomputed districts, 0 elsewhere. |
| affected_output | `clearance_rate` of zero-case rows in the harmonized panel (2022 and recomputed districts); counts unaffected. The canonical (as published) files keep the published value, so 2022 stays empty there. |
| fix | Your decision 2026-10-28: the BKA convention 0 is kept and applied everywhere (`harmonize_space()`, `difference_rows()`); the panel Parquet file carries the note in its metadata (`panel_notes` in `R/extract.R`, key `pksR_notes`) so that `pks_get()` prints it on load. The only NA left in the panel is 2010 `09185` `*50*00`, printed "-" in the PDF. |
| test | `test-harmonize_space.R`: "the clearance rate of zero cases is 0 in identity and merged districts", "the panel file carries the notes for pks_get()" |
| status | fixed |

### BUG-038
| Field | Content |
|---|---|
| id | BUG-038 |
| script and line | new code: `R/harmonize_space.R` `check_conservation()` |
| category | Harmonization logic |
| severity | minor |
| description | The population part of the conservation check summed `population`, which is NA in every Excel year except 2020; `isTRUE(NA)` then skipped the check, so the derived population was never compared. |
| evidence | Code inspection; after the fix the check runs on all 23 years and passes for both weightings. |
| affected_output | none (check gap only) |
| fix | Compare the published population where it exists, else the derived population; an NA on one side only fails. |
| test | `test-harmonize_space.R`: "conservation covers the derived population when none is published" |
| status | fixed |

### BUG-039
| Field | Content |
|---|---|
| id | BUG-039 |
| script and line | new code: `R/boundary_map.R` `check_boundary_map_source()`, `check_boundary_map_destatis()`, `boundary_names()` |
| category | Reproducibility hazards |
| severity | minor |
| description | The registry-versus-file checks only treated an NA population weight as a difference (an NA area weight gave an unhelpful error), and `boundary_names()` did not guarantee one name per code, which would duplicate rows in the joins of `harmonize_space()`. |
| evidence | Code inspection; the current registry has neither case. |
| affected_output | none |
| fix | `weights_differ()` treats any NA weight as a difference; `boundary_names()` aborts on a code with several names. |
| test | existing `test-boundary_map.R` tests pass; the pipeline run covers both functions |
| status | fixed |

### BUG-040
| Field | Content |
|---|---|
| id | BUG-040 |
| script and line | new code: `R/boundary_map.R` `update_boundary_map()` (status of reviewed Destatis rows) |
| category | Type and parsing errors; Reproducibility hazards |
| severity | minor |
| description | When a crosswalk update kept the `reviewed` status of Destatis rows, it read the new map with numeric columns and wrote it back. readr's number parser differs from R's `as.numeric()` by one unit in the last place for some values, so these weights changed their text, and the update reported changes that did not exist. Only reachable once the registry holds reviewed Destatis rows, which it does since 2026-10-29. |
| evidence | 21 of the 18,246 weights in `registry/boundary_map.csv` are parsed differently by `readr::read_csv()` and `as.numeric()`. With all Destatis rows reviewed, the round-trip test in `test-boundary_map.R` failed on 6 lines on the previous code (for example `9.137287748420012e-5` written as `9.137287748420011e-5`). The relative size, about 1e-16, does not change any value in the panel. |
| affected_output | none published; `ci/update_crosswalk.R` would have committed spurious weight changes and wrong counts of changed rows into the pull request of the next BBSR edition |
| fix | `update_boundary_map()` sets the status on the file read as text, so no weight is reparsed (commit `86d2f53`) |
| test | `test-boundary_map.R`: "a newer BBSR edition adds its periods and moves the target year" (the map must come back row for row) and "reviewed Destatis rows stay reviewed and drafts stay draft"; the first fails on the previous code |
| status | fixed |

### BUG-041
| Field | Content |
|---|---|
| id | BUG-041 |
| script and line | new code: `ci/fetch_inkar.R`, `.github/workflows/pipeline.yml` job `inkar` |
| category | Reproducibility hazards |
| severity | minor |
| description | www.inkar.de sends only its own certificate, issued by GoDaddy TLS Intermediate CA DV - R1v1, without the intermediates. Browsers fetch them, curl does not, so every request from the CI runner (and from macOS) fails with "unable to get local issuer certificate". The intermediate named in the certificate's AIA field is signed by GoDaddy TLS Root CA - R1, which is in neither the Mozilla nor the macOS root store; a valid chain needs the cross certificate of R1 signed by Go Daddy Root Certificate Authority - G2. The job also opened no issue on failure, so the error would only have shown as a failed run. |
| evidence | First CI run of the job (run 40962397456, 2026-10-29): `SSL peer certificate or SSH remote key was not OK [www.inkar.de]`. `openssl s_client`: chain of length 1 in six connections. `openssl verify` without partial chains: OK against the Mozilla roots with the DV intermediate and the R1-to-G2 cross certificate from certs.godaddy.com, not OK with the intermediate alone. |
| affected_output | none; the committed INKAR snapshot is used by the pipeline, and releases do not depend on this job |
| fix | `ci/certs/inkar_intermediates.pem` (both certificates, from `gd_bundle_dv-r1-g2.crt.pem` without its root); `inkar_ca_bundle()` in `R/population.R` adds them to the trusted roots only after `openssl::cert_verify()` succeeds, and `ci/fetch_inkar.R` sets `CURL_CA_BUNDLE` to the result; the job opens one issue when it fails |
| test | `test-population.R`: "the INKAR intermediates are used only when they verify against trusted roots" (a chain without the cross certificate is refused); local run of `ci/fetch_inkar.R`: both indicators downloaded, snapshot unchanged |
| status | fixed |

### BUG-042
| Field | Content |
|---|---|
| id | BUG-042 |
| script and line | new code: `R/boundary_map.R` `update_boundary_map()`; `tests/testthat/test-boundary_map.R` `crosswalk_update_fixture()` |
| category | Type and parsing errors; Reproducibility hazards |
| severity | major |
| description | The registry `boundary_map.csv` was built on macOS (Apple silicon). Rebuilt on the Linux CI runner, the same weights come out one unit in the last place apart for some rows, because R parses numbers with long double (80 bit on x86_64 Linux, 64 bit on Apple silicon). `update_boundary_map()` compared rows by their text (`paste()` of the weights) and wrote the rebuilt numbers, so on Linux it reported changed rows and rewrote weights that had not changed. Its round-trip test therefore failed in the pipeline job of the CI dry run, which stops every release. BUG-040 was one case of this class. |
| evidence | CI dry run 40962397456 (2026-10-29), step Tests: 2 failures in `test-boundary_map.R`, 14 of 9,124 lines differ, for example `bbsr-2004-r402` weight_area `0.988946` against `0.9889460000000002`, and one BBSR row counted as changed. The new test fails on the previous code. |
| affected_output | no data: weights differ by about 1e-16; every release since the first dry run would have been stopped by the test, and `ci/update_crosswalk.R` would have opened pull requests with spurious weight changes |
| fix | `unchanged_rows()` compares id, transition and both weights within 1e-12; `update_boundary_map()` keeps the text of unchanged rows, keeps `reviewed` on unchanged Destatis rows and counts only real changes; the fixture writes the registry text |
| test | `test-boundary_map.R`: "a map written on another platform keeps its text where the data did not change" (weights shifted by one unit in the last place must keep their text and count as unchanged) and "a newer BBSR edition adds its periods and moves the target year" |
| status | fixed |

## Known issues not reproduced in the available code

### BUG-003
| Field | Content |
|---|---|
| id | BUG-003 |
| script and line | not found |
| category | Silent data loss |
| severity | major (as reported) |
| description | Filter on codes ending in `000` dropping Berlin `11000` and Hamburg `02000`. |
| evidence | No such filter in any script of commit `45525ea` or in its 10-commit history (`git log -p`), nor in `../PKS/Code/`. Berlin and Hamburg are present in every converted, harmonized, translated and final file. `10_` special-cases `02`/`11` correctly. |
| affected_output | none found |
| fix | `validate.R` coverage check: Berlin and Hamburg in every year (Section 7.3). |
| test | `test-validate.R`: "dropping Berlin or Hamburg fails the gate (BUG-003)" |
| status | fixed: the new code never filters AGS codes by their form; the district set of every year is checked against the BBSR crosswalk and the gate stops when `11000` or `02000` is missing (tests in `test-validate.R`). Your decision 2026-10-28: the legacy code is reference only, so the status follows the new code. |

### BUG-005
| Field | Content |
|---|---|
| id | BUG-005 |
| script and line | `04_` (crosswalk usage) |
| category | Harmonization logic |
| severity | major (as reported) |
| description | Reported: BBSR sheets lack mappings for Osterode `03156` to Göttingen `03159`, old Göttingen `03152` to `03159` (2016), Eisenach `16056` to Wartburgkreis `16063` (2021). |
| evidence | The BBSR file in the repository contains all three: sheet 2015-2016 maps `3152000` and `3156000` to `3159000` with weight 1; sheet 2020-2021 maps `16056000` to `16063000` with weight 1. The legacy harmonized outputs have no `03152`, `03156` or `16056`. Conflicts with the brief (audit section 8). |
| affected_output | none found |
| fix | If you confirm, these become `source = "bbsr"` rows plus a cross-check test, not `manual` rows. |
| test | `test-boundary_map.R`: "03156, 03152 and 16056 map to 03159 and 16063 (BUG-005)" (passes: all three are BBSR rows) |
| status | fixed: the three mappings are BBSR rows with weight 1 and are guarded by a test; no manual rows needed. Your decision 2026-10-28. |

### BUG-010
| Field | Content |
|---|---|
| id | BUG-010 |
| script and line | not found |
| category | Statistical plausibility |
| severity | critical (as reported) |
| description | Reported implausible derived medians (3,500 population, HZ median 64,000). |
| evidence | Not reproducible: median district population in the converted files 148,002 (2013) to 154,899 (2020); final panel median 147,965 to 154,003 per year. The only related artifact found is BUG-033 (HZ stored as a proportion in the local project) and BUG-014 (inflated HZ on 70 rows). |
| affected_output | none found |
| fix | `validate.R` plausibility gate (median population 50,000 to 400,000, Section 7.6). |
| test | `test-validate.R`: "implausible population medians are flagged (BUG-010)" |
| status | fixed: related causes BUG-033 (HZ as proportion) and BUG-014 (inflated HZ) are fixed; the gate warns when the median district population leaves 50,000 to 400,000 (`test-validate.R`). Your decision 2026-10-28. |
