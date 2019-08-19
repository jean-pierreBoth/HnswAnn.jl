# This file provides an implementation of
# the paper hnsw. 
#
# The implementation relies on a rust templated library.


#
# Nota! all indexes are translated from 0 to 1 begining
#       by substracting one from julia to rust
#       and adding 1 from rust to Julia
#

using Printf


# a dictionary listing impleneted types and their corresponding rust names
implementedTypes = Dict{DataType, String}()