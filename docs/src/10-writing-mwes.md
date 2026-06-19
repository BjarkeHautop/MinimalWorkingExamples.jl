# Writing a good MWE

A Minimal Working Example is the single most effective way to get help with a bug or to report one. A good MWE
lets someone else reproduce your problem on the first try, without asking follow-up questions.

MinimalWorkingExamples.jl takes care of running the code and generating Markdown ready to paste into a GitHub issue, Discourse post, or Slack. What it can't do for you is decide *what* code to include. These tips cover that part.

## Make it minimal

Strip away everything that isn't needed to trigger the behaviour.

- Only keep code that is necessary to reproduce the problem. If removing a line changes nothing, remove it.
- Shrink the data. A bug that shows up on a 10,000-row table could probably be reduced to 10 rows.
- Use built-in or generated data (`rand`, `1:5`) instead of files on your disk.

Minimal is not just polite: shrinking the example is often how you find the cause yourself.

## Make it self-contained

!!! note

    By default, [`@mwe`](@ref) and [`mwe`](@ref) run your code in a temporary directory with a fresh Julia process and temporary package environment, not your current REPL session. Anything that only exists in your session will not be available.

Therefore, your snippet must:

- Include every `using`/`import` the code needs. Packages are automatically installed from `using`/`import` statements.
- Don't reference variables, functions, or constants that are defined elsewhere in your session but not in the snippet.

## Make it reproducible

You want the reader to get the *same* result you did.

- Seed any randomness if it affects the result (`using Random; Random.seed!(1405)`), so the output is deterministic.
- If the behaviour is version-specific, pin the packages with `packagespecs`, or attach a full environment with `manifest_path` (see
  [Reproducing an exact environment](@ref)). You can also set `manifest=true` to include the manifest in a collapsible details section of the generated Markdown.

## Make the problem obvious

- Arrange the code so the **final expression** is the surprising part, e.g. a wrong value or an error.
- If the result merely *looks* wrong, say what you expected in the surrounding text.

## Further reading

- [How to make a great R reproducible example](https://stackoverflow.com/q/5963269) — language-agnostic advice that applies just as well to Julia.
