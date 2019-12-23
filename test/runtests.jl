using Hnsw
using Base.Test

include("../src/hnswrs.jl")

ldpath = "/home/jpboth/Rust/hnswlib-rs/target/debug/"
setRustlibPath(ldpath)

using Logging
using Base.CoreLogging

logger = ConsoleLogger(stdout, CoreLogging.Debug)
global_logger(logger)


function testdump()
    dim = 10
    hnsw = createHnswApi(Float32, 8, 16, "DistL1")
    # block // insertion
    nbinsert = 500
    parallel = true
    if parallel 
        datas = rand(Float32, (dim, nbinsert));
        data_insert = map(i -> ( rand(Float32, dim) , UInt(i) ), 1:size(datas)[2])
        insert(hnsw, data_insert)
    else
        for i in 1:nbinsert
            data = rand(Float32, dim);
            insert(hnsw, data, UInt64(i))
        end       
    end
    #
    res = fileDump(hnsw, "testdumpfromjulia")
    if res > 0
        true
    else
        @warn "file dump failed : " "testdumpfromjulia"
        false
    end
end


function testreload()
    hnsw2 = loadHnsw("testdumpfromjulia", Float32, "DistL1")
end



@testset "distf32" begin
    @test testdistl1()
    @test testdistptr()
end