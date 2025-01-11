
```@meta
CurrentModule = StructPack
```

# Overview

Welcome to the documentation of [StructPack.jl](https://github.com/tscode/StructPack.jl).

StructPack.jl is a [julia](https://www.julialang.org) package that lets you conveniently and efficiently serialize your julia structs in a way that is compatible to the binary [msgpack standard](https://msgpack.org).

You can install it via executing
```julia
using Pkg; Pkg.add("StructPack")
```
in a julia shell. Since it uses [scoped values](https://docs.julialang.org/en/v1/base/scopedvalues/), it requires a julia version of 1.11 or newer.

## Quickstart

The functionality of StructPack.jl centers around the functions [`pack`](@ref) and [`unpack`](@ref) to serialize and deserialize julia objects.
How an object is mapped to its binary msgpack representation is controlled by the [`Format`](@ref) used during calls to [`pack`](@ref) and [`unpack`](@ref).
Default formats are specified via [`format`](@ref).

The following example uses the in-built [`StructFormat`](@ref) to automatically store the fields of `A` in the msgpack map format.
  
```julia
using StructPack

struct A
  a::Int
  b::String
end

StructPack.format(::Type{A}) = StructFormat()

bytes = pack(A(5, "welcome!"))
unpack(bytes, A)
```

StructPack.jl offers a number of pre-defined formats for different scenarios. 
See the [Formats](@ref) section of this documentation.

Consult [Usage](@ref) for a more in-depth exploration of the functionality of StructPack.jl, including an overview of the most important formats, the convenient auxiliary macro [`@pack`](@ref), as well as ways to customize packing and unpacking via [`Context`](@ref) objects.
