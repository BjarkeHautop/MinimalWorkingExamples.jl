```@meta
CurrentModule = MinimalWorkingExamples
```

# MinimalWorkingExamples.jl

Turn a snippet of Julia code into a shareable, self-contained Markdown block for pasting into a GitHub issue, Discourse post, or Slack message.

Inspired by the R package [reprex](https://reprex.tidyverse.org/).

## Installation

MinimalWorkingExamples can be installed directly from the Julia package manager. In the Julia REPL, press `]`
to enter the Pkg mode, then run:

```julia
pkg> add MinimalWorkingExamples
```

## Basic usage

Write your code in a `begin...end` block and pass it to [`@mwe`](@ref):

```julia
using MinimalWorkingExamples

@mwe begin
    using Statistics
    x = [1, 2, 3, 4, 5]
    mean(x)
end
```

This runs the code as a script in a fresh Julia process with a clean temporary environment, copies the result to your clipboard, and prints it:

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

[`mwe()`](@ref) is the function version of the macro. It accepts the same keyword arguments as `@mwe`.
If `code` is omitted, it reads Julia source from the clipboard:

```julia
# Copy some Julia code to your clipboard, then:
mwe()

# Or pass a string directly:
mwe("""
using Statistics
mean([1, 2, 3])
""")
```

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

If the code throws an error, it is captured and shown as a `#>` comment — execution stops at that line:

```julia
@mwe begin
    x = [1, 2, 3]
    x[10]
    x[1]  # never reached
end
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
</div>
```

Stacktrace can be included by passing `stacktrace=true`:

```julia
@mwe begin
    x = [1, 2, 3]
    x[10]
    x[1]  # never reached
end stacktrace=true
```

Output:

```@raw html
<div class="gh-output">
```

```julia
x = [1, 2, 3]
x[10]
#> ERROR: BoundsError: attempt to access 3-element Vector{Int64} at index [10]
#>
#> Stacktrace:
#>  [1] throw_boundserror(A::Vector{Int64}, I::Tuple{Int64})
#>    @ Base ./essentials.jl:15
#>  [2] getindex(A::Vector{Int64}, i::Int64)
#>    @ Base ./essentials.jl:919
#>  [3] top-level scope
#>    @ none:1
```

```@raw html
<small>Created on <date> with <a href="https://github.com/BjarkeHautop/MinimalWorkingExamples.jl">MinimalWorkingExamples v<version></a> using Julia <julia-version></small>
</div>
```

## Including environment details

Pass `manifest=true` to append the full `Manifest.toml` in a collapsible block, so anyone can reproduce your exact package versions:

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
end packagespecs=[PackageSpec(name="Example", version="0.5.3")]
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
