using Test

include("../src/hnswrs.jl")



@testset "Float32-DistL1" begin

    dim = 10
    hnsw = hnswInit(Float32, 8, 16, "DistL1")
    # block // insertion
    datas = rand(Float32, (dim, 500));
    data_insert = map(i -> ( rand(Float32, dim) , UInt(i) ), 1:500)
    parallel_insert(hnsw, data_insert)
    # one insertion
    v = rand(Float32, dim)
    insert(hnsw, v, UInt(501))    
    # testing search
    v1 = rand(Float32, dim)
    neighbours = search(hnsw, v1, 10, 16)
    # testing block // search
    datas = map(i -> rand(Float32, dim), 1:100)
    neighbours = parallel_search(hnsw, datas, 10, 16)

end