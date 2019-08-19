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

"""
    A structure to encapsulate the Rust structure.
"""

mutable struct HnswApi
end

logger = ConsoleLogger(stdout, CoreLogging.Debug)
global_logger(logger)

"""
# Struct Neighbour.

It contining the id of a neighbour and distance to it.
When searching for the neighbour of a given point, this struct 
returns the basic info on a neighbour consisting on its Id and the distance to the query point.

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
    . type of data vector.
        The names of types are String and correspond to rust type names i.e
        f32, i32, u16, u8. So the type arg are "f32" , "i32" and so on.
        The subsequent request insertion or search must be made with data corresponding
        to the type used in initialization of Hnsw_api. The rust library will panic otherwise.

    . maxNbConn. The maximum number of connection by node
    . search parameter
    . distname
* Return
    . A pointer to Hnsw_api


"""


function hnswInit(type :: String, maxNbConn::Int64, efConstruction::Int64, distname::String)
    @eval hnsw = ccall(
            $(string("init_hnsw_", type), libhnswso),
            Ptr{HnswApi}, # return type
            (UInt64, UInt64, Int64, Ptr{UInt8},),
            UInt64($maxNbConn), UInt64($efConstruction), UInt64(length($distname)), pointer($distname)
        )
end

# add a Val{Type} to do dispatch.

function hnswInit_f32(maxNbConn::Int64, efConstruction::Int64, distname::String)
    hnsw = hnswInit("f32", maxNbConn, efConstruction, distname)
end


"""
# function insert_f32

        inserts float vector{Float32}

"""


###################  insert method


# multpile dispatch is a real help here
function insert(ptr::Ref{HnswApi}, data::Vector{Float32}, id::Int64)
    ccall(
        (:insert_f32, libhnswso),
        Cvoid,
        (Ref{HnswApi}, UInt, Ref{Float32}, UInt64),
        ptr, UInt(length(data)), data, UInt64(id))
end


# multpile dispatch is a real help here
function insert(ptr::Ref{HnswApi}, data::Vector{UInt16}, id::Int64)
    ccall(
        (:insert_u16, libhnswso),
        Cvoid,
        (Ref{HnswApi}, UInt, Ref{UInt16}, UInt64),
        ptr, UInt(length(data)), data, UInt64(id))
end


# multpile dispatch is a real help here
function insert(ptr::Ref{HnswApi}, data::Vector{UInt8}, id::Int64)
    ccall(
        (:insert_u8, libhnswso),
        Cvoid,
        (Ref{HnswApi}, UInt, Ref{UInt8}, UInt64),
        ptr, UInt(length(data)), data, UInt64(id))
end



# multpile dispatch is a real help here
function insert(ptr::Ref{HnswApi}, data::Vector{Int32}, id::Int64)
    ccall(
        (:insert_i32, libhnswso),
        Cvoid,
        (Ref{HnswApi}, UInt, Ref{Int32}, UInt64),
        ptr, UInt(length(data)), data, UInt64(id))
end





###################  parallel insert 



function parallel_insert_f32(ptr::Ref{HnswApi}, datas::Vector{Tuple{Vector{Float32}, UInt}})
    # split vector of tuple 
    nb_vec = length(datas)
    len = length(datas[1])
    # make a Vector{Ref{Float32}} where each ptr is a ref to datas[i] memory beginning
    vec_ref = map(x-> pointer(x[1]), datas)
    ids_ref = map(x-> x[2], datas)
    neighbourhood_vec_ptr = ccall(
        (:parallel_insert_f32, libhnswso),
        Cvoid,
        (Ref{HnswApi}, UInt, UInt, Ref{Ptr{Float32}}, Ref{UInt}),
        ptr, UInt(nb_vec), UInt(len), vec_ref, ids_ref
    )
end



########   search method 

"""
# function search_f

    
"""

function search_f32(ptr::Ref{HnswApi}, vector::Vector{Float32}, knbn::Int64, ef_search ::Int64)
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