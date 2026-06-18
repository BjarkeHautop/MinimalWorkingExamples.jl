@testitem "_extract_packages" tags=[:unit, :fast] begin
    using MinimalWorkingExamples: _extract_packages

    @test _extract_packages("using Foo") == ["Foo"]
    @test _extract_packages("using Foo, Bar") == ["Foo", "Bar"]
    @test _extract_packages("using Foo: bar, baz") == ["Foo"]
    @test _extract_packages("import Foo") == ["Foo"]
    @test _extract_packages("import Foo.Bar") == ["Foo"]

    # stdlib packages should be filtered out
    @test isempty(_extract_packages("using LinearAlgebra\nusing Statistics"))

    # mix of stdlib and external
    @test _extract_packages("using LinearAlgebra\nusing SomeFakePackage123") ==
          ["SomeFakePackage123"]
end

@testitem "newprocess=false: simple arithmetic" tags=[:unit, :fast] begin
    result = MinimalWorkingExamples._run_mwe(
        "2 + 2";
        temp = false,
        newprocess = false,
        manifest = false,
        packagespecs = [],
    )
    @test result isa MinimalWorkingExamples.MWEResult
    @test contains(result.md, "julia> 2 + 2")
    @test contains(result.md, "4")
end

@testitem "newprocess=false: stdout capture" tags=[:unit, :fast] begin
    result = MinimalWorkingExamples._run_mwe(
        """println("hello mwe")""";
        temp = false,
        newprocess = false,
        manifest = false,
        packagespecs = [],
    )
    @test contains(result.md, "julia> println")
    @test contains(result.md, "hello mwe")
end

@testitem "newprocess=false: multiline expression display" tags=[:unit, :fast] begin
    result = MinimalWorkingExamples._run_mwe(
        "function f(x)\nx + 1\nend\nf(3)";
        temp = false,
        newprocess = false,
        manifest = false,
        packagespecs = [],
    )
    @test contains(result.md, "julia> function f(x)")
    @test contains(result.md, "       ")  # continuation indent (7 spaces)
    @test contains(result.md, "julia> f(3)")
    @test contains(result.md, "4")
end

@testitem "newprocess=true: simple arithmetic" tags=[:integration, :slow] begin
    result = MinimalWorkingExamples._run_mwe(
        "1 + 1";
        temp = false,
        newprocess = true,
        manifest = false,
        packagespecs = [],
    )
    @test result isa MinimalWorkingExamples.MWEResult
    @test contains(result.md, "julia> 1 + 1")
    @test contains(result.md, "2")
    @test startswith(result.md, "```julia")
    @test endswith(result.md, "```")
end

@testitem "newprocess=true: multi-expression" tags=[:integration, :slow] begin
    result = MinimalWorkingExamples._run_mwe(
        "x = 42\nx * 2";
        temp = false,
        newprocess = true,
        manifest = false,
        packagespecs = [],
    )
    @test contains(result.md, "julia> x = 42")
    @test contains(result.md, "42")
    @test contains(result.md, "julia> x * 2")
    @test contains(result.md, "84")
end

@testitem "@mwe: basic arithmetic" tags=[:integration, :slow] begin
    result = @mwe begin
        x = 6
        x ^ 2
    end temp=false newprocess=true manifest=false
    @test result isa MWEResult
    @test contains(result.md, "julia> x = 6")
    @test contains(result.md, "julia> x ^ 2")
    @test contains(result.md, "36")
end

@testitem "@mwe: manifest=false omits details block" tags=[:integration, :slow] begin
    result = @mwe begin
        1 + 1
    end temp=false newprocess=true manifest=false
    @test !contains(result.md, "<details>")
    @test !contains(result.md, "Manifest.toml")
end

@testitem "@mwe: manifest=true includes details block" tags=[:integration, :slow] begin
    result = @mwe begin
        using Statistics
        mean([1, 2, 3, 4, 5])
    end temp=true newprocess=true manifest=true
    @test contains(result.md, "julia> using Statistics")
    @test contains(result.md, "3.0")
    @test contains(result.md, "<details>")
    @test contains(result.md, "Manifest.toml")
    @test contains(result.md, "julia_version")
end

@testitem "@mwe: external package (Example.jl)" tags=[:integration, :slow] begin
    result = @mwe begin
        using Example
        Example.hello("World")
    end temp=true newprocess=true manifest=true
    @test result isa MWEResult
    @test contains(result.md, "julia> using Example")
    @test contains(result.md, "julia> Example.hello(\"World\")")
    @test contains(result.md, "Hello, World")
    @test contains(result.md, "<details>")
    @test contains(result.md, "Example")
end
