# Pipeline definition. `targets` rebuilds a year only when its raw file, its
# registry row or the code it depends on changes (replaces should_skip(),
# BUG-008), and each year is its own branch with declared inputs (BUG-009).
#
# Raw files are expected in data-raw/ (see R/download.R); they are not
# committed. Run with targets::tar_make().

library(targets)

tar_option_set(error = "stop")
tar_source("R")

# Target boundary for harmonization (brief Section 6.1.1): NULL means the
# most recent boundary covered by the crosswalk.
target_boundary <- NULL
weight_types <- c("population", "area")

list(
  # Registries
  tar_target(sources_file, "registry/sources.csv", format = "file"),
  tar_target(sources, read_sources(sources_file)),
  tar_target(reference_sources_file, "registry/reference_sources.csv", format = "file"),
  tar_target(bbsr_file, {
    ref <- readr::read_csv(reference_sources_file, col_types = readr::cols(.default = "c"))
    path <- file.path("data-raw", "bbsr", ref$file_name[ref$label == "bbsr_ref_kreise"])
    verify_sha256(path, ref$sha256[ref$label == "bbsr_ref_kreise"])
    path
  }, format = "file"),
  tar_target(boundary_map_file, "registry/boundary_map.csv", format = "file"),
  tar_target(boundary_registry, read_boundary_map(boundary_map_file)),
  tar_target(boundary_source_check, check_boundary_map_source(boundary_registry, bbsr_file)),
  # Transfers BBSR omits (BUG-035) must match the Destatis change lists
  tar_target(destatis_sources_file, "registry/destatis_sources.csv", format = "file"),
  tar_target(destatis_sources, read_destatis_sources(destatis_sources_file)),
  tar_target(destatis_files, file.path("data-raw", "destatis", destatis_sources$file_name), format = "file"),
  tar_target(destatis_changes, read_destatis_all(destatis_sources, dirname(destatis_files[1]))),
  tar_target(boundary_destatis_check, check_boundary_map_destatis(boundary_registry, destatis_changes, bbsr_file)),
  tar_target(boundary_map, {
    stopifnot(isTRUE(boundary_source_check), isTRUE(boundary_destatis_check))
    effective_boundary_map(boundary_registry)
  }),
  tar_target(target_year, if (is.null(target_boundary)) max(boundary_map$period) + 1L else as.integer(target_boundary)),
  tar_target(target_codes, boundary_codes(boundary_map, target_year)),
  tar_target(offence_map_file, "registry/offence_map.csv", format = "file"),
  tar_target(offence_map, read_offence_map(offence_map_file)),
  tar_target(known_breaks_file, "registry/known_breaks.csv", format = "file"),
  tar_target(known_breaks, read_known_breaks(known_breaks_file)),
  tar_target(bund_sources_file, "registry/bund_sources.csv", format = "file"),
  tar_target(bund_sources, read_bund_sources(bund_sources_file)),

  # National (Bund) tables, only for the validation gate (Section 7.4)
  tar_target(
    bund_raw_file,
    file.path("data-raw", "bund", bund_sources$file_name),
    pattern = map(bund_sources),
    format = "file"
  ),
  tar_target(
    national,
    extract_bund(bund_raw_file, bund_sources),
    pattern = map(bund_sources, bund_raw_file)
  ),

  # Extraction: one branch per registry row (= per year)
  tar_target(
    raw_file,
    file.path("data-raw", sources$file_name),
    pattern = map(sources),
    format = "file"
  ),
  tar_target(
    canonical,
    {
      data <- extract_source(sources, raw_file)
      validate_extraction(data, boundary_codes(boundary_map, sources$boundary_year))
    },
    pattern = map(sources, raw_file),
    iteration = "list"
  ),
  tar_target(
    canonical_file,
    write_canonical(canonical, "output/canonical"),
    pattern = map(canonical),
    format = "file"
  ),
  tar_target(year_check, assert_year_completeness(sources, canonical_file)),
  tar_target(
    offence_changes_file,
    write_lines_file(offence_key_changes(canonical), "notes/offence_key_changes.md"),
    format = "file"
  ),

  # Harmonization: one branch per (weights, year)
  tar_target(weights, weight_types),
  # Each branch records its weighting: years without any boundary change
  # carry weight_type "none" only, so the rows cannot tell.
  tar_target(
    harmonized,
    {
      spatial <- harmonize_space(canonical, boundary_map, target_year, weights)
      check_conservation(canonical, spatial)
      list(weights = weights, data = harmonize_offences(spatial, offence_map))
    },
    pattern = cross(weights, canonical),
    iteration = "list"
  ),

  # Validation gate, then output: one panel per weighting. Nothing is
  # written when a check fails.
  tar_target(
    panel_file,
    {
      panel <- dplyr::bind_rows(lapply(Filter(function(h) h$weights == weights, harmonized), `[[`, "data"))
      ctx <- list(
        target_year = target_year, target_codes = target_codes,
        canonical = canonical, years = sources$year, national = national
      )
      report <- validation_gate(panel, ctx, sprintf("output/validation/report_%s.json", weights))
      c(write_panel(panel, weights, "output/harmonized"), report)
    },
    pattern = map(weights),
    format = "file"
  ),

  # Release assets (uploaded by ci/release.R, never by tar_make())
  tar_target(
    release_assets,
    build_release_assets(canonical_file, panel_file, "registry", "output/release"),
    format = "file"
  )
)
