# Zenodo DOI of a published release.
#
# Zenodo archives every published release through its GitHub integration
# and mints the DOI only afterwards, so the manifest cannot hold it. The
# pipeline waits for the Zenodo record of the new tag and appends its DOI to
# the release notes, where pksR::pks_cite() reads it. Data, tag and
# manifest stay unchanged (notes/decisions.md, 2026-11-02).

# Record id of the concept DOI 10.5281/zenodo.23858428, which groups all
# versions archived from this repository
zenodo_concept_recid <- "23858428"

# DOI of the version archived from `tag`, or NULL when Zenodo has none yet.
# `records` is the parsed JSON of the Zenodo records search.
zenodo_version_doi <- function(records, tag) {
  hits <- records$hits$hits %||% list()
  version <- vapply(hits, function(h) h$metadata$version %||% NA_character_, "")
  doi <- vapply(hits, function(h) h$doi %||% NA_character_, "")
  found <- unique(doi[!is.na(version) & version == tag & !is.na(doi)])
  if (length(found) > 1) cli::cli_abort("Zenodo holds several records for {.val {tag}}: {.val {found}}.")
  if (length(found) == 0) NULL else found
}

# Newest versions first; anonymous requests get at most 25 records, and a
# new tag is always among the newest
zenodo_records <- function(concept_recid = zenodo_concept_recid) {
  httr2::request("https://zenodo.org/api/records") |>
    httr2::req_user_agent(pksr_user_agent) |>
    httr2::req_url_query(q = paste0("conceptrecid:", concept_recid), all_versions = "true", size = 25, sort = "mostrecent") |>
    httr2::req_retry(max_tries = 3) |>
    httr2::req_perform() |>
    httr2::resp_body_json()
}

# Polls Zenodo until the record of `tag` exists; archiving takes minutes.
zenodo_wait_for_doi <- function(tag, timeout = 1800, interval = 60, fetch = zenodo_records) {
  deadline <- Sys.time() + timeout
  repeat {
    doi <- zenodo_version_doi(fetch(), tag)
    if (!is.null(doi)) return(doi)
    if (Sys.time() + interval > deadline) {
      cli::cli_abort("Zenodo has no record for {.val {tag}} after {timeout} seconds.")
    }
    Sys.sleep(interval)
  }
}

# Release notes with a final line "DOI: <doi>". Unchanged when the line is
# there already; a different DOI is never replaced.
release_body_with_doi <- function(body, doi) {
  body <- body %||% ""
  old <- regmatches(body, regexpr("(?m)^DOI: \\S+$", body, perl = TRUE))
  if (length(old) == 1) {
    if (identical(old, paste("DOI:", doi))) return(body)
    cli::cli_abort("The release notes name another DOI ({.val {sub('^DOI: ', '', old)}}), not {.val {doi}}.")
  }
  paste0(sub("\\s+$", "", body), "\n\nDOI: ", doi, "\n")
}

github_release_by_tag <- function(repo, tag, token = github_token()) {
  resp <- github_request(sprintf("/repos/%s/releases/tags/%s", repo, utils::URLencode(tag, reserved = TRUE)), token) |>
    httr2::req_perform()
  httr2::resp_body_json(resp)
}

github_release_update_body <- function(repo, release_id, body, token = github_token()) {
  resp <- github_request(sprintf("/repos/%s/releases/%s", repo, format(release_id, scientific = FALSE)), token) |>
    httr2::req_method("PATCH") |>
    httr2::req_body_json(list(body = body)) |>
    httr2::req_perform()
  httr2::resp_body_json(resp)
}
