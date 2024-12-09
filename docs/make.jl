using DynamicDiff
using Documenter

DocMeta.setdocmeta!(DynamicDiff, :DocTestSetup, :(using DynamicDiff); recursive=true)

makedocs(;
    modules=[DynamicDiff],
    authors="MilesCranmer <miles.cranmer@gmail.com> and contributors",
    sitename="DynamicDiff.jl",
    format=Documenter.HTML(;
        canonical="https://MilesCranmer.github.io/DynamicDiff.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=["Home" => "index.md"],
)

deploydocs(; repo="github.com/MilesCranmer/DynamicDiff.jl", devbranch="main")
