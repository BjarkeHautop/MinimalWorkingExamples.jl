# ── preview rendering ──────────────────────────────────────────────────────────

@testitem "_md_inline: renders bold, italics, code spans, and links" tags=[:unit, :fast] begin
    using MinimalWorkingExamples: _md_inline

    @test _md_inline("**bold** and *italic* and `code`") ==
          "<strong>bold</strong> and <em>italic</em> and <code>code</code>"
    @test _md_inline("[text](http://example.com)") ==
          "<a href=\"http://example.com\">text</a>"
    @test _md_inline("<script>") == "&lt;script&gt;"  # escaped before inline styling
end

@testitem "_HTMLPreview: shows raw html for the custom-pane MIME type" tags=[:unit, :fast] begin
    using MinimalWorkingExamples: _HTMLPreview

    h = _HTMLPreview("<b>hi</b>")
    io = IOBuffer()
    show(io, MIME("application/vnd.julia-vscode.custompane+html"), h)
    @test String(take!(io)) == "<b>hi</b>"
end

@testitem "_display_in_editor_panel: false without an editor display backend" tags=[
    :unit,
    :fast,
] begin
    using MinimalWorkingExamples: _display_in_editor_panel

    @test !isdefined(Main, :VSCodeServer)
    @test _display_in_editor_panel("<p>hi</p>") == false
end

@testitem "_display_in_editor_panel: true when VSCodeServer provides a working InlineDisplay" tags=[
    :integration,
    :slow,
] begin
    # Faking `Main.VSCodeServer` pollutes the process's global state permanently (Julia has
    # no API to remove a top-level binding once defined), so this runs in a throwaway
    # subprocess rather than the shared test process.
    julia_exe = joinpath(Sys.BINDIR, Base.julia_exename())
    proj = Base.active_project()

    script = """
    using MinimalWorkingExamples: _display_in_editor_panel

    module VSCodeServer
    struct InlineDisplay <: Base.AbstractDisplay end
    end

    println(_display_in_editor_panel("<p>hi</p>"))  # no display method yet -> catch -> false

    Base.display(::VSCodeServer.InlineDisplay, ::MIME, ::Any) = nothing
    println(_display_in_editor_panel("<p>hi</p>"))  # now succeeds -> true
    """

    out = read(`$julia_exe --project=$proj --startup-file=no -e $script`, String)
    lines = split(strip(out), '\n')
    @test strip(lines[1]) == "false"
    @test strip(lines[2]) == "true"
end

@testitem "preview: renders code fences and swaps placeholders for images" tags=[
    :unit,
    :fast,
] begin
    dir = mktempdir()
    code = """
    struct FakePlotF end
    Base.show(io::IO, ::MIME"image/png", ::FakePlotF) = write(io, UInt8[0x01])
    println("hello <world>")
    FakePlotF()
    2 + 2
    """
    result = MinimalWorkingExamples._run_mwe(
        code;
        temp = false,
        newprocess = false,
        manifest = false,
        advertise = true,
        versioninfo = false,
        plot_dir = dir,
    )
    html = MinimalWorkingExamples._md_to_preview_html(result.md)
    @test contains(html, "<pre><code>")
    @test contains(html, "#&gt; hello &lt;world&gt;")           # escaped output
    @test contains(html, "<span class=\"hl-k\">struct</span>")  # syntax highlighting
    @test !contains(html, "Insert plot here")                   # placeholder swapped
    expected_src = MinimalWorkingExamples._file_url(joinpath(dir, "plot-1.png"))
    @test contains(html, "<img src=\"$expected_src\"")
    @test contains(
        html,
        "<a href=\"https://github.com/BjarkeHautop/MinimalWorkingExamples.jl\">",
    )
end

@testitem "preview: plain text lines render as inline-formatted paragraphs" tags=[
    :unit,
    :fast,
] begin
    using MinimalWorkingExamples: _md_to_preview_html

    html = _md_to_preview_html("Just a plain sentence with **bold** text.\n")
    @test contains(html, "<p>Just a plain sentence with <strong>bold</strong> text.</p>")
end

@testitem "preview: passes through <details> blocks and renders -# subtext lines" tags=[
    :unit,
    :fast,
] begin
    using MinimalWorkingExamples: _md_to_preview_html

    md = """
    <details>
    <summary>Environment</summary>

    ```text
    Julia 1.10
    ```

    </details>

    -# Reported via [MWE](http://example.com)
    """
    html = _md_to_preview_html(md)

    @test contains(html, "<details>\n")
    @test contains(html, "<summary>Environment</summary>\n")
    @test contains(html, "</details>\n")
    @test contains(
        html,
        "<p><sup>Reported via <a href=\"http://example.com\">MWE</a></sup></p>",
    )
end

@testitem "preview: editor variant embeds plot images as base64 data URIs" tags=[
    :unit,
    :fast,
] begin
    using MinimalWorkingExamples: _md_to_preview_html_for_editor, _image_data_uri

    dir = mktempdir()
    imgpath = joinpath(dir, "plot-1.png")
    write(imgpath, UInt8[0x89, 0x50, 0x4E, 0x47])
    md = "**Insert plot here: $imgpath**"

    editor_html = _md_to_preview_html_for_editor(md)
    @test contains(editor_html, _image_data_uri(imgpath))
    @test !contains(editor_html, "file://")
end

@testitem "_open_in_browser: returns true when an opener command is found" tags=[
    :unit,
    :fast,
] begin
    using MinimalWorkingExamples: _open_in_browser

    dir = mktempdir()
    fake_opener = joinpath(dir, "xdg-open")
    write(fake_opener, "#!/bin/sh\nexit 0\n")
    chmod(fake_opener, 0o755)

    old_path = ENV["PATH"]
    ENV["PATH"] = dir * ":" * old_path
    try
        @test _open_in_browser("/tmp/whatever.html") == true
    finally
        ENV["PATH"] = old_path
    end
end

@testitem "_open_in_browser: returns false when no opener command is found" tags=[
    :unit,
    :fast,
] begin
    using MinimalWorkingExamples: _open_in_browser

    old_path = ENV["PATH"]
    ENV["PATH"] = ""
    try
        @test _open_in_browser("/tmp/whatever.html") == false
    finally
        ENV["PATH"] = old_path
    end
end

@testitem "preview: validates the target kwarg" tags=[:unit, :fast] begin
    using MinimalWorkingExamples: preview, MWEResult

    result = MWEResult("1 + 1")
    @test_throws ArgumentError preview(result; target = :bogus)
end

@testitem "preview: opens in the browser when no editor panel is available" tags=[
    :unit,
    :fast,
] begin
    using MinimalWorkingExamples: preview, MWEResult

    @test !isdefined(Main, :VSCodeServer)
    result = MWEResult("Hello **world**")

    dir = mktempdir()
    fake_opener = joinpath(dir, "xdg-open")
    write(fake_opener, "#!/bin/sh\nexit 0\n")
    chmod(fake_opener, 0o755)

    old_path = ENV["PATH"]
    ENV["PATH"] = dir * ":" * old_path
    try
        @test_logs (:info, "Preview opened in browser.") preview(result)
    finally
        ENV["PATH"] = old_path
    end
end

@testitem "preview: reports failure when nothing can display the result" tags=[:unit, :fast] begin
    using MinimalWorkingExamples: preview, MWEResult

    @test !isdefined(Main, :VSCodeServer)
    result = MWEResult("Hello **world**")

    old_path = ENV["PATH"]
    ENV["PATH"] = ""
    try
        @test_logs (:info, r"Could not open a browser") preview(result)
    finally
        ENV["PATH"] = old_path
    end
end

@testitem "preview: opens in the editor panel when a display backend is available" tags=[
    :integration,
    :slow,
] begin
    # Same rationale as the `_display_in_editor_panel` subprocess test above: faking
    # `Main.VSCodeServer` must not leak into the shared test process.
    julia_exe = joinpath(Sys.BINDIR, Base.julia_exename())
    proj = Base.active_project()

    script = """
    using Test
    using MinimalWorkingExamples: preview, MWEResult

    module VSCodeServer
    struct InlineDisplay <: Base.AbstractDisplay end
    end
    Base.display(::VSCodeServer.InlineDisplay, ::MIME, ::Any) = nothing

    result = MWEResult("Hello **world**")
    @test_logs (:info, "Preview opened in editor panel.") preview(result)
    println("SUBPROC_PASS")
    """

    out = read(`$julia_exe --project=$proj --startup-file=no -e $script`, String)
    @test contains(out, "SUBPROC_PASS")
end
