# status/last_check.json: committed on every scheduled run, so the
# repository stays active and GitHub keeps the schedule enabled (brief
# Section 9.3). Records what the run saw.
source("ci/common.R")

read_ci <- function(name) {
  f <- file.path(ci_dir, paste0(name, ".json"))
  if (file.exists(f)) jsonlite::read_json(f) else NULL
}
fetch <- read_ci("fetch")
status <- list(
  checked_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  run = Sys.getenv("GITHUB_RUN_ID", NA),
  outcome = Sys.getenv("PKSR_OUTCOME", "unknown"),
  raw_files = if (is.null(fetch)) NULL else as.list(table(vapply(fetch, `[[`, "", "status"))),
  discovery_findings = !is.null(read_ci("discover")) && (length(read_ci("discover")$new_years) > 0 || length(read_ci("discover")$landing_pages) > 0),
  landing_pages_not_checked = length(read_ci("discover")$landing_pages_not_checked),
  release = read_ci("release")
)
invisible(ensure_dir("status"))
jsonlite::write_json(status, "status/last_check.json", auto_unbox = TRUE, pretty = TRUE, null = "null", na = "null")
