push!(LOAD_PATH, "../src/")

DOCUMENTER_DEBUG=true

using Documenter, Hnsw


makedocs(
    format = Documenter.HTML(prettyurls = false),
    sitename = "HnswAnn.jl",
    pages = Any[
        "Introduction" => "INTRO.md",
        "API documentation" => "api.md",
        "Internals" => "internals.md"
    ]
)

