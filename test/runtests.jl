using HnswAnn
using Test


ldpath = "/home.1/jpboth/Rust/hnswlib-rs/target/debug/"
setRustlibPath(ldpath)

using Logging
using Base.CoreLogging

logger = ConsoleLogger(stdout, CoreLogging.Debug)
global_logger(logger)



include("distf32.jl")
@testset "distf32" begin
    @test testdistl1()
    @test testdistptr()
end

include("dumpload.jl")
@testset "dumpreload" begin
    @test testdump()
    @test testreload()
end