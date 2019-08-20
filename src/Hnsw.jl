
module Hnsw

using Printf

include("hnswrs.jl")

export 
    Neighbour,
    Neighbourhood,
    HnswApi,
    setRustlibPath,
    insert,
    search


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
        "DistHamming", "DistJaccard"
"""
mutable struct HnswApi
    rust :: Ref{Hnswrs}
    type :: DataType
    maxNbConn::Int64
    efConstruction::Int64
    distname::String
    #
    function Hnsw(type::DataType, maxNbConn::Int64, efConstruction::Int64, distname::String)
        rust_type_name = checkForImplementedType(type)
        rust = hnswInit(type, maxNbConn, efConstruction, distname)
        new(rust, type, maxNbConn, efConstruction, distname)
    end
end


"""
 #  insert 

 function `insert(hnsw::HnswApi, data::Vector{T}, id::UInt64) where {T <: Number}`

  ARGS
  ----
  . data: the data vector to insert in struct hnsw
  . id: the (unique) id of data. Can be the rank of insertion or any hash value enabling
        identification of point for possible dump/restore of the whole hnsw structure
"""
function insert(hnsw::HnswApi, data::Vector{T}, id::UInt64) where {T <: Number}
    insert(hnsw.rust, data, id)
end


"""
# insert 

function `insert(hnsw::HnswApi, datas::Vector{Tuple{Vector{T}, UInt}}) where {T <: Number}`

This function does a block parallel insertion of datas in structure.

ARGS
----
. datas: a vector of insertion request as a Tuple associating the point to insert and its id.
"""
function insert(hnsw::HnswApi, datas::Vector{Tuple{Vector{T}, UInt}}) where {T <: Number}
    parallel_insert(hnsw.rust, datas)
end


"""
# search

function `search(hnsw::Hnsw, vector::Vector{T}, knbn::Int64, ef_search ::Int64) where {T<:Number}`

 ARGS
 ----
 . The vector for which we search neighbours
 . knbn : the number of neughbour we search
 . ef_search : the search parameter.

"""
function search(hnsw::HnswApi, vector::Vector{T}, knbn::Int64, ef_search ::Int64) where {T<:Number}
    search(hnsw.rust, vector, knbn, ef_search)
end


"""

# search

`function search(hnsw::Hnsw , datas::Vector{Vector{T}}, knbn::Int64, ef_search:: Int64) where {T<:Number}`

As for insertion this function is instersting if we batch sufficiently many request. (some hundreds)

ARGS
----
    . datas : The vector of point we search the neighbours of.
    . knbn the number of neighbours wanted.
    . ef_search : parameter search.
"""
function search(hnsw::HnswApi , datas::Vector{Vector{T}}, knbn::Int64, ef_search:: Int64) where {T<:Number}
    parallel_search(hnsw.rust, datas, knbn, ef_search)
end


end # module
