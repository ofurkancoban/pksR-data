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

## 2026-10-28: Diagnosis of bka.de access from GitHub runners and of the release 403

1. bka.de from GitHub runners (workflow `diagnose.yml`, run 40728151217, runner 57.151.137.187, AS8075 Microsoft, US): DNS resolves `www.bka.de` to 80.245.152.130 in under a second every time. Five page requests all returned HTTP 200, but the TCP connection took 2.2 to 6.0 s and the first byte up to 20 s. Of five range requests for a PDF, two succeeded quickly, two never got a TCP connection (curl exit 28 after 30 s), and one was closed after a successful TLS handshake without an HTTP response (curl exit 56). destatis.de from the same runner: TCP 0.12 s, first byte 0.4 to 0.5 s, five of five. The same requests from the maintainer's connection never failed. Conclusion: bka.de's network edge slows down and drops traffic from Microsoft Azure addresses; whether by rule or under load is not known. DNS settings cannot change this, because the source address is what matters. This confirms the raw-file mirror.
2. A Cloudflare Worker (`ci/proxy/worker.js`) was prepared to compare access from Cloudflare's network. It forwards GET requests to www.bka.de only, behind a shared secret, and keeps the pipeline's User-Agent (Cloudflare also marks Worker requests with a CF-Worker header), so it does not hide who is asking. Methods that disguise the client (residential proxies, browser imitation) were ruled out. Not connected to the pipeline unless the comparison shows a clear gain.
3. The dry-run release failed twice with HTTP 403 "Resource not accessible by integration" although the job had Contents: write. Probes (diagnose run 40732185699) showed that the workflow token creates draft releases on the branch head, with or without `target_commitish`, but not on a commit whose workflow files differ from the branch head; that needs the `workflows` permission, which the workflow token cannot get. Both failed runs released on their own commit while newer commits changing workflow files had been pushed. Decision: the release keeps pointing at the commit that built the data; `ci/release.R` checks that the branch has not moved and otherwise stops with a message to rerun. Releasing on the branch head instead would attach the data to code that did not build it.

## 2026-10-28: Cloudflare Worker first, mirror as fallback (your decision)

Decision: raw files and pages are requested from their source on every run; requests to www.bka.de go through the Cloudflare Worker `bka-proxy` (`ci/proxy/worker.js`, secrets `BKA_PROXY_URL` and `BKA_PROXY_KEY`, read as `PKSR_PROXY_URL` and `PKSR_PROXY_KEY`); destatis.de and the BBSR are asked directly. The `raw-mirror` draft release is used only when a source is unreachable. Without the secrets the pipeline asks bka.de directly.

Rationale and evidence:

1. Worker probes (diagnose run 40739284733): 8 of 10 requests to bka.de succeeded, with the first byte after 0.24 to 0.66 s (one after 10.7 s); 2 returned HTTP 525 after 36 to 45 s (Cloudflare could not complete TLS with bka.de). Directly from the runner in the run before (40738490568 and 40736506738): 4 of 10, first byte after 7 to 27 s, the others without a TCP connection. The bodies were the real BKA page and PDF.
2. Asking the source every run gives a true drift check (every file's hash is compared with the registry), not only the landing page heuristic.
3. The mirror stays because the Worker path is not perfect (525) and because a file that BKA removes or moves could otherwise no longer be rebuilt. A mirror copy is never used to hide a changed source file: a different hash from the source stops the run.
4. Cloudflare's 520 to 526, 500, 502, 504 and 429 are now retried like connection failures (httr2 retries only 429 and 503 by default).
5. The Worker does not hide who is asking: it forwards only GET requests to www.bka.de, keeps the pipeline's User-Agent, and Cloudflare marks its requests with a CF-Worker header.

## 2026-10-28: Cut-off transfers are not drift

Finding: run 40740995930 reported 9 raw files as changed. Downloaded directly from the maintainer's connection, all 9 still have the registered hash, and curl through the Worker got whole correct files. The pipeline's own downloads through the Worker (diagnose run 40746772308) showed the cause: bka.de sometimes drops the connection mid-transfer, and the Worker streamed the answer without a length, so the client saw HTTP 200 and a complete-looking but truncated file (PKS 2011: 71,426 of 6,420,557 bytes; Bund 2022: 19,567 of 165,613; Bund 2025: 71,383 of 210,712).

Decisions:

1. A source file counts as changed only when two downloads agree on the same new hash; up to three downloads are made. Hashes that never agree count as an unreachable source, so the mirror copy is used and the run goes on.
2. The Worker reads the whole upstream body before answering, compares it with the declared length, answers HTTP 502 (retried) for an incomplete transfer and always sends the real Content-Length. This needs the new `ci/proxy/worker.js` deployed in Cloudflare.

## 2026-10-28: Terms of reuse of the source data

Checked on bka.de, bbsr.bund.de, destatis.de and govdata.de (brief Section 10.6).

1. BKA, PKS tables: the year pages of PKS 2012 to 2018 and the table overview pages of PKS 2019 to 2025 carry the same notice: "Die Nutzung der Daten (vollständig oder auszugsweise) ist nur mit Quellenangabe (PKS Bundeskriminalamt, Angabe des Berichtsjahres, Angabe der Version) zulässig. Es gilt die Datenlizenz Deutschland - Namensnennung - Version 2.0". PKS 2012 to 2015 ask only for the BKA and the version, without the reporting year. The English PCS pages say the same.
2. The general copyright notice in the BKA Impressum asks for written consent for any use beyond copyright law. The specific notice on the PKS pages applies to the data and takes precedence; the manifest and README rely on it.
3. BKA, PKS yearbooks 2003 to 2011: the page listing older editions has no licence notice. The PDFs say "Nachdruck und sonstige Vervielfältigung, auch auszugsweise, nur mit Quellenangabe des Bundeskriminalamtes" (2005 to 2012), and 2003 and 2004 add "und mit Genehmigung des Bundeskriminalamtes". Releases contain numbers extracted from these PDFs, not the PDFs. Numbers as facts are not protected by copyright, but a database right (§ 87a UrhG) may apply to the tables. Whether § 5 Abs. 2 UrhG (official works) covers the PKS is not settled. Decision of the user (2026-10-28): no request to the BKA for 2003 and 2004; the figures are published with the BKA named as source, like all other years.
4. BBSR Umsteigeschlüssel: Datenlizenz Deutschland, Namensnennung, Version 2.0, per the BBSR Nutzungshinweise. The source note is "BBSR Bonn [year]", with a note on the kind and author of changes. `boundary_map.csv` in a release is such a changed work.
5. Destatis Gemeindeverzeichnis: "Vervielfältigung und Verbreitung, auch auszugsweise, mit Quellennachweis gestattet" (Destatis Impressum).
6. dl-de/by-2-0 allows commercial and non-commercial use, copying, changing and combining with other data. It requires the provider's name, the licence name or "dl-de/by-2-0" with a link, a reference to the dataset, and a note when the data were changed.
7. Consequences:
   1. The manifest gets `license` and `license_url`, and `license_note` now names the PKS source, the years, the licence and the fact that the data were changed (`attribution_note()` in `R/publish.R`). The release body uses the same text.
   2. The private raw mirror (draft release) does not redistribute anything, so these terms do not restrict it. Making the raw files public would be allowed for the dl-de tables, but not without asking for the 2003 and 2004 PDFs.
   3. The BKA asks for the table version (for example "V1.0" on the PKS 2025 Kreis page). The registry does not record it yet. Proposal: add a `bka_version` column to `registry/sources.csv`, read from the landing pages.
   4. `pksR` (Phase 4): MIT for the code; `pks_cite()` and `inst/extdata` must carry the BKA source note and the dl-de/by-2-0 notice.
8. Attribution for all sources (user request, 2026-10-28): every release ships `ATTRIBUTION.txt` and a manifest field `attribution` with one entry per source (provider, dataset, source note, licence, registry with the source URLs). The registries `bund_sources.csv`, `destatis_sources.csv` and `reference_sources.csv` are now release assets, because dl-de/by-2-0 asks for a reference to the dataset. The change note names the kind of changes and their author, as the BBSR terms require, and states that the figures are not official. The BBSR year in "BBSR Bonn [Jahr]" is the retrieval year of the crosswalk in `reference_sources.csv`; the BBSR terms do not say which year is meant.

## 2026-10-28: Automatic update of the BBSR crosswalk (your request)

1. Checked on 2026-10-28: the BBSR page links `ref-kreise-1990-2024.xlsx` (`v=3`) as the newest Kreis crosswalk, the one registered. Its last sheet is `2024-2025`, so the target boundary is 2025 with 400 districts. The Destatis lists show no Kreis-boundary change in 2025; in 2024 there were three municipality transfers across Kreis lines (`16063` to `16064`, `16064` to `16061`, `12068` to `12065`).
2. Until now a new edition would have gone unnoticed, because the landing page check only compares registered files. Discovery now also looks for `ref-kreise-1990-<year>.xlsx` links with a later year (`newer_bbsr_crosswalk()`); the recalculation file `ref-kreise-umrech-*` is another product and is ignored.
3. You asked for the update to happen automatically. It does, up to a pull request: the crosswalk job downloads the new edition (two downloads must agree), points `reference_sources.csv` at it, regenerates `boundary_map.csv` (`update_boundary_map()`), runs a trial build and the tests, pushes a branch `auto/bbsr-<file>` and opens a pull request and an issue. It does not merge into `main`: the new rows are a territorial mapping (brief Section 2, rule 9) and would move the target boundary of the next release, so the merge is your review step.
4. Safeguards in `update_boundary_map()`:
   1. BBSR ids are row positions within a sheet. If BBSR inserts or moves rows in an earlier sheet, a manual row could end up replacing the wrong transition. The update then stops and names the manual rows to re-point by hand.
   2. Destatis rows are recomputed as drafts; a row you set to `reviewed` keeps that status as long as its weights are unchanged.
   3. The summary lists added, changed and removed rows per source, and warns when the Destatis lists do not yet cover the new period (transfers BBSR omits cannot be checked then).
5. The repository setting "Allow GitHub Actions to create and approve pull requests" is off (checked 2026-10-28). Until it is switched on, the job pushes the branch and the issue names it instead of linking a pull request.

## 2026-10-28: Table versions and remaining attribution decisions (your decisions)

1. Column name `pks_version` (your choice) in `sources.csv` and `bund_sources.csv`: the BKA asks for the version of the PKS table, and the name stays distinct from the release `data_version`.
2. Values read from the headline above each download link on bka.de (2026-10-28, 427 pages of PKS 2012 to 2025): `V1.0` for the Kreis and Bund tables of 2019 to 2025. The pages of 2012 to 2018 print no version next to the links, although the 2012 to 2015 notice asks for one; the 2003 to 2011 yearbooks have none; the 2013 Kreis xls is no longer linked (only its PDF). These rows stay empty (`NA`). A republished table with a new version also changes its hash, so the fetch step reports it.
3. "BBSR Bonn [Jahr]" uses the retrieval year of the crosswalk (2026), your decision.
4. Housekeeping: issues #1 to #6 (failed runs on 2026-10-28, all resolved) closed; the draft release `test-2026.1-run7` deleted (`test-2026.1-run9` kept); the 75-character subject of commit `74e1c83` stays, because fixing it would need a force push. The first scheduled run stays on 2026-11-01.

## 2026-10-28: Offence aliases and a bilingual pksR (your decisions)

1. `pks_get(offence_keys = "------")` was too awkward (your feedback). You chose both short aliases and search by label or key. The offence map gets two columns, `alias_en` and `alias_de`: one short ASCII name per key and language (umlauts written as ae, oe, ue, ss). pksR also accepts the umlaut spelling and spaces.
2. The aliases are drafts for your review, like the mappings (brief Section 2, rule 9). They only name keys; no key, mapping or value changes. Drafted from the BKA labels:

| key | English label | alias_en | alias_de |
|---|---|---|---|
| `------` | Total offences | `total` | `insgesamt` |
| `890000` | Total offences excluding offences against the Residence, Asy | `total_excl_immigration` | `insgesamt_ohne_auslaenderrecht` |
| `****00` | Theft, total | `theft` | `diebstahl` |
| `***100` | Theft of motor cars, total, incl. unauthorized use | `car_theft` | `kraftwagendiebstahl` |
| `***200` | Theft of mopeds and motorcycles, total, incl. unauthorized u | `motorcycle_theft` | `kraftrad_diebstahl` |
| `***300` | Theft of bicycles, total, incl. unauthorized use | `bicycle_theft` | `fahrraddiebstahl` |
| `*26*00` | Shoplifting, total | `shoplifting` | `ladendiebstahl` |
| `*50*00` | Theft of parts from and items out of motor vehicles, total | `theft_from_vehicles` | `diebstahl_an_aus_kfz` |
| `*90*00` | Pickpocketing, total | `pickpocketing` | `taschendiebstahl` |
| `3***00` | Theft without aggravating circumstances | `simple_theft` | `einfacher_diebstahl` |
| `326*00` | Simple shoplifting | `simple_shoplifting` | `einfacher_ladendiebstahl` |
| `4***00` | Theft under aggravating circumstances | `aggravated_theft` | `schwerer_diebstahl` |
| `435*00` | Residential burglary | `residential_burglary` | `wohnungseinbruch` |
| `436*00` | Daytime residential burglary | `daytime_residential_burglary` | `tageswohnungseinbruch` |
| `111000` | Rape, sexual coercion and sexual assault in especially serio | `rape_sexual_coercion` | `vergewaltigung_sexuelle_noetigung` |
| `210000` | Robbery, extortion by force or threat and assault on motoris | `robbery` | `raub` |
| `211000` | Robbery and extortion by force or threat against banks, post | `bank_post_office_robbery` | `raub_geldinstitute_post` |
| `212000` | Robbery and extortion by force or threat against other cash  | `shop_robbery` | `raub_kassenraeume` |
| `216000` | Handbag robbery | `handbag_robbery` | `handtaschenraub` |
| `217000` | Other robbery in streets, paths or squares | `other_street_robbery` | `sonstiger_strassenraub` |
| `219000` | Robbery in dwellings | `home_robbery` | `raub_wohnungen` |
| `220000` | Bodily harm | `bodily_harm` | `koerperverletzung` |
| `222000` | Dangerous and serious bodily harm, female genital mutilation | `dangerous_serious_bodily_harm` | `gefaehrliche_schwere_koerperverletzung` |
| `224000` | Intentional simple bodily harm | `simple_bodily_harm` | `einfache_koerperverletzung` |
| `510000` | Fraud | `fraud` | `betrug` |
| `515000` | Obtaining services by deception | `obtaining_services_by_deception` | `erschleichen_von_leistungen` |
| `515001` | Fare evasion | `fare_evasion` | `befoerderungserschleichung` |
| `530000` | Embezzlement | `embezzlement` | `unterschlagung` |
| `540000` | Forgery of documents | `forgery` | `urkundenfaelschung` |
| `621020` | Resistance against enforcement officers | `resistance_officers` | `widerstand_vollstreckungsbeamte` |
| `621021` | Resistance against police officers | `resistance_police` | `widerstand_polizei` |
| `621100` | Resistance against and assault on enforcement officers and p | `resistance_assault_officers` | `widerstand_angriff_vollstreckungsbeamte` |
| `621110` | Resistance against enforcement officers and persons of equal | `resistance_officers_equal_status` | `widerstand_vollstreckungsbeamte_gleichstehende` |
| `621120` | Assault on enforcement officers and persons of equal status | `assault_officers` | `angriff_vollstreckungsbeamte` |
| `630000` | Accessory after the fact, obstruction of prosecution or puni | `accessory_obstruction_handling_laundering` | `beguenstigung_strafvereitelung_hehlerei_geldwaesche` |
| `640000` | Arson and causing a risk of fire | `arson` | `brandstiftung` |
| `674000` | Criminal damage | `criminal_damage` | `sachbeschaedigung` |
| `725000` | Offences against the Residence Act, the Asylum Act and the E | `immigration_offences` | `auslaenderrechtliche_verstoesse` |
| `730000` | Drug offences (unless recorded under another key) | `drug_offences` | `rauschgiftdelikte` |
| `892000` | Violent crime | `violent_crime` | `gewaltkriminalitaet` |
| `892500` | Murder, manslaughter and killing on request | `murder_manslaughter` | `mord_totschlag` |
| `897000` | Cybercrime | `cybercrime` | `cybercrime` |
| `899000` | Street crime | `street_crime` | `strassenkriminalitaet` |
| `899500` | Criminal damage by graffiti, total | `graffiti` | `graffiti` |
| `972500` | Persons who entered or stayed without permission (keys 72510 | `unauthorized_entry_stay` | `unerlaubte_einreise_aufenthalt` |
| `980100` | Cybercrime in the narrow sense | `cybercrime_narrow` | `cybercrime_im_engeren_sinne` |

3. You decided that pksR is bilingual throughout: offence labels in the data, messages and errors, README and vignettes, and help pages. This replaces the brief's rule that documentation is in English only (Section 2, rule 1) for pksR; code, comments, commit messages and file names stay English.

## 2026-10-28: Clearer offence names after review

1. Principle (maintainer): short names and English labels must be clear and must not suggest a narrower or broader offence than the key covers. The German labels stay exactly as published by the BKA.
2. Short names changed (still `status = "draft"`): `630000` from `obstruction_of_justice` / `strafvereitelung` to `accessory_obstruction_handling_laundering` / `beguenstigung_strafvereitelung_hehlerei_geldwaesche` (the key covers four offences, not one); `621110` German name from `widerstand_gleichstehende_personen` to `widerstand_vollstreckungsbeamte_gleichstehende` (the officers were missing); `892500` from `homicide` / `toetungsdelikte` to `murder_manslaughter` / `mord_totschlag` (Toetungsdelikte usually also covers killings outside this key, such as negligent killing).
3. English labels changed: "robbery-like extortion" and "robbery-like assault on motorists" (keys `210000`, `211000`, `212000`) become "extortion by force or threat" and "assault on motorists with intent to rob" (sections 255 and 316a StGB); for `630000`, "obstruction of justice (excluding in office)" becomes "obstruction of prosecution or punishment (excluding by public officials)" (section 258 StGB, without 258a).
4. Checked for all 46 keys: no short name or label (normalized) belongs to more than one key, and every short name resolves to exactly its own key in `pksR::pks_get(offence = ...)`.
5. Second review, same principle, eight more short names changed (still draft): `435*00` `residential_burglary` and `436*00` `daytime_residential_burglary` (English burglary also covers commercial premises); `217000` `other_street_robbery` / `sonstiger_strassenraub` (handbag robbery 216000 is excluded); `222000` `dangerous_serious_bodily_harm` / `gefaehrliche_schwere_koerperverletzung` (the label names both); `111000` `rape_sexual_coercion` / `vergewaltigung_sexuelle_noetigung` (only especially serious cases, not all sexual assault); `***100` German `kraftwagendiebstahl` (Kfz includes motorcycles, which are ***200); `*50*00` German `diebstahl_an_aus_kfz` (parts from vehicles since 2012); `211000` `bank_post_office_robbery` / `raub_geldinstitute_post`.
6. Also checked in the second review: every child key is at most its parent in every district-year, valid_from and valid_to equal the years in the data, and every label_de equals the last published label apart from the removed trailing "und zwar:" or "davon:" and one double space.
7. Review completed by the maintainer on 2026-10-28: all 46 rows of `registry/offence_map.csv` (harmonized keys, labels, parent keys, source keys, validity years and short names) are set to `status = "reviewed"`. `registry/known_breaks.csv` is not part of this review and stays draft.

## 2026-10-29: Review of the known breaks (still draft)

All 17 rows of `registry/known_breaks.csv` were checked against the release data; they stay `status = draft` until the maintainer reviews them.

1. BRK-015 (Cannabis Act 2024) also affects the totals: 730000 drops by 116,105 cases from 2023 to 2024, while `------` drops by 83,287 and `890000` by 72,058. Without the law change both totals would have risen. `offence_key` now lists `730000;------;890000` and the evidence gives the national totals.
2. BRK-006 said "Your decision Q4"; it is shown to users by `pksR::pks_breaks()`, so it now says "as decided by the maintainer (question Q4 of the offence review)".
3. Checked without change: the national values in the evidence of BRK-003, BRK-007, BRK-008, BRK-009 and BRK-014 to BRK-017 match the district sums of the release; the 2015 and 2016 rise of 725000 (immigration offences, 155,850 in 2014, 486,631 in 2016) is a real change, not a recording break, and is already why 890000 exists.
4. Open for the maintainer: whether to add breaks without a published methodological change, such as the Covid years 2020 and 2021.

## 2026-10-29: Census-corrected population (BRK-004, BRK-005, BUG-026)

Decided with the maintainer: the release gets a census-corrected population, so rates can be compared over the census years 2011 and 2022.

1. Reference date: the HZ of PKS year t refers to the population of 31.12.(t - 1). Checked against INKAR: the population behind the HZ equals the INKAR population of the previous year in almost every district (median gap 0.0000 percent in 2004, 2010, 2013, 2019 and 2024; all 400 districts in 2024), while the same year is 0.3 to 0.4 percent off. This also explains the breaks: PKS 2013 is the first year with a Zensus 2011 population (31.12.2012), PKS 2024 the first with a Zensus 2022 population (31.12.2023).
2. Source: INKAR indicator bev_korr ("Bevölkerung mit BBSR-Zensuskorrekturen", M_ID 5) of the BBSR, Kreise 1995 to 2023. The BBSR spreads the gap found at Zensus 2011 and Zensus 2022 linearly over the years before (back to 1990), so the series has no census break: national growth 2010 to 2011 is +0.03 percent instead of -1.74 percent. The gap reaches about 8 percent in single districts (Landshut -8.3 percent, Saarlouis +4.7 percent in 2021). The correction is an estimate of the BBSR, not an official revision; the official back-calculation of the statistical offices covers only 2012 to 2021 (Zensus 2022 base) and, for Zensus 2011, the Länder.
3. Snapshot: the INKAR interface answers POST requests with JSON, so the data cannot be a raw file with URL and hash like the BKA tables. `ci/fetch_inkar.R` (inkaR, two downloads must agree) writes `registry/population_inkar.csv` (xbev and bev_korr, 31.12.2002 to 31.12.2023) and `registry/inkar_sources.csv` (indicators, retrieval date, SHA-256, checked by a test). Both ship with every release.
4. Boundary: INKAR gives each year on the current district codes, with dissolved districts folded into their successors in all years, but small municipal transfers stay in their year (16064 loses 4 percent from 2022 to 2023). INKAR values are therefore never copied by code into another territory. `R/population.R` links each published district to its successors on the INKAR codes (crosswalk to the first boundary from the published one on whose codes are the INKAR codes) and multiplies its PKS population by a factor of those successors:
   - ratio (same census base, PKS 2003 to 2011, 2013 to 2022, 2024): INKAR corrected over INKAR uncorrected population. A factor is robust to the territory.
   - level (other census base: PKS 2012 divides by the population of 31.12.2011 before Zensus 2011, PKS 2023 by the Zensus 2011 population of 31.12.2022; INKAR has both on the newer base): the INKAR corrected value over the PKS population of all districts that make it up, so predecessors share it.
   - after (PKS 2025, 31.12.2024 is not in INKAR yet): the population behind the HZ, which is on the Zensus 2022 base; allowed only because corrected and uncorrected INKAR population agree in the last INKAR year. Refresh the snapshot when INKAR adds 2024.
   The method is chosen from the data: same base when at least 90 percent of the districts with an INKAR code agree within 0.1 percent.
5. Harmonization moves `population_corrected` with the crosswalk weights like the counts; conservation covers it, and the validation gate requires it for every district-year, within 15 percent of the population behind the HZ.
6. Counts and published rates are unchanged. `pksR::pks_rates(population = "corrected")` recomputes the rates with the new column.

## 2026-10-29: Automatic INKAR snapshot updates

1. The pipeline workflow gets a third job, `inkar`, that runs `ci/fetch_inkar.R` on every scheduled and manual run, independent of bka.de.
2. An unchanged snapshot (same SHA-256 as `registry/inkar_sources.csv`) is not rewritten, so the retrieval date does not move and a scheduled run leaves no diff.
3. A changed snapshot is never committed to `main` by CI: like a new BBSR crosswalk, it goes to a branch `auto/inkar-<last year>-<hash>` with a trial build, the tests, a pull request and an issue. Reason: the BBSR spreads each census gap back over earlier years, so a new INKAR year can revise `population_corrected` of earlier PKS years, and that is a data change the maintainer should see before it reaches a release.
4. `inkar_snapshot_diff()` reports added and removed years, added, removed and revised rows (relative change above 1e-9 in either population column) and the largest relative change of the corrected population, so the pull request shows how far back a revision reaches.

## 2026-10-29: Review of the uncertain known breaks

Decided by the maintainer on the evidence of the Bund tables (tb01 Grundtabelle) and the national district sums.

1. BRK-017 (897000, step of 59 percent in 2016) is merged into BRK-016: 897000 rises by 30,965 cases from 2015 to 2016 and its child 980100 by 30,134, and 897000 without 980100 stays between 21,852 and 24,906 from 2014 to 2020. BRK-016 now lists `980100;897000`. The id BRK-017 is retired and not reused.
2. BRK-011 (892500, killing on request added to the label in 2016): `type = notation`, `comparable = yes`. In every Bund table from 2013, 892500 equals 010000 plus 020000, and 020000 includes para. 216 StGB; the rise in 2016 is in murder and manslaughter.
3. BRK-010 (510000, paras. 265c to 265e StGB added in 2018): `comparable = yes`. The new offences (518500) have 3 cases nationally in 2018 and 5 in 2019.
4. BRK-008 (residential burglary, cited paragraphs 2016 and 2018) stays `likely`: no sub-key isolates para. 244 Abs. 4 StGB.
5. BRK-008, BRK-010, BRK-011 and BRK-016 are `reviewed`. BRK-012 stays draft with the sources found: the Bavarian LKA (Lagebild Cybercrime Bayern 2021, p. 7) states that 897000 was renamed with effect from 1 January 2021 and no longer includes software piracy, so it is not directly comparable; in the 2020 Bund table software piracy (715100, 715200) is 134 of 130,611 cases (0.10 percent). The BKA change log for 2021 (pks2021Aenderungsnachweis.pdf) could not be retrieved (bka.de unreachable from this machine).

## 2026-10-29: Research on the remaining known breaks

Evidence checked for BRK-001 to BRK-015 against the district outputs, the Bund tables, the PDF yearbooks in `data-raw/` and secondary sources (bka.de was unreachable). Texts updated where the check added facts or found an error; `comparable` and `status` unchanged pending the maintainer.

1. BRK-003: counts derived from integer HZ reproduce national totals: derived district sums 2012 fall short of the yearbook totals by the same share as published district sums 2013 (unknown place), within 0.05 percentage points for six keys. Small cells are noisy (median error 7.3 percent below 10 cases, simulated on 2013 to 2025).
2. BRK-007: the 2017 label covers para. 177 Abs. 1 to 4 and 6 to 9, not Abs. 1 to 9; corrected.
3. BRK-015: the Bund table 2024 shows 730000 as the sum of 731000 to 737000, including the new keys 736000 (KCanG) and 737000 (MedCanG).
4. Verified without change: BRK-001 (seven 4-digit keys become the same keys with 00 in 2008), BRK-002 (PDF headers 220000 until 2009, 222000 from 2010; 2013 values), BRK-006 (identity exact in 4,409 rows), BRK-013 (published boundary per year matches the reform dates), BRK-014 (yearbook 2012 prints 343,460 with (-)).
5. Review completed by the maintainer on 2026-10-29: all 16 rows of `registry/known_breaks.csv` are `reviewed` (5 `yes`, 3 `likely`, 8 `no`). BRK-012 is `likely`. Open: whether breaks without a published methodological change (Covid 2020 and 2021) are added.
