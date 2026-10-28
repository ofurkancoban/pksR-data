# Look for reporting years that bka.de links but the registry lacks, and for
# registered files that their landing page no longer links. Findings are
# reported (step output "found") and turned into an issue; the registry is
# never edited here. A newer BBSR crosswalk is reported through the step
# outputs "crosswalk_url" and "crosswalk_end_year" for the crosswalk job.
# Network errors are reported, not fatal.
source("ci/common.R")

sources <- read_sources("registry/sources.csv")
new <- tryCatch(discover_new_years(sources$year), error = function(e) e)
# Ten minutes for all landing pages; the rest is marked "not checked"
landing <- tryCatch(check_landing_pages(raw_inventory(), budget = 600), error = function(e) e)
# A new BBSR crosswalk edition comes as a new file name; the crosswalk job
# of the workflow prepares the update on a branch (ci/update_crosswalk.R).
ref <- readr::read_csv("registry/reference_sources.csv", col_types = readr::cols(.default = "c"), na = "")
bbsr <- ref[ref$label == "bbsr_ref_kreise", ]
crosswalk <- tryCatch(newer_bbsr_crosswalk(bbsr$url, landing_page = bbsr$landing_page), error = function(e) e)
new_crosswalk <- !inherits(crosswalk, "error") && nrow(crosswalk) > 0
set_output("crosswalk_url", if (new_crosswalk) crosswalk$url else "")
set_output("crosswalk_end_year", if (new_crosswalk) crosswalk$end_year else "")

# Unreachable pages are recorded in the status file; only real changes are
# findings that open an issue. The old crosswalk no longer being linked is
# the crosswalk job's business, not a second issue.
changes <- if (inherits(landing, "error")) NULL else landing[landing$status %in% c("republished", "no longer linked"), ]
if (new_crosswalk && !is.null(changes)) changes <- changes[changes$registry != "reference_sources", ]

# For each candidate file: hash and a trial extraction with a draft row, so
# the issue shows whether the known layout still applies.
last <- sources[sources$year == max(sources$year), ]
trial <- function(year, url, landing_page) {
  if (is.na(url)) return(list(year = year, url = NA, note = "year page found, no Kreis case table linked yet"))
  tmp <- tempfile(fileext = ".xlsx")
  ok <- tryCatch({ download_file(url, tmp); TRUE }, error = function(e) conditionMessage(e))
  if (!isTRUE(ok)) return(list(year = year, url = url, note = paste("download failed:", ok)))
  row <- list(
    year = year, table_id = "KR-F-01-T01", format = tolower(tools::file_ext(sub("\\?.*$", "", url))),
    url = url, landing_page = landing_page, sha256 = sha256_file(tmp), parser = "extract_xls",
    file_name = paste0(year, "_", basename(sub("\\?.*$", "", url))), boundary_year = year,
    # Layout of the latest registered year: the trial tests whether it holds
    sheet = last$sheet, skip_rows = last$skip_rows,
    # Read it from the headline above the link on the landing page
    pks_version = NA
  )
  parsed <- tryCatch({
    d <- extract_xls(tmp, row)
    sprintf("extract_xls: %d rows, %d districts, %d offence keys", nrow(d), length(unique(d$ags)), length(unique(d$offence_key)))
  }, error = function(e) paste("extract_xls failed:", conditionMessage(e)))
  c(row, list(note = parsed))
}

result <- list(
  checked_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  registry_years = range(sources$year),
  new_years = if (inherits(new, "error")) list(error = conditionMessage(new)) else
    lapply(seq_len(nrow(new)), function(i) trial(new$year[i], new$url[i], new$landing_page[i])),
  bbsr_crosswalk = if (inherits(crosswalk, "error")) list(error = conditionMessage(crosswalk)) else
    list(registered = bbsr$file_name, newer = if (new_crosswalk) crosswalk else NULL),
  landing_pages = if (inherits(landing, "error")) list(error = conditionMessage(landing)) else changes,
  landing_pages_not_checked = if (inherits(landing, "error")) list() else landing[!landing$status %in% c("republished", "no longer linked"), ]
)
write_ci(result, "discover")
found <- (!inherits(new, "error") && nrow(new) > 0) || (!inherits(landing, "error") && nrow(changes) > 0)
set_output("found", tolower(as.character(found)))
cli::cli_inform("Discovery: {if (found) 'findings reported' else 'nothing new'}.")
