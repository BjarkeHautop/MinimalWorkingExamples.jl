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

@testitem "plots: failure to save a plot surfaces as #> ERROR" tags=[:unit, :fast] begin
    dir = mktempdir()
    code = """
    struct BadPlot end
    Base.show(io::IO, ::MIME"image/png", ::BadPlot) = error("boom")
    BadPlot()
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
    @test contains(result.md, "#> ERROR: failed to save plot: boom")
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
