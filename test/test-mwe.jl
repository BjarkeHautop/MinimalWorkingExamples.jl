# ── Unit tests (internal helpers) ─────────────────────────────────────────────

@testitem "_extract_packages" tags=[:unit, :fast] begin
    using MinimalWorkingExamples: _extract_packages

    @test _extract_packages("using Foo") == ["Foo"]
    @test _extract_packages("using Foo, Bar") == ["Foo", "Bar"]
    @test _extract_packages("using Foo: bar, baz") == ["Foo"]
    @test _extract_packages("import Foo") == ["Foo"]
    @test _extract_packages("import Foo.Bar") == ["Foo"]
    @test _extract_packages("import Foo as Bar") == ["Foo"]
    @test _extract_packages("import Foo: bar as b") == ["Foo"]
    @test isempty(_extract_packages("using LinearAlgebra\nusing Statistics"))
    @test _extract_packages("using LinearAlgebra\nusing SomeFakePackage123") ==
          ["SomeFakePackage123"]
    @test isempty(_extract_packages("using Base.Threads"))
    @test isempty(_extract_packages("import Base.Threads: @threads"))
    @test isempty(_extract_packages("using Core"))
end

# ── newprocess=false (fast, in-process) ───────────────────────────────────────

@testitem "last expression value shown as #>" tags=[:unit, :fast] begin
    result = MinimalWorkingExamples._run_mwe(
        "2 + 2";
        temp = false,
        newprocess = false,
        manifest = false,
        advertise = false,
        packagespecs = [],
    )
    @test result isa MinimalWorkingExamples.MWEResult
    @test contains(result.md, "2 + 2")
    @test contains(result.md, "#> 4")
    @test !contains(result.md, "julia>")
end

@testitem "intermediate expressions produce no #> for return value" tags=[:unit, :fast] begin
    result = MinimalWorkingExamples._run_mwe(
        "x = 42\nx * 2";
        temp = false,
        newprocess = false,
        manifest = false,
        advertise = false,
        packagespecs = [],
    )
    @test contains(result.md, "x = 42")
    @test !contains(result.md, "#> 42")  # not the last expression
    @test contains(result.md, "x * 2")
    @test contains(result.md, "#> 84")   # last expression
end

@testitem "final bare literal shown as #> (in-process)" tags=[:unit, :fast] begin
    result = @mwe begin
        x = 5
        42
    end temp=false newprocess=false manifest=false advertise=false
    @test result isa MWEResult
    @test contains(result.md, "#> 42")   # the literal is the displayed value
    @test !contains(result.md, "#> 5")   # not the assignment's value
end

@testitem "stdout prefixed with #> for all expressions" tags=[:unit, :fast] begin
    result = MinimalWorkingExamples._run_mwe(
        "println(\"hello\")\n1 + 1";
        temp = false,
        newprocess = false,
        manifest = false,
        advertise = false,
        packagespecs = [],
    )
    @test contains(result.md, "#> hello")  # stdout always shown
    @test contains(result.md, "#> 2")      # last value shown
end

@testitem "nothing-returning expressions produce no #>" tags=[:unit, :fast] begin
    result = MinimalWorkingExamples._run_mwe(
        "x = nothing";
        temp = false,
        newprocess = false,
        manifest = false,
        advertise = false,
        packagespecs = [],
    )
    @test contains(result.md, "x = nothing")
    @test !contains(result.md, "#>")
end

@testitem "multiline expression" tags=[:unit, :fast] begin
    result = MinimalWorkingExamples._run_mwe(
        "function f(x)\nx + 1\nend\nf(3)";
        temp = false,
        newprocess = false,
        manifest = false,
        advertise = false,
        packagespecs = [],
    )
    @test contains(result.md, "function f(x)")
    @test !contains(result.md, "#> f (generic function with 1 method)")  # not last
    @test contains(result.md, "f(3)")
    @test contains(result.md, "#> 4")  # last
    @test !contains(result.md, "julia>")
end

@testitem "venue=:gh uses julia language tag" tags=[:unit, :fast] begin
    result = MinimalWorkingExamples._run_mwe(
        "1 + 1";
        temp = false,
        newprocess = false,
        manifest = false,
        advertise = false,
        packagespecs = [],
        venue = :gh,
    )
    @test startswith(result.md, "```julia\n")
end

@testitem "venue=:slack strips language tag" tags=[:unit, :fast] begin
    result = MinimalWorkingExamples._run_mwe(
        "1 + 1";
        temp = false,
        newprocess = false,
        manifest = false,
        advertise = false,
        packagespecs = [],
        venue = :slack,
    )
    @test startswith(result.md, "```\n")
    @test !contains(result.md, "```julia")
end

@testitem "venue=:slack defaults advertise to false" tags=[:unit, :fast] begin
    result = MinimalWorkingExamples._run_mwe(
        "1 + 1";
        temp = false,
        newprocess = false,
        manifest = false,
        packagespecs = [],
        venue = :slack,
    )
    @test !contains(result.md, "<sup>")
end

@testitem "venue=:gh defaults advertise to true" tags=[:unit, :fast] begin
    result = MinimalWorkingExamples._run_mwe(
        "1 + 1";
        temp = false,
        newprocess = false,
        manifest = false,
        packagespecs = [],
        venue = :gh,
    )
    @test contains(result.md, "<sup>")
end

@testitem "venue=:discord uses julia language tag" tags=[:unit, :fast] begin
    result = MinimalWorkingExamples._run_mwe(
        "1 + 1";
        temp = false,
        newprocess = false,
        manifest = false,
        advertise = false,
        packagespecs = [],
        venue = :discord,
    )
    @test startswith(result.md, "```julia\n")
end

@testitem "venue=:discord uses -# subtext for advertise note" tags=[:unit, :fast] begin
    result = MinimalWorkingExamples._run_mwe(
        "1 + 1";
        temp = false,
        newprocess = false,
        manifest = false,
        packagespecs = [],
        venue = :discord,
    )
    @test contains(result.md, "\n-# Created on")
    @test !contains(result.md, "<sup>")
end

@testitem "footer note: in-process when newprocess=false" tags=[:unit, :fast] begin
    result = MinimalWorkingExamples._run_mwe(
        "1 + 1";
        temp = false,
        newprocess = false,
        manifest = false,
        advertise = true,
        packagespecs = [],
    )
    @test contains(result.md, "in-process")
end

@testitem "footer note: pinned packages" tags=[:unit, :fast] begin
    using Pkg
    result = MinimalWorkingExamples._run_mwe(
        "1 + 1";
        temp = false,
        newprocess = false,
        manifest = false,
        advertise = true,
        packagespecs = [PackageSpec(name = "Example", version = "0.5.3")],
    )
    @test contains(result.md, "pinned:")
    @test contains(result.md, "Example v0.5.3")
end

@testitem "footer note: from existing Manifest.toml" tags=[:unit, :fast] begin
    manifest_file = tempname() * ".toml"
    write(manifest_file, "# placeholder")
    try
        result = MinimalWorkingExamples._run_mwe(
            "1 + 1";
            temp = false,
            newprocess = false,
            manifest = false,
            advertise = true,
            packagespecs = [],
            manifest_path = manifest_file,
        )
        @test contains(result.md, "from existing Manifest.toml")
    finally
        rm(manifest_file; force = true)
    end
end

@testitem "advertise=true appends footer" tags=[:unit, :fast] begin
    result = MinimalWorkingExamples._run_mwe(
        "1 + 1";
        temp = false,
        newprocess = false,
        manifest = false,
        advertise = true,
        packagespecs = [],
    )
    @test contains(result.md, "MinimalWorkingExamples.jl")
    @test contains(result.md, "v" * string(pkgversion(MinimalWorkingExamples)))
    @test contains(result.md, string(VERSION))
    @test contains(result.md, "<sup>")
end

@testitem "advertise=false omits footer" tags=[:unit, :fast] begin
    result = MinimalWorkingExamples._run_mwe(
        "1 + 1";
        temp = false,
        newprocess = false,
        manifest = false,
        advertise = false,
        packagespecs = [],
    )
    @test !contains(result.md, "<sup>")
end

@testitem "versioninfo=true appends environment block" tags=[:unit, :fast] begin
    result = MinimalWorkingExamples._run_mwe(
        "1 + 1";
        temp = false,
        newprocess = false,
        manifest = false,
        advertise = false,
        packagespecs = [],
        versioninfo = true,
    )
    @test contains(result.md, "<details>")
    @test contains(result.md, "Environment")
    @test contains(result.md, "Julia Version")
    @test contains(result.md, string(VERSION))
end

@testitem "venue=:gh defaults versioninfo to true" tags=[:unit, :fast] begin
    result = MinimalWorkingExamples._run_mwe(
        "1 + 1";
        temp = false,
        newprocess = false,
        manifest = false,
        advertise = false,
        packagespecs = [],
        venue = :gh,
    )
    @test contains(result.md, "<details>\n<summary>Environment</summary>")
end

@testitem "venue=:discord defaults versioninfo to false" tags=[:unit, :fast] begin
    result = MinimalWorkingExamples._run_mwe(
        "1 + 1";
        temp = false,
        newprocess = false,
        manifest = false,
        advertise = false,
        packagespecs = [],
        venue = :discord,
    )
    @test !contains(result.md, "Environment")
end

@testitem "venue=:slack defaults versioninfo to false" tags=[:unit, :fast] begin
    result = MinimalWorkingExamples._run_mwe(
        "1 + 1";
        temp = false,
        newprocess = false,
        manifest = false,
        advertise = false,
        packagespecs = [],
        venue = :slack,
    )
    @test !contains(result.md, "Environment")
end

@testitem "versioninfo=true overrides false default for :slack" tags=[:unit, :fast] begin
    result = MinimalWorkingExamples._run_mwe(
        "1 + 1";
        temp = false,
        newprocess = false,
        manifest = false,
        advertise = false,
        packagespecs = [],
        venue = :slack,
        versioninfo = true,
    )
    @test contains(result.md, "Environment")
end

@testitem "julia_args passes flags through to the subprocess" tags=[:unit, :fast] begin
    result = MinimalWorkingExamples._run_mwe(
        "Base.JLOptions().check_bounds";
        temp = false,
        newprocess = true,
        manifest = false,
        advertise = false,
        packagespecs = [],
        julia_args = "--check-bounds=no",
    )
    @test contains(result.md, "#> 2")  # 2 == "no", 0 would be the default
end

@testitem "julia_args requires newprocess=true" tags=[:unit, :fast] begin
    @test_throws ErrorException MinimalWorkingExamples._run_mwe(
        "1 + 1";
        temp = false,
        newprocess = false,
        manifest = false,
        advertise = false,
        packagespecs = [],
        julia_args = "--check-bounds=no",
    )
end

@testitem "temp=true with newprocess=false work with pkgs" tags=[:integration, :slow] begin
    result = MinimalWorkingExamples._run_mwe(
        "using Example\nExample.hello(\"World\")";
        temp = true,
        newprocess = false,
        manifest = false,
        advertise = false,
        packagespecs = [],
    )
    @test contains(result.md, "using Example")
    @test contains(result.md, "Example.hello(\"World\")")
    @test contains(result.md, "#> ")
    @test contains(result.md, "Hello, World")
end

# ── error handling ────────────────────────────────────────────────────────────

@testitem "parse error shown cleanly as #> ERROR:" tags=[:unit, :fast] begin
    result = MinimalWorkingExamples._run_mwe(
        "1 +* 2";   # invalid syntax → Meta.parseall returns an :error node
        temp = false,
        newprocess = false,
        manifest = false,
        advertise = false,
        packagespecs = [],
    )
    @test contains(result.md, "#> ERROR:")
    @test !contains(result.md, "Expr(:error")   # no raw Expr repr in output
end

@testitem "error shown as #> ERROR:" tags=[:unit, :fast] begin
    result = MinimalWorkingExamples._run_mwe(
        """error("something went wrong")""";
        temp = false,
        newprocess = false,
        manifest = false,
        advertise = false,
        packagespecs = [],
    )
    @test contains(result.md, "#> ERROR:")
    @test contains(result.md, "something went wrong")
end

@testitem "@warn captured as #>" tags=[:unit, :fast] begin
    result = MinimalWorkingExamples._run_mwe(
        "@warn \"something fishy\"";
        temp = false,
        newprocess = false,
        manifest = false,
        advertise = false,
        packagespecs = [],
    )
    @test contains(result.md, "#> ")
    @test contains(result.md, "Warning")
    @test contains(result.md, "something fishy")
end

@testitem "@info captured as #>" tags=[:unit, :fast] begin
    result = MinimalWorkingExamples._run_mwe(
        "@info \"all good\"";
        temp = false,
        newprocess = false,
        manifest = false,
        advertise = false,
        packagespecs = [],
    )
    @test contains(result.md, "#> ")
    @test contains(result.md, "Info")
    @test contains(result.md, "all good")
end

@testitem "@warn in function body: no #= ... =# in output" tags=[:unit, :fast] begin
    code = """
    function my_warn_function()
        @warn "This is a warning"
    end
    my_warn_function()
    1 + 1
    my_warn_function()
    2 + 2
    """
    result = MinimalWorkingExamples._run_mwe(
        code;
        temp = false,
        newprocess = false,
        manifest = false,
        advertise = false,
        packagespecs = [],
    )
    @test !contains(result.md, "#=")          # no LineNumberNode annotations
    @test contains(result.md, "@warn \"This is a warning\"")
    @test count("#> ┌ Warning: This is a warning", result.md) == 2  # fires twice
    @test contains(result.md, "#> 4")          # last expression value shown
end

@testitem "stacktrace=true includes Stacktrace in error output" tags=[:unit, :fast] begin
    result = @mwe begin
        error("oops");
    end temp=false newprocess=false manifest=false advertise=false stacktrace=true
    @test contains(result.md, "#> ERROR:")
    @test contains(result.md, "oops")
    @test contains(result.md, "Stacktrace")
    # Driver/runtime infrastructure frames should be stripped
    @test !contains(result.md, "mwe_driver.jl")
    @test !contains(result.md, "invokelatest")
    @test !contains(result.md, "with_logger")
end

@testitem "stacktrace=false (default) omits Stacktrace" tags=[:unit, :fast] begin
    result = MinimalWorkingExamples._run_mwe(
        """error("oops")""";
        temp = false,
        newprocess = false,
        manifest = false,
        advertise = false,
        packagespecs = [],
        stacktrace = false,
    )
    @test contains(result.md, "#> ERROR:")
    @test contains(result.md, "oops")
    @test !contains(result.md, "Stacktrace")
end

@testitem "error stops execution of subsequent expressions" tags=[:unit, :fast] begin
    result = MinimalWorkingExamples._run_mwe(
        "error(\"oops\")\n1 + 1";
        temp = false,
        newprocess = false,
        manifest = false,
        advertise = false,
        packagespecs = [],
    )
    @test contains(result.md, "#> ERROR:")
    @test !contains(result.md, "#> 2")
end

# ── mwe() function form ───────────────────────────────────────────────────────

@testitem "manifest_path and packagespecs are mutually exclusive" tags=[:unit, :fast] begin
    using Pkg
    @test_throws "mutually exclusive" mwe(
        "1 + 1";
        manifest_path = "/nonexistent/Manifest.toml",
        packagespecs = [PackageSpec(name = "Example")],
    )
end

@testitem "mwe() with explicit string" tags=[:unit, :fast] begin
    result = mwe("x = 7\nx * 3"; temp = false, newprocess = false, advertise = false)
    @test result isa MWEResult
    @test contains(result.md, "x = 7")
    @test contains(result.md, "#> 21")
end

@testitem "mwe() with comments are preserved" tags=[:unit, :fast] begin
    result = mwe("x = 7 # Set x to 7\nx * 3 # Multiply x by 3"; advertise = false)
    @test result isa MWEResult
    @test contains(result.md, "x = 7")
    @test contains(result.md, "Set x to 7")
    @test contains(result.md, "x * 3")
    @test contains(result.md, "Multiply x by 3")
    @test contains(result.md, "#> 21")
end

# ── _describe_packagespec ──────────────────────────────────────────────────────

@testitem "_describe_packagespec" tags=[:unit, :fast] begin
    using Pkg
    using MinimalWorkingExamples: _describe_packagespec

    @test _describe_packagespec(PackageSpec(name = "Foo", version = "1.2.3")) ==
          "Foo v1.2.3"
    @test _describe_packagespec(PackageSpec(name = "Foo")) == "Foo"
    @test _describe_packagespec(PackageSpec(name = "Foo", rev = "main")) == "Foo#main"
end

# ── sandbox isolation ─────────────────────────────────────────────────────────

@testitem "sandbox: subprocess LOAD_PATH excludes global environment" tags=[
    :integration,
    :slow,
] begin
    result = MinimalWorkingExamples._run_mwe(
        "println(Base.LOAD_PATH)";
        temp = true,
        newprocess = true,
        manifest = false,
        advertise = false,
        packagespecs = [],
    )
    @test !contains(result.md, "@v")
end

# ── newprocess=true (subprocess) ──────────────────────────────────────────────

@testitem "newprocess=true: error shown as #> ERROR:" tags=[:integration, :slow] begin
    result = MinimalWorkingExamples._run_mwe(
        """error("subprocess error")""";
        temp = false,
        newprocess = true,
        manifest = false,
        advertise = false,
        packagespecs = [],
    )
    @test contains(result.md, "#> ERROR:")
    @test contains(result.md, "subprocess error")
end

@testitem "newprocess=true: basic output" tags=[:integration, :slow] begin
    result = MinimalWorkingExamples._run_mwe(
        "x = 42\nx * 2";
        temp = false,
        newprocess = true,
        manifest = false,
        advertise = false,
        packagespecs = [],
    )
    @test result isa MinimalWorkingExamples.MWEResult
    @test contains(result.md, "x = 42")
    @test !contains(result.md, "#> 42")
    @test contains(result.md, "x * 2")
    @test contains(result.md, "#> 84")
    @test startswith(result.md, "```julia")
end

# ── @mwe macro tests ──────────────────────────────────────────────────────────

@testitem "@mwe: basic reprex output" tags=[:integration, :slow] begin
    result = @mwe begin
        x = 6
        x ^ 2
    end temp=false newprocess=true manifest=false advertise=false
    @test result isa MWEResult
    @test contains(result.md, "x = 6")
    @test !contains(result.md, "#> 6")
    @test contains(result.md, "x ^ 2")
    @test contains(result.md, "#> 36")
    @test !contains(result.md, "julia>")
end

@testitem "@mwe: final bare literal shown as #> (newprocess)" tags=[:integration, :slow] begin
    result = @mwe begin
        x = 5
        42
    end temp=false newprocess=true manifest=false advertise=false
    @test result isa MWEResult
    @test contains(result.md, "#> 42")
    @test !contains(result.md, "#> 5")
end

@testitem "@mwe: manifest=false omits details block" tags=[:integration, :slow] begin
    result = @mwe begin
        1 + 1
    end temp=false newprocess=true manifest=false advertise=false versioninfo=false
    @test !contains(result.md, "<details>")
    @test !contains(result.md, "Manifest.toml")
end

@testitem "@mwe: manifest=true includes details block" tags=[:integration, :slow] begin
    result = @mwe begin
        using Statistics
        mean([1, 2, 3, 4, 5])
    end temp=true newprocess=true manifest=true advertise=false
    @test contains(result.md, "using Statistics")
    @test contains(result.md, "#> 3.0")
    @test contains(result.md, "<details>")
    @test contains(result.md, "Manifest.toml")
    @test contains(result.md, "julia_version")
end

@testitem "@mwe: external package (Example.jl)" tags=[:integration, :slow] begin
    result = @mwe begin
        using Example
        Example.hello("World")
    end temp=true newprocess=true manifest=true advertise=false
    @test result isa MWEResult
    @test contains(result.md, "using Example")
    @test contains(result.md, """Example.hello("World")""")
    @test contains(result.md, "#> ")
    @test contains(result.md, "Hello, World")
    @test contains(result.md, "<details>")
    @test contains(result.md, "Example")
end

@testitem "@mwe: packagespecs pins a specific version" tags=[:integration, :slow] begin
    using Pkg
    result = @mwe begin
        using Example
        Example.hello("World")
    end temp=true newprocess=true manifest=true advertise=false packagespecs=[
        PackageSpec(name = "Example", version = "0.5.3"),
    ]
    @test result isa MWEResult
    @test contains(result.md, "Hello, World")
    @test contains(result.md, "0.5.3")   # pinned version appears in Manifest
end

@testitem "@mwe: packagespecs works with url" tags=[:integration, :slow] begin
    using Pkg
    url = "https://github.com/JuliaLang/Example.jl"
    result = @mwe begin
        using Example
        Example.hello("World")
    end packagespecs=[PackageSpec(url = url)]
    @test result isa MWEResult
    @test contains(result.md, "Hello, World")
    @test contains(result.md, url)
end

@testitem "@mwe: manifest_path reproduces exact environment" tags=[:integration, :slow] begin
    using Pkg
    ref_dir = mktempdir()
    try
        Pkg.activate(ref_dir; io = devnull)
        Pkg.add(PackageSpec(name = "Example", version = "0.5.3"); io = devnull)
        manifest_file = joinpath(ref_dir, "Manifest.toml")
        result = @mwe begin
            using Example
            Example.hello("World")
        end temp=true newprocess=true manifest=true advertise=false manifest_path=manifest_file
        @test result isa MWEResult
        @test contains(result.md, "Hello, World")
        @test contains(result.md, "0.5.3")   # exact version from the manifest
    finally
        Pkg.activate(; io = devnull)   # restore default env
        rm(ref_dir; recursive = true)
    end
end

@testitem "@mwe: imported package with alias" tags=[:integration, :slow] begin
    result = @mwe begin
        import Statistics: mean as my_mean
        x = [1, 2, 3]
        my_mean(x)
    end
    @test result isa MWEResult
    @test contains(result.md, "import Statistics: mean as my_mean")
    @test contains(result.md, "my_mean(x)")
    @test contains(result.md, "#> 2.0")

    result = @mwe begin
        import Statistics as Stats
        x = [1, 2, 3]
        Stats.mean(x)
    end
    @test result isa MWEResult
    @test contains(result.md, "import Statistics as Stats")
    @test contains(result.md, "Stats.mean(x)")
    @test contains(result.md, "#> 2.0")
end

@testitem "MWEResult: String conversion" tags=[:unit, :fast] begin
    using MinimalWorkingExamples: MWEResult
    result = MWEResult("test markdown content")
    @test String(result) == "test markdown content"
end

@testitem "MWEResult: show method for text/plain" tags=[:unit, :fast] begin
    using MinimalWorkingExamples: MWEResult
    result = MWEResult("test content")
    buf = IOBuffer()
    show(buf, MIME"text/plain"(), result)
    # The show method returns nothing, so buffer should be empty
    @test String(take!(buf)) == ""
end

@testitem "MWEResult: show method outputs markdown" tags=[:unit, :fast] begin
    using MinimalWorkingExamples: MWEResult
    result = MWEResult("```julia\n1 + 1\n#> 2\n```")
    buf = IOBuffer()
    show(buf, result)
    @test contains(String(take!(buf)), "1 + 1")
end

@testitem "_describe_packagespec: version pinning" tags=[:unit, :fast] begin
    using Pkg
    using MinimalWorkingExamples: _describe_packagespec
    spec = Pkg.PackageSpec(name = "Example", version = "0.5.3")
    desc = _describe_packagespec(spec)
    @test desc == "Example v0.5.3"
end

@testitem "_describe_packagespec: git revision" tags=[:unit, :fast] begin
    using Pkg
    using MinimalWorkingExamples: _describe_packagespec
    spec = Pkg.PackageSpec(name = "Example", rev = "master")
    desc = _describe_packagespec(spec)
    @test desc == "Example#master"
end

@testitem "_describe_packagespec: URL" tags=[:unit, :fast] begin
    using Pkg
    using MinimalWorkingExamples: _describe_packagespec
    spec = Pkg.PackageSpec(url = "https://github.com/JuliaLang/Example.jl")
    desc = _describe_packagespec(spec)
    @test contains(desc, "Example")
    @test contains(desc, "github.com")
end

@testitem "_describe_packagespec: local path" tags=[:unit, :fast] begin
    using Pkg
    using MinimalWorkingExamples: _describe_packagespec
    spec = Pkg.PackageSpec(path = "/path/to/Example.jl")
    desc = _describe_packagespec(spec)
    @test desc == "Example (local)"
end

@testitem "_spec_name: from name field" tags=[:unit, :fast] begin
    using Pkg
    using MinimalWorkingExamples: _spec_name
    spec = Pkg.PackageSpec(name = "Example")
    @test _spec_name(spec) == "Example"
end

@testitem "_spec_name: from URL" tags=[:unit, :fast] begin
    using Pkg
    using MinimalWorkingExamples: _spec_name
    spec = Pkg.PackageSpec(url = "https://github.com/JuliaLang/Example.jl")
    @test _spec_name(spec) == "Example"
end

@testitem "_spec_name: from path" tags=[:unit, :fast] begin
    using Pkg
    using MinimalWorkingExamples: _spec_name
    spec = Pkg.PackageSpec(path = "/path/to/Example.jl")
    @test _spec_name(spec) == "Example"
end

@testitem "footer includes 'current environment' note when temp=false" tags=[:unit, :fast] begin
    result = MinimalWorkingExamples._run_mwe(
        "1 + 1";
        temp = false,
        newprocess = false,
        manifest = false,
        advertise = true,
    )
    @test contains(result.md, "current environment")
end

# ── plot capture ──────────────────────────────────────────────────────────────

@testitem "plots: image link inserted at plot position (in-process)" tags=[:unit, :fast] begin
    dir = mktempdir()
    code = """
    struct FakePlotA end
    Base.show(io::IO, ::MIME"image/png", ::FakePlotA) = write(io, UInt8[0x89, 0x50, 0x4E, 0x47])
    1 + 1
    FakePlotA()
    2 + 2
    """
    result = MinimalWorkingExamples._run_mwe(
        code;
        temp = false,
        newprocess = false,
        manifest = false,
        advertise = false,
        versioninfo = false,
        plot_dir = dir,
    )
    path = joinpath(dir, "plot-1.png")
    @test isfile(path)
    @test read(path) == UInt8[0x89, 0x50, 0x4E, 0x47]
    link = replace(path, '\\' => '/')
    @test contains(
        result.md,
        "FakePlotA()\n```\n\n**Insert plot here: $link**\n\n```julia\n2 + 2",
    )
    @test contains(result.md, "#> 4")
    @test !contains(result.md, "__MWE_PLOT__")
end

@testitem "plots: explicit display() captured at position (in-process)" tags=[:unit, :fast] begin
    dir = mktempdir()
    code = """
    struct FakePlotB end
    Base.show(io::IO, ::MIME"image/png", ::FakePlotB) = write(io, UInt8[0x01])
    display(FakePlotB())
    2 + 2
    """
    result = MinimalWorkingExamples._run_mwe(
        code;
        temp = false,
        newprocess = false,
        manifest = false,
        advertise = false,
        versioninfo = false,
        plot_dir = dir,
    )
    path = joinpath(dir, "plot-1.png")
    @test isfile(path)
    link = replace(path, '\\' => '/')
    @test contains(
        result.md,
        "display(FakePlotB())\n```\n\n**Insert plot here: $link**\n\n```julia\n2 + 2",
    )
end

@testitem "plots: trailing semicolon suppresses capture" tags=[:unit, :fast] begin
    dir = mktempdir()
    code = """
    struct FakePlotC end
    Base.show(io::IO, ::MIME"image/png", ::FakePlotC) = write(io, UInt8[0x01])
    p = FakePlotC();
    2 + 2
    """
    result = MinimalWorkingExamples._run_mwe(
        code;
        temp = false,
        newprocess = false,
        manifest = false,
        advertise = false,
        versioninfo = false,
        plot_dir = dir,
    )
    @test isempty(readdir(dir))
    @test !contains(result.md, "Insert plot here")
    @test contains(result.md, "#> 4")
end

@testitem "plots: final plot value shows image instead of text repr" tags=[:unit, :fast] begin
    dir = mktempdir()
    code = """
    struct FakePlotD end
    Base.show(io::IO, ::MIME"image/png", ::FakePlotD) = write(io, UInt8[0x01])
    FakePlotD()
    """
    result = MinimalWorkingExamples._run_mwe(
        code;
        temp = false,
        newprocess = false,
        manifest = false,
        advertise = false,
        versioninfo = false,
        plot_dir = dir,
    )
    path = joinpath(dir, "plot-1.png")
    @test isfile(path)
    @test !contains(result.md, "#> FakePlotD()")
    link = replace(path, '\\' => '/')
    @test endswith(rstrip(result.md), "**Insert plot here: $link**")
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

@testitem "plots: capture works in subprocess (newprocess=true)" tags=[:integration, :slow] begin
    dir = mktempdir()
    code = """
    struct FakePlotG end
    Base.show(io::IO, ::MIME"image/png", ::FakePlotG) = write(io, UInt8[0x89, 0x50])
    1 + 1
    FakePlotG()
    2 + 2
    """
    result = MinimalWorkingExamples._run_mwe(
        code;
        temp = false,
        newprocess = true,
        manifest = false,
        advertise = false,
        versioninfo = false,
        plot_dir = dir,
    )
    path = joinpath(dir, "plot-1.png")
    @test isfile(path)
    @test read(path) == UInt8[0x89, 0x50]
    link = replace(path, '\\' => '/')
    @test contains(
        result.md,
        "FakePlotG()\n```\n\n**Insert plot here: $link**\n\n```julia\n2 + 2",
    )
    @test contains(result.md, "#> 4")
end

# Configurable defaults

@testitem "defaults reflects built-in fallbacks" tags=[:unit, :fast] begin
    using MinimalWorkingExamples: _DEFAULTS, _defaults
    d = _defaults()
    @test keys(d) == keys(_DEFAULTS)
end

@testitem "set_defaults! validates keys and values" tags=[:unit, :fast] begin
    @test_throws ArgumentError set_defaults!()
    @test_throws ArgumentError set_defaults!(bogus = 1)
    @test_throws ArgumentError set_defaults!(venue = :nope)
end

@testitem "set_defaults! overrides defaults and clears back" tags=[:unit, :fast] begin
    # Preferences.jl always leaves a LocalPreferences.toml behind (even a "cleared"
    # preference is recorded, not deleted), so remove it if this test is what created it.
    prefs_path = joinpath(dirname(Base.active_project()), "LocalPreferences.toml")
    existed_before = isfile(prefs_path)
    try
        set_defaults!(venue = :slack, temp = false)
        @test MinimalWorkingExamples._defaults().venue == :slack
        @test MinimalWorkingExamples._defaults().temp == false

        r = MinimalWorkingExamples._run_mwe("1 + 1"; newprocess = false, advertise = false)
        @test !contains(r.md, "```julia")

        r2 = mwe("1 + 1"; venue = :gh, newprocess = false, temp = false, advertise = false)
        @test contains(r2.md, "```julia")
    finally
        set_defaults!(venue = nothing, temp = nothing)
        existed_before || rm(prefs_path; force = true)
    end
    @test MinimalWorkingExamples._defaults().venue == :gh
    @test MinimalWorkingExamples._defaults().temp == true
end
