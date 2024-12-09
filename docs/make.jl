using DynamicDiff
using Documenter

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
    pages=["Home" => "index.md"],
)

deploydocs(; repo="github.com/MilesCranmer/DynamicDiff.jl.git")

# Mirror to DAMTP
ENV["DOCUMENTER_KEY"] = ENV["DOCUMENTER_KEY_CAM"]
ENV["GITHUB_REPOSITORY"] = "ai-damtp-cam-ac-uk/dynamicdiff.git"
deploydocs(; repo="github.com/ai-damtp-cam-ac-uk/dynamicdiff.git")
