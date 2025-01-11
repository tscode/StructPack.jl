
```@meta
CurrentModule = StructPack
```

# Formats

```@docs
Format
```

## Basic Formats

```@docs
NilFormat
BoolFormat
SignedFormat
UnsignedFormat
FloatFormat
StringFormat
BinaryFormat
```

## Vector and Array Formats

Besides [`VectorFormat`](@ref), which mirrors the msgpack vector format, StructPack.jl also provides convenience formats for storing isbits-vectors and multidimensional arrays.

```@docs
AbstractVectorFormat
VectorFormat
ArrayFormat
BinVectorFormat
BinArrayFormat
DynamicVectorFormat
```

## Map Formats

Besides the format [`MapFormat`](@ref), which mirrors the msgpack map format, StructPack.jl also provides specialized map implementations for structures.

```@docs
AbstractMapFormat
MapFormat
DynamicMapFormat
AbstractStructFormat
StructFormat
UnorderedStructFormat
```

## Extra Formats

```@docs
TypeFormat
TypedFormat
```

## Special Formats

```@docs
DefaultFormat
AnyFormat
```


