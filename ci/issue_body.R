# Markdown body for the issue CI opens. Usage:
#   Rscript ci/issue_body.R failure|discovery > body.md
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
cat(out, sep = "\n")
