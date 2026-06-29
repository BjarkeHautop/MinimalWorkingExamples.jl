# MinimalWorkingExamples.jl

[![Stable Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://BjarkeHautop.github.io/MinimalWorkingExamples.jl/stable)
[![Development documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://BjarkeHautop.github.io/MinimalWorkingExamples.jl/dev)
[![Test workflow status](https://github.com/BjarkeHautop/MinimalWorkingExamples.jl/actions/workflows/Test.yml/badge.svg?branch=main)](https://github.com/BjarkeHautop/MinimalWorkingExamples.jl/actions/workflows/Test.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/BjarkeHautop/MinimalWorkingExamples.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/BjarkeHautop/MinimalWorkingExamples.jl)
[![Lint workflow Status](https://github.com/BjarkeHautop/MinimalWorkingExamples.jl/actions/workflows/Lint.yml/badge.svg?branch=main)](https://github.com/BjarkeHautop/MinimalWorkingExamples.jl/actions/workflows/Lint.yml?query=branch%3Amain)
[![Docs workflow Status](https://github.com/BjarkeHautop/MinimalWorkingExamples.jl/actions/workflows/Docs.yml/badge.svg?branch=main)](https://github.com/BjarkeHautop/MinimalWorkingExamples.jl/actions/workflows/Docs.yml?query=branch%3Amain)
[![BestieTemplate](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/JuliaBesties/BestieTemplate.jl/main/docs/src/assets/badge.json)](https://github.com/JuliaBesties/BestieTemplate.jl)

Turn a snippet of Julia code into a shareable, self-contained Markdown block for pasting into a GitHub issue, Discourse post, or Slack message.

Inspired by the R package [reprex](https://reprex.tidyverse.org/).

## Installation

MinimalWorkingExamples can be installed directly from the Julia package manager. In the Julia REPL, press `]`
to enter the Pkg mode, then run:

```julia
pkg> add MinimalWorkingExamples
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

`mwe` is the function version of the macro. If the first argument is not given, code is read from the clipboard:

```julia
# Run code from clipboard
mwe()
```

## Contributing

Contributions of all kinds are welcome!

The package is still evolving, so feedback on defaults and output format is especially valuable. If you have an idea for improving the generated output or the user experience, please open an issue.
