
"""
Format for arrays that remembers the array size.

Built upon [`VectorFormat`](@ref).

## Defaults
`ArrayFormat` is the default format for `AbstractArray`. Use

    format(::Type{T}) = ArrayFormat()

or

    @pack T in ArrayFormat

to make `ArrayFormat` the default format for type `T`. If `T` is abstract,
use `{<: T}` to cover all subtypes.

## Packing
To support packing values of type `T` in `ArrayFormat`, implement

    destruct(val::T, ::ArrayFormat)::R

where the returned value `ret::R` must define `size` and must be packable in
[`VectorFormat`](@ref).

## Unpacking
To support unpacking values of type `T` packed in `ArrayFormat`, implement

    construct(::Type{T}, ::ArrayValue{Generator{T}}, ::ArrayFormat)::T

or make sure that the constructor `T(val::ArrayValue{Generator{T}})` is defined
(see [`ArrayValue`](@ref) and [`Generator`](@ref)).
"""
struct ArrayFormat <: Format end

"""
Wrapper struct employed when unpacking a value in [`ArrayFormat`](@ref).

Contains the fields `size` and `data`, the latter of which is usually a
`Generator` after reconstruction via unpack.
"""
struct ArrayValue{T}
  size::NTuple{N, Int} where {N}
  data::T
end

format(::Type{<:ArrayValue}) = StructFormat()
fieldformats(::Type{<:ArrayValue}) = (DefaultFormat(), VectorFormat())

function pack(io::IO, value, ::ArrayFormat, ctx::Context)::Nothing
  val = destruct(value, ArrayFormat(), ctx)
  return pack(io, ArrayValue(size(val), val), ctx)
end

function unpack(io::IO, ::Type{T}, ::ArrayFormat, ctx::Context)::T where {T}
  val = unpack(io, ArrayValue{Generator{T}}, ctx)
  return construct(T, val, ArrayFormat(), ctx)
end

"""
Pack vectors in binary format.  

Built upon [`BinaryFormat`](@ref).

## Defaults
`BinVectorFormat` is the default format for `BitVector`. Use

    format(::Type{T}) = BinVectorFormat()

or

    @pack T in BinVectorFormat

to make `BinVectorFormat` the default format for type `T`. If `T` is abstract,
use `{<: T}` to cover all subtypes.

## Packing
To support packing values of type `T` in `BinVectorFormat`, implement

    destruct(val::T, ::BinVectorFormat)::R

where the returned value `ret::R` must be packable in [`BinaryFormat`](@ref).

## Unpacking
To support unpacking values of type `T` packed in `BinVectorFormat`, implement

    construct(::Type{T}, ::Vector{UInt8}, ::BinVectorFormat)::T

or make sure that the constructor `T(bytes::Vector{UInt8})` is defined.
"""
struct BinVectorFormat <: Format end

function pack(io::IO, value, ::BinVectorFormat, ctx::Context)::Nothing
  val = destruct(value, BinVectorFormat(), ctx)
  return pack(io, val, BinaryFormat(), ctx)
end

function unpack(io::IO, ::Type{T}, ::BinVectorFormat, ctx::Context)::T where {T}
  bytes = unpack(io, BinaryFormat(), ctx)
  return construct(T, bytes, BinVectorFormat(), ctx)
end

"""
Pack arrays in binary format.  

Built upon [`BinVectorFormat`](@ref).

## Defaults
`BinArrayFormat` is the default format for `BitArray{N}` for `N > 1`. Use

    format(::Type{T}) = BinArrayFormat()

or

    @pack T in BinArrayFormat

to make `BinVectorFormat` the default format for type `T`. If `T` is abstract,
use `{<: T}` to cover all subtypes.

## Packing
To support packing values of type `T` in `BinArrayFormat`, implement

    destruct(val::T, ::BinArrayFormat)::R

where the returned value `ret::R` must define `Base.size` and must be packable
in [`BinaryFormat`](@ref).

## Unpacking
To support unpacking values of type `T` packed in `BinArrayFormat`, implement

    construct(::Type{T}, ::BinArrayValue{Vector{UInt8}}, ::BinArrayFormat)::T

or make sure that the constructor `T(val::BinArrayValue{Vector{UInt8}})` is
defined (see [`BinArrayValue`(@ref)]).
"""
struct BinArrayFormat <: Format end

"""
Wrapper object for unpacking values in [`BinArrayFormat`](@ref).

Contains the fields `size` and `data`, the latter of which is a `Vector{UInt8}`
after reconstruction via unpack.
"""
struct BinArrayValue{T}
  size::NTuple{N, Int} where {N}
  data::T
end

format(::Type{<:BinArrayValue}) = StructFormat()
fieldformats(::Type{<:BinArrayValue}) = (DefaultFormat(), BinVectorFormat())

function pack(io::IO, value, ::BinArrayFormat, ctx::Context)
  val = destruct(value, BinArrayFormat(), ctx)
  pack(io, BinArrayValue(size(val), val), ctx)
  return
end

function unpack(io::IO, ::Type{T}, ::BinArrayFormat, ctx::Context)::T where {T}
  val = unpack(io, BinArrayValue{Vector{UInt8}}, ctx)
  return construct(T, val, BinArrayFormat(), ctx)
end

