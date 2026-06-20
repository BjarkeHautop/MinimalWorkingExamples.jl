# MinimalWorkingExamples.jl

<!-- [![Stable Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://BjarkeHautop.github.io/MinimalWorkingExamples.jl/stable)-->
[![Development documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://BjarkeHautop.github.io/MinimalWorkingExamples.jl/dev)
[![Test workflow status](https://github.com/BjarkeHautop/MinimalWorkingExamples.jl/actions/workflows/Test.yml/badge.svg?branch=main)](https://github.com/BjarkeHautop/MinimalWorkingExamples.jl/actions/workflows/Test.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/BjarkeHautop/MinimalWorkingExamples.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/BjarkeHautop/MinimalWorkingExamples.jl)
[![Lint workflow Status](https://github.com/BjarkeHautop/MinimalWorkingExamples.jl/actions/workflows/Lint.yml/badge.svg?branch=main)](https://github.com/BjarkeHautop/MinimalWorkingExamples.jl/actions/workflows/Lint.yml?query=branch%3Amain)
[![Docs workflow Status](https://github.com/BjarkeHautop/MinimalWorkingExamples.jl/actions/workflows/Docs.yml/badge.svg?branch=main)](https://github.com/BjarkeHautop/MinimalWorkingExamples.jl/actions/workflows/Docs.yml?query=branch%3Amain)
[![BestieTemplate](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/JuliaBesties/BestieTemplate.jl/main/docs/src/assets/badge.json)](https://github.com/JuliaBesties/BestieTemplate.jl)

Turn a snippet of Julia code into a shareable, self-contained Markdown block for pasting into a GitHub issue, Discourse post, or Slack message.

Inspired by the R package [reprex](https://reprex.tidyverse.org/).

## Installation

Not yet registered. Install directly from GitHub:

```julia
using Pkg
Pkg.add(url="https://github.com/BjarkeHautop/MinimalWorkingExamples.jl")
```

## Basic usage

Write your code in a `begin...end` block and pass it to `@mwe`:

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
````

The value of the last expression is shown as `#>`, as are any `print` calls and log messages (`@warn`, `@info`) in the code.

The result is returned as a `MWEResult`, so you can access the Markdown string directly if the clipboard is unavailable:

```julia
result = @mwe begin
    1 + 1
end
print(result.md)  # print the Markdown string
```

`mwe()` is the function version of the macro. If the first argument is not given, code is read from the clipboard.

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

````markdown
```julia
x = [1, 2, 3]
x[10]
#> ERROR: BoundsError: attempt to access 3-element Vector{Int64} at index [10]
```
````

Stacktrace can be included by passing `stacktrace=true`.

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
```

Pinned packages are noted in the footer: `· pinned: Example v0.5.3`.

## Reproducing an exact environment

Pass `manifest_path` to use an existing `Manifest.toml` as-is.

```julia
@mwe begin
    using Example
    Example.hello("World")
end manifest_path="/path/to/your/Manifest.toml"
```

## To do

- Implement a `@mwe_self` or similar so MinimalWorkingExamples can be used
to report bugs about itself easily?

- Support plots like reprex does? (low priority?)
