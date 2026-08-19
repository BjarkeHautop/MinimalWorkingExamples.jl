# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

MinimalWorkingExamples.jl is a Julia package that turns a snippet of Julia code into a shareable,
self-contained Markdown block (for GitHub issues, Discord, Slack) — the code is run and each
statement's value/output is echoed as a `#>` comment. Inspired by the R package `reprex`.

All source is in `src/` (two files: `MinimalWorkingExamples.jl` and `preview.jl`, the latter
`include`d into the former). Tests live in `test/`.

## Development commands

- **Test**: `julia --project=. -e "using Pkg; Pkg.test()"`
- **REPL with the project active**: `julia --project=.`
- **Format**: `julia -e 'using JuliaFormatter; format(".")'` (or `pre-commit run -a`, see below)

### Testing via julia-mcp

When the [julia-mcp](https://github.com/aplavin/julia-mcp) server is available,
prefer it over spawning new Julia processes — the session stays alive between
calls, avoiding recompilation. Use `<full path>/test` as `env_path`, load the
runner once with `using TestItemRunner`, then run filtered tests:

- All tests: `@run_package_tests verbose=false`
- By test name: `@run_package_tests verbose=false filter=ti->contains(ti.name, "some name")`
- By filename: `@run_package_tests verbose=false filter=ti->contains(ti.filename, "some-file")`

Tests are `@testitem`s tagged `:unit`/`:fast` or slower integration tags; `test/test-core.jl` covers
the main run pipeline, `test/test-plots.jl` covers plot capture, `test/test-preview.jl` covers the
HTML preview renderer.

## Conventions

- Match the existing code style in `src/`.
- Add or update tests in `test/` for any behavior change.
- Code is formatted with [JuliaFormatter](https://github.com/domluna/JuliaFormatter.jl) per
  `.JuliaFormatter.toml` (4-space indent, 92-col margin). Run `pre-commit run -a` before committing
  to apply this and the repo's other pre-commit hooks (markdownlint, yamllint, trailing-whitespace,
  etc.) — CI's Lint workflow enforces them via `SKIP=no-commit-to-branch pre-commit run -a`.
- CI also runs a link checker (`lychee`, config in `.lychee.toml`) over the whole repo, and a `Docs`
  workflow that runs Documenter doctests and builds `docs/` — keep docstrings and any
  `docs/src/*.md` changes in sync with code changes, since broken doctests or links will fail CI.

## Architecture

### Two entry points, one driver

`mwe(code; kwargs...)` (a function taking a code string, defaulting to the clipboard) and `@mwe`
(a macro taking a `begin...end` block, converting it to a code string via `_block_to_code_string`)
both funnel into `_run_mwe`, the single place that resolves defaults, validates kwargs, dispatches
to an execution backend, and assembles the final Markdown. `mwe_rescue` is a third entry point that
first strips a pasted `julia>` REPL transcript down to code (`_rescue_transcript`) before also
calling `_run_mwe`.

### Execution backends

`_run_mwe` picks one of two backends based on `newprocess`:

- `_run_in_new_process`: writes a self-contained driver script (`_build_driver_script`, a large
  string template) to a temp dir and runs it as `julia --project=<tmp> ... script.jl` in a
  subprocess, capturing its stdout. This is the default and gives full reproducibility (fresh
  process, isolated environment, no interference from the calling session).
- `_run_in_current_process`: `_execute_code_in_current_process` re-implements the same
  parse/eval/capture loop directly via `Core.eval`/`_capture_eval`, for `newprocess=false`.

Both backends independently re-implement the same logic (parse top-level expressions, redirect
stdout/stderr per-statement, decide whether to echo a statement's value, capture plots) because one
runs as generated source in a subprocess and the other runs as compiled Julia in-process — when
changing behavior (e.g. what counts as "display-suppressing", output formatting), **update both
places** (`_build_driver_script`'s template vs. `_execute_code_in_current_process` and its helpers
`_find_expr_end_line`/`_find_final_end_line`/`_suppresses_display`/`_capture_eval`).

Per top-level expression, both backends: reprint the original source text for that expression
(via line-range bookkeeping, not the parsed AST, so comments/formatting are preserved for `mwe()`),
eval it, capture stdout/stderr/logging output as `#>`-prefixed lines, and — unless the expression is
an assignment/definition (`_suppresses_display`/`_MWE_SUPPRESSED_HEADS`) or produced other output —
show the returned value as a `#>` line too.

### Environment setup

`temp=true` (default) auto-creates an isolated temp project: `_extract_packages` parses `using`/
`import` statements out of the code to determine what to `Pkg.add`, then `_setup_temp_env!` runs
`Pkg.add`/`Pkg.instantiate` in a subprocess against that temp project. `packagespecs`/
`manifest_path` let the caller pin versions or reuse an existing `Manifest.toml` instead of
auto-resolving.

### Plot capture

When `plot_dir` is set, both backends register a custom `Base.AbstractDisplay`
(`_MWEPlotDisplay` in the driver-script template; `_PlotSink` in-process) that intercepts
PNG-showable values, saves them under `plot_dir`, and emits a `__MWE_PLOT__:<path>` marker line
into the captured output. `_assemble_body` later splits the captured output on these markers to
interleave `**Insert plot here: ...**` placeholders between code fences at the right position.

### Markdown assembly and preview

`_run_mwe` builds the final Markdown from the captured output (`_assemble_body`) plus optional
`<details>` sections (stacktrace, environment/versioninfo, Manifest.toml) and an advertisement
footer, then copies it to the clipboard. `preview.jl` (an `include`d file, not a submodule) renders
that same restricted Markdown subset to HTML (`_render_preview_body`/`_wrap_html`) for the
`preview()` function, with a hand-rolled Julia syntax highlighter (`_highlight_julia_line`) — it
targets two destinations, the system browser (`file://` plot links) and the VS Code Julia
extension's custom viewer pane (`_display_in_editor_panel`, base64-embedded plot images since that
webview can't load `file://`).

### Persistent defaults

`set_defaults!` writes to Preferences.jl-backed persistent config (`_default`/`_DEFAULTS`), which
`_run_mwe`'s keyword defaults read at call time — distinct from the ephemeral `packagespecs`/
`manifest_path` args that Preferences.jl doesn't (and can't) persist.
