using Hnsw
using Test

include("../src/hnswrs.jl")




function testdistl1()
    dim = 10
    hnsw = createHnswApi(Float32, 8, 16, "DistL1")
    # block // insertion
    datas = rand(Float32, (dim, 500));
    data_insert = map(i -> ( rand(Float32, dim) , UInt(i) ), 1:size(datas)[2])
    parallel_insert(hnsw, data_insert)
    # one insertion
    v = rand(Float32, dim)
    one_insert(hnsw, v, UInt(501))    
    # testing search
    v1 = rand(Float32, dim)
    neighbours = one_search(hnsw, v1, 10, 16)
    # testing block // search
    datas = map(i -> rand(Float32, dim), 1:100)
    neighbours = parallel_search(hnsw, datas, 10, 16)
    true
end


#  rust calling so length will be passes as a usize.

function mydist(pa::Ptr{Float32}, pb::Ptr{Float32}, l::UInt64)
#    println("in mydist")
    #
   dist = 0
    #   
    va = unsafe_wrap(Array{Float32,1}, pa, NTuple{1,Int64}(Int64(l)); own = false)
    vb = unsafe_wrap(Array{Float32,1}, pb, NTuple{1,Int64}(Int64(l)); own = false)
    for i in  1:l
        dist += abs(va[i] - vb[i])
    end
    return Float32(dist)
end


mydist_ptr = Base.@cfunction(mydist, Cfloat, (Ptr{Cfloat}, Ptr{Cfloat}, Culonglong))


# test only serial insertion/search until julia 1.3

function testdistptr()
    dim = 10
    hnsw = hnswInit(Float32, 8, 16, mydist_ptr)
    # block // insertion
    nbinsert = 100
    for i in 1:nbinsert
        data = rand(Float32, dim);
        one_insert(hnsw, data, UInt64(i))
    end
    # testing search
    println("testing one search")
    v1 = rand(Float32, dim)
    neighbours = one_search(hnsw, v1, 10, 16)
    true
end


function testdump()
    dim = 10
    hnsw = createHnswApi(Float32, 8, 16, "DistL1")
    # block // insertion
    datas = rand(Float32, (dim, 500));
    data_insert = map(i -> ( rand(Float32, dim) , UInt(i) ), 1:size(datas)[2])
    insert(hnsw, data_insert)
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
    hnsw = loadHnsw("testdumpfromjulia", Float32, "DistL1")
end



@testset "f32" begin
    @test testdistl1()
    @test testdistptr()
end