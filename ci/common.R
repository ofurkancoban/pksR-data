# Shared setup for the CI scripts: load the pipeline functions and give
# every script one place to write its machine-readable result.
for (f in list.files("R", pattern = "\\.R$", full.names = TRUE)) source(f)

ci_dir <- ensure_dir("output/ci")

write_ci <- function(x, name) {
  jsonlite::write_json(x, file.path(ci_dir, paste0(name, ".json")), auto_unbox = TRUE, pretty = TRUE, null = "null", na = "null", digits = NA)
}

# GitHub Actions step outputs (no-op outside Actions)
set_output <- function(name, value) {
  out <- Sys.getenv("GITHUB_OUTPUT")
  if (nzchar(out)) cat(sprintf("%s=%s\n", name, value), file = out, append = TRUE)
}
