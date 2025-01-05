
```@meta
CurrentModule = Pack
```

# Overview

Welcome to the documentation of Pack.jl!

Pack.jl is a [julia](https://www.julialang.org) package that allows you to
conveniently and efficiently serialize structs comptible to the binary [msgpack
standard](https://msgpack.org).
It can be installed via executing
```julia
using Pkg; Pkg.add("Pack")
```
in a julia shell.

The functionality of Pack.jl revolves around the functions [`pack`](@ref) and
[`unpack`](@ref) to serialize and deserialize julia objects.

How an object is mapped to msgpack when [`pack`](@ref) and [`unpack`](@ref)
are called depends on the [`Format`](@ref) used during serialization. Default
formats for a given type are specified via [`format`](@ref).

```julia
using Pack

struct A
  a::Int
  b::String
end

Pack.format(::Type{A}) = Pack.MapFormat()

bytes = Pack.pack(A(5, "welcome!"))
Pack.unpack(bytes, A)
```

Sometimes, there are reasons why the format of a type should deviate from the
one provided by [`format`](@ref). One way to achieve this, without affecting the
global behavior of Pack.jl, is via the use of [`Rules`](@ref)s.

See [Usage](@ref) for an introduction to the package.

See [Formats](@ref) for an overview of supported formats.

See [Rules](@ref) for more information about rules.
