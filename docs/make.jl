using DynamicDiff
using Documenter

readme = joinpath(@__DIR__, "..", "README.md")
index_content = let r = read(readme, String)
    # Wrap img tags in raw HTML blocks:
    r = replace(r, r"(<img\s+[^>]+>)" => s"""

```@raw html
\1
```

""")
    # Remove end img tags:
    r = replace(r, r"</img>" => "")
    # Remove div tags:
    r = replace(r, r"<div[^>]*>" => "")
    # Remove end div tags:
    r = replace(r, r"</div>" => "")

    top_part = """
    # Introduction

    """

    bottom_part = """
    ## Contents

    """

    join((top_part, r, bottom_part), "\n")
end

index_md = joinpath(@__DIR__, "src", "index.md")
open(index_md, "w") do f
    write(f, index_content)
end

DocMeta.setdocmeta!(DynamicDiff, :DocTestSetup, :(using DynamicDiff); recursive=true)

makedocs(;
    modules=[DynamicDiff],
    authors="MilesCranmer <miles.cranmer@gmail.com> and contributors",
    clean=true,
    sitename="DynamicDiff.jl",
    format=Documenter.HTML(;
        canonical="https://ai.damtp.cam.ac.uk/dynamicdiff/stable",
        edit_link="main",
        assets=String[],
    ),
    pages=["Home" => "index.md", "API" => "api.md"],
)

ENV["GITHUB_REPOSITORY"] = "ai-damtp-cam-ac-uk/dynamicdiff.git"
deploydocs(; repo="github.com/ai-damtp-cam-ac-uk/dynamicdiff.git")
