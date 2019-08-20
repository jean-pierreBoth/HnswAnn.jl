push!(LOAD_PATH, "../src/")

DOCUMENTER_DEBUG=true

using Documenter, Hnsw


makedocs(
    format = Documenter.HTML(prettyurls = false),
    sitename = "Hnsw.jl",
    pages = Any[
        "Introduction" => "INTRO.md",
        "API documentation" => "api.md",
        "Internals" => "internals.md"
    ]
)

deploydocs(
    repo = "Hnsw.jl.git",
    target = "build",
    julia = "1.1",
    osname = "linux",
    deps = nothing,
    make = nothing
)
