
```@meta
CurrentModule = StructPack
```

# Formats

```@docs
Format
```

## Basic formats

```@docs
NilFormat
BoolFormat
SignedFormat
UnsignedFormat
FloatFormat
StringFormat
BinaryFormat
ExtensionFormat
```

## Vector and array formats

Besides [`VectorFormat`](@ref), which directly mirrors the msgpack vector format, StructPack.jl also provides convenience formats for storing isbits-vectors and multidimensional arrays.

```@docs
AbstractVectorFormat
VectorFormat
ArrayFormat
BinVectorFormat
BinArrayFormat
DynamicVectorFormat
```

## Map formats

Besides [`MapFormat`](@ref), which directly mirrors the msgpack map format, StructPack.jl also provides specialized map implementations for structures.

```@docs
AbstractMapFormat
MapFormat
DynamicMapFormat
AbstractStructFormat
StructFormat
UnorderedStructFormat
FlexibleStructFormat
```

## Type formats

```@docs
TypeFormat
TypedFormat
```

## Special formats

```@docs
DefaultFormat
AnyFormat
SetContextFormat
```
