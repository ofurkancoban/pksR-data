# Territorial transfers that the BBSR crosswalk omits (BUG-035), taken from
# the Destatis lists of municipal territorial changes (Gemeindeverzeichnis,
# Namens- und Gebietsaenderungen). Registry: registry/destatis_sources.csv.
#
# A transfer between two districts is missing when BBSR has no row from the
# giving district to the district the receiving one belongs to at the end of
# the period. Its weights are moved inhabitants (or area) divided by the
# giving district's population (or area) at the start of the period, both
# from the BBSR sheet itself, so numerator and denominator stay consistent
# with the BBSR rows. Where BBSR models a transfer, its implied inhabitants
# agree with Destatis (notes/decisions.md).

destatis_sources_columns <- c(
  "label", "covers", "url", "landing_page", "sha256", "retrieved_at", "file_name", "notes"
)

read_destatis_sources <- function(path) {
  s <- readr::read_csv(path, col_types = readr::cols(.default = "c"), na = "")
  if (!identical(names(s), destatis_sources_columns) || anyDuplicated(s$label) || anyNA(s$sha256)) {
    cli::cli_abort("{.file {path}} does not follow the destatis_sources layout.")
  }
  s
}

# The 13 columns sit at the same position in every file 2003 to 2025:
# 4 giving AGS, 5 name, 6 type of change, 7 area, 8 inhabitants,
# 10 receiving AGS, 11 name, 13 statistical effective date. The area unit
# changes: hectares until the 2006 file, square metres from 2007; it is read
# from the header of column 7.
read_destatis_changes <- function(path, sha256) {
  verify_sha256(path, sha256)
  sheet <- grep("^Gebiets", readxl::excel_sheets(path), value = TRUE)
  if (length(sheet) != 1) {
    cli::cli_abort("{.file {basename(path)}}: expected one data sheet.")
  }
  d <- suppressMessages(readxl::read_excel(path, sheet = sheet, col_names = FALSE, col_types = "text"))
  if (ncol(d) < 13) {
    cli::cli_abort("{.file {basename(path)}}: {ncol(d)} columns, expected 13 (layout drift).")
  }
  area_header <- tolower(paste(stats::na.omit(d[[7]][1:8]), collapse = " "))
  unit <- if (grepl("fl.che (in )?qm", area_header)) 1 else if (grepl("fl.che (in )?ha", area_header)) 1e4 else NA
  if (is.na(unit)) {
    cli::cli_abort("{.file {basename(path)}}: area unit not found in the header of column 7.")
  }
  # Municipality rows carry two 8-digit AGS; rows for associations of
  # municipalities (Gemeindeverband) have none and are not territory.
  is_gem <- grepl("^[0-9]{8}$", d[[4]]) & grepl("^[0-9]{8}$", d[[10]])
  log_rows_removed(nrow(d), sum(is_gem), paste("header, association and footnote rows in", basename(path)))
  d <- d[is_gem, ]
  # Some files (2006) carry stray numbers to the right of a few rows of the
  # table; they must stay outside the rows used here.
  if (ncol(d) > 13 && any(!is.na(as.matrix(d[substr(d[[4]], 1, 5) != substr(d[[10]], 1, 5), -(1:13)])))) {
    cli::cli_abort("{.file {basename(path)}}: values right of the table in transfer rows.")
  }
  date <- destatis_date(d[[13]])
  if (anyNA(date)) {
    cli::cli_abort("{.file {basename(path)}}: unreadable effective dates.")
  }
  tibble::tibble(
    kennziffer = d[[1]],
    from_gem = d[[4]], from_name = d[[5]], change_type = d[[6]],
    area_m2 = as_number(d[[7]], "Destatis area") * unit, inhabitants = as_number(d[[8]], "Destatis inhabitants"),
    to_gem = d[[10]], to_name = d[[11]], effective = date
  )
}

# Dates come as Excel serial numbers or as dd.mm.yyyy text.
destatis_date <- function(x) {
  serial <- grepl("^[0-9]+(\\.0+)?$", x)
  out <- rep(as.Date(NA), length(x))
  out[serial] <- as.Date(as.numeric(x[serial]), origin = "1899-12-30")
  out[!serial] <- as.Date(x[!serial], format = "%d.%m.%Y")
  out
}

# A change effective on day d belongs to the BBSR period t with
# 31.12.t < d <= 31.12.(t+1), i.e. t = year(d) - 1.
destatis_period <- function(date) as.integer(format(date, "%Y")) - 1L

# Population and area of each district at 31.12. of the period start, from
# the BBSR sheet. Rows hold either the pieces of a district or (2018-2019)
# repeat the district total on every row.
bbsr_district_totals <- function(path, periods) {
  dplyr::bind_rows(lapply(periods, function(t) {
    d <- suppressMessages(readxl::read_excel(path, sheet = paste0(t, "-", t + 1), col_types = "text"))
    h <- gsub("[[:space:]]+", " ", names(d))
    jp <- grep("^Bev.lkerung am", h)
    ja <- grep("^Fl.che am", h)
    if (length(jp) != 1 || length(ja) != 1) {
      cli::cli_abort("BBSR sheet {t}-{t + 1}: population or area column not found.")
    }
    # The unit in the header is unreliable (2007-2008 says "in 1.000" but
    # gives persons), so it is decided by magnitude: a median district
    # below 10,000 means thousands.
    scale <- if (stats::median(as_number(d[[jp]], "BBSR population"), na.rm = TRUE) < 1e4) 1000 else 1
    keep <- !is.na(d[[1]])
    x <- tibble::tibble(
      ags = normalize_ags(d[[1]][keep]),
      population = as_number(d[[jp]][keep], "BBSR population") * scale,
      area_km2 = as_number(d[[ja]][keep], "BBSR area")
    )
    totals <- dplyr::summarise(
      dplyr::group_by(x, ags),
      repeated = dplyr::n() > 1 && length(unique(population)) == 1 && length(unique(area_km2)) == 1,
      population = if (repeated) population[1] else sum(population),
      area_km2 = if (repeated) area_km2[1] else sum(area_km2),
      .groups = "drop"
    )
    totals$period <- as.integer(t)
    totals[c("period", "ags", "population", "area_km2")]
  }))
}

# Rows for boundary_map.csv (source "destatis") for every transfer that the
# BBSR rows do not imply. `bbsr_map` is the map after manual replacements.
destatis_transfer_rows <- function(changes, bbsr_map, totals) {
  x <- changes[substr(changes$from_gem, 1, 5) != substr(changes$to_gem, 1, 5), ]
  x$period <- destatis_period(x$effective)
  x <- x[x$period %in% bbsr_map$period, ]
  x$from_ags <- normalize_ags(substr(x$from_gem, 1, 5))
  x$to_district <- normalize_ags(substr(x$to_gem, 1, 5))

  # District the receiving one belongs to at the end of the period
  x$to_ags <- mapply(function(p, k) {
    t <- unique(bbsr_map$to_ags[bbsr_map$period == p & bbsr_map$from_ags == k])
    if (length(t) == 0) k else if (length(t) == 1) t else NA_character_
  }, x$period, x$to_district)
  if (anyNA(x$to_ags)) {
    cli::cli_abort("A Destatis transfer goes to a district that BBSR splits in the same period.")
  }
  implied <- paste(x$period, x$from_ags, x$to_ags) %in% paste(bbsr_map$period, bbsr_map$from_ags, bbsr_map$to_ags)
  x <- x[!implied, ]

  rows <- dplyr::summarise(
    dplyr::group_by(x, period, from_ags, to_ags),
    inhabitants = sum(inhabitants, na.rm = TRUE),
    area_km2 = sum(area_m2, na.rm = TRUE) / 1e6,
    kennziffer = paste(sort(unique(kennziffer)), collapse = ", "),
    municipalities = paste(sort(unique(from_name)), collapse = ", "),
    effective = paste(sort(unique(format(effective, "%d.%m.%Y"))), collapse = ", "),
    .groups = "drop"
  )
  check_denominators(rows, totals)
  totals <- dplyr::rename(totals, src_population = population, src_area_km2 = area_km2)
  rows <- join_checked(rows, totals, by = c("period", from_ags = "ags"), what = "Destatis transfers and BBSR district totals")
  names_from <- unique(bbsr_map[c("period", "from_ags", "from_name")])
  names_to <- unique(bbsr_map[c("period", "to_ags", "to_name")])
  rows <- join_checked(rows, names_from, by = c("period", "from_ags"), what = "Destatis transfers and source names")
  rows <- join_checked(rows, names_to, by = c("period", "to_ags"), what = "Destatis transfers and target names")
  tibble::tibble(
    id = sprintf("destatis-%d-%s-%s", rows$period, rows$from_ags, rows$to_ags),
    period = rows$period,
    from_ags = rows$from_ags, from_name = rows$from_name,
    to_ags = rows$to_ags, to_name = rows$to_name,
    weight_population = rows$inhabitants / rows$src_population,
    weight_area = rows$area_km2 / rows$src_area_km2,
    source = "destatis",
    replaces = NA_character_,
    status = "draft",
    reason = sprintf(
      "Transfer missing in BBSR (BUG-035). Destatis %s, effective %s: %s; %s inhabitants, %.4f km2 from %s to %s. Weights relative to the BBSR population (%s) and area (%.2f km2) of %s at 31.12.%d; the same amount is taken off the %s to %s row.",
      rows$kennziffer, rows$effective, rows$municipalities, trimws(format(rows$inhabitants, big.mark = ",")),
      rows$area_km2, rows$from_ags, rows$to_ags, trimws(format(round(rows$src_population), big.mark = ",", scientific = FALSE)),
      rows$src_area_km2, rows$from_ags, rows$period, rows$from_ags, rows$from_ags
    )
  )[boundary_map_columns]
}

read_destatis_all <- function(sources, dir) {
  dplyr::bind_rows(lapply(seq_len(nrow(sources)), function(i) {
    read_destatis_changes(file.path(dir, sources$file_name[i]), sources$sha256[i])
  }))
}

# The BBSR population column is not always the source population (sheet
# 2007-2008 gives the new target district's population on all Saxon rows).
# A denominator must therefore agree with the same district in the
# neighbouring sheet: within 10 percent for population, 5 percent for area.
check_denominators <- function(rows, totals) {
  key <- paste(totals$period, totals$ags)
  for (i in seq_len(nrow(rows))) {
    own <- totals[key == paste(rows$period[i], rows$from_ags[i]), ]
    ref <- totals[key %in% paste(rows$period[i] + c(-1L, 1L), rows$from_ags[i]), ]
    if (nrow(own) != 1 || nrow(ref) == 0) {
      cli::cli_abort("No BBSR totals to check the denominator of {rows$from_ags[i]} in {rows$period[i]}.")
    }
    pop_ok <- rows$inhabitants[i] == 0 || any(abs(own$population / ref$population - 1) < 0.10)
    area_ok <- any(abs(own$area_km2 / ref$area_km2 - 1) < 0.05)
    if (!pop_ok || !area_ok) {
      cli::cli_abort("Implausible BBSR denominator for {rows$from_ags[i]} in {rows$period[i]}: population {own$population}, area {own$area_km2}.")
    }
  }
  invisible(TRUE)
}
