
module Hnsw

using Printf

include("hnswrs.jl")

export 
    Neighbour,
    Neighbourhood,
    HnswApi,
    createHnswApi,
    setRustlibPath,
    insert,
    search,
    fileDump,
    HnswDescription,
    getDescription,
    loadHnsw

"""

# HnswApi

This is the structure encapsulting the rust api.

## FIELDS
 -------

* rust : a reference pointer coming from rust library. An opaque structure not to be manipulated.

* type : The type of Vector

* maxNbConn : The number of connection to use in Hnsw structure. Between 8 and 64.

* efConstruction : The with of neighbours search used when constructing links between nodes.
    A rule of thumb is between maxNbConn and 64.

* distname : the name o the distance to use. It can be "DistL1", "DistL2", "DistCosine", DistDot", 
        "DistHamming", "DistJaccard" or "DistPtr"

* A pointer to a function computing distances created by the macro @cfunction.
    The signature of the function must be Cfloat, (Ptr{Cfloat}, Ptr{Cfloat}, Culonglong)).
    
    See the testdistptr function in test.jl and the documentation of @cfunction.

"""
mutable struct HnswApi
    rust :: Ref{Hnswrs}
    type :: DataType
    maxNbConn::Int64
    efConstruction::Int64
    distname::String
    distfunctPtr :: Union{ Some{Ptr{Cvoid}} , Nothing }
end


"""
  #  `function createHnswApi(type::DataType, maxNbConn::Int64, efConstruction::Int64, distname::String)`

  This function creates a standard HnswApi with pre-coded distances. 
  It benefits from parallel insert/search method
    
"""
function createHnswApi(type::DataType, maxNbConn::Int64, efConstruction::Int64, distname::String)
    rust_type_name = checkForImplementedType(type)
    rust = hnswInit(type, maxNbConn, efConstruction, distname)
    HnswApi(rust, type, maxNbConn, efConstruction, distname, nothing)
end

"""
# ` function createHnswApi(type::DataType, maxNbConn::Int64, efConstruction::Int64, distance::Ptr{Cvoid}) `

Create a HnswApi with a custom distance function pointer. In this case the name of the distance 
is set to "CustomPtr"
* CAUTION:
It must be noted that as Julia (for version < 1.3) is not thread safe this api cannot use
parallel insertion/search in this case although it seems to run in Julia 1.2

"""
function createHnswApi(type::DataType, maxNbConn::Int64, efConstruction::Int64, distance::Ptr{Cvoid})
    rust_type_name = checkForImplementedType(type)
    rust = hnswInit(type, maxNbConn, distance)
    # we store distance to avoid garbage collection of pointer as it is referenced in rust library.
    HnswApi(rust, type, maxNbConn, efConstruction, "CustomPtr", Some(distance))
end




"""
 #  insert 

 `function insert(hnsw::HnswApi, data::Vector{T}, id::UInt64) where {T <: Number}`

## Args
  
- data: the data vector to insert in struct hnsw
- id: the (unique) id of data. Can be the rank of insertion or any hash value enabling
        identification of point for possible dump/restore of the whole hnsw structure
"""
function insert(hnsw::HnswApi, data::Vector{T}, id::UInt64) where {T <: Number}
    one_insert(hnsw.rust, data, id)
end


"""
# parallel insertion

`function insert(hnsw::HnswApi, datas::Vector{Tuple{Vector{T}, UInt}}) where {T <: Number}`

This function does a block parallel insertion of datas in structure.

## Args
----
- datas: a vector of insertion request as a Tuple associating the point to insert and its id.
"""
function insert(hnsw::HnswApi, datas::Vector{Tuple{Vector{T}, UInt}}) where {T <: Number}
    parallel_insert(hnsw.rust, datas)
end


"""
# search

` function search(hnsw::Hnsw, vector::Vector{T}, knbn::Int64, ef_search ::Int64) where {T<:Number}`

 ## Args
 
- The vector for which we search neighbours
- knbn : the number of neughbour we search
- ef_search : the search parameter.

"""
function search(hnsw::HnswApi, vector::Vector{T}, knbn::Int64, ef_search ::Int64) where {T<:Number}
    one_search(hnsw.rust, vector, knbn, ef_search)
end


"""

# parallel search

`function search(hnsw::Hnsw , datas::Vector{Vector{T}}, knbn::Int64, ef_search:: Int64) where {T<:Number}`

As for insertion this function is instersting if we batch sufficiently many request. (some hundreds)

##  Args

- datas : The vector of point we search the neighbours of.
- knbn the number of neighbours wanted.
- ef_search : parameter search.
"""
function search(hnsw::HnswApi , datas::Vector{Vector{T}}, knbn::Int64, ef_search:: Int64) where {T<:Number}
    parallel_search(hnsw.rust, datas, knbn, ef_search)
end



"""
# `function fileDump(hnsw::HnswApi,  filename::String)`

Returns 1 if OK , -1 if failure.
`function fileDump(hnsw::HnswApi,  filename::String)`

This dumps the whole data in the structure in 2 binary files:
- one file has name obtained by appending ".hnsw.graph" to filename and contains the graph structure of Hnsw
- the other file has name obtained by appending ".hnsw.data" to filename and contains for each data vector 
    inserted in the hnsw structure the couple id , data vector 
"""
function fileDump(hnsw::HnswApi,  filename::String)
    res = filedump(hnsw.rust, hnsw.type, filename)
    res
end


end # module
