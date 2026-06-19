module MinimalWorkingExamples

using Dates: today
using Logging
using Pkg
using InteractiveUtils: clipboard

export @mwe, mwe, MWEResult

"""
    @mwe begin
        code
    end [venue=:gh] [temp=true] [newprocess=true] [manifest=false] [advertise=nothing]
        [packagespecs=PackageSpec[]] [manifest_path=nothing] [verbose=false] [stacktrace=false]

Generate a Minimal Working Example (MWE) formatted as Markdown, then copy it to the clipboard.

The code is rendered as a copy-pasteable Julia script with the output of the final expression
(and any `print`/logging calls) shown as `#>` comments.

# Keyword arguments
- `venue=:gh`: output format — `:gh` for GitHub-Flavored Markdown (default), `:slack` for Slack
  (strips the language identifier from the code fence).
- `temp=true`: create a temporary isolated environment and auto-add packages from `using`/`import`.
  When `false`, code runs in the current environment without auto-adding packages (to avoid
  polluting the user's project).
- `newprocess=true`: run the MWE in a fresh Julia process for reproducibility. If `temp=true` and
  `newprocess=false`, the temporary project is activated, code runs, and the original project state is restored afterward.
- `manifest=false`: append the `Manifest.toml` in a collapsible `<details>` block.
- `advertise`: append a footer noting the date, this package, and Julia version used.
  Defaults to `true` for `:gh` and `false` for `:slack`; can be set explicitly to override.
- `packagespecs=PackageSpec[]`: vector of [`Pkg.PackageSpec`](https://pkgdocs.julialang.org/v1/api/#Pkg.PackageSpec)s for packages that need a specific
  version, git revision, URL, or local path.
- `manifest_path=nothing`: path to an existing `Manifest.toml` to use as-is.
  Mutually exclusive with `packagespecs`.
- `verbose=false`: if `true`, show Pkg output (downloads, resolver messages) during environment
  setup.
- `stacktrace=false`: if `true`, append the full stacktrace after the error message.

# Examples

```julia
@mwe begin
    using Statistics
    x = [1, 2, 3, 4, 5]
    mean(x)
end
```

Produces (copied to clipboard):
````markdown
```julia
using Statistics
x = [1, 2, 3, 4, 5]
mean(x)
#> 3.0
```

<sup>Created on <date> with [MinimalWorkingExamples v<pkg-version>](https://github.com/BjarkeHautop/MinimalWorkingExamples.jl) using Julia <version></sup>
````
Pin a package to a specific version:

```julia
using Pkg
@mwe begin
    using Example
    Example.hello("World")
end packagespecs=[PackageSpec(name="Example", version="0.5.3")]
```

Include the stacktrace when an error is thrown:

```julia
@mwe begin
    x = [1, 2, 3]
    x[10]
end stacktrace=true
```
"""
macro mwe(ex, kwargs...)
    code_str = _block_to_code_string(ex)

    kw = Dict{Symbol,Any}()
    for kwarg in kwargs
        if kwarg isa Expr && kwarg.head == :(=)
            kw[kwarg.args[1]] = esc(kwarg.args[2])
        end
    end

    return quote
        MinimalWorkingExamples._run_mwe(
            $code_str;
            venue = $(get(kw, :venue, :(:gh))),
            temp = $(get(kw, :temp, true)),
            newprocess = $(get(kw, :newprocess, true)),
            manifest = $(get(kw, :manifest, false)),
            advertise = $(get(kw, :advertise, nothing)),
            packagespecs = $(get(kw, :packagespecs, :(Pkg.PackageSpec[]))),
            manifest_path = $(get(kw, :manifest_path, nothing)),
            verbose = $(get(kw, :verbose, false)),
            stacktrace = $(get(kw, :stacktrace, false)),
        )
    end
end

"""
    mwe([code]; venue=:gh, temp=true, newprocess=true, manifest=false, advertise=nothing,
               packagespecs=PackageSpec[], manifest_path=nothing, verbose=false, stacktrace=false)

Function form of [`@mwe`](@ref). Accepts code as a plain string.
If `code` is omitted, reads Julia source from the clipboard.

# Examples

```julia
# Run code already copied to the clipboard:
mwe()

# Format for Slack:
mwe(; venue=:slack)

# Run an explicit string:
mwe(\"""
using Statistics
mean([1, 2, 3])
\""")
```
"""
function mwe(
    code::AbstractString = clipboard();
    venue::Symbol = :gh,
    temp::Bool = true,
    newprocess::Bool = true,
    manifest::Bool = false,
    advertise::Union{Bool,Nothing} = nothing,
    packagespecs::Vector = Pkg.PackageSpec[],
    manifest_path::Union{AbstractString,Nothing} = nothing,
    verbose::Bool = false,
    stacktrace::Bool = false,
)
    _run_mwe(
        code;
        venue,
        temp,
        newprocess,
        manifest,
        advertise,
        packagespecs,
        manifest_path,
        verbose,
        stacktrace,
    )
end

# ── Result type ────────────────────────────────────────────────────────────────

"""
    MWEResult

Wraps the Markdown string produced by `@mwe`. Displays silently in the REPL
(the output is already printed on creation); access the Markdown string via `.md`.
"""
struct MWEResult
    md::String
end

Base.show(::IO, ::MIME"text/plain", ::MWEResult) = nothing
Base.show(io::IO, r::MWEResult) = print(io, r.md)
Base.String(r::MWEResult) = r.md

# ── Macro helpers ──────────────────────────────────────────────────────────────

# Base.remove_linenums! strips LineNumberNodes from :block/:quote but leaves
# them in macrocall arg lists.
# string() then prints them as ` #= file:line =#` annotations. Strip those.
# Top-level nodes can also be bare literals or symbols (e.g. a final `42`),
# which are not `Expr`; render those directly.
function _expr_to_display_string(node)
    node isa Expr || return string(node)
    s = string(Base.remove_linenums!(deepcopy(node)))
    return replace(s, r"#= [^\n=]*:\d+ =# ?" => "")
end

function _block_to_code_string(ex::Expr)
    ex.head == :block || error("@mwe expects a begin...end block")
    lines = String[]
    for arg in ex.args
        arg isa LineNumberNode && continue
        push!(lines, _expr_to_display_string(arg))
    end
    return join(lines, "\n")
end

# ── Package helpers ────────────────────────────────────────────────────────────

function _is_stdlib(name::AbstractString)
    return isdir(joinpath(Sys.STDLIB, name))
end

function _extract_packages(code_str::AbstractString)
    packages = String[]
    toplevel = Meta.parseall(code_str)
    for node in toplevel.args
        node isa LineNumberNode && continue
        node isa Expr || continue
        node.head in (:using, :import) || continue
        for item in node.args
            item isa Expr || continue
            # `import Foo as Bar` wraps the module path in an `:as` node.
            inner = item.head == :as ? item.args[1] : item
            inner isa Expr || continue
            top = if inner.head == :.
                string(first(inner.args))
            elseif inner.head == :(:)
                src = inner.args[1]
                src isa Expr && src.head == :. ? string(first(src.args)) : nothing
            else
                nothing
            end
            isnothing(top) && continue
            push!(packages, top)
        end
    end
    return filter(!_is_stdlib, unique(packages))
end

function _repr_packagespec(spec::Pkg.PackageSpec)
    parts = String[]
    _get(f) =
        try
            f()
        catch
            ;
            nothing
        end

    (n = _get(() -> spec.name); !isnothing(n) && !isempty(n)) &&
        push!(parts, "name=$(repr(n))")
    (u = _get(() -> spec.uuid); !isnothing(u)) && push!(parts, "uuid=$(repr(string(u)))")

    let v = _get(() -> spec.version)
        if !isnothing(v)
            v_str = string(v)
            (!isempty(v_str) && v_str != "*") && push!(parts, "version=$(repr(v_str))")
        end
    end

    url = _get(() -> spec.repo.source)
    isnothing(url) && (url = _get(() -> spec.url))
    (!isnothing(url) && !isempty(url)) && push!(parts, "url=$(repr(url))")

    rev = _get(() -> spec.repo.rev)
    isnothing(rev) && (rev = _get(() -> spec.rev))
    (!isnothing(rev) && !isempty(rev)) && push!(parts, "rev=$(repr(rev))")

    (p = _get(() -> spec.path); !isnothing(p) && !isempty(p)) &&
        push!(parts, "path=$(repr(p))")
    (s = _get(() -> spec.subdir); !isnothing(s) && !isempty(s)) &&
        push!(parts, "subdir=$(repr(s))")

    return "Pkg.PackageSpec($(join(parts, ", ")))"
end

function _describe_packagespec(spec::Pkg.PackageSpec)
    _get(f) =
        try
            f()
        catch
            ;
            nothing
        end

    name = let n = _get(() -> spec.name);
        (!isnothing(n) && !isempty(n)) ? n : "?"
    end

    v = _get(() -> spec.version)
    v_str = if !isnothing(v)
        s = string(v);
        (isempty(s) || s == "*") ? nothing : s
    end

    url = _get(() -> spec.repo.source)
    isnothing(url) && (url = _get(() -> spec.url))

    rev = _get(() -> spec.repo.rev)
    isnothing(rev) && (rev = _get(() -> spec.rev))

    path = _get(() -> spec.path)

    if !isnothing(v_str)
        "$name@$v_str"
    elseif !isnothing(rev)
        "$name#$rev"
    elseif !isnothing(url)
        "$name (url)"
    elseif !isnothing(path) && !isempty(path)
        "$name (local)"
    else
        name
    end
end

# ── Driver script ──────────────────────────────────────────────────────────────

function _build_driver_script(code_str::AbstractString; stacktrace::Bool = false)
    return """
    using Logging

    function _mwe_prefix_output(str)
        isempty(str) && return
        for line in split(rstrip(str, '\\n'), '\\n')
            println("#> ", line)
        end
    end

    function _mwe_to_display_string(ex)
        ex isa Expr || return string(ex)
        s = string(Base.remove_linenums!(deepcopy(ex)))
        return replace(s, r"#= [^\\n=]*:\\d+ =# ?" => "")
    end

    const _mwe_code = $(repr(code_str))
    const _mwe_nodes = [n for n in Meta.parseall(_mwe_code).args if !(n isa LineNumberNode)]
    for (i, _mwe_node) in enumerate(_mwe_nodes)
        if _mwe_node isa Expr && _mwe_node.head === :error
            _mwe_prefix_output("ERROR: " * sprint(showerror, _mwe_node.args[1]))
            break
        end
        println(_mwe_to_display_string(_mwe_node))

        _mwe_original_out = Base.stdout
        _mwe_original_err = Base.stderr
        _mwe_rd_out, _mwe_wr_out = redirect_stdout()
        _mwe_rd_err, _mwe_wr_err = redirect_stderr()
        local _mwe_val = nothing
        local _mwe_err = nothing
        local _mwe_bt = nothing
        try
            _mwe_val = with_logger(ConsoleLogger(_mwe_wr_err, Logging.Info)) do
                Base.invokelatest(Core.eval, Main, _mwe_node)
            end
        catch _e
            _mwe_err = _e
            _mwe_bt = catch_backtrace()
        finally
            redirect_stdout(_mwe_original_out)
            redirect_stderr(_mwe_original_err)
            close(_mwe_wr_out)
            close(_mwe_wr_err)
        end
        _mwe_captured_out = read(_mwe_rd_out, String)
        _mwe_captured_err = read(_mwe_rd_err, String)
        close(_mwe_rd_out)
        close(_mwe_rd_err)

        _mwe_prefix_output(_mwe_captured_out)
        _mwe_prefix_output(_mwe_captured_err)
        if !isnothing(_mwe_err)
            if $(stacktrace)
                _mwe_frames = Base.stacktrace(_mwe_bt)
                _mwe_cutoff = findfirst(
                    f -> f.func === :eval && endswith(String(f.file), "boot.jl"),
                    _mwe_frames,
                )
                _mwe_frames = isnothing(_mwe_cutoff) ? _mwe_frames : _mwe_frames[1:_mwe_cutoff-1]
                _mwe_st = isempty(_mwe_frames) ? "" : "\\n" * sprint(Base.show_backtrace, _mwe_frames)
                _mwe_err_str = sprint(showerror, _mwe_err) * _mwe_st
            else
                _mwe_err_str = sprint(showerror, _mwe_err)
            end
            _mwe_prefix_output("ERROR: " * _mwe_err_str)
            break
        end
        if i == length(_mwe_nodes) && _mwe_val !== nothing
            _mwe_buf = IOBuffer()
            show(IOContext(_mwe_buf, :limit => true, :color => false), MIME"text/plain"(), _mwe_val)
            _mwe_prefix_output(String(take!(_mwe_buf)))
        end
    end
    """
end

# ── Environment setup ──────────────────────────────────────────────────────────

function _setup_temp_env!(
    tmpdir::AbstractString,
    code_str::AbstractString,
    packagespecs::Vector,
    manifest_path::Union{AbstractString,Nothing} = nothing;
    verbose::Bool = false,
)
    if !isnothing(manifest_path)
        cp(manifest_path, joinpath(tmpdir, "Manifest.toml"))
        setup_script = "using Pkg\nPkg.instantiate()\n"
    else
        packages = _extract_packages(code_str)

        spec_names =
            Set(s.name for s in packagespecs if !isnothing(s.name) && !isempty(s.name))
        packages = filter(p -> p ∉ spec_names, packages)

        add_stmts = String[]
        isempty(packages) || push!(add_stmts, "Pkg.add([$(join(repr.(packages), ", "))])")
        for spec in packagespecs
            push!(add_stmts, "Pkg.add($(_repr_packagespec(spec)))")
        end
        push!(add_stmts, "Pkg.instantiate()")

        setup_script = "using Pkg\n$(join(add_stmts, "\n"))\n"
    end

    julia_exe = joinpath(Sys.BINDIR, Base.julia_exename())
    cmd = addenv(
        `$julia_exe --project=$tmpdir --startup-file=no -e $setup_script`,
        "JULIA_LOAD_PATH" => "@:@stdlib",
    )
    verbose ? run(cmd) : run(pipeline(cmd; stdout = devnull, stderr = devnull))
end

# ── Execution backends ─────────────────────────────────────────────────────────

function _run_in_new_process(
    code_str::AbstractString;
    temp::Bool = true,
    manifest::Bool = true,
    packagespecs::Vector = Pkg.PackageSpec[],
    manifest_path::Union{AbstractString,Nothing} = nothing,
    verbose::Bool = false,
    stacktrace::Bool = false,
)
    mktempdir() do tmpdir
        temp && _setup_temp_env!(tmpdir, code_str, packagespecs, manifest_path; verbose)

        script_path = joinpath(tmpdir, "mwe_driver.jl")
        write(script_path, _build_driver_script(code_str; stacktrace))

        julia_exe = joinpath(Sys.BINDIR, Base.julia_exename())
        project_flag = temp ? "--project=$tmpdir" : "--project=@."
        cmd = `$julia_exe $project_flag --startup-file=no -q $script_path`
        temp && (cmd = addenv(cmd, "JULIA_LOAD_PATH" => "@:@stdlib"))

        repl_output = try
            readchomp(cmd)
        catch e
            error("MWE execution failed:\n$(sprint(showerror, e))")
        end

        manifest_str = ""
        if manifest && temp
            mp = joinpath(tmpdir, "Manifest.toml")
            isfile(mp) && (manifest_str = read(mp, String))
        end

        return repl_output, manifest_str
    end
end

function _capture_eval(ex)
    original_out = Base.stdout
    original_err = Base.stderr
    rd_out, wr_out = redirect_stdout()
    rd_err, wr_err = redirect_stderr()
    local val = nothing
    local err = nothing
    local bt = nothing
    try
        val = Logging.with_logger(Logging.ConsoleLogger(wr_err, Logging.Info)) do
            Base.invokelatest(Core.eval, Main, ex)
        end
    catch e
        err = e
        bt = catch_backtrace()
    finally
        redirect_stdout(original_out)
        redirect_stderr(original_err)
        close(wr_out)
        close(wr_err)
    end
    captured_out = read(rd_out, String)
    captured_err = read(rd_err, String)
    close(rd_out)
    close(rd_err)
    return val, captured_out, captured_err, err, bt
end

function _prefix_lines(io::IO, str::AbstractString, prefix::AbstractString)
    isempty(str) && return
    for line in split(rstrip(str, '\n'), '\n')
        println(io, prefix, line)
    end
end

# Keep only frames above the Core.eval boundary — everything below is driver
# or REPL infrastructure irrelevant to the user's code.
function _user_frames(bt)
    frames = Base.stacktrace(bt)
    cutoff = findfirst(f -> f.func === :eval && endswith(String(f.file), "boot.jl"), frames)
    return isnothing(cutoff) ? frames : frames[1:(cutoff-1)]
end

function _format_error(err, bt; stacktrace::Bool = false)
    stacktrace || return sprint(showerror, err)
    frames = _user_frames(bt)
    st = isempty(frames) ? "" : "\n" * sprint(Base.show_backtrace, frames)
    return sprint(showerror, err) * st
end

function _execute_code_in_current_process(
    code_str::AbstractString;
    stacktrace::Bool = false,
)
    buf = IOBuffer()
    nodes = [n for n in Meta.parseall(code_str).args if !(n isa LineNumberNode)]
    for (i, node) in enumerate(nodes)
        if node isa Expr && node.head === :error
            _prefix_lines(buf, "ERROR: " * sprint(showerror, node.args[1]), "#> ")
            break
        end
        ex_str = _expr_to_display_string(node)
        val, captured_out, captured_err, err, bt = _capture_eval(node)
        println(buf, ex_str)
        _prefix_lines(buf, captured_out, "#> ")
        _prefix_lines(buf, captured_err, "#> ")
        if !isnothing(err)
            _prefix_lines(buf, "ERROR: " * _format_error(err, bt; stacktrace), "#> ")
            break
        end
        if i == length(nodes) && val !== nothing
            val_buf = IOBuffer()
            show(
                IOContext(val_buf, :limit => true, :color => false),
                MIME"text/plain"(),
                val,
            )
            _prefix_lines(buf, String(take!(val_buf)), "#> ")
        end
    end
    return String(take!(buf))
end

function _run_in_current_process(
    code_str::AbstractString;
    temp::Bool = false,
    packagespecs::Vector = Pkg.PackageSpec[],
    manifest_path::Union{AbstractString,Nothing} = nothing,
    verbose::Bool = false,
    stacktrace::Bool = false,
)
    if temp
        mktempdir() do tmpdir
            _setup_temp_env!(tmpdir, code_str, packagespecs, manifest_path; verbose)
            original_project = Base.active_project()
            try
                Pkg.activate(tmpdir)
                output = _execute_code_in_current_process(code_str; stacktrace)
                return output, ""
            finally
                if isnothing(original_project)
                    Pkg.activate()
                else
                    Pkg.activate(original_project)
                end
            end
        end
    else
        output = _execute_code_in_current_process(code_str; stacktrace)
        return output, ""
    end
end

# ── Public entry point ─────────────────────────────────────────────────────────

function _run_mwe(
    code_str::AbstractString;
    venue::Symbol = :gh,
    temp::Bool = true,
    newprocess::Bool = true,
    manifest::Bool = false,
    advertise::Union{Bool,Nothing} = nothing,
    packagespecs::Vector = Pkg.PackageSpec[],
    manifest_path::Union{AbstractString,Nothing} = nothing,
    verbose::Bool = false,
    stacktrace::Bool = false,
)
    venue in (:gh, :slack) || error("venue must be :gh or :slack, got $(repr(venue))")
    if !isnothing(manifest_path) && !isempty(packagespecs)
        error("`manifest_path` and `packagespecs` are mutually exclusive; pass only one")
    end
    _advertise = isnothing(advertise) ? (venue === :gh) : advertise

    repl_output, manifest_str = if newprocess
        _run_in_new_process(
            code_str;
            temp,
            manifest,
            packagespecs,
            manifest_path,
            verbose,
            stacktrace,
        )
    else
        _run_in_current_process(
            code_str;
            temp,
            packagespecs,
            manifest_path,
            verbose,
            stacktrace,
        )
    end

    lang = venue === :gh ? "julia" : ""
    md = "```$lang\n$repl_output\n```"
    if _advertise
        notes = String[]
        !newprocess && push!(notes, "in-process")
        if !isnothing(manifest_path)
            push!(notes, "from existing Manifest.toml")
        elseif !isempty(packagespecs)
            push!(notes, "pinned: " * join(_describe_packagespec.(packagespecs), ", "))
        end
        extra = isempty(notes) ? "" : " · " * join(notes, " · ")
        md *= "\n\n<sup>Created on $(today()) with [MinimalWorkingExamples v$(pkgversion(MinimalWorkingExamples))](https://github.com/BjarkeHautop/MinimalWorkingExamples.jl) using Julia $VERSION$extra</sup>"
    end
    if manifest && !isempty(manifest_str)
        md *= "\n\n<details>\n<summary>Manifest.toml</summary>\n\n```toml\n$manifest_str\n```\n\n</details>"
    end

    try
        clipboard(md)
        @info "MWE copied to clipboard!"
    catch
        @info "Could not copy to clipboard — printing only."
    end
    println(md)
    return MWEResult(md)
end

end # module
