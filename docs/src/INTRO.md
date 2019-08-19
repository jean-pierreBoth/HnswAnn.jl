# This package provides an implementation of the paper hnsw

 The package provides Approximate Near Neighbour search for Vector of numeric types
 (i.e Vector{T} where T <: Number)
 and different associated standard distances.

 T can be instantiated by Float32, UInt8, UInt16, UInt32, Int32.
 Distances can be L1, L2, Cosine for float values and  L1, L2, Hamming for integer values.

 The implementation relies on a Rust multithreaded, templated library with SIMD avx2 acceleration
 for some couples of type/distances.

## Rust installation and crate hnsw-rs installation

   Rust libray installation (Cf https://www.rust-lang.org/tools/install)

   run : curl https://sh.rustup.rs -sSf | sh

   download of the Hnsw-rs package : git clone https://gitlab.com/jpboth/hnswlib-rs

   compilation of rust library : cargo build --release.
