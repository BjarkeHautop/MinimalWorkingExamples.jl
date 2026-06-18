module MinimalWorkingExamples

using Pkg
using InteractiveUtils: clipboard

export @mwe, MWEResult

"""
    @mwe begin
        code
    end [temp=true] [newprocess=true] [manifest=true] [packagespecs=PackageSpec[]]

Generate a Minimal Working Example (MWE) formatted as a Julia REPL session in Markdown.

Executes `code` and formats the output as a Markdown fenced code block with REPL-style
`julia>` prompts, then copies the result to the clipboard.

# Keyword arguments
- `temp=true`: run in a temporary environment; packages from `using`/`import` are auto-added
- `newprocess=true`: run the MWE in a fresh Julia process for reproducibility
- `manifest=true`: append the `Manifest.toml` in a collapsible `<details>` block
- `packagespecs=PackageSpec[]`: additional `PackageSpec`s (useful for specific versions, PRs, URLs)

# Examples
```julia
@mwe begin
    using Statistics
    x = [1, 2, 3, 4, 5]
    mean(x)
end
```
"""
macro mwe(ex, kwargs...)
    code_str = _block_to_code_string(ex)

    kw = Dict{Symbol,Any}()
    for kwarg in kwargs
        if kwarg isa Expr && kwarg.head == :(=)
            kw[kwarg.args[1]] = kwarg.args[2]
        end
    end

    return quote
        MinimalWorkingExamples._run_mwe(
            $code_str;
            temp = $(get(kw, :temp, true)),
            newprocess = $(get(kw, :newprocess, true)),
            manifest = $(get(kw, :manifest, true)),
            packagespecs = $(get(kw, :packagespecs, :(Pkg.PackageSpec[]))),
        )
    end
end

# ── Result type ───────────────────────────────────────────────────────────────

"""
    MWEResult

Wraps the Markdown string produced by `@mwe`. Displays silently in the REPL
(the formatted output is printed directly); access the raw string via `.md`.
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

    url = something(_get(() -> spec.repo.source), _get(() -> spec.url), nothing)
    (!isnothing(url) && !isempty(url)) && push!(parts, "url=$(repr(url))")

    rev = something(_get(() -> spec.repo.rev), _get(() -> spec.rev), nothing)
    (!isnothing(rev) && !isempty(rev)) && push!(parts, "rev=$(repr(rev))")

    (p = _get(() -> spec.path); !isnothing(p) && !isempty(p)) &&
        push!(parts, "path=$(repr(p))")
    (s = _get(() -> spec.subdir); !isnothing(s) && !isempty(s)) &&
        push!(parts, "subdir=$(repr(s))")

    return "Pkg.PackageSpec($(join(parts, ", ")))"
end

# ── Driver script ──────────────────────────────────────────────────────────────

function _build_driver_script(code_str::AbstractString)
    return """
    function _mwe_show(val)
        val === nothing && return
        show(IOContext(stdout, :limit => true, :color => false), MIME"text/plain"(), val)
        println()
    end

    const _mwe_code = $(repr(code_str))
    for _mwe_node in Meta.parseall(_mwe_code).args
        _mwe_node isa LineNumberNode && continue
        _mwe_ex    = Base.remove_linenums!(deepcopy(_mwe_node))
        _mwe_str   = string(_mwe_ex)
        _mwe_lines = split(_mwe_str, '\\n')
        print("julia> ", _mwe_lines[1], "\\n")
        for _mwe_line in _mwe_lines[2:end]
            print("       ", _mwe_line, "\\n")
        end
        _mwe_show(Base.invokelatest(Core.eval, Main, _mwe_node))
    end
    """
end

# ── Environment setup ──────────────────────────────────────────────────────────

function _setup_temp_env!(
    tmpdir::AbstractString,
    code_str::AbstractString,
    packagespecs::Vector,
)
    packages = _extract_packages(code_str)

    add_stmts = String[]
    isempty(packages) || push!(add_stmts, "Pkg.add([$(join(repr.(packages), ", "))])")
    for spec in packagespecs
        push!(add_stmts, "Pkg.add($(_repr_packagespec(spec)))")
    end
    push!(add_stmts, "Pkg.instantiate()")

    setup_script = "using Pkg\n$(join(add_stmts, "\n"))\n"
    julia_exe = joinpath(Sys.BINDIR, Base.julia_exename())
    run(`$julia_exe --project=$tmpdir --startup-file=no -e $setup_script`)
end

# ── Execution backends ─────────────────────────────────────────────────────────

function _run_in_new_process(
    code_str::AbstractString;
    temp::Bool = true,
    manifest::Bool = true,
    packagespecs::Vector = Pkg.PackageSpec[],
)
    mktempdir() do tmpdir
        temp && _setup_temp_env!(tmpdir, code_str, packagespecs)

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

function _run_in_current_process(code_str::AbstractString)
    buf = IOBuffer()
    for node in Meta.parseall(code_str).args
        node isa LineNumberNode && continue
        node isa Expr || continue
        ex_str = string(Base.remove_linenums!(deepcopy(node)))
        lines = split(ex_str, '\n')
        print(buf, "julia> ", lines[1], "\n")
        for line in lines[2:end]
            print(buf, "       ", line, "\n")
        end
        val, captured = _capture_eval(node)
        print(buf, captured)
        if val !== nothing
            show(IOContext(buf, :limit => true, :color => false), MIME"text/plain"(), val)
            println(buf)
        end
    end
    return String(take!(buf)), ""
end

# ── Public entry point ─────────────────────────────────────────────────────────

function _run_mwe(
    code_str::AbstractString;
    temp::Bool = true,
    newprocess::Bool = true,
    manifest::Bool = true,
    packagespecs::Vector = Pkg.PackageSpec[],
)
    repl_output, manifest_str = if newprocess
        _run_in_new_process(code_str; temp, manifest, packagespecs)
    else
        _run_in_current_process(code_str)
    end

    md = "```julia\n$repl_output\n```"
    if manifest && !isempty(manifest_str)
        md *= "\n\n<details>\n<summary>Manifest.toml</summary>\n\n```toml\n$manifest_str\n```\n\n</details>"
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
