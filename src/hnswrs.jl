# This file provides glue from julia to our hnsw rust crate
#
#

using Printf

using Logging
using Base.CoreLogging



const libhnswso = "libhnsw_rs"


# to be called before anything
"""
# initialization of Julia DL_LOAD_PATH

 `function setRustlibPath(path::String)`

This function tells julia where is installed the rust dynamic library implementing the
Hnsw algorithm.
It must be called after `using Hnsw` and before any function call

The argument is the path to the rust library.
"""
function setRustlibPath(path::String)
    push!(Base.DL_LOAD_PATH, path)
end


"""
# initRustLog

initialize the log system of Rust by environment.
"""
function initRustLog()
    # use of macro eval makes possible the use of the variable libhnswso
    @eval ccall($("init_rust_log", libhnswso),
        Cvoid,
        (),
    )
end



"""
    A structure to encapsulate the Rust structure.
"""
mutable struct Hnswrs
end


"""
    A structure to encapsulate HnswIoApi needed for reloading a Hnsw
"""

mutable struct HnswIoApi
end


logger = ConsoleLogger(stdout, CoreLogging.Debug)
global_logger(logger)

"""
# Struct Neighbour.

It contains the id of a neighbour and distance to the query point.

When searching for the neighbour of a given point, this struct is the basic block
of vector returned by search methods.
"""
struct Neighbour
    id::UInt
    dist::Float32
end


"""
# struct Neighbourhood. 

A pointer to Neighbours
Structure returned by request searchNeighbour

"""
struct Neighbourhood
    nbgh::Int64
    neighbours::Ptr{Neighbour}
end



"""
# struct NeighbourhoodVect

 To retrive answer to parallel search of neigbourhood.
"""
struct NeighbourhoodVect
    nb_request::UInt
    neighbourhoods::Ptr{Neighbourhood}
end


"""
# implementedTypes

implementedTypes is a dictionary that has 2 functionalities
1.  It lists the types on which an instantiation is made for languages others than Rust.
2.  It enables the mapping to the correct method in rust interface by concatenating the type to the
    name of the method to be called.

The NoData type is a Rust unit structure used when reloading only the graph of the Ann.
In this case no query can be done on the Hnsw structure
"""
implementedTypes = Dict{DataType,String}()
implementedTypes[Float32] = "f32"
implementedTypes[UInt8] = "u8"
implementedTypes[UInt16] = "u16"
implementedTypes[Int32] = "i32"
implementedTypes[UInt32] = "u32"
implementedTypes[Nothing] = "NoData"


# a hack to enable reload from rust when typename given by Rust is not known but the user
# knows the data type in nodes 
# In this case the user can give the typename as keyboard input. 
implementedTypeNames = Dict{String,DataType}()
implementedTypeNames["UInt32"] = UInt32
implementedTypeNames["Int32"] = Int32
implementedTypeNames["UInt8"] = UInt8
implementedTypeNames["UInt16"] = UInt16
implementedTypeNames["Float32"] = Float32
implementedTypeNames["Nothing"] = Nothing




function checkForImplementedType(type::DataType)
    if haskey(implementedTypes, type)
        return implementedTypes[type]
    else
        println("unimplemented type = ", type)
        throw("hnswrs : unimplement type")
    end
end

"""
# function getHnswio

`function getHnswio(filename::String)`

## Args
- filename used to find files to reload (supposed to be in current directory)

## Return
- A pointer to HnswIoApi
"""

function getHnswio(filename::String)
    hnswio = ccall(("get_hnswio", libhnswso),
        Ptr{HnswIoApi}, # return type
        (UInt64, Ptr{UInt8},),
        UInt64(length(filename)), pointer(filename),
    )
end

"""

# function hnswInit

`function hnswInit(type :: DataType, maxNbConn::Int64, efConstruction::Int64, distname::String)`

## Args
- type of data vector: UInt32, UInt16, UInt8 , Float32
        These types are mapped to String corresponding to 
        rust type names by the interface in the dictionary implementedTypes.
        The subsequent request insertion or search must be made with data corresponding
        to the type used in initialization of Hnsw_api. The rust library will panic otherwise.

- maxNbConn. The maximum number of connection by node
- search parameter
- distname : names of distances as recognized by the Julia Rust interface
    - "DistL1" 
    - "DistL2"
    - "DistJaccard"
    - "DistHamming"
    - "DistCosine"
    - "DistDot"
    - "DistLevenhstein"
    - "DistJensenShannon"
    - "DistNoDist"
    
    Types and distance must be in adequation

 ## Return
    - A pointer to Hnswrs


"""
function hnswInit(type::DataType, maxNbConn::Int64, efConstruction::Int64, distname::String)
    # check for type
    rust_type_name = checkForImplementedType(type)
    @eval hnsw = ccall(
        $(string("init_hnsw_", rust_type_name), libhnswso),
        Ptr{Hnswrs}, # return type
        (UInt64, UInt64, Int64, Ptr{UInt8},),
        UInt64($maxNbConn), UInt64($efConstruction), UInt64(length($distname)), pointer($distname)
    )
end



"""

# function hnswInit
`function hnswInit(type :: DataType, maxNbConn::Int64, efConstruction::Int64, f :: Ptr{Cvoid})`

## Args
- datatype can be one of :
- UInt8
- UInt32
- UInt16
- Float32
    The Julia DataType is converted to Rust type  i.e
    f32, i32, u16, u8. So the type arg a.
    The subsequent request insertion or search must be made with data corresponding
    to the type used in initialization of Hnsw_api. The rust library will panic otherwise.

- maxNbConn. The maximum number of connection by node
- search parameter
- a C-api function pointer to the distance to be used

 ## Return
    - A pointer to Hnswrs


"""
function hnswInit(type::DataType, maxNbConn::Int64, efConstruction::Int64, f::Ptr{Cvoid})
    @info "recieving function ptr : " f
    # check for type
    rust_type_name = checkForImplementedType(type)
    @eval hnsw = ccall(
        $(string("init_hnsw_ptrdist_", rust_type_name), libhnswso),
        Ptr{Hnswrs}, # return type
        (UInt64, UInt64, Ptr{Cvoid}),
        UInt64($maxNbConn), UInt64($efConstruction), $f
    )
end

###################  insert method


"""
# one_insert

` function one_insert(ptr::Ref{Hnswrs}, data::Vector{T}, id::UInt64) where {T <: Number} `

The function first checks that it is called for an implemented type.
It generates the name of the rust function to be called and
passes the call to @eval as we cannot call directly ccall with a 
non constant couple (fname, library) Cf Julia manual
"""
function one_insert(ptr::Ref{Hnswrs}, data::Vector{T}, id::UInt64) where {T<:Number}
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

` function parallel_insert(ptr::Ref{Hnswrs}, datas::Vector{Tuple{Vector{T}, UInt}}) where {T <: Number} `
"""
function parallel_insert(ptr::Ref{Hnswrs}, datas::Vector{Tuple{Vector{T},UInt}}) where {T<:Number}
    # get data type of first field of tuple in datas
    d_type = eltype(fieldtype(eltype(datas), 1))
    rust_type_name = checkForImplementedType(d_type)
    # split vector of tuple 
    nb_vec = length(datas)
    # get length of first component of first data (i.e dim of first vector)
    dim = length(datas[1][1])
    # make a Vector{Ref{Float32}} where each ptr is a ref to datas[i] memory beginning
    vec_ref = map(x -> pointer(x[1]), datas)
    ids_ref = map(x -> x[2], datas)
    @eval neighbourhood_vec_ptr = ccall(
        $(string("parallel_insert_", rust_type_name), libhnswso),
        Cvoid,
        (Ref{Hnswrs}, UInt, UInt, Ref{Ptr{$T}}, Ref{UInt}),
        $ptr, UInt($nb_vec), UInt($dim), $vec_ref, $ids_ref
    )
end



########   search method 

"""
# function one_search

 `  function one_search(ptr::Ref{Hnswrs}, vector::Vector{T}, knbn::Int64, ef_search ::Int64) where {T<:Number}` 
"""
function one_search(ptr::Ref{Hnswrs}, vector::Vector{T}, knbn::Int64, ef_search::Int64) where {T<:Number}
    rust_type_name = checkForImplementedType(eltype(vector))
    #
    @eval neighbours_ptr = ccall(
        $(string("search_neighbours_", rust_type_name), libhnswso),
        Ptr{Neighbourhood},
        (Ref{Hnswrs}, UInt, Ref{$T}, UInt, UInt),
        $ptr, UInt(length($vector)), $vector, UInt($knbn), UInt($ef_search)
    )
    # now return a Vector{Neighbourhood}
    # @debug "\n search (rust) returned pointer, will do unsafe_load"  neighbours_ptr
    neighbourhood = unsafe_load(neighbours_ptr::Ptr{Neighbourhood})
    # @debug "\n search rs returned neighbours "  neighbourhood
    neighbours = unsafe_wrap(Array{Neighbour,1}, neighbourhood.neighbours, NTuple{1,Int64}(neighbourhood.nbgh); own=true)
    # @debug "neighbours : " neighbours
    # we got Vector{Neighbour}
    return neighbours
end




# we must return a Vector{Vector{Neighbour}} , one Vector{Neighbour} per request input
"""
# parallel_search function

` function parallel_search(ptr::Ref{Hnswrs}, datas::Vector{Vector{T}}, knbn::Int64, ef_search:: Int64) where {T<:Number} `

parallel search of a Vector of Vectors with search parameters.
"""
function parallel_search(ptr::Ref{Hnswrs}, datas::Vector{Vector{T}}, knbn::Int64, ef_search::Int64) where {T<:Number}
    d_type = eltype(eltype(datas))
    rust_type_name = checkForImplementedType(d_type)
    #
    nb_vec = length(datas)
    len = length(datas[1])
    # make a Vector{Ref{Float32}} where each ptr is a ref to datas[i] memory beginning
    vec_ref = map(x -> pointer(x), datas)
    @eval neighbourhood_vec_ptr = ccall(
        $(string("parallel_search_neighbours_", rust_type_name), libhnswso),
        Ptr{NeighbourhoodVect},
        (Ref{Hnswrs}, UInt, UInt, Ref{Ptr{$T}}, UInt, UInt),
        $ptr, UInt($nb_vec), UInt($len), $vec_ref, UInt($knbn), UInt($ef_search)
    )
    # @debug "\n parallel_search_neighbours rust returned pointer" neighbourhood_vec_ptr
    neighbourhoods_vec = unsafe_load(neighbourhood_vec_ptr::Ptr{NeighbourhoodVect})
    neighbourhoods = unsafe_wrap(Array{Neighbourhood,1}, neighbourhoods_vec.neighbourhoods, NTuple{1,Int64}(neighbourhoods_vec.nb_request); own=true)
    neighbourhoods_answer = Vector{Vector{Neighbour}}(undef, nb_vec)
    # now we must unwrap each neighbourhood
    for i in 1:nb_vec
        # @debug "\n unwraping neighbourhood of request " i
        neighbourhoods_answer[i] = unsafe_wrap(Array{Neighbour,1}, neighbourhoods[i].neighbours, NTuple{1,Int64}(neighbourhoods[i].nbgh); own=true)
    end
    #
    return neighbourhoods_answer
end


function filedump(ptr::Ref{Hnswrs}, d_type::DataType, filename::String)
    @info " julia : filedump : " filename
    rust_type_name = checkForImplementedType(d_type)
    @info " julia : dumping for rust type : " rust_type_name
    resdump = @eval ccall(
        $(string("file_dump_", rust_type_name), libhnswso),
        Clonglong,
        (Ref{Hnswrs}, UInt64, Ptr{UInt8},),
        $ptr, UInt64(length($filename)), pointer($filename)
    )
    resdump
end


struct LoadHnswDescription
    dumpmode::UInt8
    #max number of connections in layers != 0
    max_nb_connection::UInt8
    # number of observed layers
    nb_layer::UInt8
    # search parameter
    ef::UInt64
    # total number of points
    nb_point::UInt64
    # dimesion of data vector
    data_dimension::UInt64
    # length and pointer on dist name
    distname_len::UInt64
    distname::Ptr{UInt8}
    # T typename
    t_name_len::UInt64
    t_name::Ptr{UInt8}
end


"""
# struct HnswDescription

When trying to reload a Hnsw structure from a previous dump
it is necessary to known some characteristics of the data dumped.
So first a call to getDescription is made, then with info returnded
it is possible to call loadHnsw with the adequate parameters.
The parameters necessay to call loadHnsw are:

-   DataType of vectors stored in structure (it also help not inserting
        different size of data)
-   The distance name (just now the case of Ptr distance is not treated, The name of distance
        is set to DistPtr)
    The others descriptors are just given for information but not necessary.
"""
struct HnswDescription
    maxNbConn::Int64
    # number of observed layers
    nb_layer::Int64
    # search parameter
    ef::Int64
    # total number of points
    nb_point::Int64
    # dimesion of data vector
    data_dimension::Int64
    # type of vector 
    type::DataType
    # name of distance
    distname::String
    # pointer on distance function
    distfunctPtr::Union{Some{Ptr{Cvoid}},Nothing}

end


#  to load a description of graph stored in a file
#  filename is the base of the filename (without suffixes "hnsw.graph" of hnsw.data"

"""
# `function getDescription(filename::String `

This function returns a description of graph stored such as type of data stored (Float32,....)
    type of distance and search parameters.
    Information in data type is necessary to be able to instantiate the rust library and is used 
    by function loadHnsw(filename :: String, ....)
    typename and distancename transmitted are those know to Rust
"""
function getDescription(filename::String)
    #
    description_ptr = ccall(
        (:load_hnsw_description, libhnswso),
        Ptr{LoadHnswDescription},
        (UInt64, Ptr{UInt8},),
        UInt64(length(filename)), pointer(filename)
    )
    # 
    if description_ptr == C_NULL
        println("call to getDescription failed , filename was :", filename)
        return nothing
    end
    #
    ffiDescription = unsafe_load(description_ptr::Ptr{LoadHnswDescription})
    @info " data dimension : " ffiDescription.data_dimension
    typename_u = unsafe_wrap(Array{UInt8,1}, ffiDescription.t_name, NTuple{1,UInt64}(ffiDescription.t_name_len); own=true)
    typename = String(typename_u)
    @info "getDescription got typename : " typename
    # get key for typename
    allkeys = collect(keys(implementedTypes))
    keyindex = findfirst(x -> implementedTypes[x] == typename, allkeys)
    graphOnly = false
    if keyindex === nothing
        graphOnly = true
        # this can happen if we reload from Rust user specific type
        # that reduces to Vector of known types (for examples objects hashed with probminhash)
        println("type not implemented : ", typename)
        println("using NoData type and loading only the graph part of the data")
        @warn "typename asked for is not corresponding to any declared valid type"
        @warn "loading only graph part of data"
        typename = "NoData"
        keytype = Nothing
    else
        keytype = allkeys[keyindex]
        @info " keytype : " keytype
    end
    # now we have rust type name and we know it is implemented
    # we must check if distname is "DistPtr"
    distname_u = unsafe_wrap(Array{UInt8,1}, ffiDescription.distname, NTuple{1,UInt64}(ffiDescription.distname_len); own=true)
    distname = String(distname_u)
    if graphOnly
        # if graphOnly we set distance to NoDist
        distname = "DistNoDist"
    end
    # dump info
    println("Description generated :")
    println("distance name : ", distname)
    println("data type : ", typename)
    #
    HnswDescription(Int64(ffiDescription.max_nb_connection),
        Int64(ffiDescription.nb_layer),
        Int64(ffiDescription.ef),
        Int64(ffiDescription.nb_point),
        Int64(ffiDescription.data_dimension),
        keytype,
        distname,
        nothing
    )
end



"""
# `function loadHnsw(filename :: String, type :: DataType, distname :: String)`

This function reloads data from the 2 files created when dumping data
the graph and data files.
The filename sent as arg is the base of the names used to dump files in.
It does not have the suffixes ".hnsw.graph" and ".hnsw.data"

- datatype can be one of :
    - UInt8
    - UInt32
    - UInt16
    - Float32
    - Nothing

The type Nothing makes only sense when reloading a previous dump and we want
only to reload the graph part of the dump. It must be associated to the DistNoDist distance
as no query will be possible with the Nothing type of data


- distnames can be one of (depending on the datatype):
    - "DistL1"
    - "DistL2"
    - "DistHamming"
    - "DistJaccard"
    - "DistCosine"
    - "DistDot"
    - "DistLevenhstein"
    - "DistJensenShannon"
    - "DistNoDist"


This function returns a couple (HnswDescription, HnswApi, HnswIoApi)
"""
function loadHnsw(filename::String, type::DataType, distname::String)
    # get a HnswIoApi pointer to drive reload
    hnswio = getHnswio(filename)
    # append hnsw.graph and load description
    graphFileName = filename * ".hnsw.graph"
    # get a HnswDescription
    description = getDescription(graphFileName)
    # check for types
    if description === nothing
        @warn "some error occurred, could not load a coherent description"
        return nothing
    end
    println("dimension of data :", description.data_dimension)
    rust_type_name = checkForImplementedType(type)
    # call rust stub
    @eval hnsw = ccall(
        $(string("load_hnswdump_", rust_type_name, "_", distname), libhnswso),
        Ptr{Hnswrs}, # return type
        (Ref{HnswIoApi},),
        $hnswio
    )
    #
    println("returned from load_hnswdump_")
    maxNbConn = description.maxNbConn
    # we do not know how rust constructed it...
    efConstruction = 0
    distname_load = description.distname
    # coherence check
    findres = findfirst(distname, distname_load)
    if findres === nothing
        # We can accept this only if type is Nothing meaning we reload only graph.
        if type !== Nothing
            @warn "some error occurred, distances do not match, expected %s, got %s", distname, distname_load
            return nothing
        else
            # in fact if type is Nothing, distname was already set to DistNoDist in getDescription
            distname = "DistNoDist"
        end
    end
    hnswapi = HnswApi(hnsw, type, maxNbConn, efConstruction, distname, nothing)
    (description, hnswapi, hnswio)
end