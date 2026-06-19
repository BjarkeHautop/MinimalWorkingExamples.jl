# Advanced Settings

MinimalWorkingExamples.jl is designed to make examples reproducible by running them in isolation. The defaults should work for most users and use cases.

Here we explain the advanced settings and when you might want to use them. Since these settings can affect reproducibility, any non-default behavior is noted in the generated footer.

## `newprocess`

By default (`newprocess=true`), the example runs in a separate Julia process and cannot access definitions from your current session.

If you set `newprocess=false`, the example runs in the current Julia session and can access existing definitions:

```julia
f(x) = 2x

@mwe begin
    f(3)
end newprocess=false
```

This is primarily useful for reducing generation time by reusing work already performed in the current session, such as loading large packages.

Since the generated example can depend on session state that is not shown in the MWE, this feature should be used with care when sharing examples.

## `temp`

By default (`temp=true`), a temporary environment is created and packages are installed automatically from the `using` and `import` statements found in the example.

When `temp=false`, the code runs in the current environment without auto-adding packages. This is often faster because it reuses packages from the current environment. However, if the issue depends on specific package versions in your local environment, `temp=true` ensures a fresh environment is used and can help rule out environment-specific behavior.

## `packagespecs`

The main use of `packagespecs` is probably to check if
the development version of the package solves the bug
you encountered

```julia
using Pkg

@mwe begin
    using Example
    Example.hello()
end packagespecs=[
    PackageSpec(url = "https://github.com/JuliaLang/Example.jl")
]
```
