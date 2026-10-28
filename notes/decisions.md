# Design decisions

Each entry: date, decision, rationale. Research decisions (offence and territorial mappings) are only proposed here until you confirm them.

## 2026-10-27: Legacy repository location and handling

Decision: the legacy repository is cloned to `../legacy/ImmigrationCrimeGermany_AppliedEconResearchProj/` (commit `45525ea`) and only read. R scripts are never run from its root.

Rationale: brief Section 3. Its `.Rprofile` activates `renv`, which writes into the clone when R starts there.

## 2026-10-27: Local `../PKS/` folder treated as a third reference, not as the later project

Decision: `../PKS/Code/pks.R` and `harmonize.R` are audited as an additional reference. The later project described in the brief (2013 to 2025, `offense_codebook.csv`) is recorded as not provided.

Rationale: the folder does not contain the scripts or codebook named in the brief; it extracts only `------` (population and HZ).

## 2026-10-27: Full-population verification instead of a sample

Decision: extraction was verified on every cell (63,795 PDF cells, 2,460,744 Excel cells) instead of 5 districts x 3 keys per year.

Rationale: the brief's sample is a minimum; a complete comparison gives an exact error rate at little extra cost. Scripts are kept in `notes/audit/` so the evidence is reproducible.

## 2026-10-27: Audit scripts kept outside the pipeline

Decision: `notes/audit/*.R` are evidence only and will not be ported into `pksR-data`.

Rationale: Phase 0 forbids new pipeline code. The independent parser in `verify_pdf.R` informs the design of `extract_pdf.R` (header-driven column assignment), but the pipeline version will be written and tested separately in Phase 1.

## 2026-10-27: Newest BBSR crosswalk checked

Decision: the crosswalk source for `pksR-data` is `ref-kreise-1990-2024.xlsx` (BBSR, sheets up to 2024-2025), with the 6 Mayen-Koblenz cells as `source = "manual"` rows in `registry/boundary_map.csv`.

Rationale: you asked for the newest table. Its 33 overlapping sheets are identical to the 2023 file, and it adds 2023-2024 and 2024-2025 without territorial change (audit section 6.5).

## 2026-10-27: Phase 1 decisions

1. Workspace layout: `pksR/pksR-data/` holds the pipeline repository; `notes/` moved there as in the brief's tree. The user-facing package will be a sibling folder in Phase 4. Raw files live in `data-raw/` (gitignored) and are reproducible from `registry/sources.csv`. Rationale: two repositories as in Section 4, one workspace for now.
2. Registry columns added to the Section 5.1 contract (for your review): `file_name` (local name, needed because 2019 to 2025 share one server file name), `pages` (PDF page range of the Kreis table), `boundary_year` (boundary the BKA published that year on). Rationale: URLs must not be templated, and page ranges and boundaries must be data, not code.
3. Schema column added to Section 5.2 (draft, pending Q1): `population`, the published population (PDF years: 1 January; 2020: EW 31.12.2019). PDF years keep `cases`, `cleared`, `suspects` and `derived_population` at NA. Rationale: the PDFs publish population, HZ and AQ only; counts derived from rounded HZ would be estimates (BUG-015).
4. `offence_key` is stored as printed in each year's header, with one exception: dash groups ("- - --", "----") become `------`. So 2003 to 2007 carry 4-digit keys (`2200`, `435*`), 2008 onward 6-digit keys. Linking them is the job of `registry/offence_map.csv` in Phase 2. Rationale: Section 5.2 says "as published", and the dash group is the only key whose printed form varies by layout, not by meaning.
5. `offence_label` is NA for PDF years: the tables print only keys; the labels appear in running text. Labels come from `offence_map.csv` in Phase 2.
6. PDF-era `region_name` carries spacing artefacts ("Neumün ster" in 2007) that are in the PDF text layer itself (poppler's text output shows them too). Names are informative; `ags` is the identifier.
7. Clearance rates above 100 and cleared cases above recorded cases are valid (cases cleared this year that were recorded in earlier years) and are not rejected.
8. The Excel tables contain more fields than the canonical schema keeps: attempts percent, firearm threatened and fired, suspects male and female, non-German suspects count and percent. They are not extracted yet. Question for you: add them to the schema? Non-German suspects may matter for your thesis.
9. The district set of every year is validated against the BBSR crosswalk at the year's `boundary_year`; all 23 years pass, which confirms the proposed boundary mapping (Proposed item 1 below).

## Proposed, awaiting your confirmation

1. Published boundary per PKS year (draft for `registry/sources.csv`, column `boundary_year`): 2003 to 2007: same year; 2008: 2007; 2009: 2008; 2010: 2010; 2011: 2010; 2012 to 2015: same year; 2016: 2015; 2017 to 2020: same year; 2021: 2020; 2022 to 2025: same year (no territorial change 2023 to 2025 per BBSR). Derived from district counts and the legacy rule; consistent with all district sets (audit section 4).
2. PDF years keep `cases = NA` and get derived counts only in a separately flagged form (question Q1).
3. `------` and `890000` are kept as separate series and never coalesced (question Q4).
4. The PDF bodily harm column is stored under the key printed in each year's header (`220000` until 2009, `222000` from 2010).
5. Default target boundary year 2025 (most recent in the crosswalk, territorially identical to 2023).

## 2026-10-27: Locale-independent code

Decision: R code in `pksR-data` contains only ASCII outside comments; non-ASCII characters in strings and regexes are written as `\u` escapes. A test in `tests/testthat/test-pipeline.R` enforces this.

Rationale: on the maintainer machine `LANG=en_DE.UTF-8` is not an installed locale, so R falls back to `C`, where the literal umlaut in the Excel header regex was invalid and 10 tests failed. Forced rebuild of all 23 years after the fix gave byte-identical Parquet files.

## 2026-10-27: Your answers to Q1, Q4, Q5 and the boundary proposal

1. Q1 (PDF counts): `cases` stays NA for 2003 to 2012. A separate column `cases_derived = hz * population / 1e5` is added to the canonical schema, rows carrying it have `estimated = TRUE`, and harmonization of PDF years uses it. Published `cases` and derived counts never share a column.
2. Q4 (total crime): two series. `------` (all offences) covers 2003 to 2025 unchanged. `890000` (all offences excluding offences against residence, asylum and free-movement law) is published 2015 to 2025; for 2014 it is computed as `------` minus `725000`. Evidence: the identity holds exactly in all 4,409 district rows 2015 to 2025. It cannot be computed before 2014 because `725000` is not in those tables. You first chose "coalesce"; I stopped because coalescing reproduces BUG-012, and you then chose this option.
3. Q5 (Mayen-Koblenz, Cochem-Zell 2014 to 2016): keep the legacy fix. Mayen-Koblenz maps to itself with weight 1, Cochem-Zell is renormalized to 1. The apparent 1.7 percent transfer is a roadmap item (Gemeinde-level check). Superseded 2026-10-28: there is no such transfer (see below).
4. Published boundary per year (Proposed item 1 above) and default target boundary 2025: confirmed.

## 2026-10-27: Phase 2 decisions (for your review)

1. `registry/boundary_map.csv` holds every BBSR row of the sheets 2003-2004 to 2024-2025 (`source = "bbsr"`, `status = "official"`, ids `bbsr-<period>-r<Excel row>`) plus manual rows (`source = "manual"`, `status = "draft"`) that each replace exactly one BBSR row (`replaces`). Original and replacement stay side by side, so every deviation from BBSR is visible. The pipeline checks that the BBSR rows still equal the BBSR file (`check_boundary_map_source()`). Rationale: brief Section 3, item 2, without hand-editing BBSR values.
2. Manual rows: 4 rows for Q5 (Mayen-Koblenz and Cochem-Zell 2014 and 2015, weights 1) and 1 row for a probable BBSR code typo in sheet 2011-2012 (BUG-034, `manual-2011-07231`). The second one is my interpretation and changes Bernkastel-Wittlich and Trier-Saarburg 2003 to 2011 by about 1 percent; please confirm or reject.
3. Weights are never renormalized. Weight sums must equal 1 within 1e-6 for both weightings after manual rows (BUG-017).
4. Harmonized schema (`harmonized_spec`): the canonical columns plus `offence_key_published`; `offence_key` is the harmonized key. Counts are double because population or area splits give fractional cases; rounding would break the conservation check.
5. Population is one value per district and year: the published population where it exists (PDF years, 2020), otherwise the derived population of the `------` row (most cases, least HZ rounding). It is harmonized once and joined to all offence rows (BUG-014). In the harmonized panel `derived_population` is therefore district-level, not row-level.
6. Rates: districts that are unchanged (one source, same code, weight 1) keep the published HZ and AQ. Changed districts get `hz = cases / population * 1e5` and `clearance_rate = cleared / cases * 100`, using derived counts in PDF years and the published population where available.
7. Flags: `harmonized = TRUE` for every changed district; `estimated = TRUE` when a target receives a fractional share of a source district, and for all PDF-year rows (derived counts, Q1); `weight_type` is `none` for unchanged districts, otherwise the weighting used. A missing value in any source district makes the target value missing (no undercount).
8. Region names: published name for unchanged districts, BBSR name at the target boundary for changed ones.
9. Target boundary: `target_boundary <- NULL` in `_targets.R` means the latest boundary covered by the crosswalk (2025); set an integer to change it. Both weightings are always built: `output/harmonized/<weights>/pks_kreis_panel.parquet` plus one `pks_kreis_<year>.csv.gz` per year.
10. Offence map grammar: `source_keys` entries `EXPR@YEARS`, EXPR a published key or `KEY minus KEY`. A published key without a mapping, or a mapped key missing in the data, stops the pipeline. The draft has 46 harmonized keys, one per published 6-digit key; 4-digit PDF keys 2003 to 2007 map to the 6-digit form. Keys that changed meaning (for example `621020` to `621100`) are not linked; candidates are listed in `registry/known_breaks.csv`.
11. `cleared_derived` added next to `cases_derived` (same logic as Q1), so AQ can be recomputed for harmonized PDF years.
12. Mid-year reforms (Section 6.1.6): the boundary each BKA table uses is `boundary_year` in `registry/sources.csv` (confirmed by you) and documented as BRK-013.
13. Validation check 7.4 (sum over districts equals the Bund table) is implemented but reported as `skipped`: no Bund source is registered yet. The Kreis tables contain no national total row. Superseded 2026-10-27: Bund tables 2013 to 2025 registered, check active (item 6 below).

## 2026-10-27: Your answers on the Phase 2 report

1. BUG-034 (code versus name). You asked to follow the code, not the name, but to verify it. Verification by area conservation (`notes/audit/bbsr_area_check.R`) falsifies the published code: the 10.1 km2 piece of Excel row 160 leaves 07231 (1,177.75 to 1,167.57 km2) and joins 07235 (1,091.36 to 1,101.47 km2), and the area weight reproduces the piece only with the area of 07231 (10.0 km2, against 0.09 km2 with 07235). Read as published, the row would double-count Trier-Saarburg and lose 10 km2 of Bernkastel-Wittlich. The manual row stays; its reason now cites the area evidence instead of the name.
2. The same check verifies Q5: the Cochem-Zell transfer is to 07140 Rhein-Hunsrueck-Kreis in 2013-2014 and is modelled correctly there; the weights in 2014-2015 and 2015-2016 are copies of it on rows without any area change. The legacy fix (weight 1) is therefore correct, not an approximation. My earlier hypothesis of a 1.7 percent transfer to Mayen-Koblenz was wrong.
3. The check also found transfers that BBSR does not model at all (BUG-035); not fixed, because the weights are unknown without Gemeinde-level data. Superseded 2026-10-28: fixed with the Destatis change lists (below).
4. Offence map ("apply what is correct"): every parent key was tested against the data (child cases never exceed parent cases, 0 violations in every district-year 2013 to 2025); two parents were added on that basis (`899500` within `674000`, `892500` within `892000`) and `980100` within `897000`. Approach for definition changes, following the brief's design (`offence_map.csv` links keys, `known_breaks.csv` and `pks_breaks()` document breaks): the same published key stays one harmonized series; every change of definition is a row in `known_breaks.csv` with a new column `comparable` (`yes`, `likely`, `no`, `unknown`) and the national series as evidence. Different published keys are never linked. Splitting a key into versions was rejected because it breaks the single-parent hierarchy (for example `515000` under a split `510000`).
5. New breaks found in the data: `*50*00` in 2012 (in/aus becomes an/aus; the 2012 yearbook prints (-), i.e. not comparable; +41.6 percent nationally), `730000` in 2024 (Cannabis Act, -34 percent), `980100` and `897000` in 2016 (series double or jump by 59 percent). Citation-only changes without a step (`435*00`, `436*00`, `212000`) are `likely` comparable.
6. Bund tables (7.4): the district sum is not equal to the Bund total, because cases with unknown place of offence are counted nationally but mostly not in a district. Bound checked for all 538 key-years 2013 to 2025: sum over districts <= Bund always holds; Bund minus the Tatortverteilung column "unbekannt" <= sum over districts holds in 532 key-years and misses by 1 to 17 cases in 6 (2019: `***100`, `***200`, `111000`; 2021: `***200`, `217000`, `630000`, largest 0.064 percent). The gate therefore uses the lower bound minus max(5 cases, 0.1 percent of the Bund value) and the exact upper bound (`national_slack()` in `R/national.R`). The 13 Bund tables are in `registry/bund_sources.csv`; every URL was taken from a link on the BKA year page (2016 to 2018 are named `STD-F-01-T01`, 2013 to 2015 `tb01_FaelleGrundtabelle`). PDF years 2003 to 2012 are not checked against the Bund: their district counts are derived from rounded HZ and came from a separate LKA query (2003 yearbook), so no bound can be stated.
7. Schema additions (`cases_derived`, `cleared_derived`, `offence_key_published`, double counts in the harmonized panel): accepted by you on 2026-10-27.

## 2026-10-28: Transfers missing in the BBSR crosswalk (BUG-035), fixed with Destatis

Decision: `registry/boundary_map.csv` gets a third row source, `destatis`, generated by `build_boundary_map()` from the 24 Destatis lists of municipal territorial changes 2003 to 2025 (`registry/destatis_sources.csv`, files in `data-raw/destatis/`). A transfer between districts becomes a row when BBSR has no row from the giving district to the district the receiving one belongs to at the end of the period; its population weight is the moved inhabitants divided by the giving district's BBSR population at the start of the period, the area weight likewise with area, and both are taken off the giving district's own row. The pipeline recomputes these rows from the Destatis files (`check_boundary_map_destatis()`), so they are data, not hand edits; status `draft` because the rule is mine.

Rationale and evidence:

1. Destatis lists 156 district-to-district transfers 2003 to 2025; BBSR implies 91 (including the MV case 13059 to 13062, where both districts go to 13075), 65 are missing. 58 of these move no inhabitants (boundary straightening, at most 0.7 percent of a district's area); 7 move people: 16064 to 16061 (3,881 inhabitants, 01.01.2023; 1,552, 01.01.2024), 16063 to 16064 (184, 01.01.2024), 08415 to 08425 (120, 2011), 06635 to 05958 (24, 2009), 12067 to 12053 (10, 2008), 14511 to 14521 (2, 2019).
2. The method reproduces BBSR where BBSR models a transfer: implied inhabitants 3,341 against Destatis 3,341 (15265, 2004), 2,094 against 2,094 (15151, 2005), 3,298 against 3,326 (16063, 2019).
3. Destatis confirms two earlier decisions independently: Trittenheim moved from 07231 to 07235 on 01.01.2012 (07/2012/0001-R, BUG-034), and Lahr, Moersdorf, Zilshausen from 07135 to 07140 on 01.07.2014 (07/2014/0003-R, Q5); Destatis has no transfer between 07135 and 07137.
4. Source quirks handled in code: Destatis gives area in hectares until the 2006 file and in square metres from 2007 (unit read from the header); the BBSR population column says "in 1.000" in sheet 2007-2008 but holds persons (scale decided by magnitude), and on the Saxon rows of that sheet it holds the new target district's population, so every denominator must agree with the neighbouring sheet within 10 percent (population) and 5 percent (area), otherwise the build stops.
5. Effect on the panel (population weights): 2,402 of 233,600 cells change. 16061 Eichsfeld gains about 5.5 percent population in 2003 to 2022, 16064 Unstrut-Hainich loses about 5.2 percent; all other changes are below 0.2 percent (`notes/legacy_vs_new.md`).

## 2026-10-28: Legacy code is reference only

Decision (yours): the legacy repository only gives ideas; what counts is that the new code is complete and correct. Bugs that cannot be located in the legacy code are closed when the new code demonstrably prevents them (code plus regression test). Applied to BUG-003, BUG-005 and BUG-010.

## 2026-10-28: End-to-end review of Phases 0 to 2

1. Clearance rate of zero cases (BUG-037), your decision: 0, the BKA convention, for every row with 0 cases in the harmonized panel, including recomputed districts, derived keys and the 2022 cells the BKA left empty. It is not a real rate (6 to 19 rows per year have cleared > 0 from cases of earlier years), so the panel Parquet file stores a note in its metadata (key `pksR_notes`, text in `panel_notes`, `R/extract.R`). Requirement for Phase 4: `pks_get()` prints every note in `pksR_notes` with `cli` when it loads the data. The canonical files keep the values as published.
2. Strict number parsing (BUG-036): text cells from spreadsheets go through `as_number()`, which aborts on anything that is not a number or empty, so a layout change cannot turn values into NA unnoticed.
3. Independent value check against the source files (brief Section 3.1.8): 195 cells (5 districts x 3 keys, 13 Excel years; cases, attempts, cleared, suspects, HZ) and 80 PDF district rows (8 per year, 10 PDF years; population plus 7 HZ and 7 AQ values each, 1,200 values) were compared with the raw files by code independent of the extractors. Observed error rate: 0.

## 2026-10-28: Phase 3, release mechanics

1. Raw files in CI: every run downloads all 61 registered files (23 Kreis tables, 13 Bund tables, 24 Destatis lists, the BBSR crosswalk) and compares their SHA-256 with the registries (`fetch_raw()`). A file with another hash never replaces the registered one: it is kept in `data-raw/_drift/`, the run stops and an issue is opened. The BBSR crosswalk got its own registry, `registry/reference_sources.csv`, so CI can fetch it; its hash equals the one recorded in the Phase 0 audit.
2. New years: `discover_new_years()` follows the links of the BKA PKS entry page (`pks_node.html`, which links the page of the latest year) and walks at most 40 pages of that year looking for a Kreis case table (`/<year>/Kreis/Faelle/` or `KR-F-<n>`). No URL is built from a template. A finding opens an issue with a draft registry row (URL, landing page, SHA-256, layout of the latest registered year) and the result of a trial extraction; the registry is never edited by CI, because a new year needs a layout check and a crosswalk sheet for its boundary. Registered files are also checked against their landing page: a link to the same file with another `?v=` is reported as republished.
3. Release assets: per weighting `pks_kreis_panel_<weights>.parquet`, `pks_kreis_<year>_<weights>.csv.gz` and `validation_<weights>.json`, plus `pks_kreis_published.parquet` (all years as published), the registries `sources.csv`, `boundary_map.csv`, `offence_map.csv`, `known_breaks.csv`, and `manifest.json`. The weighting suffix deviates from the file names in the brief's manifest example because asset names must be unique within a release. The Parquet files carry the data notes in their metadata (`pksR_notes`), and the manifest repeats them.
4. Manifest: the fields of brief Section 5.3 plus `weights`, `validation` (status per weighting), `notes` and `content_sha256`, a fingerprint of the data in each Parquet file. A scheduled run releases only when a fingerprint differs from the latest published release, so unchanged data never produce a new version.
5. Versions: `<year>.<n>` counted per calendar year, tag `v<version>`. Published releases are immutable: an existing tag aborts the upload, and every uploaded asset is compared with the local file by name and size.
6. Dry runs are draft prereleases tagged `test-<version>-run<n>`, visible only to the maintainer, so no data become public before the BKA terms of reuse are confirmed. Public releases need the repository variable `PUBLISH_ENABLED = true`, which only you set.
7. No piggyback (deviation from brief Section 4.1): piggyback 0.1.5 fails once the repository holds a draft release (`pb_releases()` reads `published_at`, which is null for drafts), does not report prereleases, and only warns when a release cannot be created. `R/github.R` talks to the GitHub release API with `httr2`, which the pipeline already uses.
8. Schedule: monthly on the 1st at 05:17 UTC and weekly on Mondays from March to May. Scheduled runs commit `status/last_check.json`; `keepalive.yml` re-enables the pipeline workflow weekly and commits a heartbeat only when the repository has been idle for 50 days.

## 2026-10-28: Private mirror of the raw files (your decision)

Decision: CI takes the raw files from a private mirror, the draft release `raw-mirror` of this repository (61 files, 132 MB), and checks every copy against the registered SHA-256. A file missing in the mirror is downloaded from its source URL and then added to the mirror. Republished files are detected from the landing pages of all four registries instead of downloading every file each month. `Rscript ci/mirror.R` uploads local files to the mirror after a new file is registered.

Rationale and evidence:

1. bka.de drops connections from GitHub runners at random: in run 40672047901 the first 5 requests failed (PKS 2003 to 2007), in run 40687986906 the first attempt stalled and the rerun fetched all 61 files, in run 40695396376 PKS 2015 to 2017 failed (timeouts, a TLS error), and in run 40706798700, with ten seconds between requests, almost every request failed until the job hit its 90 minute limit. The pace does not matter, so retrying or slowing down cannot make monthly downloads reliable. Circumventing the restriction (proxies, browser imitation) was ruled out.
2. A draft release is visible only to people with write access, so the BKA files are not redistributed publicly while the terms of reuse are open.
3. The registries remain the source of truth: a mirror copy with another hash is ignored, and the source URL decides.
4. Every request now has a total time limit including retries (5 minutes for files, 2 minutes for pages), and the landing page check gives up on a host after three unreachable pages in a row, so a dead host fails the run quickly with a report instead of holding it until the timeout. Unreachable pages are listed in `status/last_check.json`; only republished or unlinked files open an issue.
