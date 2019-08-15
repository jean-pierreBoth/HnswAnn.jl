# This file provides glue from julia to our hnsw rust crate
#
# Nota! all indexes are translated from 0 to 1 begining
#       by substracting one from julia to rust
#       and adding 1 from rust to Julia
#

using Printf

using Logging
using Base.CoreLogging

ldpath = "/home/jpboth/Rust/hnswlib-rs/target/debug/"

const libhnswso = "libhnsw"

const DEBUG = 1

# to be called before anything
function initlibso(path::String)
    push!(Base.DL_LOAD_PATH, path)
end

mutable struct HnswApi
end

logger = ConsoleLogger(stdout, CoreLogging.Debug)
global_logger(logger)

"""
Struct contining the id of a neighbour and distance to it.

"""
struct Neighbour 
    id :: UInt
    dist :: Float32
end


"""
A pointer to Neighbours
Structure returned by request searchNeighbour

"""

struct Neighbourhood 
    nbgh :: Int64
    neighbours :: Ptr{Neighbour}
end



"""
 To retrive answer to parallel search of neigbourhood
"""

struct NeighbourhoodVect
    nb_request :: UInt
    neighbourhoods :: Ptr{Neighbourhood}
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
function insert_f32_rs(ptr::Ref{HnswApi}, data::Vector{Float32}, id::Int64)
    ccall(
        (:insert_f32, libhnswso),
        Cvoid,
        (Ref{HnswApi}, UInt, Ref{Float32}, UInt64),
        ptr, UInt(length(data)), data, UInt64(id))
end


"""
# function search_f

    
"""

function search_f32_rs(ptr::Ref{HnswApi}, vector::Vector{Float32}, knbn::Int64, ef_search ::Int64)
    neighbours_ptr = ccall(
        (:search_neighbours_f32, libhnswso),
        Ptr{Neighbourhood},
        (Ref{HnswApi}, UInt, Ref{Float32}, UInt, UInt),
        ptr, UInt(length(vector)), vector, UInt(knbn), UInt(ef_search)
    )
    # now return a Vector{Neighbourhood}
    println("ccal returned", neighbours_ptr)
    @debug "\n search_f32_rs returned pointer"  neighbours_ptr
    println("trying unsafe load")
    neighbourhood = unsafe_load(neighbours_ptr::Ptr{Neighbourhood})
    @debug "\n search_f32_rs returned neighbours "  neighbourhood
    @printf("\n unwrapping  neighbourhood")
    neighbours = unsafe_wrap(Array{Neighbour,1}, neighbourhood.neighbours, NTuple{1,Int64}(neighbourhood.nbgh); own = true)
    @debug "neighbours : " neighbours
    # we got Vector{Neighbour}
    return neighbours
end


# we must return a Vector{Vector{Neighbour}} , one Vector{Neighbour} per request input

function parallel_search_f32(ptr::Ref{HnswApi}, datas::Vector{Vector{Float32}}, knbn::Int64, ef_search:: Int64)
    nb_vec = length(datas)
    len = length(datas[1])
    # make a Vector{Ref{Float32}} where each ptr is a ref to datas[i] memory beginning
    vec_ref = map(x-> pointer(x), datas)
    neighbourhood_vec_ptr = ccall(
        (:parallel_search_neighbours_f32, libhnswso),
        Ptr{NeighbourhoodVect},
        (Ref{HnswApi}, UInt, UInt, Ref{Ptr{Float32}}, UInt, UInt),
        ptr, UInt(nb_vec), UInt(len), vec_ref, UInt(knbn), UInt(ef_search)
    )
    @debug "\n parallel_search_neighbours_f32 returned pointer" neighbourhood_vec_ptr
    neighbourhoods_vec = unsafe_load(neighbourhood_vec_ptr::Ptr{NeighbourhoodVect})
    @printf("\n unwrapping  neighbourhoods_vec")
    neighbourhoods = unsafe_wrap(Array{Neighbourhood,1}, neighbourhoods_vec.neighbourhoods, NTuple{1,Int64}(neighbourhoods_vec.nb_request); own = true)
    neighbourhoods_answer = Vector{Vector{Neighbour}}(undef, nb_vec)
    # now we must unwrap each neighbourhood
    for i in 1:nb_vec
        @debug "\n unwraping neighbourhood of request " i
        neighbourhoods_answer[i] = unsafe_wrap(Array{Neighbour,1}, neighbourhoods[i].neighbours, NTuple{1,Int64}(neighbourhoods[i].nbgh); own = true)
    end
    #
    return neighbourhoods_answer
end