# This file provides an implementation of
# the paper hnsw. 
#
# The implementation relies on a rust templated library.


module Hnsw

using Printf

include("hnswrs.jl")

export 
    Neighbour,
    Neighbourhood,
    Hnsw,
    setRustlibPath,
    insert,
    search


mutable struct Hnsw
    rust :: Ref{HnswApi}
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


function insert(hnsw::Hnsw, data::Vector{T}, id::UInt64) where {T <: Number}
    insert(hnsw.rust, data, id)
end


function insert(hnsw::Hnsw, datas::Vector{Tuple{Vector{T}, UInt}}) where {T <: Number}
    parallel_insert(hnsw.rust, datas)
end


function search(hnsw::Hnsw, vector::Vector{T}, knbn::Int64, ef_search ::Int64) where {T<:Number}
    search(hnsw.rust, vector, knbn, ef_search)
end


function search(hnsw::Hnsw , datas::Vector{Vector{T}}, knbn::Int64, ef_search:: Int64) where {T<:Number}
    parallel_search(hnsw.rust, datas, knbn, ef_search)
end


end # module
