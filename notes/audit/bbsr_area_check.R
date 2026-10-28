# Evidence for BUG-034, BUG-035 and the Q5 manual rows: area conservation
# across the BBSR transition sheets 2003-2004 to 2024-2025. Audit only.
# Run from pksR-data/.
p <- "data-raw/bbsr/ref-kreise-1990-2024.xlsx"
rows <- dplyr::bind_rows(lapply(2003:2024, function(t) {
  d <- readxl::read_excel(p, sheet = paste0(t, "-", t + 1), col_types = "text")
  h <- gsub("[[:space:]]+", " ", names(d))
  tibble::tibble(period = t, row = seq_len(nrow(d)) + 1L, from = d[[1]], to = d[[grep(paste0("^Kreise 31.12.", t + 1), h)]],
    wa = as.numeric(d[[grep("^fl", h, ignore.case = TRUE)[1]]]), area = as.numeric(d[[grep("^Fl.che am", h)]]))
}))
rows <- rows[!is.na(rows$from), ]
# 1) within a sheet: piece area = w_area * total area of the source
src <- dplyr::summarise(dplyr::group_by(rows, period, from), A = sum(area), n = dplyr::n(), .groups = "drop")
r <- dplyr::left_join(rows, src, by = c("period", "from"))
r$expected <- r$wa * r$A
bad1 <- r[abs(r$expected - r$area) > 0.5, ]
cat("Within-sheet mismatches (piece area vs weight x source area, > 0.5 km2):\n"); print(as.data.frame(bad1[, c("period","row","from","to","wa","area","A","expected")]))
# 2) across sheets: target area at t+1 vs sum of weighted source areas at t
into <- dplyr::summarise(dplyr::group_by(r, period, to), A_in = sum(wa * A), .groups = "drop")
nxt <- dplyr::mutate(src, period = period - 1L)
x <- dplyr::inner_join(into, nxt, by = c("period", "to" = "from"))
x$diff <- x$A - x$A_in
cat("\nAcross-sheet: |diff| distribution km2:\n"); print(quantile(abs(x$diff), c(.5,.9,.99,1)))
print(as.data.frame(x[abs(x$diff) > 2, ]))
