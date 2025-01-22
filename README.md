# StructPack.jl

[![Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://tscode.github.io/StructPack.jl/stable/)
[![Docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://tscode.github.io/StructPack.jl/dev/)
[![Build Status](https://github.com/tscode/StructPack.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/tscode/StructPack.jl/actions/workflows/CI.yml?query=branch%3Amain)

This [julia](https://julialang.org) package is for people who want to efficiently serialize their beloved structures in a simple, flexible, and transparent way.
It operates on top of the binary [msgpack standard](https://msgpack.org/index.html).

You might like this package because it

- is pure and straightforward julia with no dependencies.
- is very flexible, with context-dependent format choices.
- has an easy interface.
- is reasonably fast.
- avoids uncontrolled code execution during unpacking.
- produces sound msgpack files that can be read universally.

On the other hand, StructPack.jl is (probably) not the right choice if you
 
- need to serialize arbitrary julia objects (functions, ...).
- have enormous files and need lazy loading capabilities.

While the functionality to read generic msgpack files is included (currently without support for the [timestamp](https://github.com/msgpack/msgpack/blob/master/spec.md#timestamp-extension-type) extension type) and is viewed as a major design goal of StructPack.jl, you should also consider the excellent package [MsgPack.jl](https://github.com/JuliaIO/MsgPack.jl), which served as inspiration for StructPack.jl.

## Installation
You can install StructPack.jl from the general julia registry.
```julia
using Pkg
Pkg.add("StructPack")
```
A julia version of 1.9 or newer is needed.
Support for the scoped value [`StructPack.context`](https://tscode.github.io/StructPack.jl/dev/reference/#StructPack.context) requires version 1.11 or newer.

## Usage
To pack or unpack a value `val::T` via StructPack.jl, you must assign its type `T` a format `F <: Format`.
The format determines how the struct is mapped to msgpack.
StructPack.jl offers a number of convenient formats [out of the box](https://tscode.github.io/StructPack.jl/dev/formats/).

Default formats for your type `T` can be specified via
```julia
StructPack.format(::Type{T}) = F()
```
or via the convenience macro
```julia
@pack T in F
```
You can then pack and unpack your value as follows:
```julia
val = ... # create some value of type T

# You may also use an io as first argument
# in calls to pack / unpack
bytes = pack(val)
val = unpack(bytes, T)
```
Alternatively, you can specify formats directly when calling the functions `pack` and `unpack`:
```julia
bytes = pack(val, F())
val = unpack(bytes, T, F())
```
You can also let the format depend on a [surrounding struct](https://tscode.github.io/StructPack.jl/dev/usage/#Parents-matter) or on a so-called [`Context`](https://tscode.github.io/StructPack.jl/dev/usage/#Context-matters).

The following snippet demonstrates some of the features of StructPack.jl.
```julia
using StructPack

abstract type A end

struct B <: A
  a::Int
  b::Float64
end

struct C <: A
  a::Int
end

struct D
  x::String
  y::Matrix{B}
  z::A
end

D(z; y) = D("default", y, z)

# Subtypes of A should be stored in StructFormat by default
@pack {<: A} in StructFormat

# D should be stored in StructFormat, but only save the fields z and y
# (in this order) and use a special constructor to built it.
#
# Furthermore, the B-Matrix behind y should be stored in a special array format
# that efficiently stores binary data (works because isbitstype(B) == true).
#
# Lastly, since z is assigned an abstract type, we have to store the type
# information alongside its value.
@pack D in StructFormat D(z; y) [y in BinArrayFormat, z in TypedFormat]

# Create a matrix of B entries and the value you seek to serialize
y = B.([1, 2, 3], rand(5)')
val = D(C(5); y)

bytes = pack(val)
val2 = unpack(bytes, D)

@assert val.x == val2.x
@assert val.y == val2.y
@assert val.z == val2.z
```
In this example, `bytes` will be the msgpack equivalent of 
```js
{
  z: {
    type: {
      name: "C",
      params: [],
      path: ["Main"],
    },
    value: {
      a: 5,
    },
  },
  y: {
    size: [3, 5],
    data: UInt8[...],
  },
}
```
See [this tutorial](https://tscode.github.io/StructPack.jl/dev/usage/) for a more thorough explanation of the capabilities of StructPack.jl.

## Rationale

Julia already offers a wealth of packages that can be used for data serialization and storage.
Besides `Base.Serialization`, this includes
[JLD.jl](https://github.com/JuliaIO/JLD.jl),
[JLD2.jl](https://github.com/JuliaIO/JLD2.jl),
[JSON.jl](https://github.com/JuliaIO/JSON.jl),
[JSON3.jl](https://github.com/quinnj/JSON3.jl),
[BSON.jl](https://github.com/JuliaIO/BSON.jl),
[Serde.jl](https://github.com/bhftbootcamp/Serde.jl),
[MsgPack.jl](https://github.com/JuliaIO/MsgPack.jl),
and likely many others.
So why does StructPack.jl deserve to exist?

In previous projects, I often found myself in situations where I wanted to permanantly, reliably and efficiently store custom julia structs that contained binary data.
When something about my structs would change, I wanted a transparent mechanism to implement backward compatability.
I also wanted enough flexibility to reconstruct a value based on abstract type information only, in a controlled way.
Loading this value should not be able to execute arbitrary code, since I would not always trust the source blindly.

Oh, and the interface should be straightforward. And the code base should be
transparent and avoid complexities, as far as possible. Ideally, it should also
be compatible to a universally used format.

Thus, this package was born. May it help you.

## Q&A

> Is this package well-tested, performance optimized, and 100% production ready?

None of the three, probably.
Tests cover basic functionality but are not exhaustive.
Performance is decent but could likely be improved, especially for typed serialization via [`TypedFormat`](https://tscode.github.io/StructPack.jl/dev/formats/#StructPack.TypedFormat).
However, the design should be fixed and the API more or less stable.
Features that are currently not supported are unlikely to make it into a future release, unless they fit neatly and don't increase code complexity by much.

What will most certainly make it into future releases is a better default support for types in `Base`.
Support for popular types and standard packages could also rather easily be added via package extensions.
I will patiently be waiting for corresponding issues and pull requests.

> Can I trust you that [`unpack`](https://tscode.github.io/StructPack.jl/dev/formats/#StructPack.unpack) does not destroy my computer and the internet?

Certainly not!
But StructPack.jl tries its best to be safe.
In particular, it never calls `eval`.
The most sensitive operation is unpacking via [`TypedFormat`](https://tscode.github.io/StructPack.jl/dev/formats/#StructPack.TypedFormat), where runtime-dependent constructors are called.
By default, it is checked that these constructors actually fit the abstract type to be unpacked.
Nevertheless, in situations where you do not understand the subtypes well, it is in principle possible that more or less arbitrary code is executed.

> Can I load generic msgpack files?

This should work as long as your file does not make use of extensions of the msgpack format.
The special format enabling this under the hood is the [`AnyFormat`](https://tscode.github.io/StructPack.jl/dev/formats/#StructPack.AnyFormat).
 
> What about msgpack files that do not exactly fit my struct? Can I load them?

It depends.

You probably look for [`FlexibleStructFormat`](https://tscode.github.io/StructPack.jl/dev/formats/#StructPack.UnorderedStructFormat) or [`UnorderedStructFormat`](https://tscode.github.io/StructPack.jl/dev/formats/#StructPack.UnorderedStructFormat) (if you know that all struct fields will be present, but the sorting may be off).

If the key names in the file differ from the struct field names, you will have to come up with an own solution that uses contexts together with a custom implementation of `StructPack.fieldnames` for loading.

If the actual values in the file differ from the struct field values, on the other hand, a different approach is needed.
In this case, if you know the type differences beforehand, you can use contexts together with [`@pack`](https://tscode.github.io/StructPack.jl/dev/macro) to go quite far.
See [here](https://tscode.github.io/StructPack.jl/dev/usage/#Contexts:-Case-study).

