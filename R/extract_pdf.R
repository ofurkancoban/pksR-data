# Extraction of the district tables in the PKS yearbooks 2003 to 2012.
#
# The tables publish, per district: population on 1 January, and HZ and AQ
# for seven offence groups. They publish no case counts, so `cases` and
# `cleared` stay NA (BUG-015); counts derived from the rounded HZ and AQ go
# into `cases_derived` and `cleared_derived` with `estimated = TRUE` (Q1).
# Offence keys are read from each year's header
# row instead of a fixed list, because the second group changes from 220000
# to 222000 in 2010 (BUG-011).

extract_pdf <- function(path, source) {
  pages <- parse_pages(source$pages)
  words <- pdftools::pdf_data(path)
  if (max(pages) > length(words)) {
    cli::cli_abort("{.file {basename(path)}} has {length(words)} pages, registry expects {source$pages}")
  }
  rows <- lapply(pages, function(p) parse_pdf_page(words[[p]], page = p))
  wide <- do.call(rbind, rows)

  keys <- unique(lapply(rows, attr, "offence_keys"))
  if (length(keys) != 1) {
    cli::cli_abort("Offence keys differ between pages of {.file {basename(path)}}")
  }
  pdf_to_canonical(wide, keys[[1]], source)
}

# Words of one table line: y positions within 2 points belong together.
cluster_lines <- function(y) {
  ys <- sort(unique(y))
  breaks <- c(TRUE, diff(ys) > 2)
  line_of_y <- cumsum(breaks)
  line_of_y[match(y, ys)]
}

# Glue word fragments that pdftools splits inside numbers (2007 to 2009
# write "03452" as "0345" + "2", 2003 writes "1 728 806" as three words).
# "-" (no value) is never glued to a neighbour.
merge_number_fragments <- function(w) {
  w <- w[order(w$x), ]
  out <- w[0, ]
  for (i in seq_len(nrow(w))) {
    n <- nrow(out)
    glue <- n > 0 &&
      w$x[i] - (out$x[n] + out$width[n]) < 4 &&
      grepl("^[0-9.,]+$", out$text[n]) && grepl("^[0-9.,]+$", w$text[i])
    if (glue) {
      out$text[n] <- paste0(out$text[n], w$text[i])
      out$width[n] <- w$x[i] + w$width[i] - out$x[n]
    } else {
      out <- rbind(out, w[i, ])
    }
  }
  out
}

# District names: fragments closer than 1.5 points are one word. The PDF text
# layer itself splits some names ("Neumün ster" in 2007, also in poppler's own
# text output), so PDF-era names carry spacing artefacts; `ags` is the
# identifier, names are informative only (see notes/decisions.md).
join_name_words <- function(w) {
  w <- w[order(w$x), ]
  if (nrow(w) == 0) {
    return(NA_character_)
  }
  gap <- w$x[-1] - (w$x[-nrow(w)] + w$width[-nrow(w)])
  paste0(w$text, c(ifelse(gap < 1.5, "", " "), ""), collapse = "")
}

normalize_pdf_key <- function(key) {
  if (grepl("^-+$", key)) "------" else key
}

parse_pdf_header <- function(w) {
  hz <- w[w$text %in% c("HZ", "AQ"), ]
  hz$line <- cluster_lines(hz$y)
  counts <- table(hz$line)
  if (length(counts) == 0 || max(counts) != 14) {
    cli::cli_abort("No header row with 14 HZ/AQ columns.")
  }
  head_row <- hz[hz$line == as.integer(names(which.max(counts))), ]
  head_row <- head_row[order(head_row$x), ]
  if (!identical(head_row$text, rep(c("HZ", "AQ"), 7))) {
    cli::cli_abort("Header row is not 7 HZ/AQ pairs.")
  }
  centers <- head_row$x + head_row$width / 2
  hy <- min(head_row$y)

  # Key line: the line just above the HZ/AQ row that holds the dash group of
  # "Straftaten insgesamt"; other lines there carry the reporting period.
  near <- w[w$y >= hy - 16 & w$y <= hy - 3 & w$x >= centers[1] - 15, ]
  near$line <- cluster_lines(near$y)
  dash_lines <- unique(near$line[grepl("^-+$", near$text)])
  if (length(dash_lines) != 1) {
    cli::cli_abort("Cannot find the offence key line above the HZ/AQ row.")
  }
  key_words <- near[near$line == dash_lines, ]
  dashes <- grepl("^-+$", key_words$text)
  coded <- key_words[!dashes, ]
  col <- vapply(coded$x + coded$width / 2, function(cx) which.min(abs(centers - cx)), integer(1))
  if (!any(dashes) || !identical(sort(col), 3:14)) {
    cli::cli_abort("Cannot read the offence keys above the HZ/AQ row.")
  }
  key_by_col <- coded$text[order(col)]
  if (!identical(key_by_col[c(TRUE, FALSE)], key_by_col[c(FALSE, TRUE)])) {
    cli::cli_abort("HZ and AQ columns carry different offence keys.")
  }
  list(
    centers = centers,
    y = hy,
    keys = c("------", vapply(key_by_col[c(TRUE, FALSE)], normalize_pdf_key, ""))
  )
}

parse_pdf_page <- function(w, page) {
  header <- parse_pdf_header(w)
  centers <- header$centers
  body <- w[w$y > header$y + 2, ]
  body$line <- cluster_lines(body$y)

  value_cols <- c("population", paste0(rep(c("hz", "aq"), 7), "_", rep(1:7, each = 2)))
  out <- list()
  last_y <- NA_real_
  for (ln in sort(unique(body$line))) {
    lw <- body[body$line == ln, ]
    # Footer rules ("____") can share a line with the last district of a page
    lw <- lw[!grepl("^_+$", lw$text), ]
    if (nrow(lw) == 0) next
    lw <- lw[order(lw$x), ]
    has_letter <- grepl("[[:alpha:]]", lw$text)

    if (!any(grepl("[0-9]", lw$text))) {
      # A text-only line directly below a district row continues its name
      # ("LK Weißenburg-" / "Gunzenhausen"). The page is the scope, so header
      # text of the next page is never attached (BUG-022).
      if (length(out) > 0 && all(lw$x < centers[1] - 30) && lw$y[1] - last_y < 15) {
        prev <- out[[length(out)]]$region_name
        part <- join_name_words(lw)
        out[[length(out)]]$region_name <- paste0(prev, if (endsWith(prev, "-")) "" else " ", part)
      }
      next
    }
    if (!any(has_letter)) next

    first_letter <- min(which(has_letter))
    lead <- merge_number_fragments(lw[seq_len(first_letter - 1), ])
    key <- lead$text[grepl("^[0-9]{5}$", lead$text)]
    if (length(key) != 1) next # not a district row (footer, page number)

    # Values start at the first token after the name with a digit or "-";
    # footnote markers such as "*)" stay part of the published name.
    is_value <- seq_len(nrow(lw)) > first_letter & (grepl("[0-9]", lw$text) | lw$text == "-")
    first_value <- min(which(is_value))
    name <- join_name_words(lw[first_letter:(first_value - 1), ])
    values <- merge_number_fragments(lw[first_value:nrow(lw), ])
    value_center <- values$x + values$width / 2
    is_pop <- value_center < centers[1] - 8
    if (sum(is_pop) != 1) {
      cli::cli_abort("Page {page}, district {key}: expected one population value, found {sum(is_pop)}.")
    }
    col <- vapply(value_center[!is_pop], function(cx) which.min(abs(centers - cx)), integer(1))
    if (anyDuplicated(col) || length(col) != 14) {
      cli::cli_abort("Page {page}, district {key}: cannot assign {length(col)} values to 14 columns.")
    }
    cells <- c(values$text[is_pop], values$text[!is_pop][order(col)])
    out[[length(out) + 1]] <- c(list(ags = key, region_name = name, page = page), as.list(setNames(cells, value_cols)))
    last_y <- max(lw$y)
  }
  if (length(out) == 0) {
    cli::cli_abort("Page {page}: no district rows found.")
  }
  res <- do.call(rbind.data.frame, c(out, stringsAsFactors = FALSE))
  attr(res, "offence_keys") <- header$keys
  res
}

pdf_to_canonical <- function(wide, keys, source) {
  n <- nrow(wide)
  long <- lapply(seq_along(keys), function(g) {
    data.frame(
      ags = wide$ags,
      region_name = wide$region_name,
      offence_key = keys[g],
      hz = parse_german_number(wide[[paste0("hz_", g)]]),
      clearance_rate = parse_german_number(wide[[paste0("aq_", g)]]),
      population = parse_german_number(wide$population),
      stringsAsFactors = FALSE,
      row.names = NULL
    )
  })
  data <- do.call(rbind, long)
  data$year <- source$year
  data$source_format <- "pdf"
  data$source_file <- source$file_name
  data$boundary_year <- source$boundary_year
  data$harmonized <- FALSE
  data$weight_type <- "none"
  data$cases_derived <- data$hz * data$population / 1e5
  data$cleared_derived <- data$cases_derived * data$clearance_rate / 100
  data$estimated <- TRUE
  stopifnot(nrow(data) == n * length(keys))
  as_canonical(data)
}
