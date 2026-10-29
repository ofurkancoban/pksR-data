# Legacy panel versus new panel

Date: 2026-10-27. Evidence script: `notes/audit/legacy_vs_new.R`.

Compared: the legacy harmonized tables `01_datasets/processed/PKS/02-harmonized/{year}_PKS_harmonized.csv` (commit `45525ea`, boundary 2023) with the new panel `output/harmonized/population/pks_kreis_panel.parquet` (population weights, boundary 2025). The 2023 and 2025 boundaries are territorially identical (audit section 6.5), so districts match one to one.

Matching: cells are matched on year, AGS and offence key. For 2010 to 2012 the legacy key `220000` is matched to the new `222000`, because the legacy label was wrong (BUG-011). A cell counts as changed when the relative difference exceeds 1e-6 or exactly one side is NA. For PDF years the new value is `cases_derived` (and `cleared_derived`), since the PDFs publish no counts.

## Coverage

| | cells |
|---|---|
| Matched (2003 to 2024) | 216,800 |
| Only in legacy | 0 |
| Only in new, 2003 to 2024 | 400 (`890000` in 2014, computed as `------` minus `725000`, decision Q4) |
| Only in new, 2025 | 16,400 (year not covered by the legacy pipeline) |

No district-year-key cell of the legacy output is lost.

## Changed cells

| Variable | Era | Cells | Changed | Size of change | Cause |
|---|---|---|---|---|---|
| cases, cleared | Excel 2013 to 2024 | 188,800 | 0 | below 5e-15 | none: spatial harmonization of counts reproduces the legacy result exactly, including all mergers and splits |
| cases | PDF 2003 to 2012 | 28,000 | 27,814 | median 0.025 percent, max 9.5 percent | legacy rounded the derived counts to whole numbers (95.5 percent of 2005 legacy counts are integers); new `cases_derived` is unrounded. Large relative changes occur only for small counts (BUG-015) |
| cleared | PDF 2003 to 2012 | 28,000 | 27,901 | max 8.6 percent | same rounding |
| population, hz, cases | PDF 2003 to 2011, `07231` and `07235` | 126 | 126 | `07231` minus 0.93 percent, `07235` plus 0.73 to 1.00 percent | BBSR 2011-2012 code typo, corrected by the reviewed manual row `manual-2011-07231` (BUG-034). Example 2011: Bernkastel-Wittlich population 111,073 becomes 110,035, Trier-Saarburg 141,646 becomes 142,684 |
| population, hz | merged or split districts, Excel years | 1,639 | 148 | 70 legacy cells (2013 to 2021) carry a population up to 98.9 percent too small, so their HZ is up to 93.8 times too large (22 cells more than 10 times, 36 more than 2 times) | BUG-014: legacy kept one population per offence row and dropped the NA population of zero-case rows when merging. Largest case: 2013, `07140` Rhein-Hunsrueck-Kreis, `892500`: population 1,089 instead of 102,091, HZ 3.15 instead of 0.034. Example: 2020, `16063` Wartburgkreis, `219000`: population 42,250 becomes 161,224, HZ 7.10 becomes 1.86 |
| population, hz | zero-case rows, all Excel years | 7,851 | 7,851 | NA becomes a value | legacy left HZ and population NA where cases are 0 (785 cells in 2023 alone); new keeps the published HZ of 0 and the district population |

Changed cells by year for HZ (Excel era, both causes above): 2013: 43, 2014: 583, 2015: 653, 2016: 640, 2017: 666, 2018: 716, 2019: 727, 2020: 757, 2021: 835, 2022: 803, 2023: 785, 2024: 791.

## What this means for the earlier paper

1. Excel-era counts used in the master panel are unchanged by the new pipeline. The panel-level problems are definitional and lie in the legacy merge step `12_`, not in harmonization:
   1. Total crime switches from `------` to `890000` in 2015 (BUG-012): national level 6.41 percent (2015) and 7.73 percent (2016) of all offences drop out of the series in the refugee-influx years. The new panel offers `------` for 2003 to 2025 and `890000` for 2014 to 2025.
   2. Bodily harm mixes three definitions (BUG-013). The new panel keeps `220000`, `222000` and `224000` separate.
2. HZ values from the legacy harmonized tables are wrong for 148 merged or split district cells (BUG-014). The master panel recomputed rates with INKAR population, so its 8 keys are not affected by this specific error.
3. PDF-era counts change only by rounding, except for Bernkastel-Wittlich and Trier-Saarburg 2003 to 2011 (about 1 percent, `manual-2011-07231`, reviewed 2026-10-29).

Not quantified here: the effect on the regression results of scripts `14_` to `30_`. That needs re-running your analysis on the new panel, which is outside `pksR-data`.

## Update 2026-10-28: transfers missing in BBSR (BUG-035)

The table above was computed before the Destatis transfers were added; the legacy panel lacks them too. Adding the 65 Destatis rows changes 2,402 of 233,600 cells of the new panel (population weights):

| District | Years | Population change | Note |
|---|---|---|---|
| `16061` Eichsfeld | 2003 to 2023 | +5.5 percent (2003 to 2022), less in 2023 | receives 3,881 (01.01.2023) and 1,552 (01.01.2024) inhabitants from `16064` |
| `16064` Unstrut-Hainich-Kreis | 2003 to 2023 | -5.2 percent | gives those, receives 184 from `16063` |
| `16063` Wartburgkreis | 2003 to 2023 | -0.12 percent | |
| `08425`, `08415`, `14521`, `14511`, `12053`, `12067`, `06635`, `05958` | various | below 0.2 percent | small transfers |

Example, 2020 total crime (`------`): Eichsfeld 4,737 becomes 5,082 cases (population 100,006 becomes 105,469), Unstrut-Hainich 6,465 becomes 6,129. For the legacy paper this affects only these districts; the direction is the same for all offence keys.

## Correction 2026-10-29: size of the BUG-014 error

The first version of the table above gave the legacy HZ as "up to 25.9 times too large". That figure was wrong: `notes/audit/legacy_vs_new.R` ranked cells by a relative difference whose denominator is floored at 1, which shrinks the error of cells with an HZ below 1, and most BUG-014 cells are rare offences with an HZ below 1. Measured on the legacy data alone (offence-row population against the district population of the same year), 70 cells are affected and the maximum factor per year is 93.8 (2013), 25.9 (2014, 2015), 26.0 (2016), 37.9 (2017), 38.0 (2018), 1.3 (2019) and 3.8 (2020, 2021), as in `notes/bug_register.md` (BUG-014). The script now ranks by the exact ratio and reports this measurement.

The effect of the Destatis transfers on cases is also larger in relative terms than their effect on population: total crime (`------`) in `16061` Eichsfeld rises by 6.4 to 8.7 percent in 2013 to 2022 (2013: 3,658 becomes 3,977 cases), because Eichsfeld has a lower crime rate than `16064`, from which the territory comes.
