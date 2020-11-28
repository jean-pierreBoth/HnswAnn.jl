
# HnswAnn.jl

 **This package provides an interface to a rust implementation of the paper by Yu. A. Malkov and D. A. Yashunin: \
"Efficient and Robust approximate nearest neighbours using Hierarchical Navigable Small World Graphs" (2016, 2018)**

 The package provides Approximate Near Neighbour search for Vector of numeric types
 (i.e Vector{T} where T <: Number)
 and different associated standard distances.

 T can be instantiated by Float32, UInt8, UInt16, UInt32, Int32.  
 Distances can be L1, L2, Cosine, Dot, L1, L2, Hamming, Jaccard, JensenShannon. 
 It is also possible one's own distance function by using julia callbacks compiled with the macro *@function*.  

* Note : Dot is just the Cosine Distance but vectors are assumed normalized to 1. by user before entering insertion and search methods.

 The implementation relies on a Rust multithreaded, templated library with SIMD avx2 acceleration
 for Float32 values and L1, L2, and Dot.

## Rust installation and crate hnsw-rs installation

* Rust installation see [Rust Install](https://www.rust-lang.org/tools/install)

run :  
curl https://sh.rustup.rs -sSf | sh

   The hnsw_rs package can be downloaded from [Hnsw](https://gitlab.com/jpboth/hnswlib-rs) or soon
   from [crate.io](https://crates.io/).

* compilation of rust library.
    By default the rust crate builds a static library. The **_Building_** paragraph in the README.md file of the rust crate, describes how to build the dynamic libray needed for use with Julia.

* Then push the path to the library *libhnsw_rs.so* in Base.DL\_LOAD\_PATH
(see this package function setRustlibPath(path::String)

## Algorithm and Input Parameters

The algorithm stores points in layers (at most 16), and a graph is constructed to enable a search from less densely populated levels to most densely populated levels by constructing links from less dense layers to the most dense layer (level 0).

Roughly the algorithm runs as follows:

Upon insertion, the level **_l_** of a new point is sampled with an exponential law, limiting the number of levels to 16,
so that level 0 is the most densely populated layer, upper layers being exponentially less populated as level increases.  
The nearest neighbour of the point is searched in lookup tables from the upper level to the level just above its layer (**_l_**), so we should arrive near the new point at its level at a relatively low cost. Then the *__max\_nb\_connection__* nearest neighbours are searched in neighbours of neighbours table (with a reverse updating of tables) recursively from its layer **_l_** down to the most populated level 0.  

The scale parameter of the exponential law depends on the maximum number of connection possible for a point (parameter *__max\_nb\_connection__*) to others.  
Explicitly the scale parameter is chosen as : `scale=1/ln(max_nb_connection)`.

The main parameters occuring in constructing the graph or in searching are:

* *__max\_nb\_connection__* (in hnsw initialization)
    The maximum number of links from one point to others. Values ranging from 16 to 64 are standard initialising values, the higher the more time consuming.

* *__ef_construction__* (in hnsw initialization)  
    This parameter controls the width of the search for neighbours during insertion. Values from 200 to 800 are standard initializing values, the higher the more time consuming.

* *__max_layer__* (in hnsw initialization)  
    The maximum number of layers in graph. Must be less or equal than 16.

* *__ef_arg__* (in search methods)  
    This parameter controls the width of the search in the lowest level, it must be greater than number of neighbours asked but can be less than *__ef\_construction__*.
    As a rule of thumb it could be between the number of neighbours we will ask for (knbn arg in search method) and
    *__max\_nb\_connection__*.
