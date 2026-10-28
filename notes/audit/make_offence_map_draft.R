# One-off generator for the draft registry/offence_map.csv (kept out of the
# pipeline: the CSV is the registry, this only avoids retyping labels).
d <- dplyr::bind_rows(lapply(list.files("output/canonical", full.names = TRUE), arrow::read_parquet))
u <- unique(d[!is.na(d$offence_label), c("year", "offence_key", "offence_label")])
u <- u[order(-u$year), ]
latest <- u[!duplicated(u$offence_key), ]
strip <- function(x) trimws(sub("\\s*(davon|darunter|und zwar):\\s*$", "", gsub("[[:space:]]+", " ", x)))
lab <- function(k) strip(latest$offence_label[latest$offence_key == k])

rows <- tibble::tribble(
  ~key, ~src, ~en, ~parent, ~notes,
  "------", "------@2003-2025", "Total offences", NA, "PDF years print the key as dashes of varying length; stored as ------ (decision 2026-10-27).",
  "890000", "------ minus 725000@2014;890000@2015-2025", "Total offences excluding offences against the Residence, Asylum and EU Freedom of Movement Acts (key 725000)", "------", "Published from 2015. 2014 computed as ------ minus 725000 (identity exact in all 4,409 district rows 2015 to 2025 for cases, attempts and cleared; suspects not additive, NA in 2014). Your decision Q4.",
  "****00", "****00@2014-2025", "Theft, total", "------", "",
  "***100", "***100@2013-2025", "Theft of motor cars, total, incl. unauthorized use", "****00", "",
  "***200", "***200@2014-2025", "Theft of mopeds and motorcycles, total, incl. unauthorized use", "****00", "",
  "***300", "***300@2014-2025", "Theft of bicycles, total, incl. unauthorized use", "****00", "",
  "*26*00", "*26*00@2023-2025", "Shoplifting, total", "****00", "New in the Kreis table in 2023.",
  "*50*00", "*50*@2003-2007;*50*00@2008-2025", "Theft of parts from and items out of motor vehicles, total", "****00", "Definition break 2012 (BRK-014): until 2011 in/aus (items inside vehicles), from 2012 an/aus (including vehicle parts); the 2012 yearbook marks the change as not comparable. Legacy translation labelled this key theft of motor cars (BUG-024); that is ***100. 4-digit notation until 2007.",
  "*90*00", "*90*00@2014-2025", "Pickpocketing, total", "****00", "",
  "3***00", "3***00@2014-2025", "Theft without aggravating circumstances", "****00", "",
  "326*00", "326*00@2014-2025", "Simple shoplifting", "3***00", "Also part of *26*00 (from 2023).",
  "4***00", "4***00@2014-2025", "Theft under aggravating circumstances", "****00", "",
  "435*00", "435*@2003-2007;435*00@2008-2025", "Residential burglary", "4***00", "Label adds para. 244a StGB in 2016 and para. 244 Abs. 4 StGB from 2018 (BRK-008, citation changes; national series without a step). 4-digit notation until 2007.",
  "436*00", "436*00@2013-2025", "Daytime residential burglary", "435*00", "Label changes 2016 to 2018 as for 435*00.",
  "111000", "111000@2014-2025", "Rape, sexual coercion and sexual assault in especially serious cases, incl. resulting in death", "------", "Definition changes in 2017 and 2018 (BRK-007): three different scopes of para. 177 StGB in one key; also part of 892000.",
  "210000", "210000@2013-2025", "Robbery, robbery-like extortion and robbery-like assault on motorists", "------", "",
  "211000", "211000@2014-2025", "Robbery and robbery-like extortion of banks, post offices and postal agencies", "210000", "",
  "212000", "212000@2014-2025", "Robbery and robbery-like extortion of other cash desks and shops", "210000", "Label changes in 2020 (sonstige Zahlstellen becomes sonstige Kassenraeume).",
  "216000", "216000@2014-2025", "Handbag robbery", "210000", "",
  "217000", "217000@2014-2025", "Other robbery in streets, paths or squares", "210000", "",
  "219000", "219000@2014-2025", "Robbery in dwellings", "210000", "",
  "220000", "2200@2003-2007;220000@2008-2009,2013", "Bodily harm", "------", "Absent 2010 to 2012 (the PDF column is 222000 then) and from 2014. Kept separate from 222000 and 224000 (BUG-013).",
  "222000", "222000@2010-2025", "Dangerous and serious bodily harm, female genital mutilation", "220000", "2010 to 2012 from the PDF bodily harm column (BUG-011). Label adds para. 226a StGB from 2014.",
  "224000", "224000@2013-2025", "Intentional simple bodily harm", "220000", "",
  "510000", "510000@2013-2025", "Fraud", "------", "Cited paragraphs extended in 2018 (265a-e).",
  "515000", "515000@2014-2025", "Obtaining services by deception", "510000", "",
  "515001", "515001@2013-2025", "Fare evasion", "515000", "",
  "530000", "530000@2014-2025", "Embezzlement", "------", "",
  "540000", "540000@2014-2025", "Forgery of documents", "------", "",
  "621020", "621020@2014-2017", "Resistance against enforcement officers", "------", "Replaced in 2018 by 621100 to 621120 (BRK-009). Not linked: 621110 continues the level (2017: 22,904; 2018: 21,551) but assaults formerly in 621020 moved to 621120, so neither new key has the old scope.",
  "621021", "621021@2013-2017", "Resistance against police officers", "621020", "",
  "621100", "621100@2018-2025", "Resistance against and assault on enforcement officers and persons of equal status", "------", "",
  "621110", "621110@2018-2025", "Resistance against enforcement officers and persons of equal status", "621100", "",
  "621120", "621120@2018-2025", "Assault on enforcement officers and persons of equal status", "621100", "",
  "630000", "630000@2014-2025", "Accessory after the fact, obstruction of justice (excluding in office), handling stolen goods and money laundering", "------", "",
  "640000", "640000@2014-2025", "Arson and causing a risk of fire", "------", "",
  "674000", "6740@2003-2007;674000@2008-2025", "Criminal damage", "------", "4-digit notation until 2007.",
  "725000", "725000@2014-2025", "Offences against the Residence Act, the Asylum Act and the EU Freedom of Movement Act", "------", "Asylverfahrensgesetz renamed Asylgesetz in the 2016 label.",
  "730000", "7300@2003-2007;730000@2008-2025", "Drug offences (unless recorded under another key)", "------", "Cannabis Act from 1 April 2024 (BRK-015). 4-digit notation until 2007.",
  "892000", "892000@2013-2025", "Violent crime", "------", "Summary key; overlaps 111000, 210000, 222000, 892500 and others. Never add it to its components.",
  "892500", "892500@2013-2025", "Murder, manslaughter and killing on request", "892000", "Summary key, part of violent crime (892000; 0 violations of 892500 <= 892000 in 5,200 district-years). Label adds killing on request from 2016 (BRK-011).",
  "897000", "897000@2014-2025", "Cybercrime", "------", "Summary key. Label Computerkriminalitaet until 2020, Cybercrime from 2021 (BRK-012); unexplained jump in 2016 (BRK-017).",
  "899000", "8990@2003-2007;899000@2008-2025", "Street crime", "------", "Summary key; overlaps theft and robbery keys. 4-digit notation until 2007.",
  "899500", "899500@2013-2025", "Criminal damage by graffiti, total", "674000", "Summary key within criminal damage (0 violations of 899500 <= 674000 in 5,200 district-years).",
  "972500", "972500@2014-2023", "Persons who entered or stayed without permission (keys 725100, 725700)", "725000", "Summary of 725100 and 725700, both within 725000. Dropped from the Kreis table in 2024.",
  "980100", "980100@2014-2020", "Cybercrime in the narrow sense", "897000", "Summary key within 897000 (0 violations in 2,800 district-years). Label IuK-Kriminalitaet im engeren Sinne until 2016; the key list disappears from the label in 2016 and the series doubles (BRK-016). Dropped from the Kreis table in 2021."
)
first_last <- function(src) {
  y <- unlist(lapply(strsplit(src, ";")[[1]], function(e) {
    r <- sub(".*@", "", e); unlist(lapply(strsplit(r, ",")[[1]], function(p) { b <- as.integer(strsplit(p, "-")[[1]]); seq(b[1], b[length(b)]) }))
  }))
  range(y)
}
fl <- t(vapply(rows$src, first_last, integer(2)))
map <- tibble::tibble(
  offence_key_harmonized = rows$key,
  label_de = vapply(rows$key, lab, ""),
  label_en = rows$en,
  parent_key = rows$parent,
  valid_from = fl[, 1], valid_to = fl[, 2],
  source_keys = rows$src,
  status = "draft",
  notes = ifelse(rows$notes == "", NA, rows$notes)
)
stopifnot(!anyNA(map$label_de))
readr::write_csv(map, "registry/offence_map.csv", na = "")
cat(nrow(map), "keys\n")
