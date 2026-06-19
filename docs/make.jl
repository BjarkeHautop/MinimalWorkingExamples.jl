using MinimalWorkingExamples
using Documenter
using Dates: today

DocMeta.setdocmeta!(
    MinimalWorkingExamples,
    :DocTestSetup,
    :(using MinimalWorkingExamples);
    recursive = true,
)

function generate_footer_html(; pinned_note = "")
    date = today()
    version = pkgversion(MinimalWorkingExamples)
    julia_version = VERSION
    extra = isempty(pinned_note) ? "" : " · $pinned_note"
    return """<small>Created on $date with <a href="https://github.com/BjarkeHautop/MinimalWorkingExamples.jl">MinimalWorkingExamples v$version</a> using Julia $julia_version$extra</small>"""
end

function postprocess_html()
    build_dir = joinpath(@__DIR__, "build")

    # Update all HTML files in the build directory
    for (root, dirs, files) in walkdir(build_dir)
        for file in files
            if endswith(file, ".html")
                html_path = joinpath(root, file)
                content = read(html_path, String)

                # Handle the pinned version case first (more specific)
                footer_pinned =
                    generate_footer_html(; pinned_note = "pinned: Example@0.5.3")
                content = replace(
                    content,
                    r"<small>Created on <date> with <a href=\"https://github\.com/BjarkeHautop/MinimalWorkingExamples\.jl\">MinimalWorkingExamples v<version></a> using Julia <julia-version> · pinned: Example@0\.5\.3</small>" =>
                        footer_pinned,
                )

                # Then handle the general case (no pinned note)
                footer = generate_footer_html()
                content = replace(
                    content,
                    r"<small>Created on <date> with <a href=\"https://github\.com/BjarkeHautop/MinimalWorkingExamples\.jl\">MinimalWorkingExamples v<version></a> using Julia <julia-version></small>" =>
                        footer,
                )

                write(html_path, content)
            end
        end
    end
end

# Add titles of sections and overrides page titles
const titles =
    Dict("10-writing-mwes.md" => "Writing MWEs", "91-developer.md" => "Developer docs")

function recursively_list_pages(folder; path_prefix = "")
    pages_list = Any[]
    for file in readdir(folder)
        if file == "index.md"
            # We add index.md separately to make sure it is the first in the list
            continue
        end
        # this is the relative path according to our prefix, not @__DIR__, i.e., relative to `src`
        relpath = joinpath(path_prefix, file)
        # full path of the file
        fullpath = joinpath(folder, relpath)

        if isdir(fullpath)
            # If this is a folder, enter the recursion case
            subsection = recursively_list_pages(fullpath; path_prefix = relpath)

            # Ignore empty folders
            if length(subsection) > 0
                title = if haskey(titles, relpath)
                    titles[relpath]
                else
                    @error "Bad usage: '$relpath' does not have a title set. Fix in 'docs/make.jl'"
                    relpath
                end
                push!(pages_list, title => subsection)
            end

            continue
        end

        if splitext(file)[2] != ".md" # non .md files are ignored
            continue
        elseif haskey(titles, relpath) # case 'title => path'
            push!(pages_list, titles[relpath] => relpath)
        else # case 'title'
            push!(pages_list, relpath)
        end
    end

    return pages_list
end

function list_pages()
    root_dir = joinpath(@__DIR__, "src")
    pages_list = recursively_list_pages(root_dir)

    return ["index.md"; pages_list]
end

makedocs(;
    modules = [MinimalWorkingExamples],
    authors = "Bjarke Hautop Kristensen <bjarke.hautop@gmail.com>",
    repo = "https://github.com/BjarkeHautop/MinimalWorkingExamples.jl/blob/{commit}{path}#{line}",
    sitename = "MinimalWorkingExamples.jl",
    format = Documenter.HTML(;
        canonical = "https://BjarkeHautop.github.io/MinimalWorkingExamples.jl",
        assets = ["assets/gh-output.css"],
        repolink = "https://github.com/BjarkeHautop/MinimalWorkingExamples.jl",
    ),
    pages = list_pages(),
)

postprocess_html()

deploydocs(; repo = "github.com/BjarkeHautop/MinimalWorkingExamples.jl")
