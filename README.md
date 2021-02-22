
# HnswAnn.jl

 **This package provides an interface to a Rust implementation of the paper by Yu. A. Malkov and D. A. Yashunin: \
"Efficient and Robust approximate nearest neighbours using Hierarchical Navigable Small World Graphs" (2016, 2018)**

It can be useful to Rust users of the crate [hnsw_rs](https://gitlab.com/jpboth/hnswlib-rs) needing an interactive access to their data, but can be useful to Julia users needing a "metal" implementation.

The package provides Approximate Near Neighbour search for Vector of numeric types
(i.e Vector{T} where T <: Number) and different associated standard distances.

T can be instantiated by Float32, UInt8, UInt16, UInt32, Int32 depending on the distance.
Distances can be L1, L2, Cosine, Dot, Hamming, Jaccard, JensenShannon, Hellinger.  
It is also possible to define one's own distance function by sending Julia callbacks compiled with the macro *@function* to the Rust library.  

* Note : Dot is just the Cosine Distance but vectors are assumed normalized to 1. by user before entering insertion and search methods.

The implementation relies on a Rust multithreaded, templated library with SIMD avx2 acceleration
for Float32 values and L1, L2, and Dot.

It also provides dump/reload utilities.

## Rust installation and crate hnsw-rs installation

* Rust installation see [Rust Install](https://www.rust-lang.org/tools/install)

run :  
curl https://sh.rustup.rs -sSf | sh

   The hnsw_rs package can be downloaded from [Hnsw](https://gitlab.com/jpboth/hnswlib-rs) or soon
   from [crate.io](https://crates.io/).

* compilation of rust library.
    By default the rust crate builds a static library. The ***Building*** paragraph in the README.md file of the rust crate, describes how to build the dynamic libray needed for use with Julia.

* Then push the path to the library *libhnsw_rs.so* in Base.DL_LOAD_PATH
(see this package function setRustlibPath(path::String).

* Logging for the Rust library can be initialized from Julia with the function *initRustLog*.
    It uses env_logger.

## License

Licensed under either of

* Apache License, Version 2.0, [LICENSE-APACHE](LICENSE-APACHE) or <http://www.apache.org/licenses/LICENSE-2.0>
* MIT license [LICENSE-MIT](LICENSE-MIT) or <http://opensource.org/licenses/MIT>

at your option.

This software was written on my own while working at [CEA](http://www.cea.fr/)
