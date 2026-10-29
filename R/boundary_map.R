# registry/boundary_map.csv: the territorial crosswalk in long form.
#
# One row per (period, from district, to district) for every BBSR transition
# sheet "t-(t+1)" (boundary 31.12.t to 31.12.t+1). Rows with source "bbsr"
# reproduce the BBSR file cell for cell; rows with source "manual" replace a
# BBSR row (column `replaces`) and carry a reason; rows with source
# "destatis" add a transfer that BBSR omits (BUG-035, R/destatis.R), and
# their weights are taken off the giving district's own row. All rows stay
# in the file so every deviation from BBSR is visible (brief Section 3,
# item 2).

boundary_map_columns <- c(
  "id", "period", "from_ags", "from_name", "to_ags", "to_name",
  "weight_population", "weight_area", "source", "replaces", "status", "reason"
)

# Read one BBSR sheet. Columns are matched by their header text, and every
# expected column must match exactly once: the legacy code fell back to the
# first column when the weight header did not match (BUG-018).
read_bbsr_sheet <- function(path, period) {
  sheet <- paste0(period, "-", period + 1)
  if (!sheet %in% readxl::excel_sheets(path)) {
    cli::cli_abort("The crosswalk {.file {basename(path)}} has no sheet {.val {sheet}} (BUG-018).")
  }
  d <- suppressMessages(readxl::read_excel(path, sheet = sheet, col_types = "text"))
  header <- gsub("[[:space:]]+", " ", names(d))
  find <- function(pattern) {
    j <- which(grepl(pattern, header, ignore.case = TRUE))
    if (length(j) != 1) {
      cli::cli_abort("Sheet {.val {sheet}}: {length(j)} columns match {.val {pattern}}.")
    }
    d[[j]]
  }
  # Built as a list first: inside tibble() a later argument would see the
  # new `period` column instead of the scalar argument.
  cols <- list(
    id = sprintf("bbsr-%d-r%03d", period, seq_len(nrow(d)) + 1L),
    from_ags = find(paste0("^Kreise 31\\.12\\.", period, "$")),
    from_name = find(paste0("^Kreisname ", period, "$")),
    to_ags = find(paste0("^Kreise 31\\.12\\.", period + 1, "$")),
    to_name = find(paste0("^Kreisname ", period + 1, "$")),
    weight_population = as_number(find("^bev\u00f6lkerungs- ?proportionaler"), "population weight"),
    weight_area = as_number(find("^fl\u00e4chen- ?proportionaler"), "area weight")
  )
  out <- tibble::as_tibble(c(cols["id"], list(period = as.integer(period)), cols[-1]))
  empty <- is.na(out$from_ags) & is.na(out$to_ags)
  log_rows_removed(nrow(out), sum(!empty), paste("empty rows in sheet", sheet))
  out <- out[!empty, ]
  if (anyNA(out[c("from_ags", "to_ags", "weight_population", "weight_area")])) {
    cli::cli_abort("Sheet {.val {sheet}}: incomplete crosswalk rows.")
  }
  out$from_ags <- normalize_ags(out$from_ags)
  out$to_ags <- normalize_ags(out$to_ags)
  out$source <- "bbsr"
  out$replaces <- NA_character_
  out$status <- "official"
  out$reason <- NA_character_
  out[boundary_map_columns]
}

read_bbsr_crosswalk <- function(path, periods) {
  dplyr::bind_rows(lapply(periods, function(p) read_bbsr_sheet(path, p)))
}

# Regenerate the BBSR rows of boundary_map.csv from the BBSR file and keep the
# manual rows already in the file. Run by hand when the BBSR file changes.
build_boundary_map <- function(bbsr_path, map_path, periods, destatis_changes = NULL) {
  manual <- if (file.exists(map_path)) {
    m <- read_boundary_map_raw(map_path)
    m[m$source == "manual", ]
  } else {
    NULL
  }
  map <- dplyr::bind_rows(read_bbsr_crosswalk(bbsr_path, periods), manual)
  if (!is.null(destatis_changes)) {
    map <- dplyr::bind_rows(map, destatis_transfer_rows(
      destatis_changes, apply_manual_rows(map), bbsr_district_totals(bbsr_path, periods)
    ))
  }
  map <- map[order(map$period, match(map$source, c("bbsr", "manual", "destatis")), map$id), ]
  readr::write_csv(map, map_path, na = "")
  invisible(map)
}

read_boundary_map_raw <- function(path) {
  m <- readr::read_csv(path, col_types = readr::cols(.default = "c"), na = "")
  missing <- setdiff(boundary_map_columns, names(m))
  if (length(missing) > 0) {
    cli::cli_abort("{.file {path}} lacks columns {.val {missing}}")
  }
  m$period <- as.integer(m$period)
  m$weight_population <- as_number(m$weight_population, "weight_population")
  m$weight_area <- as_number(m$weight_area, "weight_area")
  m[boundary_map_columns]
}

read_boundary_map <- function(path) {
  m <- read_boundary_map_raw(path)
  if (anyDuplicated(m$id)) {
    cli::cli_abort("Duplicate ids in {.file {path}}.")
  }
  if (!all(m$source %in% c("bbsr", "manual", "destatis"))) {
    cli::cli_abort("Unknown source in {.file {path}}.")
  }
  manual <- m[m$source == "manual", ]
  if (anyNA(manual$reason) || anyNA(manual$replaces) ||
      !all(manual$status %in% c("draft", "reviewed"))) {
    cli::cli_abort("Manual rows need a reason, the replaced BBSR id and status draft or reviewed.")
  }
  if (!all(manual$replaces %in% m$id[m$source == "bbsr"]) || anyDuplicated(manual$replaces)) {
    cli::cli_abort("Every manual row must replace exactly one existing BBSR row.")
  }
  added <- m[m$source == "destatis", ]
  if (anyNA(added$reason) || !all(is.na(added$replaces)) || !all(added$status %in% c("draft", "reviewed"))) {
    cli::cli_abort("Destatis rows need a reason, no replaced id and status draft or reviewed.")
  }
  m
}

# The crosswalk actually used: BBSR rows with their manual replacements.
effective_boundary_map <- function(map) {
  out <- apply_destatis_rows(apply_manual_rows(map), map[map$source == "destatis", ])
  assert_boundary_map(out)
  out
}

apply_manual_rows <- function(map) {
  replaced <- map$id %in% map$replaces[map$source == "manual"]
  map[!replaced & map$source != "destatis", ]
}

# Each added transfer moves its share off the giving district's row to
# itself in the same period, so weight sums stay 1.
apply_destatis_rows <- function(map, added) {
  for (i in seq_len(nrow(added))) {
    own <- which(map$period == added$period[i] & map$from_ags == added$from_ags[i] & map$to_ags == added$from_ags[i])
    if (length(own) != 1) {
      cli::cli_abort("{added$id[i]}: the giving district has no own row to take the transfer from.")
    }
    map$weight_population[own] <- map$weight_population[own] - added$weight_population[i]
    map$weight_area[own] <- map$weight_area[own] - added$weight_area[i]
  }
  dplyr::bind_rows(map, added)
}

# Destatis rows in the registry must equal what the Destatis files imply.
check_boundary_map_destatis <- function(map, destatis_changes, bbsr_path) {
  periods <- sort(unique(map$period))
  fresh <- destatis_transfer_rows(destatis_changes, apply_manual_rows(map), bbsr_district_totals(bbsr_path, periods))
  stored <- map[map$source == "destatis", ]
  j <- dplyr::full_join(stored, fresh, by = "id", suffix = c("", ".file"))
  differs <- weights_differ(j)
  if (any(differs)) {
    cli::cli_abort("{sum(differs)} Destatis row{?s} in the registry differ from the Destatis files: {.val {head(j$id[differs])}}")
  }
  invisible(TRUE)
}

# Rows of a registry-versus-file join whose weights differ or exist on one
# side only (an NA weight counts as a difference).
weights_differ <- function(j) {
  differ <- function(a, b) is.na(a) | is.na(b) | abs(a - b) > 1e-12
  differ(j$weight_population, j$weight_population.file) | differ(j$weight_area, j$weight_area.file)
}

# Weights must sum to 1 per source district and period, and consecutive
# periods must chain: the districts at 31.12.(t+1) are the sources of
# period t+1. No renormalization (BUG-017): every deviation is a manual row.
assert_boundary_map <- function(map, tolerance = 1e-6) {
  for (w in c("weight_population", "weight_area")) {
    sums <- stats::aggregate(map[[w]], map[c("period", "from_ags")], sum)
    bad <- sums[abs(sums$x - 1) > tolerance, ]
    if (nrow(bad) > 0) {
      cli::cli_abort(c(
        "{w} does not sum to 1 for {nrow(bad)} source district{?s} (BUG-017).",
        "x" = "{.val {paste0(bad$period, ':', bad$from_ags, '=', signif(bad$x, 6))}}"
      ))
    }
  }
  if (any(map$weight_population < 0 | map$weight_area < 0)) {
    cli::cli_abort("Negative crosswalk weights.")
  }
  periods <- sort(unique(map$period))
  if (!identical(periods, seq(min(periods), max(periods)))) {
    cli::cli_abort("Crosswalk periods have gaps: {.val {setdiff(seq(min(periods), max(periods)), periods)}} (BUG-018).")
  }
  for (p in periods[-length(periods)]) {
    to <- sort(unique(map$to_ags[map$period == p]))
    from_next <- sort(unique(map$from_ags[map$period == p + 1]))
    if (!identical(to, from_next)) {
      cli::cli_abort("Crosswalk periods {p} and {p + 1} do not chain.")
    }
  }
  invisible(map)
}

# BBSR rows in the registry must equal the BBSR file, so a hand edit of a
# BBSR row (instead of a documented manual row) is caught.
check_boundary_map_source <- function(map, bbsr_path) {
  bbsr <- map[map$source == "bbsr", ]
  fresh <- read_bbsr_crosswalk(bbsr_path, sort(unique(bbsr$period)))
  key <- c("id", "period", "from_ags", "to_ags")
  joined <- dplyr::full_join(bbsr, fresh, by = key, suffix = c("", ".file"))
  differs <- weights_differ(joined)
  if (any(differs)) {
    cli::cli_abort("{sum(differs)} BBSR row{?s} in the registry differ from {.file {basename(bbsr_path)}}: {.val {head(joined$id[differs])}}")
  }
  invisible(TRUE)
}

# District codes valid on 31.12. of `year` according to the crosswalk.
boundary_codes <- function(map, year) {
  if (year %in% map$period) {
    return(sort(unique(map$from_ags[map$period == year])))
  }
  if ((year - 1) %in% map$period) {
    return(sort(unique(map$to_ags[map$period == year - 1])))
  }
  cli::cli_abort("The crosswalk does not cover {year}.")
}

boundary_names <- function(map, year) {
  rows <- if (year %in% map$period) {
    map[map$period == year, c("from_ags", "from_name")]
  } else {
    map[map$period == year - 1, c("to_ags", "to_name")]
  }
  names(rows) <- c("ags", "name")
  rows <- unique(rows)
  # Two spellings of one code would duplicate rows in every join on it.
  if (anyDuplicated(rows$ags)) {
    cli::cli_abort("Boundary {year}: codes with several names: {.val {unique(rows$ags[duplicated(rows$ags)])}}")
  }
  rows
}

# Moves boundary_map.csv to a new BBSR edition (ci/update_crosswalk.R).
# BBSR rows are regenerated for every period from the first registered one
# to the last sheet of the new file. Manual rows are kept, which is safe
# only while the BBSR row each one replaces still describes the same
# transition: BBSR ids are row positions, so a row inserted by BBSR would
# make a manual row replace the wrong one, and the update stops instead.
# Destatis rows are recomputed as drafts; a row already "reviewed" keeps
# that status when its weights did not change. Returns what changed.
update_boundary_map <- function(bbsr_path, map_path, destatis_changes) {
  old <- read_boundary_map_raw(map_path)
  sheets <- grep("^[0-9]{4}-[0-9]{4}$", readxl::excel_sheets(bbsr_path), value = TRUE)
  periods <- seq(min(old$period), max(as.integer(substr(sheets, 1, 4))))
  fresh <- read_bbsr_crosswalk(bbsr_path, periods)

  manual <- old[old$source == "manual", ]
  transition <- function(d) paste(d$period, d$from_ags, d$to_ags)
  before <- old[match(manual$replaces, old$id), ]
  after <- fresh[match(manual$replaces, fresh$id), ]
  moved <- manual$id[is.na(after$id) | transition(before) != transition(after)]
  if (length(moved) > 0) {
    cli::cli_abort(c(
      "{length(moved)} manual row{?s} replace a BBSR row that describes another transition in {.file {basename(bbsr_path)}}: {.val {moved}}.",
      "i" = "Point {.field replaces} at the new BBSR row by hand."
    ))
  }

  build_boundary_map(bbsr_path, map_path, periods, destatis_changes)
  new <- read_boundary_map_raw(map_path)
  signature <- function(d) paste(d$id, d$from_ags, d$to_ags, d$weight_population, d$weight_area)
  reviewed <- old[old$source == "destatis" & old$status == "reviewed", ]
  keep <- new$source == "destatis" & signature(new) %in% signature(reviewed)
  if (any(keep)) {
    new$status[keep] <- "reviewed"
    # Rewrite from the text, not from the parsed numbers: a double read and
    # written again can change in its last digit
    text <- readr::read_csv(map_path, col_types = readr::cols(.default = "c"), na = "", progress = FALSE)
    text$status[keep] <- "reviewed"
    readr::write_csv(text, map_path, na = "")
  }

  compare <- function(src) {
    o <- old[old$source == src, ]
    n <- new[new$source == src, ]
    changed <- n$id[n$id %in% o$id & !signature(n) %in% signature(o)]
    list(
      added = sum(!n$id %in% o$id), removed = sum(!o$id %in% n$id), changed = length(changed),
      changed_ids = utils::head(changed, 20)
    )
  }
  last_change <- if (nrow(destatis_changes)) max(destatis_changes$effective) else as.Date(NA)
  list(
    periods = range(periods),
    new_periods = setdiff(periods, old$period),
    previous_target_year = max(old$period) + 1L,
    target_year = max(periods) + 1L,
    target_districts = length(boundary_codes(effective_boundary_map(read_boundary_map(map_path)), max(periods) + 1L)),
    bbsr = compare("bbsr"), destatis = compare("destatis"),
    manual_rows_kept = nrow(manual),
    destatis_reviewed_kept = sum(keep),
    # Transfers BBSR omits can only be found for periods the Destatis lists
    # cover; period t holds the changes of year t + 1
    destatis_last_change = format(last_change),
    destatis_covers_new_periods = !is.na(last_change) && as.integer(format(last_change, "%Y")) >= max(periods) + 1L
  )
}

# Points the row `label` of reference_sources.csv at a new file.
update_reference_source <- function(path, label, url, sha256, file_name, retrieved_at = Sys.Date()) {
  ref <- readr::read_csv(path, col_types = readr::cols(.default = "c"), na = "")
  i <- which(ref$label == label)
  if (length(i) != 1) cli::cli_abort("{.file {path}} has no single row {.val {label}}.")
  ref$url[i] <- url
  ref$sha256[i] <- sha256
  ref$file_name[i] <- file_name
  ref$retrieved_at[i] <- format(as.Date(retrieved_at))
  readr::write_csv(ref, path, na = "")
  invisible(ref[i, ])
}
