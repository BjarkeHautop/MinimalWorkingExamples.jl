_escape_html(s::AbstractString) = replace(
    s,
    '&' => "&amp;",
    '<' => "&lt;",
    '>' => "&gt;",
    '"' => "&quot;",
    '\'' => "&#39;",
)

_md_links_to_html(s::AbstractString) =
    replace(s, r"\[([^\]]+)\]\(([^)]+)\)" => s"<a href=\"\2\">\1</a>")

# Inline Markdown (bold, italics, code spans, links) for plain text lines.
function _md_inline(s::AbstractString)
    h = _escape_html(s)
    h = replace(h, r"\*\*([^*]+)\*\*" => s"<strong>\1</strong>")
    h = replace(h, r"\*([^*]+)\*" => s"<em>\1</em>")
    h = replace(h, r"`([^`]+)`" => s"<code>\1</code>")
    return _md_links_to_html(h)
end

const _JULIA_KEYWORDS = Set([
    "abstract",
    "baremodule",
    "begin",
    "break",
    "catch",
    "const",
    "continue",
    "do",
    "else",
    "elseif",
    "end",
    "export",
    "false",
    "finally",
    "for",
    "function",
    "global",
    "if",
    "import",
    "in",
    "isa",
    "let",
    "local",
    "macro",
    "missing",
    "module",
    "mutable",
    "nothing",
    "primitive",
    "quote",
    "return",
    "struct",
    "true",
    "try",
    "type",
    "using",
    "where",
    "while",
])

# One line of Julia at a time: strings, comments, macros, symbols, numbers,
# identifiers, then any other single character. Line-based, so triple-quoted
# strings spanning lines are highlighted only approximately — fine for a preview.
# The symbol alternative excludes a `:` preceded by a word char or another `:`,
# so type annotations (`x::Int`) and ranges (`1:n`) aren't mistaken for `:name`.
# The `=` alternative excludes one adjacent to `=`, `!`, `<`, `>` so comparison
# operators (`==`, `!=`, `<=`, `>=`) and pair arrows (`=>`) fall through to the
# plain single-character case instead of being styled as assignment.
const _HL_TOKEN_RE =
    r"\"(?:\\.|[^\"\\])*\"|#.*$|@[A-Za-z_]\w*|(?<![\w:]):[A-Za-z_]\w*!?|\d+(?:\.\d+)?(?:[eEf][+-]?\d+)?|[A-Za-z_]\w*!?|(?<![=!<>])=(?![=>])|."

const _HL_IDENTIFIER_RE = r"^[A-Za-z_]\w*!?$"

function _token_class(tok::AbstractString, next_char::Union{Char,Nothing})
    startswith(tok, '#') && return "hl-c"
    startswith(tok, '"') && return "hl-s"
    startswith(tok, '@') && return "hl-m"
    startswith(tok, ':') && length(tok) > 1 && return "hl-y"
    occursin(r"^\d", tok) && return "hl-n"
    tok in _JULIA_KEYWORDS && return "hl-k"
    tok == "=" && return "hl-o"
    # An identifier directly followed by `(` is a function call or definition.
    next_char === '(' && occursin(_HL_IDENTIFIER_RE, tok) && return "hl-f"
    return ""
end

function _highlight_julia_line(line::AbstractString)
    # Captured output lines render as one muted span.
    startswith(line, "#>") &&
        return "<span class=\"hl-out\">" * _escape_html(line) * "</span>"
    out = IOBuffer()
    for m in eachmatch(_HL_TOKEN_RE, line)
        next_idx = m.offset + ncodeunits(m.match)
        next_char = next_idx <= ncodeunits(line) ? line[next_idx] : nothing
        cls = _token_class(m.match, next_char)
        esc = _escape_html(m.match)
        isempty(cls) ? print(out, esc) :
        print(out, "<span class=\"", cls, "\">", esc, "</span>")
    end
    return String(take!(out))
end

function _file_url(path::AbstractString)
    p = replace(abspath(path), '\\' => '/')
    return startswith(p, "/") ? "file://" * p : "file:///" * p
end

_image_data_uri(path::AbstractString) = "data:image/png;base64,$(base64encode(read(path)))"

const _PREVIEW_CSS = """
body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
       max-width: 850px; margin: 2rem auto; padding: 0 1rem; color: #1f2328; background: #ffffff; }
pre { background: #f6f8fa; border-radius: 6px; padding: 16px; overflow-x: auto; }
code { font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace;
       font-size: 85%; }
img { max-width: 100%; }
sup { color: #59636e; }
details { margin: 1em 0; }
summary { cursor: pointer; }
.hl-k, .hl-o { color: #cf222e; }
.hl-s { color: #0a3069; }
.hl-c { color: #59636e; }
.hl-n, .hl-m, .hl-y, .hl-f { color: #0550ae; }
.hl-out { color: #59636e; }
@media (prefers-color-scheme: dark) {
    body { color: #e6edf3; background: #0d1117; }
    pre { background: #161b22; }
    sup { color: #8b949e; }
    .hl-k, .hl-o { color: #ff7b72; }
    .hl-s { color: #a5d6ff; }
    .hl-c { color: #8b949e; }
    .hl-n, .hl-m, .hl-y, .hl-f { color: #79c0ff; }
    .hl-out { color: #8b949e; }
}
"""

# Same rules as `_PREVIEW_CSS`, for the editor-panel preview. The code block uses a border
# rather than a background fill, since layering a
# background on both `pre` and its `code` child produced a stray highlight-like band.
const _EDITOR_PREVIEW_CSS = """
body { font-family: var(--vscode-font-family, -apple-system, BlinkMacSystemFont, "Segoe UI",
       Helvetica, Arial, sans-serif); margin: 1rem; padding: 0;
       color: var(--vscode-foreground, #1f2328); background: var(--vscode-editor-background, transparent); }
pre { background: transparent; border: 1px solid rgba(128, 128, 128, 0.35); border-radius: 6px;
      padding: 16px; overflow-x: auto; }
code { font-family: var(--vscode-editor-font-family, ui-monospace, SFMono-Regular, "SF Mono",
       Menlo, Consolas, monospace); font-size: 85%; background: transparent; }
img { max-width: 100%; }
sup { color: var(--vscode-descriptionForeground, #59636e); }
details { margin: 1em 0; }
summary { cursor: pointer; }
.hl-k, .hl-o { color: #cf222e; }
.hl-s { color: #0a3069; }
.hl-c { color: #59636e; }
.hl-n, .hl-m, .hl-y, .hl-f { color: #0550ae; }
.hl-out { color: #59636e; }
@media (prefers-color-scheme: dark) {
    .hl-k, .hl-o { color: #ff7b72; }
    .hl-s { color: #a5d6ff; }
    .hl-c { color: #8b949e; }
    .hl-n, .hl-m, .hl-y, .hl-f { color: #79c0ff; }
    .hl-out { color: #8b949e; }
}
"""

# Parser state for `_render_line!`: whether we are inside a code fence, whether that
# fence holds Julia code (and should be syntax-highlighted), and whether plot images
# should be embedded as base64 data URIs rather than linked via `file://`.
mutable struct _PreviewState
    in_code::Bool
    highlight::Bool
    embed_images::Bool
end
_PreviewState(embed_images::Bool = false) = _PreviewState(false, false, embed_images)

function _render_line!(io::IO, line::AbstractString, state::_PreviewState)
    if startswith(line, "```")
        print(io, state.in_code ? "</code></pre>\n" : "<pre><code>")
        # Highlight Julia fences; leave ```toml/```text blocks plain. Fences
        # without a language tag (venue=:slack) hold Julia code too.
        state.highlight = !state.in_code && chopprefix(line, "```") in ("julia", "")
        state.in_code = !state.in_code
    elseif state.in_code
        println(io, state.highlight ? _highlight_julia_line(line) : _escape_html(line))
    elseif (m = match(_PLOT_PLACEHOLDER_RE, line); !isnothing(m))
        plot_path = something(m[1])
        src = state.embed_images ? _image_data_uri(plot_path) : _file_url(plot_path)
        println(io, "<p><img src=\"$src\" alt=\"plot\"></p>")
    elseif line in ("<details>", "</details>") || startswith(line, "<summary>")
        println(io, line)
    elseif startswith(line, "<sup>")
        println(io, "<p>", _md_links_to_html(line), "</p>")
    elseif startswith(line, "-# ")
        println(io, "<p><sup>", _md_links_to_html(chopprefix(line, "-# ")), "</sup></p>")
    elseif isempty(strip(line))
        # block tags handle their own spacing
    else
        println(io, "<p>", _md_inline(line), "</p>")
    end
    return nothing
end

_wrap_html(body::AbstractString, css::AbstractString = _PREVIEW_CSS) = """
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>MWE preview</title>
<style>$css</style>
</head>
<body>
$body</body>
</html>
"""

# Renders the restricted Markdown emitted by `mwe()`/`@mwe` to an HTML body fragment
# (`_wrap_html` adds the <html>/<head>/<body> wrapper).
function _render_preview_body(md::AbstractString; embed_images::Bool = false)
    body = IOBuffer()
    state = _PreviewState(embed_images)
    for line in eachsplit(md, '\n')
        _render_line!(body, line, state)
    end
    return String(take!(body))
end

# For the external-browser fallback: plot images link to their `file://` path.
_md_to_preview_html(md::AbstractString) = _wrap_html(_render_preview_body(md))

# For the editor's custom viewer pane: its webview sandbox can't load `file://` paths
_md_to_preview_html_for_editor(md::AbstractString) =
    _wrap_html(_render_preview_body(md; embed_images = true), _EDITOR_PREVIEW_CSS)

function _open_in_browser(path::AbstractString)
    cmd = if Sys.iswindows()
        `cmd /c start "" $path`
    elseif Sys.isapple()
        `open $path`
    else
        `xdg-open $path`
    end
    try
        run(cmd; wait = false)
        return true
    catch
        return false
    end
end

# Thin wrapper so we can attach a `show` method for the VS Code custom-pane MIME type
# without depending on VSCodeServer.
struct _HTMLPreview
    html::String
end

Base.show(
    io::IO,
    ::MIME{Symbol("application/vnd.julia-vscode.custompane+html")},
    h::_HTMLPreview,
) = print(io, h.html)

# Shows `html` in the Julia VS Code extension's viewer panel
function _display_in_editor_panel(html::AbstractString)
    isdefined(Main, :VSCodeServer) || return false
    vs = Main.VSCodeServer
    isdefined(vs, :InlineDisplay) || return false
    try
        d = Base.invokelatest(vs.InlineDisplay)
        mime = MIME(
            "application/vnd.julia-vscode.custompane+html;id=mwe-preview;title=\"MWE preview\"",
        )
        Base.invokelatest(display, d, mime, _HTMLPreview(html))
        return true
    catch
        return false
    end
end

"""
    preview(result::MWEResult; target::Union{Symbol,Nothing}=nothing)

Render the Markdown of an [`MWEResult`](@ref) to HTML, to check what the MWE will look
like before posting it. Plot placeholders are replaced by the actual saved image files.

`target` picks the viewer: `:editor` for the host editor's viewer panel, `:browser` for
the default browser, or `nothing` (the default) to use the editor panel when available
and fall back to the browser otherwise.

Returns the path of the generated HTML file.

# Examples

```julia
result = mwe()
preview(result)
preview(result; target = :browser)
```
"""
function preview(r::MWEResult; target::Union{Symbol,Nothing} = nothing)
    (isnothing(target) || target in (:editor, :browser)) || throw(
        ArgumentError("target must be :editor, :browser, or nothing, got $(repr(target))"),
    )
    path = joinpath(mktempdir(), "mwe_preview.html")
    write(path, _md_to_preview_html(r.md))
    if target !== :browser && _display_in_editor_panel(_md_to_preview_html_for_editor(r.md))
        @info "Preview opened in editor panel."
    elseif _open_in_browser(path)
        @info "Preview opened in browser."
    else
        @info "Could not open a browser — preview written to $path"
    end
    return path
end
