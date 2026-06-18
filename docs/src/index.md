```@meta
CurrentModule = MinimalWorkingExamples
```

# MinimalWorkingExamples.jl

Turn a snippet of Julia code into a shareable, self-contained Markdown block — ready to paste into a GitHub issue, Discourse post, or Slack message. Inspired by the R package [reprex](https://reprex.tidyverse.org/).

## Installation

Not yet registered. Install directly from GitHub:

```julia
using Pkg
Pkg.add(url="https://github.com/BjarkeHautop/MinimalWorkingExamples.jl")
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

````markdown
```julia
using Statistics
x = [1, 2, 3, 4, 5]
mean(x)
#> 3.0
```

<sup>Created on <date> with [MinimalWorkingExamples v<pkg-version>](https://github.com/BjarkeHautop/MinimalWorkingExamples.jl) using Julia <version></sup>
````

The value of the last expression is shown as `#>`, as are any `print`/`println` calls and log messages (`@warn`, `@info`) in the code.

The result is returned as a [`MWEResult`](@ref), so you can access the Markdown string directly if the clipboard is unavailable:

```julia
result = @mwe begin
    1 + 1
end
print(result.md)  # print the Markdown string
```

[`mwe()`](@ref) is the function version of the macro. If the first argument is not given, code is read from the clipboard.

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

# Pin to a specific version
@mwe begin
    using Example
    Example.hello("World")
end packagespecs=[PackageSpec(name="Example", version="0.5.3")]

# Use a PR branch directly from GitHub
@mwe begin
    using MyPackage
    MyPackage.new_feature()
end packagespecs=[PackageSpec(url="https://github.com/user/MyPackage.jl", rev="my-fix-branch")]
```

Pinned packages are noted in the footer: `· pinned: Example@0.5.3`.

## Reproducing an exact environment

Pass `manifest_path` to use an existing `Manifest.toml` as-is.

```julia
@mwe begin
    using Example
    Example.hello("World")
end manifest_path="/path/to/your/Manifest.toml"
```
