
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
    v1 = [0.5 for i in 1:dim]
    neighbours = search(hnsw, v1, 8, 16)
    @info " 0.5 vector neighbours list : " neighbours
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
    v1 = [0.5 for i in 1:dim]
    neighbours = search(hnsw2, v1, 8, 16)
    @info " 0.5 vector neighbours list : " neighbours
    true
end

