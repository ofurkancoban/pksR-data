# Cell-by-cell diff of two xlsx workbooks with whitespace normalization
args <- commandArgs(trailingOnly = TRUE)
o <- args[1]; f <- args[2]
norm <- function(x) {
  x <- gsub("[[:space:]]+", " ", x); x <- trimws(x)
  num <- suppressWarnings(as.numeric(x))
  ifelse(is.na(num), x, as.character(signif(num, 10)))
}
n <- 0
for (s in intersect(readxl::excel_sheets(o), readxl::excel_sheets(f))) {
  a <- suppressMessages(readxl::read_excel(o, sheet = s, col_names = FALSE, col_types = "text"))
  b <- suppressMessages(readxl::read_excel(f, sheet = s, col_names = FALSE, col_types = "text"))
  if (!identical(dim(a), dim(b))) cat("DIM DIFF", s, dim(a), "vs", dim(b), "\n")
  nr <- min(nrow(a), nrow(b)); nc <- min(ncol(a), ncol(b))
  for (j in seq_len(nc)) {
    x <- norm(a[[j]][1:nr]); y <- norm(b[[j]][1:nr])
    d <- which(!(x == y | (is.na(x) & is.na(y))) | xor(is.na(x), is.na(y)))
    for (i in d) {
      n <- n + 1
      cat(sprintf("%s | row %d | col %d (%s) | %s -> %s | %s %s\n", s, i, j, norm(a[[j]][1]),
                  x[i], y[i], a[[1]][i], a[[2]][i]))
    }
  }
}
cat("TOTAL DIFFS:", n, "\n")
