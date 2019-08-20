push!(LOAD_PATH, "../src/")

DOCUMENTER_DEBUG=true

using Documenter, Hnsw


makedocs(
    format = :html,
    sitename = "Hnsw.jl",
    pages = Any[
        "Introduction" => "INTRO.md",
        "RPTree.jl documentation" => "index.md",
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
