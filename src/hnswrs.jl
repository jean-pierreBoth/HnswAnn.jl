# This file provides glue from julia to our hnsw rust crate
#
#

using Printf

using Logging
using Base.CoreLogging

ldpath = "/home/jpboth/Rust/hnswlib-rs/target/debug/"

const libhnswso = "libhnsw"


# to be called before anything
"""
# function setRustlibPath

This function tells julia where is installed the rust dynamic library implementing the
    Hnsw algorithm.

The argument is the path to the rust library.
It must be called after `using Hnsw` and before any function call

"""
function setRustlibPath(path::String)
    push!(Base.DL_LOAD_PATH, path)
end

setRustlibPath(ldpath)

"""
    A structure to encapsulate the Rust structure.
"""
mutable struct Hnswrs
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
# struct Neighbourhood. 

A pointer to Neighbours
Structure returned by request searchNeighbour

"""
struct Neighbourhood 
    nbgh :: Int64
    neighbours :: Ptr{Neighbour}
end



"""
# struct NeighbourhoodVect

 To retrive answer to parallel search of neigbourhood.
"""
struct NeighbourhoodVect
    nb_request :: UInt
    neighbourhoods :: Ptr{Neighbourhood}
end


"""
# implementedTypes

implementedTypes is a dictionary that has 2 functionalities
1.  It lists the types on which an instantiation is made for languages others than Rust.
2.  It enables the mapping to the correct method in rust library by concatenating the type to the
    name of the method to be called.
"""
implementedTypes = Dict{DataType, String}()
implementedTypes[Float32] = "f32"
implementedTypes[UInt8] = "u8"
implementedTypes[UInt16] = "u16"
implementedTypes[Int32] = "i32"
implementedTypes[UInt32] = "u32"


function checkForImplementedType(type::DataType)
    if haskey(implementedTypes, type)
        return implementedTypes[type]
    else
        throw("hnswrs : unimplement type")
    end
end

"""

# function hnswInit

## Args
* type of data vector.
        The names of types are String and correspond to rust type names i.e
        f32, i32, u16, u8. So the type arg are "f32" , "i32" and so on.

        The subsequent request insertion or search must be made with data corresponding
        to the type used in initialization of Hnsw_api. The rust library will panic otherwise.

* maxNbConn. The maximum number of connection by node
* search parameter
* distname

 ## Return
    *A pointer to Hnswrs


"""
function hnswInit(type :: DataType, maxNbConn::Int64, efConstruction::Int64, distname::String)
    # check for type
    rust_type_name = checkForImplementedType(type)
    @eval hnsw = ccall(
            $(string("init_hnsw_", rust_type_name), libhnswso),
            Ptr{Hnswrs}, # return type
            (UInt64, UInt64, Int64, Ptr{UInt8},),
            UInt64($maxNbConn), UInt64($efConstruction), UInt64(length($distname)), pointer($distname)
        )
end



###################  insert method


"""
# one_insert

    The function first checks that it is called for an implemented type.
    It generates the name of the rust function to be called and
    passes the call to @eval as we cannot call directly ccall with a 
    non constant couple (fname, library) Cf Julia manual
"""
function one_insert(ptr::Ref{Hnswrs}, data::Vector{T}, id::UInt64) where {T <: Number}
    rust_type_name = checkForImplementedType(eltype(data))
    @eval ccall(
        $(string("insert_", rust_type_name), libhnswso),
        Cvoid,
        (Ref{Hnswrs}, UInt, Ref{$T}, UInt64),
        $ptr, UInt(length($data)), $data, UInt64($id))
end




###################  parallel insert 


"""
    # parallel insertion 
"""
function parallel_insert(ptr::Ref{Hnswrs}, datas::Vector{Tuple{Vector{T}, UInt}}) where {T <: Number}
    # get data type of first field of tuple in datas
    d_type = eltype(fieldtype(eltype(datas),1))
    rust_type_name = checkForImplementedType(d_type)
    # split vector of tuple 
    nb_vec = length(datas)
    len = length(datas[1])
    # make a Vector{Ref{Float32}} where each ptr is a ref to datas[i] memory beginning
    vec_ref = map(x-> pointer(x[1]), datas)
    ids_ref = map(x-> x[2], datas)
    @eval neighbourhood_vec_ptr = ccall(
        $(string("parallel_insert_", rust_type_name), libhnswso),
        Cvoid,
        (Ref{Hnswrs}, UInt, UInt, Ref{Ptr{$T}}, Ref{UInt}),
        $ptr, UInt($nb_vec), UInt($len), $vec_ref, $ids_ref
    )
end



########   search method 

"""
# function one_search

    
"""
function one_search(ptr::Ref{Hnswrs}, vector::Vector{T}, knbn::Int64, ef_search ::Int64) where {T<:Number}
    rust_type_name = checkForImplementedType(eltype(vector))
    #
    @eval neighbours_ptr = ccall(
        $(string("search_neighbours_", rust_type_name), libhnswso),
        Ptr{Neighbourhood},
        (Ref{Hnswrs}, UInt, Ref{$T}, UInt, UInt),
        $ptr, UInt(length($vector)), $vector, UInt($knbn), UInt($ef_search)
    )
    # now return a Vector{Neighbourhood}
    @debug "\n search (rust) returned pointer, will do unsafe_load"  neighbours_ptr
    neighbourhood = unsafe_load(neighbours_ptr::Ptr{Neighbourhood})
    @debug "\n search rs returned neighbours "  neighbourhood
    neighbours = unsafe_wrap(Array{Neighbour,1}, neighbourhood.neighbours, NTuple{1,Int64}(neighbourhood.nbgh); own = true)
    @debug "neighbours : " neighbours
    # we got Vector{Neighbour}
    return neighbours
end




# we must return a Vector{Vector{Neighbour}} , one Vector{Neighbour} per request input
"""
# parallel_search function
"""
function parallel_search(ptr::Ref{Hnswrs}, datas::Vector{Vector{T}}, knbn::Int64, ef_search:: Int64) where {T<:Number}
    d_type = eltype(eltype(datas))
    rust_type_name = checkForImplementedType(d_type)
    #
    nb_vec = length(datas)
    len = length(datas[1])
    # make a Vector{Ref{Float32}} where each ptr is a ref to datas[i] memory beginning
    vec_ref = map(x-> pointer(x), datas)
    @eval neighbourhood_vec_ptr = ccall(
        $(string("parallel_search_neighbours_", rust_type_name), libhnswso),
        Ptr{NeighbourhoodVect},
        (Ref{Hnswrs}, UInt, UInt, Ref{Ptr{$T}}, UInt, UInt),
        $ptr, UInt($nb_vec), UInt($len), $vec_ref, UInt($knbn), UInt($ef_search)
    )
    @debug "\n parallel_search_neighbours rust returned pointer" neighbourhood_vec_ptr
    neighbourhoods_vec = unsafe_load(neighbourhood_vec_ptr::Ptr{NeighbourhoodVect})
    @debug("\n unwrapping  neighbourhoods_vec")
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