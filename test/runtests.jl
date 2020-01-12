using Hnsw
using Test


ldpath = "/home/jpboth/Rust/hnswlib-rs/target/release/"
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

include("./dumpload.jl")
@testset "dumpreload" begin
    @test testdump()
    @test testreload()
end