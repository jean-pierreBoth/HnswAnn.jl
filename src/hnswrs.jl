# This file provides glue from julia to our hnsw rust crate
#
# Nota! all indexes are translated from 0 to 1 begining
#       by substracting one from julia to rust
#       and adding 1 from rust to Julia
#

using Printf

using Core

ldpath = "/home/jpboth/Rust/hnswlib-rs/target/debug/"

const libhnswso = "libhnsw"

const DEBUG = 1

# to be called before anything
function initlibso(path::String)
    push!(Base.DL_LOAD_PATH, path)
end

mutable struct HnswApi
end



"""
Struct contining the id of a neighbour and distance to it.

"""
mutable struct Neighbour 
    id::UInt64
    dist :: Float32
end


"""
A pointer to Neighbours
Structure returned by request searchNeighbour

"""

mutable struct Neighbourhood 
    nbgh :: UInt64
    neighbours :: Ptr{Neighbour}
end



"""
 To retrive answer to parallel search of neigbourhood
"""

mutable struct NeighbourhoodVect
    len :: UInt64
    neigbourhood :: Ptr{Neighbourhood}
end
"""

# function hnswInit

* Args
    . maxNbConn The maximum number of connection by node
    . search parameter
* Return
    . A pointer to Hnsw_api


"""

# add a Val{Type} to do dispatch.

function hnswInit(maxNbConn::Int64, efConstruction::Int64, distname::String)
    hnsw = ccall(
            (:init_hnsw_f32, libhnswso),
            Ptr{HnswApi}, # return type
            (UInt64, UInt64, Int64, Ptr{UInt8},),
            UInt64(maxNbConn), UInt64(efConstruction), UInt64(length(distname)), pointer(distname)
        )
end


"""
# function insert_f32

        inserts float vector{Float32}

"""

# multpile dispatch is a real help here
function insert_f32_rs(ptr::Ref{HnswApi}, data::Vector{Float32}, id::UInt64)
    ccall(
        (:insert_f32, libhnswso),
        Cvoid,
        (Csize_t, Ptr{Cfloat}, Culonglong),
        length(data), data, id)
end


"""
# function search_f

    
"""

function search_f32_rs(ptr::Ref{HnswApi}, vector::Vector{Float32}, knbn::UInt64)
    neighbours_ptr = ccall(
        (:search_neighbours_f32, libhnswso),
        Ptr{Neighbourhood},
        (Csize_t, Ref{Cfloat}),
        length(vector), vector
    )
    # now return a Vector{Neighbourhood}
    neighbourhood = unsafe_load(neighbours_ptr::Ptr{Neighbourhood})
    @debug "\n search_f32_rs returned neighbours "  neighbourhood
    nbgh = neighbourhood.nbgh
    neighbours = unsafe_wrap(Array{Neighbour,1}, neighbourhood.ptr, NTuple{1,UInt}(nbgh); own = true)
    # we got Vector{Neighbour}
    return neighbours
end



function parallel_search_f32(ptr::Ref{HnswApi}, datas::Vector{Vector{Float32}}, knbn::UInt64, ef_search:: UInt64)
    nb_vec = length(datas)
    len = length(datas[1])
    # make a Vector{Ref{Float32}} where each ptr is a ref to datas[i] memory beginning

end