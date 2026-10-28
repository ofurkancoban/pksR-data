# Private mirror of the registered raw files: one draft release of this
# repository (tag "raw-mirror"), visible only to maintainers, so the BKA
# files are not redistributed publicly. It is the fallback, not the source:
# fetch_raw() asks the source first (bka.de through the Cloudflare Worker)
# and takes a mirror copy only when the source is unreachable, checked
# against the registered SHA-256 like every other copy.
#
# Why keep it: bka.de is not reliably reachable from GitHub runners, even
# through the Worker (HTTP 525 in 2 of 10 probes), and a file BKA removes or
# moves would otherwise make its year impossible to rebuild
# (notes/decisions.md).

mirror_tag <- "raw-mirror"

# Asset names are the path below data-raw/ with "/" as "__"
# ("bund/2013_tb01....xls" -> "bund__2013_tb01....xls").
mirror_asset_name <- function(path, raw_dir = "data-raw") {
  rel <- sub(paste0("^", gsub(".", "\\.", raw_dir, fixed = TRUE), "/"), "", path)
  gsub("/", "__", rel, fixed = TRUE)
}

# The mirror release (a draft), or NULL when there is none.
find_mirror <- function(repo) {
  r <- github_releases(repo)
  r <- r[r$tag_name == mirror_tag, ]
  if (nrow(r) == 0) return(NULL)
  if (nrow(r) > 1 || !r$draft) {
    cli::cli_abort("The raw-file mirror must be exactly one draft release tagged {.val {mirror_tag}}.")
  }
  r
}

ensure_mirror <- function(repo) {
  m <- find_mirror(repo)
  if (!is.null(m)) return(m)
  # Use the response: a new release can be missing from the list for a
  # moment after it was created.
  r <- github_release_create(
    repo, mirror_tag,
    body = "Private mirror of the raw files registered in registry/. Not a data release; never publish.",
    draft = TRUE, prerelease = FALSE
  )
  tibble::tibble(id = as.numeric(r$id), tag_name = r$tag_name, draft = isTRUE(r$draft), prerelease = isTRUE(r$prerelease), assets = list(list()))
}

# A function(name, dest) for fetch_raw(): TRUE when the mirror holds the
# asset and it was downloaded to `dest`.
mirror_fetcher <- function(repo) {
  m <- find_mirror(repo)
  if (is.null(m)) return(function(name, dest) FALSE)
  assets <- github_release_assets(repo, m$id)
  function(name, dest) {
    id <- assets$id[assets$name == name]
    if (length(id) != 1) return(FALSE)
    github_download_asset(repo, id, dest)
    TRUE
  }
}

# Uploads every local file of the inventory whose hash matches the registry
# and that the mirror lacks. Returns the names uploaded.
mirror_upload <- function(inventory, repo) {
  m <- ensure_mirror(repo)
  have <- github_release_assets(repo, m$id)$name
  ok <- file.exists(inventory$path)
  ok[ok] <- vapply(which(ok), function(i) identical(sha256_file(inventory$path[i]), inventory$sha256[i]), TRUE)
  todo <- inventory[ok & !inventory$mirror_name %in% have, ]
  for (i in seq_len(nrow(todo))) {
    tmp <- file.path(tempdir(), todo$mirror_name[i])
    file.copy(todo$path[i], tmp, overwrite = TRUE)
    github_upload_asset(repo, m$id, tmp)
    unlink(tmp)
  }
  invisible(todo$mirror_name)
}
