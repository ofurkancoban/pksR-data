# Markdown body for the issue CI opens. Usage:
#   Rscript ci/issue_body.R failure|discovery|crosswalk|inkar > body.md
#   Rscript ci/issue_body.R crosswalk-commit|inkar-commit > message.txt
source("ci/common.R")

kind <- commandArgs(trailingOnly = TRUE)[1]
run <- sprintf("%s/%s/actions/runs/%s", Sys.getenv("GITHUB_SERVER_URL", "https://github.com"),
               Sys.getenv("GITHUB_REPOSITORY", "ofurkancoban/pksR-data"), Sys.getenv("GITHUB_RUN_ID", ""))
out <- c(sprintf("Run: %s", run), "")
# One line, no pipes, so a message cannot break a Markdown table cell
cell <- function(x) gsub("|", "/", gsub("[[:space:]]+", " ", x %||% ""), fixed = TRUE)
read_ci <- function(name) {
  f <- file.path(ci_dir, paste0(name, ".json"))
  if (file.exists(f)) jsonlite::read_json(f) else NULL
}

if (kind == "failure") {
  out <- c(out, "The pipeline stopped. No release was published.", "")
  fetch <- read_ci("fetch")
  if (!is.null(fetch)) {
    bad <- Filter(function(x) x$status %in% c("changed", "failed"), fetch)
    if (length(bad)) {
      out <- c(out, "## Raw files", "", "| registry | label | status | detail |", "|---|---|---|---|",
               vapply(bad, function(x) sprintf("| %s | %s | %s | %s |", x$registry, x$label, x$status, cell(x$message)), ""), "")
    }
  }
  for (f in list.files("output/validation", "^report_.+\\.json$", full.names = TRUE)) {
    r <- jsonlite::read_json(f)
    failed <- Filter(function(x) x$status == "fail", r$checks)
    if (length(failed)) {
      out <- c(out, sprintf("## Validation gate (%s)", basename(f)), "")
      for (x in failed) out <- c(out, sprintf("- **%s**: %s", x$check, paste(utils::head(unlist(x$problems), 10), collapse = "; ")))
      out <- c(out, "")
    }
  }
  out <- c(out, "Logs and reports are attached to the run as artifact `pipeline-reports`.")
}

if (kind == "discovery") {
  d <- read_ci("discover")
  if (length(d$new_years)) {
    out <- c(out, "## New reporting years on bka.de", "",
             "Add a row to `registry/sources.csv` after checking the layout. Draft values from the run:", "")
    for (y in d$new_years) {
      out <- c(out, sprintf("### %s", y$year %||% "?"), "", "```", jsonlite::toJSON(y, auto_unbox = TRUE, pretty = TRUE, null = "null", na = "null"), "```", "")
    }
  }
  if (length(d$landing_pages)) {
    out <- c(out, "## Registered files no longer linked as registered", "", "```",
             jsonlite::toJSON(d$landing_pages, auto_unbox = TRUE, pretty = TRUE, na = "null"), "```", "")
  }
}
# A newer BBSR crosswalk (crosswalk job): the same text serves the pull
# request and the issue. BUILD_OUTCOME and TESTS_OUTCOME are the outcomes of
# the trial steps, PR_URL the pull request if one could be opened.
if (kind %in% c("crosswalk", "crosswalk-commit")) {
  x <- read_ci("crosswalk")
  if (is.null(x)) stop("output/ci/crosswalk.json is missing")
  years <- if (length(x$new_periods)) paste(unlist(x$new_periods), collapse = ", ") else "none"
  facts <- c(
    sprintf("BBSR crosswalk %s replaces %s.", x$file, x$previous_file),
    sprintf("New periods: %s. Target boundary year %s -> %s with %s districts.",
            years, x$previous_target_year, x$target_year, x$target_districts),
    sprintf("BBSR rows: %s added, %s changed, %s removed. Destatis rows: %s added, %s changed, %s removed.",
            x$bbsr$added, x$bbsr$changed, x$bbsr$removed, x$destatis$added, x$destatis$changed, x$destatis$removed),
    sprintf("Manual rows kept: %s. Reviewed Destatis rows kept: %s.", x$manual_rows_kept, x$destatis_reviewed_kept)
  )
}
if (kind == "crosswalk-commit") {
  out <- c(sprintf("data(registry): update BBSR crosswalk to %s", sub("\\.xlsx$", "", x$file)), "",
           strwrap(paste(c(facts, "New Destatis rows are drafts and need review."), collapse = " "), width = 72))
}
if (kind == "crosswalk") {
  pr <- Sys.getenv("PR_URL")
  out <- c(out, "## New BBSR crosswalk edition", "",
           sprintf("Source: <%s> (SHA-256 `%s`).", x$url, x$sha256), "",
           paste("-", facts),
           sprintf("- Trial build: **%s**, tests: **%s**.", Sys.getenv("BUILD_OUTCOME", "not run"), Sys.getenv("TESTS_OUTCOME", "not run")),
           if (!isTRUE(x$destatis_covers_new_periods))
             sprintf("- The Destatis change lists end at %s: transfers BBSR omits cannot be checked for the new periods yet. Add the newer list to `registry/destatis_sources.csv`.", x$destatis_last_change),
           if (length(x$bbsr$changed_ids)) sprintf("- BBSR revised earlier rows: %s", paste(unlist(x$bbsr$changed_ids), collapse = ", ")),
           "",
           if (nzchar(pr)) sprintf("Pull request with the updated registry: %s", pr) else
             sprintf("The updated registry is on branch `%s`; open a pull request from it.", Sys.getenv("BRANCH")),
           "",
           "Before merging: review the new rows in `registry/boundary_map.csv` (new Destatis rows are drafts), add the decision to `notes/decisions.md`, and expect the next release to use the new target boundary year.")
}
# A changed INKAR snapshot (inkar job): the commit message doubles as the
# pull request body, the issue adds the trial outcomes and the link
if (kind %in% c("inkar", "inkar-commit")) {
  x <- read_ci("inkar")
  if (is.null(x)) stop("output/ci/inkar.json is missing")
  listed <- function(v) if (length(v)) paste(unlist(v), collapse = ", ") else "none"
  facts <- c(
    sprintf("INKAR population snapshot for 31.12.%s to 31.12.%s (SHA-256 %s, previously %s).",
            x$years[[1]], x$years[[2]], substr(x$sha256, 1, 12), substr(x$previous_sha256 %||% "none", 1, 12)),
    sprintf("Years added: %s. Years removed: %s. Rows added: %s, removed: %s.",
            listed(x$years_added), listed(x$years_removed), x$rows_added, x$rows_removed),
    sprintf("Rows revised: %s in years %s, largest change of the corrected population %.2f percent.",
            x$rows_changed, listed(x$years_changed), 100 * x$max_change_corrected)
  )
}
if (kind == "inkar-commit") {
  out <- c(sprintf("data(registry): update the inkar population snapshot to %s", max(unlist(x$years))), "",
           strwrap(paste(c(facts, "The snapshot sets population_corrected for every PKS year that divides by a population of these years."), collapse = " "), width = 72))
}
if (kind == "inkar") {
  pr <- Sys.getenv("PR_URL")
  out <- c(out, "## New INKAR population snapshot", "",
           paste("-", facts),
           sprintf("- Trial build: **%s**, tests: **%s**.", Sys.getenv("BUILD_OUTCOME", "not run"), Sys.getenv("TESTS_OUTCOME", "not run")),
           if (length(x$years_added)) "- A new year moves PKS years from the method `after` to `ratio` or `level` in `R/population.R`; check the method messages in the build log.",
           "",
           if (nzchar(pr)) sprintf("Pull request with the new snapshot: %s", pr) else
             sprintf("The new snapshot is on branch `%s`; open a pull request from it.", Sys.getenv("BRANCH")),
           "",
           "Before merging: check the revised years against the BBSR notes, add the decision to `notes/decisions.md`, and expect the next release to change `population_corrected` and the corrected rates.")
}
cat(out, sep = "\n")
