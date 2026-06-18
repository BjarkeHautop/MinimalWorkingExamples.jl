# ── Unit tests (internal helpers) ─────────────────────────────────────────────

@testitem "_extract_packages" tags=[:unit, :fast] begin
    using MinimalWorkingExamples: _extract_packages

    @test _extract_packages("using Foo") == ["Foo"]
    @test _extract_packages("using Foo, Bar") == ["Foo", "Bar"]
    @test _extract_packages("using Foo: bar, baz") == ["Foo"]
    @test _extract_packages("import Foo") == ["Foo"]
    @test _extract_packages("import Foo.Bar") == ["Foo"]
    @test isempty(_extract_packages("using LinearAlgebra\nusing Statistics"))
    @test _extract_packages("using LinearAlgebra\nusing SomeFakePackage123") ==
          ["SomeFakePackage123"]
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
    @test !contains(result.md, "MinimalWorkingExamples.jl")
    @test !contains(result.md, "<sup>")
end

# ── newprocess=true (subprocess) ──────────────────────────────────────────────

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
    @test endswith(result.md, "```")
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

@testitem "@mwe: manifest=false omits details block" tags=[:integration, :slow] begin
    result = @mwe begin
        1 + 1
    end temp=false newprocess=true manifest=false advertise=false
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

@testitem "@mwe: manifest_path reproduces exact environment" tags=[:integration, :slow] begin
    using Pkg
    # Build a reference environment with Example 0.5.3 to get a known Manifest.toml
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
