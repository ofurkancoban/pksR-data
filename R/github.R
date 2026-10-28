# Minimal GitHub release API client (create, list, upload, download).
#
# Used instead of piggyback (brief Section 4.1): piggyback 0.1.5 fails as
# soon as the repository holds a draft release (pb_releases() reads
# published_at, which is null for drafts), does not report prerelease, and
# only warns when a release cannot be created. Dry runs are drafts, so the
# pipeline needs all three (notes/decisions.md).

github_token <- function() {
  token <- Sys.getenv("GITHUB_TOKEN", Sys.getenv("GITHUB_PAT"))
  if (!nzchar(token)) cli::cli_abort("Set GITHUB_TOKEN (or GITHUB_PAT) to talk to the GitHub API.")
  token
}

github_request <- function(url, token = github_token()) {
  if (!grepl("^https://", url)) url <- paste0("https://api.github.com", url)
  httr2::request(url) |>
    httr2::req_user_agent(pksr_user_agent) |>
    httr2::req_auth_bearer_token(token) |>
    httr2::req_headers(Accept = "application/vnd.github+json", `X-GitHub-Api-Version` = "2022-11-28") |>
    httr2::req_retry(max_tries = 3)
}

# All releases including drafts (drafts are visible with push access).
github_releases <- function(repo, token = github_token()) {
  out <- list()
  page <- 1
  repeat {
    resp <- github_request(sprintf("/repos/%s/releases?per_page=100&page=%d", repo, page), token) |> httr2::req_perform()
    batch <- httr2::resp_body_json(resp)
    out <- c(out, batch)
    if (length(batch) < 100) break
    page <- page + 1
  }
  tibble::tibble(
    id = vapply(out, function(r) as.numeric(r$id), 1),
    tag_name = vapply(out, function(r) r$tag_name, ""),
    draft = vapply(out, function(r) isTRUE(r$draft), TRUE),
    prerelease = vapply(out, function(r) isTRUE(r$prerelease), TRUE),
    assets = lapply(out, function(r) r$assets)
  )
}

github_release_create <- function(repo, tag, body, draft, prerelease, commit = NULL, token = github_token()) {
  payload <- list(tag_name = tag, name = tag, body = body, draft = draft, prerelease = prerelease)
  if (!is.null(commit) && nzchar(commit)) payload$target_commitish <- commit
  resp <- github_request(sprintf("/repos/%s/releases", repo), token) |>
    httr2::req_body_json(payload) |>
    httr2::req_perform()
  httr2::resp_body_json(resp)
}

github_upload_asset <- function(repo, release_id, path, token = github_token()) {
  url <- sprintf("https://uploads.github.com/repos/%s/releases/%s/assets", repo, format(release_id, scientific = FALSE))
  resp <- github_request(url, token) |>
    httr2::req_url_query(name = basename(path)) |>
    httr2::req_body_file(path, type = "application/octet-stream") |>
    httr2::req_perform()
  httr2::resp_body_json(resp)
}

github_release_assets <- function(repo, release_id, token = github_token()) {
  resp <- github_request(sprintf("/repos/%s/releases/%s/assets?per_page=100", repo, format(release_id, scientific = FALSE)), token) |>
    httr2::req_perform()
  a <- httr2::resp_body_json(resp)
  tibble::tibble(
    id = vapply(a, function(x) as.numeric(x$id), 1),
    name = vapply(a, function(x) x$name, ""),
    size = vapply(a, function(x) as.numeric(x$size), 1)
  )
}

github_download_asset <- function(repo, asset_id, path, token = github_token()) {
  github_request(sprintf("/repos/%s/releases/assets/%s", repo, format(asset_id, scientific = FALSE)), token) |>
    httr2::req_headers(Accept = "application/octet-stream") |>
    httr2::req_perform(path = path)
  path
}
