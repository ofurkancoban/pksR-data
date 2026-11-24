# Word gaps in the district names of the PDF years (BUG-043).
#
# The text layer of the yearbooks has no reliable word gaps: pdftools
# reports positions in whole points, so a gap inside a word ("Wolfenbü ttel",
# 2008) and a gap between words ("Herzogtum Lauenburg") can both be 2
# points, and the 2011 layer holds names without any gap ("BadKreuznach").
# No gap threshold separates the two cases, so join_name_words() keeps its
# threshold and the names are repaired with a vocabulary instead: every word
# of every BBSR name in the crosswalk. Only spaces are added or removed, and
# a hyphen that splits a word at a line break; letters are never changed.

# Words the BKA printed that no BBSR name contains. They are kept as
# published; any other unknown word stops the pipeline (check_region_names()).
published_name_words <- c(
  Salle = "2007 to 2009: 'Halle (Salle)', misprint of Saale in the yearbooks",
  Jerochower = "2008: 'Jerochower Land', misprint of Jerichower in the yearbook",
  Burgenland = "2007 and 2009: 'Burgenland', short form of Burgenlandkreis in the yearbooks",
  Salzland = "2007 and 2009: 'Salzland', short form of Salzlandkreis in the yearbooks"
)

# District type prefixes of the PDF tables
pdf_name_prefixes <- c("SK", "LK", "KfS", "K", "RV")

name_vocabulary <- function(map) {
  words <- unlist(strsplit(c(map$from_name, map$to_name), " ", fixed = TRUE))
  words <- unlist(strsplit(words, "[-/]"))
  words <- strip_word_marks(words)
  # BBSR prints "a.d.Waldnaab" as one word; the word itself is "Waldnaab"
  words <- c(words, strip_abbreviation(words))
  words <- words[nchar(words) >= 2]
  unique(c(words, pdf_name_prefixes, names(published_name_words)))
}

# Brackets, footnote markers and commas do not make a word unknown.
strip_word_marks <- function(x) gsub("^[(]+|[)*,]+$", "", x)

# Abbreviations such as "a.d.", "i.d." or "i." in front of a word
# ("a.d.Ruhr", "i.Fichtelgebirge") are printed without a space.
strip_abbreviation <- function(x) sub("^([[:lower:]]{1,2}\\.)+", "", x)

is_known_word <- function(w, vocab) {
  w <- strip_abbreviation(strip_word_marks(w))
  if (!nzchar(w) || w %in% vocab) {
    return(TRUE)
  }
  parts <- strip_abbreviation(strip_word_marks(strsplit(w, "[-/]")[[1]]))
  length(parts) > 1 && all(!nzchar(parts) | parts %in% vocab)
}

# The split of `w` into known words with the fewest parts, ties broken by the
# longest first part; NULL when there is none. A part never starts with a
# hyphen, comma or closing bracket, so "Aachen,Städteregion" becomes
# "Aachen, Städteregion" and "Rhein-KreisNeuss" becomes "Rhein-Kreis Neuss".
split_word <- function(w, vocab, max_parts = 4) {
  if (is_known_word(w, vocab)) {
    return(w)
  }
  n <- nchar(w)
  if (max_parts < 2 || n < 2) {
    return(NULL)
  }
  best <- NULL
  for (k in seq_len(n - 1)) {
    left <- substr(w, 1, k)
    right <- substr(w, k + 1, n)
    if (!grepl("^[[:alpha:](]", right) || !is_known_word(left, vocab)) next
    rest <- split_word(right, vocab, max_parts - 1)
    if (is.null(rest)) next
    cand <- c(left, rest)
    if (is.null(best) || length(cand) < length(best) ||
      (length(cand) == length(best) && nchar(cand[1]) > nchar(best[1]))) {
      best <- cand
    }
  }
  best
}

# A hyphen that ends a line in the yearbook stays in the extracted name
# ("Breisgau-Hoch-schwarzwald"). It is removed when the part after it starts
# in lower case and the joined word is known.
join_line_break_hyphens <- function(w, vocab) {
  parts <- strsplit(w, "-", fixed = TRUE)[[1]]
  i <- 1
  while (i < length(parts)) {
    joined <- paste0(parts[i], parts[i + 1])
    if (grepl("^[[:lower:]]", parts[i + 1]) && is_known_word(joined, vocab)) {
      parts <- c(parts[seq_len(i - 1)], joined, parts[-seq_len(i + 1)])
    } else {
      i <- i + 1
    }
  }
  paste(parts, collapse = "-")
}

respace_name <- function(name, vocab) {
  if (is.na(name)) {
    return(name)
  }
  w <- strsplit(name, " ", fixed = TRUE)[[1]]
  w <- w[nzchar(w)]
  # Remove a space inside a word: "Waldn aab" becomes "Waldnaab" when only
  # the joined word is known
  i <- 1
  while (i < length(w)) {
    joined <- paste0(w[i], w[i + 1])
    both_known <- is_known_word(w[i], vocab) && is_known_word(w[i + 1], vocab)
    if (!both_known && is_known_word(joined, vocab)) {
      w <- c(w[seq_len(i - 1)], joined, w[-seq_len(i + 1)])
    } else {
      i <- i + 1
    }
  }
  w <- vapply(w, join_line_break_hyphens, "", vocab = vocab, USE.NAMES = FALSE)
  # Add a missing space: "HerzogtumLauenburg" becomes "Herzogtum Lauenburg"
  w <- unlist(lapply(w, function(x) split_word(x, vocab) %||% x))
  paste(w, collapse = " ")
}

unknown_name_words <- function(name, vocab) {
  w <- strsplit(name, " ", fixed = TRUE)[[1]]
  w[nzchar(w) & !vapply(w, is_known_word, logical(1), vocab = vocab)]
}

# Repairs the names of the PDF years and reports every change; the names of
# the spreadsheet years are left as published.
repair_region_names <- function(data, map) {
  if (!identical(unique(data$source_format), "pdf")) {
    return(data)
  }
  vocab <- name_vocabulary(map)
  old <- unique(data$region_name)
  new <- vapply(old, respace_name, "", vocab = vocab, USE.NAMES = FALSE)
  changed <- old != new
  if (any(changed)) {
    cli::cli_inform(c(
      "{unique(data$year)}: word gaps repaired in {sum(changed)} district name{?s} (BUG-043).",
      stats::setNames(paste0(old[changed], " -> ", new[changed]), rep("*", sum(changed)))
    ))
  }
  data$region_name <- new[match(data$region_name, old)]
  check_region_names(data, vocab)
}

# Every word of a PDF name must be a BBSR word or a listed BKA spelling, so
# a name damaged by the text layer cannot reach a release unnoticed.
check_region_names <- function(data, vocab) {
  names_ <- unique(data$region_name)
  unknown <- lapply(names_, unknown_name_words, vocab = vocab)
  bad <- lengths(unknown) > 0
  if (any(bad)) {
    cli::cli_abort(c(
      "{unique(data$year)}: {sum(bad)} district name{?s} with words outside the BBSR names (BUG-043).",
      stats::setNames(
        paste0(names_[bad], ": ", vapply(unknown[bad], paste, "", collapse = ", ")),
        rep("x", sum(bad))
      ),
      "i" = "Add a word printed by the BKA to {.code published_name_words} with its reason."
    ))
  }
  invisible(data)
}
