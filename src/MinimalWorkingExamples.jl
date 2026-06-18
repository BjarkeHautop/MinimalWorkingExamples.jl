module MinimalWorkingExamples

using Dates: today
using Pkg
using InteractiveUtils: clipboard

export @mwe, mwe, MWEResult

"""
    @mwe begin
        code
    end [temp=true] [newprocess=true] [manifest=false] [advertise=true] [packagespecs=PackageSpec[]] [manifest_path=nothing]

Generate a Minimal Working Example (MWE) formatted as Markdown, then copy it to the clipboard.

The code is rendered as a copy-pasteable Julia script with the output of the final expression
(and any `print`/`println` calls) shown as `#>` comments.

# Keyword arguments
- `temp=true`: run in a temporary environment; packages from `using`/`import` are auto-added
- `newprocess=true`: run the MWE in a fresh Julia process for reproducibility
- `manifest=false`: append the `Manifest.toml` in a collapsible `<details>` block
- `advertise=true`: append a footer noting the date, this package, and Julia version used
- `packagespecs=PackageSpec[]`: vector of `Pkg.PackageSpec`s for packages that need a specific
  version, git revision, URL, or local path — instead of the latest registered version.
  Useful for creating MWEs of unmerged PRs or pre-release fixes. Any package named here
  overrides the auto-detected version from `using`/`import`.
- `manifest_path=nothing`: path to an existing `Manifest.toml` to use as-is. When set,
  `Pkg.add` is skipped entirely and `Pkg.instantiate()` reproduces the exact environment.
  Mutually exclusive with `packagespecs`.

# Examples

Basic usage:

```julia
@mwe begin
    using Statistics
    x = [1, 2, 3, 4, 5]
    mean(x)
end
```

Produces (copied to clipboard):

```julia
using Statistics
x = [1, 2, 3, 4, 5]
mean(x)
#> 3.0
```

<sup>Created on <date> with MinimalWorkingExamples.jl using Julia <version></sup>

Pin a package to a specific version (e.g. to reproduce a bug fixed in the next release):

```julia
using Pkg
@mwe begin
    using Example
    Example.hello("World")
end packagespecs=[PackageSpec(name="Example", version="0.5.3")]
```

Use a PR branch directly from GitHub:

```julia
using Pkg
@mwe begin
    using MyPackage
    MyPackage.new_feature()
end packagespecs=[PackageSpec(url="https://github.com/user/MyPackage.jl", rev="my-fix-branch")]
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
            temp = $(get(kw, :temp, true)),
            newprocess = $(get(kw, :newprocess, true)),
            manifest = $(get(kw, :manifest, false)),
            advertise = $(get(kw, :advertise, true)),
            packagespecs = $(get(kw, :packagespecs, :(Pkg.PackageSpec[]))),
            manifest_path = $(get(kw, :manifest_path, nothing)),
        )
    end
end

"""
    mwe([code]; temp=true, newprocess=true, manifest=false, advertise=true,
               packagespecs=PackageSpec[], manifest_path=nothing)

Function form of [`@mwe`](@ref). Accepts code as a plain string.
If `code` is omitted, reads Julia source from the clipboard.

# Examples

```julia
# Run code already copied to the clipboard:
mwe()

# Run an explicit string:
mwe(\"""
using Statistics
mean([1, 2, 3])
\""")
```
"""
function mwe(
    code::AbstractString = clipboard();
    temp::Bool = true,
    newprocess::Bool = true,
    manifest::Bool = false,
    advertise::Bool = true,
    packagespecs::Vector = Pkg.PackageSpec[],
    manifest_path::Union{AbstractString,Nothing} = nothing,
)
    _run_mwe(code; temp, newprocess, manifest, advertise, packagespecs, manifest_path)
end

# ── Result type ────────────────────────────────────────────────────────────────

"""
    MWEResult

Wraps the Markdown string produced by `@mwe`. Displays silently in the REPL
(the formatted output is already printed directly); access the raw string via `.md`.
"""
struct MWEResult
    md::String
end

Base.show(::IO, ::MIME"text/plain", ::MWEResult) = nothing
Base.show(io::IO, r::MWEResult) = print(io, r.md)
Base.String(r::MWEResult) = r.md

# ── Macro helpers ──────────────────────────────────────────────────────────────

function _block_to_code_string(ex::Expr)
    ex.head == :block || error("@mwe expects a begin...end block")
    lines = String[]
    for arg in ex.args
        arg isa LineNumberNode && continue
        push!(lines, string(Base.remove_linenums!(deepcopy(arg))))
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
            top = if item.head == :.
                string(first(item.args))
            elseif item.head == :(:)
                src = item.args[1]
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

function _build_driver_script(code_str::AbstractString)
    return """
    function _mwe_prefix_output(str)
        isempty(str) && return
        for line in split(rstrip(str, '\\n'), '\\n')
            println("#> ", line)
        end
    end

    const _mwe_code = $(repr(code_str))
    const _mwe_nodes = [n for n in Meta.parseall(_mwe_code).args if !(n isa LineNumberNode)]
    for (i, _mwe_node) in enumerate(_mwe_nodes)
        _mwe_ex = Base.remove_linenums!(deepcopy(_mwe_node))
        println(string(_mwe_ex))

        _mwe_original = Base.stdout
        _mwe_rd, _mwe_wr = redirect_stdout()
        local _mwe_val
        try
            _mwe_val = Base.invokelatest(Core.eval, Main, _mwe_node)
        finally
            redirect_stdout(_mwe_original)
            close(_mwe_wr)
        end
        _mwe_captured = read(_mwe_rd, String)
        close(_mwe_rd)

        _mwe_prefix_output(_mwe_captured)
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
    manifest_path::Union{AbstractString,Nothing} = nothing,
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
    run(`$julia_exe --project=$tmpdir --startup-file=no -e $setup_script`)
end

# ── Execution backends ─────────────────────────────────────────────────────────

function _run_in_new_process(
    code_str::AbstractString;
    temp::Bool = true,
    manifest::Bool = true,
    packagespecs::Vector = Pkg.PackageSpec[],
    manifest_path::Union{AbstractString,Nothing} = nothing,
)
    mktempdir() do tmpdir
        temp && _setup_temp_env!(tmpdir, code_str, packagespecs, manifest_path)

        script_path = joinpath(tmpdir, "mwe_driver.jl")
        write(script_path, _build_driver_script(code_str))

        julia_exe = joinpath(Sys.BINDIR, Base.julia_exename())
        project_flag = temp ? "--project=$tmpdir" : "--project=@."
        cmd = `$julia_exe $project_flag --startup-file=no -q $script_path`

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

function _capture_eval(ex::Expr)
    original = Base.stdout
    rd, wr = redirect_stdout()
    local val
    try
        val = Base.invokelatest(Core.eval, Main, ex)
    finally
        redirect_stdout(original)
        close(wr)
    end
    captured = read(rd, String)
    close(rd)
    return val, captured
end

function _prefix_lines(io::IO, str::AbstractString, prefix::AbstractString)
    isempty(str) && return
    for line in split(rstrip(str, '\n'), '\n')
        println(io, prefix, line)
    end
end

function _run_in_current_process(code_str::AbstractString)
    buf = IOBuffer()
    nodes =
        [n for n in Meta.parseall(code_str).args if !(n isa LineNumberNode) && n isa Expr]
    for (i, node) in enumerate(nodes)
        ex_str = string(Base.remove_linenums!(deepcopy(node)))
        val, captured = _capture_eval(node)
        println(buf, ex_str)
        _prefix_lines(buf, captured, "#> ")
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
    return String(take!(buf)), ""
end

# ── Public entry point ─────────────────────────────────────────────────────────

function _run_mwe(
    code_str::AbstractString;
    temp::Bool = true,
    newprocess::Bool = true,
    manifest::Bool = false,
    advertise::Bool = true,
    packagespecs::Vector = Pkg.PackageSpec[],
    manifest_path::Union{AbstractString,Nothing} = nothing,
)
    repl_output, manifest_str = if newprocess
        _run_in_new_process(code_str; temp, manifest, packagespecs, manifest_path)
    else
        _run_in_current_process(code_str)
    end

    md = "```julia\n$repl_output\n```"
    if manifest && !isempty(manifest_str)
        md *= "\n\n<details>\n<summary>Manifest.toml</summary>\n\n```toml\n$manifest_str\n```\n\n</details>"
    end
    if advertise
        notes = String[]
        !newprocess && push!(notes, "in-process")
        if !isnothing(manifest_path)
            push!(notes, "from existing Manifest.toml")
        elseif !isempty(packagespecs)
            push!(notes, "pinned: " * join(_describe_packagespec.(packagespecs), ", "))
        end
        extra = isempty(notes) ? "" : " · " * join(notes, " · ")
        md *= "\n\n<sup>Created on $(today()) with [MinimalWorkingExamples.jl](https://github.com/BjarkeHautop/MinimalWorkingExamples.jl) using Julia $VERSION$extra</sup>"
    end

    try
        clipboard(md)
        @info "MWE copied to clipboard!"
    catch
        @warn "Could not copy to clipboard — printing only."
    end
    println(md)
    return MWEResult(md)
end

end # module
