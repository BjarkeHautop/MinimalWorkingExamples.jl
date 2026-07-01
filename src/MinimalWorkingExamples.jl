module MinimalWorkingExamples

using Dates: today
using Logging
using Pkg
using InteractiveUtils: clipboard, versioninfo as interactive_versioninfo
using Preferences: load_preference, set_preferences!

export @mwe, MWEResult, mwe, set_defaults!

const _DEFAULTS = (
    venue = :gh,
    temp = true,
    newprocess = true,
    manifest = false,
    advertise = nothing,
    verbose = false,
    stacktrace = false,
    versioninfo = false,
    julia_args = "",
)

function _default(key::Symbol)
    haskey(_DEFAULTS, key) || error("unknown default $(repr(key))")
    stored = load_preference(MinimalWorkingExamples, String(key))
    isnothing(stored) && return _DEFAULTS[key]
    key === :venue && return Symbol(stored)
    return stored
end

_defaults() = (; (k => _default(k) for k in keys(_DEFAULTS))...)

"""
    set_defaults!(; kwargs...)

Persistently override the default keyword arguments of [`@mwe`](@ref) and
[`mwe`](@ref) using [Preferences.jl](https://github.com/JuliaPackaging/Preferences.jl).

Any of `venue`, `temp`, `newprocess`, `manifest`, `advertise`, `verbose`,
`stacktrace`, `versioninfo`, and `julia_args` may be set. Passing `nothing` for a key clears it,
reverting to the built-in default.

# Examples

```julia
# Always format for Slack and skip the isolated environment:
set_defaults!(venue=:slack, temp=false)

# Go back to the built-in venue default:
set_defaults!(venue=nothing)
```
"""
function set_defaults!(; kwargs...)
    isempty(kwargs) && throw(
        ArgumentError(
            "Provide at least one default to set, e.g. `set_defaults!(venue=:slack)`",
        ),
    )

    prefs = Pair{String,Any}[]

    for (k, v) in kwargs
        haskey(_DEFAULTS, k) || throw(
            ArgumentError(
                "`$k` is not a configurable default; choose from: $(join(keys(_DEFAULTS), ", "))",
            ),
        )

        if isnothing(v)
            push!(prefs, String(k) => nothing)  # delete -> revert to built-in

        elseif k === :venue
            (v === :gh || v === :discord || v === :slack) || throw(
                ArgumentError("venue must be :gh, :discord or :slack, got $(repr(v))"),
            )

            push!(prefs, String(k) => String(v))

        else
            push!(prefs, String(k) => v)
        end
    end

    set_preferences!(MinimalWorkingExamples, prefs...; force = true)

    @info "Defaults updated."
    return nothing
end

"""
    @mwe begin
        code
    end [venue=:gh] [temp=true] [newprocess=true] [manifest=false] [advertise=nothing]
        [packagespecs=PackageSpec[]] [manifest_path=nothing] [verbose=false] [stacktrace=false]
        [versioninfo=false] [julia_args=""]

Generate a Minimal Working Example (MWE) formatted as Markdown, then copy it to the clipboard.

The code is rendered as a copy-pasteable Julia script with the output of the final expression
(and any `print`/logging calls) shown as `#>` comments.

# Keyword arguments
- `venue=:gh`: output format — `:gh` for GitHub-Flavored Markdown (default), `:discord` for Discord
  (same as `:gh` but the advertisement note uses Discord's `-# ` subtext syntax instead of `<sup>`),
  `:slack` for Slack (strips the language identifier from the code fence).
- `temp=true`: create a temporary isolated environment and auto-add packages from `using`/`import`.
  When `false`, code runs in the current environment without auto-adding packages (to avoid
  polluting the user's project).
- `newprocess=true`: run the MWE in a fresh Julia process; startup files are disabled to ensure
  reproducibility. If `newprocess=false`, the MWE runs in the current session. If also `temp=true`,
  a temporary project is activated for the execution and then restored.
- `manifest=false`: append the `Manifest.toml` in a collapsible `<details>` block.
- `advertise`: append a footer noting the date, this package, and Julia version used.
  Defaults to `false` for `:slack` and `true` otherwise; can be set explicitly to override.
- `packagespecs=PackageSpec[]`: vector of [`Pkg.PackageSpec`](https://pkgdocs.julialang.org/v1/api/#Pkg.PackageSpec)s for packages that need a specific
  version, git revision, URL, or local path.
- `manifest_path=nothing`: path to an existing `Manifest.toml` to use as-is.
  Mutually exclusive with `packagespecs`.
- `verbose=false`: if `true`, show Pkg output (downloads, resolver messages) during environment
  setup.
- `stacktrace=false`: if `true`, append the full stacktrace after the error message.
- `versioninfo=false`: if `true`, append a collapsible "Environment" block showing the output
  of `versioninfo()`.
- `julia_args=""`: extra command-line flags passed through to the isolated Julia process, e.g.
  `"-t 4"` or `"--check-bounds=no"`. Only valid when `newprocess=true`.

!!! note
    Comments in the code block are not preserved in the output. Use [`mwe`](@ref) if you need to preserve comments.

!!! tip
    The defaults above (except `packagespecs` and `manifest_path`) can be changed
    persistently with [`set_defaults!`](@ref).

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

    # Forward only the keyword arguments the user actually wrote; `_run_mwe`
    # supplies the rest from the (possibly user-configured) defaults.
    params = Expr(:parameters)
    for kwarg in kwargs
        if kwarg isa Expr && kwarg.head == :(=)
            push!(params.args, Expr(:kw, kwarg.args[1], esc(kwarg.args[2])))
        end
    end

    return Expr(:call, :(MinimalWorkingExamples._run_mwe), params, code_str)
end

"""
    mwe([code]; venue=:gh, temp=true, newprocess=true, manifest=false, advertise=nothing,
               packagespecs=PackageSpec[], manifest_path=nothing, verbose=false, stacktrace=false,
               versioninfo=false, julia_args="")

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

# Comments are preserved:
mwe(\"""
1+1 # This comment is preserved
\""")
```
"""
function mwe(
    code::AbstractString = clipboard();
    venue::Symbol = _default(:venue),
    temp::Bool = _default(:temp),
    newprocess::Bool = _default(:newprocess),
    manifest::Bool = _default(:manifest),
    advertise::Union{Bool,Nothing} = _default(:advertise),
    packagespecs::Vector = Pkg.PackageSpec[],
    manifest_path::Union{AbstractString,Nothing} = nothing,
    verbose::Bool = _default(:verbose),
    stacktrace::Bool = _default(:stacktrace),
    versioninfo::Bool = _default(:versioninfo),
    julia_args::AbstractString = _default(:julia_args),
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
        versioninfo,
        julia_args,
    )
end

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
    name in ("Base", "Core", "Main") && return true
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

function _spec_name(spec::Pkg.PackageSpec)
    n = try
        spec.name
    catch
        ;
        nothing
    end
    !isnothing(n) && !isempty(n) && return n
    src = try
        spec.url
    catch
        ;
        nothing
    end
    if isnothing(src)
        src = try
            spec.path
        catch
            ;
            nothing
        end
    end
    isnothing(src) && return nothing
    base = basename(rstrip(src, '/'))
    return endswith(base, ".jl") ? base[1:(end-3)] : base
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

    name = let n = _spec_name(spec);
        isnothing(n) ? "?" : n
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
        "$name v$v_str"
    elseif !isnothing(rev)
        "$name#$rev"
    elseif !isnothing(url)
        "$name ($url)"
    elseif !isnothing(path) && !isempty(path)
        "$name (local)"
    else
        name
    end
end

# ── Driver script ──────────────────────────────────────────────────────────────

function _build_driver_script(
    code_str::AbstractString;
    stacktrace::Bool = false,
    versioninfo_path::Union{AbstractString,Nothing} = nothing,
)
    versioninfo_stmt = isnothing(versioninfo_path) ? "" : """
    using InteractiveUtils
    open($(repr(versioninfo_path)), "w") do _mwe_vio
        InteractiveUtils.versioninfo(_mwe_vio)
    end
    """
    return """
    using Logging

    function _mwe_prefix_output(str)
        isempty(str) && return
        for line in split(rstrip(str, '\\n'), '\\n')
            println("#> ", line)
        end
    end

    const _mwe_code = $(repr(code_str))
    const _mwe_src_lines = split(_mwe_code, '\\n')

    # Pair each expression with its start line from LineNumberNodes
    _mwe_items = Tuple{Int,Any}[]
    let _cur_line = 1
        for _n in Meta.parseall(_mwe_code).args
            if _n isa LineNumberNode
                _cur_line = _n.line
            else
                push!(_mwe_items, (_cur_line, _n))
            end
        end
    end

    for (i, (_mwe_start, _mwe_node)) in enumerate(_mwe_items)
        if _mwe_node isa Expr && _mwe_node.head === :error
            _mwe_prefix_output("ERROR: " * sprint(showerror, _mwe_node.args[1]))
            break
        end
        _mwe_end = i < length(_mwe_items) ? _mwe_items[i + 1][1] - 1 : length(_mwe_src_lines)
        println(rstrip(join(_mwe_src_lines[_mwe_start:_mwe_end], '\\n')))

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
        if i == length(_mwe_items) && _mwe_val !== nothing
            _mwe_buf = IOBuffer()
            show(IOContext(_mwe_buf, :limit => true, :color => false), MIME"text/plain"(), _mwe_val)
            _mwe_prefix_output(String(take!(_mwe_buf)))
        end
    end
    $versioninfo_stmt
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
    install_names = String[]

    if !isnothing(manifest_path)
        cp(manifest_path, joinpath(tmpdir, "Manifest.toml"))
        setup_script = "using Pkg\nPkg.instantiate()\n"
    else
        packages = _extract_packages(code_str)

        spec_names = Set(filter(!isnothing, _spec_name.(packagespecs)))
        packages = filter(p -> p ∉ spec_names, packages)

        append!(install_names, packages)
        append!(install_names, filter(!isnothing, _spec_name.(packagespecs)))

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
        "JULIA_LOAD_PATH" => join(["@", "@stdlib"], Sys.iswindows() ? ";" : ":"),
    )
    if isempty(install_names)
        @info "Instantiating environment..."
    else
        @info "Installing packages: $(join(install_names, ", "))..."
    end
    verbose ? run(cmd) : run(pipeline(cmd; stdout = devnull, stderr = devnull))
    @info "Running code..."
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
    versioninfo::Bool = false,
    julia_args::AbstractString = "",
)
    mktempdir() do tmpdir
        temp && _setup_temp_env!(tmpdir, code_str, packagespecs, manifest_path; verbose)

        versioninfo_path = versioninfo ? joinpath(tmpdir, "mwe_versioninfo.txt") : nothing
        script_path = joinpath(tmpdir, "mwe_driver.jl")
        write(script_path, _build_driver_script(code_str; stacktrace, versioninfo_path))

        julia_exe = joinpath(Sys.BINDIR, Base.julia_exename())
        project_flag = temp ? "--project=$tmpdir" : "--project=@."
        extra_flags = Cmd(Base.shell_split(julia_args))
        cmd = `$julia_exe $project_flag --startup-file=no $extra_flags -q $script_path`
        temp && (
            cmd = addenv(
                cmd,
                "JULIA_LOAD_PATH" =>
                    join(["@", "@stdlib"], Sys.iswindows() ? ";" : ":"),
            )
        )

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

        env_str = ""
        if !isnothing(versioninfo_path) && isfile(versioninfo_path)
            env_str = rstrip(read(versioninfo_path, String), '\n')
        end

        return repl_output, manifest_str, env_str
    end
end

struct CapturedError{E,B<:Vector}
    exception::E
    backtrace::B
end

struct EvalResult{V,E<:Union{Nothing,CapturedError}}
    value::V
    stdout::String
    stderr::String
    error::E
end

function _capture_eval(ex)
    original_out = Base.stdout
    original_err = Base.stderr
    rd_out, wr_out = redirect_stdout()
    rd_err, wr_err = redirect_stderr()
    local val = nothing
    local captured_error = nothing
    try
        val = Logging.with_logger(Logging.ConsoleLogger(wr_err, Logging.Info)) do
            Base.invokelatest(Core.eval, Main, ex)
        end
    catch e
        captured_error = CapturedError(e, catch_backtrace())
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
    return EvalResult(val, captured_out, captured_err, captured_error)
end

function _prefix_lines(io::IO, str::AbstractString, prefix::AbstractString)
    isempty(str) && return
    for line in split(rstrip(str, '\n'), '\n')
        println(io, prefix, line)
    end
end

# Keep only frames above the Core.eval boundary — everything below is driver
# or REPL infrastructure irrelevant to the user's code.
function _user_frames(bt::Vector)
    frames = Base.stacktrace(bt)
    cutoff = findfirst(f -> f.func === :eval && endswith(String(f.file), "boot.jl"), frames)
    return isnothing(cutoff) ? frames : frames[1:(cutoff-1)]
end

function _format_error(ce::CapturedError; stacktrace::Bool = false)
    stacktrace || return sprint(showerror, ce.exception)
    frames = _user_frames(ce.backtrace)
    st = isempty(frames) ? "" : "\n" * sprint(Base.show_backtrace, frames)
    return sprint(showerror, ce.exception) * st
end

function _execute_code_in_current_process(
    code_str::AbstractString;
    stacktrace::Bool = false,
)
    buf = IOBuffer()
    src_lines = split(code_str, '\n')
    items = Tuple{Int,Any}[]
    let cur_line = 1
        for n in Meta.parseall(code_str).args
            if n isa LineNumberNode
                cur_line = n.line
            else
                push!(items, (cur_line, n))
            end
        end
    end
    for (i, (start_line, node)) in enumerate(items)
        if node isa Expr && node.head === :error
            _prefix_lines(buf, "ERROR: " * sprint(showerror, node.args[1]), "#> ")
            break
        end
        end_line = i < length(items) ? items[i+1][1] - 1 : length(src_lines)
        ex_str = rstrip(join(src_lines[start_line:end_line], '\n'))
        result = _capture_eval(node)
        println(buf, ex_str)
        _prefix_lines(buf, result.stdout, "#> ")
        _prefix_lines(buf, result.stderr, "#> ")
        err = result.error
        if !isnothing(err)
            _prefix_lines(buf, "ERROR: " * _format_error(err; stacktrace), "#> ")
            break
        end
        if i == length(items) && result.value !== nothing
            val_buf = IOBuffer()
            show(
                IOContext(val_buf, :limit => true, :color => false),
                MIME"text/plain"(),
                result.value,
            )
            _prefix_lines(buf, String(take!(val_buf)), "#> ")
        end
    end
    return rstrip(String(take!(buf)), '\n')
end

function _run_in_current_process(
    code_str::AbstractString;
    temp::Bool = false,
    packagespecs::Vector = Pkg.PackageSpec[],
    manifest_path::Union{AbstractString,Nothing} = nothing,
    verbose::Bool = false,
    stacktrace::Bool = false,
    versioninfo::Bool = false,
)
    env_str() = versioninfo ? rstrip(sprint(interactive_versioninfo), '\n') : ""
    if temp
        mktempdir() do tmpdir
            _setup_temp_env!(tmpdir, code_str, packagespecs, manifest_path; verbose)
            original_project = Base.active_project()
            try
                Pkg.activate(tmpdir)
                output = _execute_code_in_current_process(code_str; stacktrace)
                return output, "", env_str()
            finally
                if isnothing(original_project)
                    Pkg.activate()
                else
                    Pkg.activate(original_project)
                end
            end
        end
    else
        return _execute_code_in_current_process(code_str; stacktrace), "", env_str()
    end
end

# ── Public entry point ─────────────────────────────────────────────────────────

function _run_mwe(
    code_str::AbstractString;
    venue::Symbol = _default(:venue),
    temp::Bool = _default(:temp),
    newprocess::Bool = _default(:newprocess),
    manifest::Bool = _default(:manifest),
    advertise::Union{Bool,Nothing} = _default(:advertise),
    packagespecs::Vector = Pkg.PackageSpec[],
    manifest_path::Union{AbstractString,Nothing} = nothing,
    verbose::Bool = _default(:verbose),
    stacktrace::Bool = _default(:stacktrace),
    versioninfo::Bool = _default(:versioninfo),
    julia_args::AbstractString = _default(:julia_args),
)
    venue in (:gh, :discord, :slack) ||
        error("venue must be :gh, :discord or :slack, got $(repr(venue))")
    if !isnothing(manifest_path) && !isempty(packagespecs)
        error("`manifest_path` and `packagespecs` are mutually exclusive; pass only one")
    end
    if !isempty(julia_args) && !newprocess
        error(
            "`julia_args` requires `newprocess=true`; there is no subprocess to pass flags to",
        )
    end
    _advertise = isnothing(advertise) ? (venue !== :slack) : advertise

    repl_output, manifest_str, env_str = if newprocess
        _run_in_new_process(
            code_str;
            temp,
            manifest,
            packagespecs,
            manifest_path,
            verbose,
            stacktrace,
            versioninfo,
            julia_args,
        )
    else
        _run_in_current_process(
            code_str;
            temp,
            packagespecs,
            manifest_path,
            verbose,
            stacktrace,
            versioninfo,
        )
    end

    lang = venue === :slack ? "" : "julia"
    md = "```$lang\n$repl_output\n```"
    if _advertise
        notes = String[]
        !newprocess && push!(notes, "in-process")
        !temp && push!(notes, "current environment")
        if !isnothing(manifest_path)
            push!(notes, "from existing Manifest.toml")
        elseif !isempty(packagespecs)
            push!(notes, "pinned: " * join(_describe_packagespec.(packagespecs), ", "))
        end
        extra = isempty(notes) ? "" : " · " * join(notes, " · ")
        note = "Created on $(today()) with [MinimalWorkingExamples v$(pkgversion(MinimalWorkingExamples))](https://github.com/BjarkeHautop/MinimalWorkingExamples.jl) using Julia $VERSION$extra"
        md *= venue === :discord ? "\n\n-# $note" : "\n\n<sup>$note</sup>"
    end
    if versioninfo && !isempty(env_str)
        md *= "\n\n<details>\n<summary>Environment</summary>\n\n```text\n$env_str\n```\n\n</details>"
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
