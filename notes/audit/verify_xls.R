# Compare legacy converted CSVs with raw BKA workbooks cell by cell (audit only)
# Argument: the 01_datasets folder of the legacy repository
L <- commandArgs(trailingOnly = TRUE)[1]
raw <- list.files(file.path(L, "raw/PKS"), pattern = "xls", full.names = TRUE)
conv_dir <- file.path(L, "processed/PKS/01-converted")
num_cols <- c("Erfasste_Faelle","Straftaten_HZ","Versuche_Anzahl","Versuche_Anteil_Prozent",
  "Mit_Schusswaffe_gedroht","Mit_Schusswaffe_geschossen","Aufklaerung_Faelle","Aufklaerungsquote",
  "Tatverdaechtige_Insgesamt","Tatverdaechtige_Maennlich","Tatverdaechtige_Weiblich",
  "Nichtdeutsche_Tatverdaechtige_Anzahl","Nichtdeutsche_Tatverdaechtige_Prozent")
for (f in raw) {
  yr <- substr(basename(f), 1, 4)
  r <- suppressMessages(readxl::read_excel(f, col_names = FALSE, col_types = "text"))
  r <- r[which(r[[1]] == "------")[1]:nrow(r), ]
  r <- r[!is.na(r[[1]]) & !is.na(r[[3]]), ]
  is2013 <- yr == "2013"
  rr <- data.frame(key = r[[1]], label = r[[2]], ags = r[[3]],
    name = if (is2013) r[[5]] else r[[4]], type = if (is2013) r[[4]] else r[[5]],
    stringsAsFactors = FALSE)
  for (i in seq_along(num_cols)) rr[[num_cols[i]]] <- suppressWarnings(as.numeric(r[[5 + i]]))
  cv <- read.csv(list.files(conv_dir, pattern = paste0("^", yr), full.names = TRUE), colClasses = "character")
  m <- merge(rr, cv, by.x = c("key", "ags"), by.y = c("Schluesselzahl", "Kreisschluessel"), all = TRUE)
  mis <- sapply(num_cols, function(v) {
    a <- m[[paste0(v, ".x")]]; b <- as.numeric(m[[paste0(v, ".y")]])
    sum(!((is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & abs(a - b) <= 1e-6 * pmax(1, abs(a)))))
  })
  cat(sprintf("%s raw=%d conv=%d only_raw=%d only_conv=%d dup_raw=%d name_mis=%d type_mis=%d label_mis=%d cells=%d mismatches=%s\n",
    yr, nrow(rr), nrow(cv), sum(is.na(m$Kreis)), sum(is.na(m$name)),
    sum(duplicated(rr[, c("key","ags")])), sum(m$name != m$Kreis, na.rm = TRUE),
    sum(m$type != m$Kreisart, na.rm = TRUE), sum(m$label != m$Straftat, na.rm = TRUE),
    nrow(m) * length(num_cols), paste(names(mis)[mis > 0], mis[mis > 0], collapse = ", ")))
  # Leftover rows in raw: footer or Bund/Land rows?
  odd <- rr[!grepl("^[0-9]{5}$", rr$ags), ]
  if (nrow(odd)) cat("   non-5-digit ags rows:", nrow(odd), paste(head(unique(odd$ags)), collapse = " "), "\n")
}
