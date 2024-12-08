using DynamicAutodiff
using Documenter

DocMeta.setdocmeta!(
    DynamicAutodiff, :DocTestSetup, :(using DynamicAutodiff); recursive=true
)

makedocs(;
    modules=[DynamicAutodiff],
    authors="MilesCranmer <miles.cranmer@gmail.com> and contributors",
    sitename="DynamicAutodiff.jl",
    format=Documenter.HTML(;
        canonical="https://MilesCranmer.github.io/DynamicAutodiff.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=["Home" => "index.md"],
)

deploydocs(; repo="github.com/MilesCranmer/DynamicAutodiff.jl", devbranch="main")
