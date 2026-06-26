# Advanced Settings

Almost all defaults can be changed by using [`set_defaults!`](@ref):

```julia
using MinimalWorkingExamples
set_defaults!(venue=:slack, temp=false)
```

MinimalWorkingExamples.jl is designed to produce reproducible examples by running them in isolation. The settings described below provide more advanced control over this behaviour. Because these settings can affect reproducibility, any non-default values are recorded in the generated footer.

## `newprocess`

By default (`newprocess=true`), the example runs in a separate Julia process and cannot access definitions from your current session. Additionally, user startup files are disabled in this fresh process.

If you set `newprocess=false`, the example runs in the current Julia session and can access existing definitions:

```julia
f(x) = 2x

@mwe begin
    f(3)
end newprocess=false
```

This is primarily useful for reducing generation time by reusing work already performed in the current session.

Since the generated example can depend on session state that is not shown in the MWE, this feature should be used with care when sharing examples.

## `temp`

By default (`temp=true`), a temporary environment is created and packages are installed automatically from the `using` and `import` statements found in the example.

When `temp=false`, the code runs in the current environment without auto-adding packages, hence avoiding the installation and compiling of packages. However, if the issue depends on specific package versions in your local environment, `temp=true` ensures a fresh environment is used and can help rule out environment-specific behaviour.

## `packagespecs`

The main use of `packagespecs` is to test a development version of a package, for example, to check whether it fixes a bug:

```julia
using Pkg

@mwe begin
    using Example
    Example.hello()
end packagespecs=[
    PackageSpec(url = "https://github.com/JuliaLang/Example.jl")
]
```

or to showcase new behaviour for your PR:

```julia
using Pkg

@mwe begin
    using Example
    Example.hello()
end packagespecs=[
    PackageSpec(url = "https://github.com/YourUsername/Example.jl", rev = "my-new-feature")
]
```
