```@meta
CurrentModule = MinimalWorkingExamples
```

# MinimalWorkingExamples.jl

Turn a snippet of Julia code into a shareable, self-contained Markdown block for pasting into a GitHub issue, Discourse post, or Slack message.

Inspired by the R package [reprex](https://reprex.tidyverse.org/).

## Installation

MinimalWorkingExamples can be installed directly from the Julia package manager. In the Julia REPL, press `]` to enter the Pkg mode, then run:

```julia
pkg> add MinimalWorkingExamples
```

## Basic usage

The quickest way: copy your code to the clipboard, then call [`mwe()`](@ref) with no arguments:

```julia
using MinimalWorkingExamples

mwe()
```

Or write your code in a `begin...end` block and pass it to [`@mwe`](@ref) directly:

```julia
@mwe begin
    using Statistics
    x = [1, 2, 3, 4, 5]
    mean(x)
end
```

!!! note

    Generally [`mwe()`](@ref) is the better choice: it preserves your code's exact formatting and comments, and all you need to do is copy the code and call it. [`@mwe`](@ref) strips comments and requires a `begin...end` block, but is more convenient to show inline, so most examples in this documentation use it.

Either way, this runs the code as a script in a fresh Julia process with a clean temporary environment, copies the result to your clipboard, and shows a preview of the rendered
Markdown:

```@raw html
<div class="gh-output">
```

```julia
using Statistics
x = [1, 2, 3, 4, 5]
mean(x)
#> 3.0
```

```@raw html
<small>Created on <date> with <a href="https://github.com/BjarkeHautop/MinimalWorkingExamples.jl">MinimalWorkingExamples v<version></a> using Julia <julia-version></small>

<details>
<summary>Environment</summary>
<pre><mwe-versioninfo></pre>
</details>
</div>
```

The value of the last expression is shown as `#>`, as are any `print` calls and log messages (`@warn`, `@info`) in the code.

The result is returned as a [`MWEResult`](@ref), so you can access the Markdown string directly if the clipboard is unavailable:

```julia
result = @mwe begin
    1 + 1
end
print(result.md)  # print the Markdown string
```

[`mwe()`](@ref) and [`@mwe`](@ref) accept the same keyword arguments.

## Venue

The `venue` keyword controls the output format. Use `:gh` (default) for GitHub, Discourse, and other
platforms that render GitHub-Flavored Markdown, `:discord` for Discord, and `:slack` for Slack.

```julia
@mwe begin
    1 + 1
end venue=:slack
```

`:discord` matches `:gh` but renders the attribution footer using Discord's `-#` subtext syntax instead of `<sup>`.

`:slack` strips the language identifier from the code fence (Slack doesn't render language-tagged fences) and omits the attribution footer.

## Errors

If the code throws an error, it is captured and shown as a `#>` comment. The stacktrace is included in a collapsible block below the code:

```julia
@mwe begin
    x = [1, 2, 3]
    x[10]
end versioninfo=false
```

Output:

```@raw html
<div class="gh-output">
```

```julia
x = [1, 2, 3]
x[10]
#> ERROR: BoundsError: attempt to access 3-element Vector{Int64} at index [10]
```

```@raw html
<small>Created on <date> with <a href="https://github.com/BjarkeHautop/MinimalWorkingExamples.jl">MinimalWorkingExamples v<version></a> using Julia <julia-version></small>

<details>
<summary>Stacktrace</summary>

```

```julia
 [1] throw_boundserror(A::Vector{Int64}, I::Tuple{Int64})
   @ Base ./essentials.jl:15
 [2] getindex(A::Vector{Int64}, i::Int64)
   @ Base ./essentials.jl:919
 [3] top-level scope
   @ none:1
```

```@raw html
</details>
</div>
```

## Plots

Any plot produced while running the code is saved as a PNG file and replaced in the Markdown with a
`**Insert plot here: <path>**` placeholder at the position it was produced. Files land in the
`plot_dir` directory (default `MWEPlots/`, created next to your working directory); upload them
alongside the generated Markdown.

Copy the following code, taken from the [Plots.jl documentation](https://docs.juliaplots.org/stable/#), and call `mwe()` on it; this is the output:

```@raw html
<div class="gh-output">
```

```julia
# load a dataset
using RDatasets
iris = dataset("datasets", "iris");

# load the StatsPlots recipes (for DataFrames) available via:
# Pkg.add("StatsPlots")
using StatsPlots

# Scatter plot with some custom settings
@df iris scatter(
    :SepalLength,
    :SepalWidth,
    group = :Species,
    title = "My awesome plot",
    xlabel = "Length",
    ylabel = "Width",
    m = (0.5, [:cross :hex :star7], 12),
    bg = RGB(0.2, 0.2, 0.2)
)
```

MWEPLOTPLACEHOLDER

```@raw html
<small>Created on <date> with <a href="https://github.com/BjarkeHautop/MinimalWorkingExamples.jl">MinimalWorkingExamples v<version></a> using Julia <julia-version></small>

<details>
<summary>Environment</summary>
<pre><mwe-versioninfo></pre>
</details>
</div>
```

## Including environment details

Two independent, opt-in-or-out blocks can be appended after the code:

- `versioninfo`: appends the output of `versioninfo()` in a collapsible "Environment" block. Defaults to
  `true` for `:gh`, and `false` for `:discord` and
  `:slack`, since collapsible `<details>` blocks aren't rendered outside
  GitHub-Flavored Markdown.
- `manifest=false`: pass `manifest=true` to append the full `Manifest.toml` in a collapsible block,
  so anyone can reproduce your exact package versions. Same caveat about `<details>` rendering
  applies for `:discord`/`:slack`.

```julia
@mwe begin
    using DataFrames
    df = DataFrame(a = 1:3, b = ["x", "y", "z"])
    df
end manifest=true
```

## Pinning a specific package version

Use `packagespecs` to pin one or more packages to a particular version, git revision, or URL.

```julia
using Pkg

@mwe begin
    using Example
    Example.hello("World")
end packagespecs=[PackageSpec(name="Example", version="0.5.3")] versioninfo=false
```

Output:

```@raw html
<div class="gh-output">
```

```julia
using Example
Example.hello("World")
#> "Hello, World!"
```

```@raw html
<small>Created on <date> with <a href="https://github.com/BjarkeHautop/MinimalWorkingExamples.jl">MinimalWorkingExamples v<version></a> using Julia <julia-version> · pinned: Example v0.5.3</small>
</div>
```

For more details on packagespecs options see [`Pkg.PackageSpec` documentation](https://pkgdocs.julialang.org/v1/api/#Pkg.PackageSpec).

## Reproducing an exact environment

Pass `manifest_path` to use an existing `Manifest.toml` as-is.

```julia
@mwe begin
    using Example
    Example.hello("World")
end manifest_path="/path/to/your/Manifest.toml"
```
