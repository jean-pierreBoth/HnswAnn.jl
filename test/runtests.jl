using Hnsw
#using Test


ldpath = "/home/jpboth/Rust/hnswlib-rs/target/debug/"
setRustlibPath(ldpath)

using Logging
using Base.CoreLogging

logger = ConsoleLogger(stdout, CoreLogging.Debug)
global_logger(logger)



include("./distf32.jl")
@testset "distf32" begin
    @test testdistl1()
    @test testdistptr()
end

include("./dumpreload.jl")
@testset "dumpreload" begin
    @test testdump()
    @test testreload()
end