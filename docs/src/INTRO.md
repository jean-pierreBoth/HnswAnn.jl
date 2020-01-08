
# Hnsw.jl

 **This package provides an interface to a rust implementation of the paper by Yu. A. Malkov and D. A. Yashunin: \
"Efficient and Robust approximate nearest neighbours using Hierarchical Navigable Small World Graphs" (2016, 2018)**

 The package provides Approximate Near Neighbour search for Vector of numeric types
 (i.e Vector{T} where T <: Number)
 and different associated standard distances.

 T can be instantiated by Float32, UInt8, UInt16, UInt32, Int32.  
 Distances can be L1, L2, Cosine and Dot for float values and  L1, L2, Hamming and Jaccard for integer values. It is also possible one's own distance function by using julia callbacks compiled with the macro *@function*.  

* Note : Dot is just the Cosine Distance but vectors are assumed normalized to 1. by user before entering insertion and search methods.

 The implementation relies on a Rust multithreaded, templated library with SIMD avx2 acceleration
 for Float32 values and L1, L2, and Dot.

## Rust installation and crate hnsw-rs installation

* Rust installation see [Rust Install](https://www.rust-lang.org/tools/install)

run :  
curl https://sh.rustup.rs -sSf | sh

   The hnsw-rs package can be downloaded from [Hnsw](https://gitlab.com/jpboth/hnswlib-rs) or soon
   from [crate.io](https://crates.io/).

* compilation of rust library.
    By default the rust crate builds a static library. The ***Building*** paragraph in the README.md file
    describes how build the dynamic libray needed for use with Julia.
