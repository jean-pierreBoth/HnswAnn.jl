
# Hnsw.jl

 **This package provides an interface to a rust implementation of the paper by Yu. A. Malkov and D. A. Yashunin: \
Efficient and Robust approximate nearest neighbours using Hierarchical Navigable Small World Graphs (2016)**

 The package provides Approximate Near Neighbour search for Vector of numeric types
 (i.e Vector{T} where T <: Number)
 and different associated standard distances.

 T can be instantiated by Float32, UInt8, UInt16, UInt32, Int32.
 Distances can be L1, L2, Cosine for float values and  L1, L2, Hamming and Jaccard for integer values. Moreover the use can define its own distance function by using julia callbacks compile with the macro *@function*

 The implementation relies on a Rust multithreaded, templated library with SIMD avx2 acceleration
 for some couples of type/distances.

## Rust installation and crate hnsw-rs installation

   Rust libray installation [Rust Install](https://www.rust-lang.org/tools/install)

   run : curl https://sh.rustup.rs -sSf | sh

   The Hnsw-rs package can be downloaded from [Hnsw](https://gitlab.com/jpboth/hnswlib-rs)

   compilation of rust library : cargo build --release.
