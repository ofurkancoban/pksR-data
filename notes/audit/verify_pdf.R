# Independent re-extraction of the PDF Kreis tables (audit only, not pipeline code).
# Assigns word tokens to columns by x position of the "HZ"/"AQ" header tokens,
# then compares with the legacy converted CSVs cell by cell.
args <- commandArgs(trailingOnly = TRUE)
pdf_dir <- args[1]
legacy_dir <- args[2]
out_file <- args[3]

groups <- c("Straftaten", "Koerperverletzung", "Wohnungseinbruch", "DiebstahlKfz",
            "Sachbeschaedigung", "Rauschgift", "Strassenkriminalitaet")
legacy_key <- c("------", "220000", "435*00", "*50*00", "674000", "730000", "899000")

parse_num <- function(x) {
  x <- gsub("\\.", "", x)
  x <- gsub(",", ".", x)
  suppressWarnings(as.numeric(x))
}

extract_year <- function(pdf) {
  txt <- pdftools::pdf_text(pdf)
  pages <- which(grepl("kreis-", tolower(txt)))
  words <- pdftools::pdf_data(pdf)
  out <- list()
  for (p in pages) {
    w <- words[[p]]
    if (nrow(w) == 0) next
    w$yr <- round(w$y / 3)
    # Header row: the y line with the most HZ/AQ tokens
    hz <- w[w$text %in% c("HZ", "AQ"), ]
    if (nrow(hz) < 14) next
    hy <- as.integer(names(which.max(table(hz$y))))
    hdr <- hz[abs(hz$y - hy) <= 2, ]
    hdr <- hdr[order(hdr$x), ]
    if (nrow(hdr) != 14) next
    centers <- hdr$x + hdr$width / 2
    # Einwohner column sits left of the first HZ column; its date token marks it
    date_tok <- w[grepl("^01\\.01\\.", w$text) & abs(w$y - hy) <= 12, ]
    ew_center <- if (nrow(date_tok)) date_tok$x[1] + date_tok$width[1] / 2 else centers[1] - 60
    all_centers <- c(ew_center, centers)
    # Data rows: group tokens by y line, merge fragments separated by < 4pt
    body <- w[w$y > hy + 3, ]
    for (yy in sort(unique(body$y))) {
      row <- body[abs(body$y - yy) <= 1, ]
      row <- row[order(row$x), ]
      merged <- list(); cur <- row[1, ]
      if (nrow(row) > 1) for (i in 2:nrow(row)) {
        gap <- row$x[i] - (cur$x + cur$width)
        if (gap < 4) {
          cur$text <- paste0(cur$text, row$text[i]); cur$width <- row$x[i] + row$width[i] - cur$x
        } else { merged[[length(merged) + 1]] <- cur; cur <- row[i, ] }
      }
      merged[[length(merged) + 1]] <- cur
      m <- do.call(rbind, merged)
      kidx <- which(grepl("^\\d{5}$", m$text) & m$x < ew_center - 60)
      if (length(kidx) == 0) next
      key <- m$text[kidx[1]]
      m <- m[grepl("^[0-9.,-]+$", m$text) & m$x > ew_center - 60, ]
      if (nrow(m) == 0) next
      mc <- m$x + m$width / 2
      col <- vapply(mc, function(cx) which.min(abs(all_centers - cx)), integer(1))
      vals <- rep(NA_character_, 15)
      for (i in seq_along(col)) vals[col[i]] <- m$text[i]
      out[[length(out) + 1]] <- data.frame(ags = key, page = p,
        t(setNames(vals, c("EW", paste0(rep(groups, each = 2), "_", c("HZ", "AQ"))))),
        check.names = FALSE)
    }
  }
  do.call(rbind, out)
}

res <- list()
for (pdf in list.files(pdf_dir, pattern = "^20(0[3-9]|1[0-2])_.*\\.pdf$", full.names = TRUE)) {
  year <- substr(basename(pdf), 1, 4)
  ind <- extract_year(pdf)
  ind <- ind[!duplicated(ind$ags), ]
  leg <- read.csv(list.files(legacy_dir, pattern = paste0("^", year, "_"), full.names = TRUE),
                  colClasses = "character")
  for (g in seq_along(groups)) {
    l <- leg[leg$Schluesselzahl == legacy_key[g], ]
    m <- merge(ind[, c("ags", "EW", paste0(groups[g], c("_HZ", "_AQ")))], l,
               by.x = "ags", by.y = "Kreisschluessel", all = TRUE)
    hz_i <- parse_num(m[[paste0(groups[g], "_HZ")]]); hz_l <- as.numeric(m$Straftaten_HZ)
    aq_i <- parse_num(m[[paste0(groups[g], "_AQ")]]); aq_l <- as.numeric(m$Aufklaerungsquote)
    ew_i <- parse_num(m$EW); ew_l <- as.numeric(m$Einwohner)
    neq <- function(a, b) !((is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & abs(a - b) < 1e-9))
    res[[length(res) + 1]] <- data.frame(year = year, group = groups[g],
      n_independent = sum(!is.na(m$EW)), n_legacy = nrow(l),
      only_independent = sum(is.na(m$Schluesselzahl)), only_legacy = sum(is.na(m$EW)),
      hz_mismatch = sum(neq(hz_i, hz_l)), aq_mismatch = sum(neq(aq_i, aq_l)),
      ew_mismatch = sum(neq(ew_i, ew_l)),
      examples = paste(head(m$ags[neq(hz_i, hz_l) | neq(aq_i, aq_l) | neq(ew_i, ew_l)], 5), collapse = " "))
  }
  message(year, ": independent rows ", nrow(ind))
}
r <- do.call(rbind, res)
write.csv(r, out_file, row.names = FALSE)
print(r, row.names = FALSE)
