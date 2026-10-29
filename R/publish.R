# Release files, manifest and upload (brief Sections 5.3 and 9).
#
# Assets of one data release:
#   pks_kreis_published.parquet          all years as published (canonical)
#   pks_kreis_<year>_published.csv.gz    the same, one file per year
#   pks_kreis_panel_<weights>.parquet    harmonized panel per weighting
#   pks_kreis_<year>_<weights>.csv.gz    the same, one file per year
#   validation_<weights>.json            validation gate report
#   sources.csv, bund_sources.csv, destatis_sources.csv,
#   reference_sources.csv, boundary_map.csv, offence_map.csv,
#   known_breaks.csv, population_inkar.csv,
#   inkar_sources.csv                    registries of this release
#   ATTRIBUTION.txt                      source notes and licences
#   manifest.json                        written last, describes all others
# Weightings get a suffix because asset names must be unique in a release.
# Published releases are never changed: a correction is a new version.

# Terms of the source data (notes/decisions.md, 2026-10-28):
#   BKA       PKS pages: Datenlizenz Deutschland, Namensnennung, Version 2.0;
#             source "PKS Bundeskriminalamt", reporting year, version
#   BBSR      Nutzungshinweise: the same licence; source "BBSR Bonn [Jahr]",
#             a link to www.bbsr.bund.de, and the kind and author of changes
#   Destatis  Impressum: copying and distribution with a source note
# The licence requires a note that the data were changed, so every release
# says what pksR-data changed and who made the changes.
data_license <- list(id = "dl-de/by-2-0", url = "https://www.govdata.de/dl-de/by-2-0")

pipeline_author <- "\u00d6mer Furkan \u00c7oban"
pipeline_url <- "https://github.com/ofurkancoban/pksR-data"

# One entry per source, built from the registries in `registry_dir` (the
# release copies of them, so the note matches the files of the release).
source_attributions <- function(registry_dir, years) {
  read <- function(f) readr::read_csv(file.path(registry_dir, f), col_types = readr::cols(.default = "c"), na = "")
  ref <- read("reference_sources.csv")
  des <- read("destatis_sources.csv")
  inkar <- read("inkar_sources.csv")
  bbsr_year <- substr(ref$retrieved_at[ref$label == "bbsr_ref_kreise"], 1, 4)
  inkar_year <- substr(inkar$retrieved_at, 1, 4)
  des_years <- range(as.integer(substr(des$label, 1, 4)))
  if (length(bbsr_year) != 1 || is.na(bbsr_year) || length(inkar_year) != 1 || is.na(inkar_year) || anyNA(des_years)) {
    cli::cli_abort("The registries in {.file {registry_dir}} lack the dates for the source notes.")
  }
  list(
    list(
      provider = "Bundeskriminalamt (BKA)",
      dataset = "Polizeiliche Kriminalstatistik (PKS), case tables for Kreise and for the Bund",
      license = data_license$id, license_url = data_license$url,
      source_note = sprintf("PKS Bundeskriminalamt, reporting years %d to %d, table versions in column pks_version of sources.csv and bund_sources.csv", min(years), max(years)),
      registry = c("sources.csv", "bund_sources.csv")
    ),
    list(
      provider = "Bundesinstitut f\u00fcr Bau-, Stadt- und Raumforschung (BBSR), https://www.bbsr.bund.de",
      dataset = "Umsteigeschl\u00fcssel f\u00fcr Kreise (ref-kreise)",
      license = data_license$id, license_url = data_license$url,
      source_note = paste("BBSR Bonn", bbsr_year),
      registry = "reference_sources.csv"
    ),
    list(
      provider = "Statistisches Bundesamt (Destatis)",
      dataset = "Gemeindeverzeichnis, Namens- und Gebiets\u00e4nderungen",
      license = "Copying and distribution with a source note (Destatis Impressum)",
      license_url = "https://www.destatis.de/DE/Service/Impressum/_inhalt.html",
      source_note = sprintf("Statistisches Bundesamt (Destatis), Gemeindeverzeichnis, %d to %d", des_years[1], des_years[2]),
      registry = "destatis_sources.csv"
    ),
    list(
      provider = "Bundesinstitut f\u00fcr Bau-, Stadt- und Raumforschung (BBSR), https://www.bbsr.bund.de",
      dataset = sprintf("INKAR, Kreise, years %s: Bev\u00f6lkerung gesamt and Bev\u00f6lkerung mit BBSR-Zensuskorrekturen", inkar$years),
      license = data_license$id, license_url = data_license$url,
      source_note = paste("INKAR, BBSR Bonn", inkar_year),
      registry = "inkar_sources.csv"
    )
  )
}

changes_note <- function() {
  paste0(
    "Changes: case counts extracted from the published BKA tables, district codes normalized, ",
    "counts harmonized to one boundary year (target_boundary_year in manifest.json) with BBSR weights ",
    "and documented corrections (boundary_map.csv), offence keys mapped (offence_map.csv), rates and ",
    "derived population recomputed, census-corrected population (INKAR) dated to the HZ reference date and moved to the boundary of each row. Changes made by ", pipeline_author, " with pksR-data (", pipeline_url, "). ",
    "These are not official figures of the BKA, the BBSR or Destatis."
  )
}

attribution_note <- function(attributions) {
  notes <- vapply(attributions, function(a) {
    sprintf("%s. Licence: %s (%s).", a$source_note, a$license, a$license_url)
  }, "")
  paste(c(paste("Sources:", paste(notes, collapse = " ")), changes_note()), collapse = " ")
}

# ATTRIBUTION.txt: the source notes for users of the CSV files, who may
# never read manifest.json.
write_attribution <- function(attributions, path) {
  block <- function(a) {
    c(a$provider,
      sprintf("  Dataset:     %s", a$dataset),
      sprintf("  Source note: %s", a$source_note),
      sprintf("  Licence:     %s <%s>", a$license, a$license_url),
      sprintf("  Source URLs: %s", paste(a$registry, collapse = ", ")), "")
  }
  lines <- c(
    "Attribution for this pksR-data release", "",
    unlist(lapply(attributions, block)),
    strwrap(changes_note(), width = 72)
  )
  writeLines(enc2utf8(lines), path, useBytes = TRUE)
  path
}

# Notes stored in the Parquet metadata (key "pksR_notes") and in the
# manifest; pksR::pks_get() prints them when it loads the data.
published_notes <- c(
  clearance_rate_zero_cases = paste(
    "As published: clearance_rate is 0 where cases are 0, except in 2022, where",
    "the BKA table leaves these cells empty (NA). It is not a real rate."
  )
)

write_parquet_with_notes <- function(data, path, notes) {
  table <- arrow::arrow_table(data)
  table$metadata$pksR_notes <- jsonlite::toJSON(as.list(notes), auto_unbox = TRUE)
  arrow::write_parquet(table, path)
  path
}

release_registry_files <- c(
  "sources.csv", "bund_sources.csv", "destatis_sources.csv", "reference_sources.csv",
  "boundary_map.csv", "offence_map.csv", "known_breaks.csv", "population_inkar.csv", "inkar_sources.csv"
)

# `panel_files` is the output of the panel_file target: per weighting the
# panel Parquet file, one CSV.gz per year and the validation report.
build_release_assets <- function(canonical_files, panel_files, registry_dir, dir) {
  if (dir.exists(dir)) unlink(dir, recursive = TRUE)
  ensure_dir(dir)
  published <- dplyr::bind_rows(lapply(sort(canonical_files), arrow::read_parquet))
  out <- write_parquet_with_notes(published, file.path(dir, "pks_kreis_published.parquet"), published_notes)
  # The same per year as CSV, so pksR reads the data as published
  # without depending on arrow
  for (d in split(published, published$year)) {
    path <- file.path(dir, sprintf("pks_kreis_%d_published.csv.gz", unique(d$year)))
    readr::write_csv(d[order(d$offence_key, d$ags), ], path, na = "")
    out <- c(out, path)
  }

  for (f in panel_files) {
    name <- basename(f)
    if (grepl("^report_(.+)\\.json$", name)) {
      target <- sub("^report_(.+)\\.json$", "validation_\\1.json", name)
    } else {
      w <- basename(dirname(f))
      target <- if (name == "pks_kreis_panel.parquet") {
        sprintf("pks_kreis_panel_%s.parquet", w)
      } else if (grepl("^pks_kreis_[0-9]{4}\\.csv\\.gz$", name)) {
        sub("\\.csv\\.gz$", sprintf("_%s.csv.gz", w), name)
      } else {
        cli::cli_abort("Unexpected panel output {.file {f}}.")
      }
    }
    dest <- file.path(dir, target)
    if (file.exists(dest)) cli::cli_abort("Two pipeline files map to the release asset {.file {target}}.")
    file.copy(f, dest)
    out <- c(out, dest)
  }
  for (f in release_registry_files) {
    dest <- file.path(dir, f)
    file.copy(file.path(registry_dir, f), dest)
    out <- c(out, dest)
  }
  attributions <- source_attributions(dir, range(published$year))
  c(out, write_attribution(attributions, file.path(dir, "ATTRIBUTION.txt")))
}

# "2026.1", "2026.2", ... from the existing release tags "v2026.1", ...
next_data_version <- function(tags, year = as.integer(format(Sys.Date(), "%Y"))) {
  m <- regmatches(tags, regexec("^v([0-9]{4})\\.([0-9]+)$", tags))
  m <- m[lengths(m) == 3]
  n <- as.integer(vapply(m, `[`, "", 3))[as.integer(vapply(m, `[`, "", 2)) == year]
  sprintf("%d.%d", year, if (length(n)) max(n) + 1L else 1L)
}

asset_rows <- function(path) {
  if (grepl("\\.parquet$", path)) return(arrow::read_parquet(path, as_data_frame = FALSE)$num_rows)
  if (grepl("\\.csv(\\.gz)?$", path)) return(nrow(readr::read_csv(path, col_types = readr::cols(.default = "c"), na = "", progress = FALSE)))
  NA_integer_
}

# Fingerprint of the data itself, independent of file encoding, so that a
# rerun without changes is recognized and not released again.
content_sha256 <- function(path) {
  digest::digest(as.data.frame(arrow::read_parquet(path)), algo = "sha256")
}

build_manifest <- function(dir, data_version, pipeline_commit, created_at = Sys.time()) {
  files <- sort(setdiff(list.files(dir), "manifest.json"))
  paths <- file.path(dir, files)
  reports <- lapply(file.path(dir, grep("^validation_.+\\.json$", files, value = TRUE)), jsonlite::read_json)
  names(reports) <- vapply(reports, function(r) unlist(r$weights)[1] %||% "unknown", "")
  status <- vapply(reports, function(r) {
    s <- vapply(r$checks, `[[`, "", "status")
    if (any(s == "fail")) "fail" else if (any(s == "warn")) "warn" else "pass"
  }, "")
  if (length(reports) == 0 || any(status == "fail")) {
    cli::cli_abort("No release without a passed validation gate for every weighting.")
  }
  targets_year <- unique(vapply(reports, function(r) as.integer(r$target_boundary_year), 1L))
  years <- range(unlist(lapply(reports, function(r) unlist(r$years))))
  attributions <- source_attributions(dir, years)
  panels <- grep("^pks_kreis_(panel_.+|published)\\.parquet$", files, value = TRUE)
  list(
    data_version = data_version,
    created_at = format(created_at, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    pipeline_commit = pipeline_commit,
    target_boundary_year = targets_year,
    years = as.integer(years),
    weights = names(reports),
    files = lapply(seq_along(files), function(i) {
      list(name = files[i], sha256 = sha256_file(paths[i]), bytes = file.size(paths[i]), rows = asset_rows(paths[i]))
    }),
    content_sha256 = stats::setNames(lapply(file.path(dir, panels), content_sha256), sub("\\.parquet$", "", panels)),
    validation = as.list(status),
    notes = list(published = as.list(published_notes), harmonized = as.list(panel_notes)),
    sources = "registry/sources.csv at pipeline_commit",
    license = data_license$id,
    license_url = data_license$url,
    attribution = attributions,
    license_note = attribution_note(attributions),
    zenodo_doi = NULL
  )
}

write_manifest <- function(manifest, dir) {
  path <- file.path(dir, "manifest.json")
  # na = "null": files without rows (JSON reports) must not get the string "NA"
  jsonlite::write_json(manifest, path, auto_unbox = TRUE, pretty = TRUE, null = "null", na = "null", digits = NA)
  path
}

# TRUE when the data differ from the release described by `previous`
# (a parsed manifest, or NULL when there is none).
data_changed <- function(manifest, previous) {
  if (is.null(previous)) return(TRUE)
  !identical(manifest$content_sha256[order(names(manifest$content_sha256))],
             previous$content_sha256[order(names(previous$content_sha256))])
}

# The release must point at the commit that built the data. The workflow
# token cannot create a release on a commit whose workflow files differ from
# the branch head (HTTP 403 "Resource not accessible by integration",
# diagnose run 40732185699), so a branch that moved during the run stops the
# release with a clear message instead.
assert_branch_unchanged <- function(repo, branch, commit, head = github_branch_head(repo, branch)) {
  if (!identical(head, commit)) {
    cli::cli_abort(c(
      "Branch {.val {branch}} moved during the run ({substr(commit, 1, 7)} to {substr(head, 1, 7)}); no release.",
      "i" = "Rerun the pipeline on the new commit."
    ))
  }
  invisible(TRUE)
}

# Creates the release and uploads every asset, manifest last, then checks
# that GitHub holds exactly these files with these sizes. An existing tag is
# never touched (published releases are immutable).
publish_release <- function(dir, repo, tag, body, draft = FALSE, prerelease = FALSE, commit = NULL) {
  if (tag %in% github_releases(repo)$tag_name) {
    cli::cli_abort("Release {.val {tag}} exists already in {repo}; published releases are immutable.")
  }
  files <- file.path(dir, c(sort(setdiff(list.files(dir), "manifest.json")), "manifest.json"))
  release <- github_release_create(repo, tag, body, draft = draft, prerelease = prerelease, commit = commit)
  for (f in files) github_upload_asset(repo, release$id, f)
  online <- github_release_assets(repo, release$id)
  local <- tibble::tibble(name = basename(files), size = file.size(files))
  check <- dplyr::full_join(local, online, by = "name", suffix = c("", "_online"))
  bad <- check[is.na(check$size) | is.na(check$size_online) | check$size != check$size_online, ]
  if (nrow(bad) > 0) {
    cli::cli_abort("Release {.val {tag}}: uploaded assets differ from the local files: {.val {bad$name}}")
  }
  cli::cli_inform("Release {.val {tag}} created with {nrow(online)} assets{if (draft) ' (draft)' else ''}.")
  invisible(release)
}

# Manifest of the latest published (not draft, not prerelease) data release
# "v<version>", or NULL when there is none.
latest_manifest <- function(repo) {
  r <- github_releases(repo)
  r <- r[!r$draft & !r$prerelease & grepl("^v[0-9]{4}\\.[0-9]+$", r$tag_name), ]
  if (nrow(r) == 0) return(NULL)
  r <- r[order(numeric_version(sub("^v", "", r$tag_name)), decreasing = TRUE), ][1, ]
  a <- r$assets[[1]]
  id <- vapply(a, function(x) as.numeric(x$id), 1)[vapply(a, function(x) x$name, "") == "manifest.json"]
  if (length(id) != 1) cli::cli_abort("Release {.val {r$tag_name}} has no manifest.json.")
  path <- github_download_asset(repo, id, tempfile(fileext = ".json"))
  jsonlite::read_json(path)
}
