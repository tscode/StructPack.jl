
"""
Format for arrays that remembers the array size.

Built upon the format [`VectorFormat`](@ref).

### Packing
To support packing a value `val` of type `T` in `ArrayFormat`, implement

    destruct(val::T, ::ArrayFormat)::R

where the returned value `ret::R` must define `size` and must be packable in
[`VectorFormat`](@ref).

### Unpacking
To support unpacking a value of type `T` packed in `ArrayFormat`, implement

    construct(::Type{T}, ::ArrayValue{Generator{T}}, ::ArrayFormat)::T

or make sure that the constructor `T(val::ArrayValue{Generator{T}})` is defined
(see [`ArrayValue`](@ref) and [`Generator`](@ref)).

### Defaults
`ArrayFormat` is the default format for `AbstractArray`. Use

    format(::Type{T}) = ArrayFormat()

or

    @pack T in ArrayFormat

to make `ArrayFormat` the default format for type `T` (if `T` is abstract,
use `{<: T}` to cover all subtypes).
"""
struct ArrayFormat <: Format end

"""
Wrapper struct employed when unpacking a value in [`ArrayFormat`](@ref).

Contains the fields `size` and `data`.
"""
struct ArrayValue{T}
  datatype::Symbol
  size::Vector{Int}
  data::T
end

format(::Type{<:ArrayValue}) = MapFormat()

function valueformat(::Type{<:ArrayValue}, ::MapFormat, state)
  return state == 3 ? VectorFormat() : DefaultFormat()
end

function pack(io::IO, value, ::ArrayFormat, scope::Scope)::Nothing
  val = destruct(value, ArrayFormat(), scope)
  datatype = Base.eltype(val) |> string |> Symbol
  return pack(io, ArrayValue(datatype, collect(size(val)), val), scope)
end

function unpack(io::IO, ::Type{T}, ::ArrayFormat, scope::Scope)::T where {T}
  val = unpack(io, ArrayValue{Generator{T}}, scope)
  return construct(T, val, ArrayFormat(), scope)
end

"""
Pack vectors in binary format.  

Built upon the format [`BinaryFormat`](@ref).

### Packing
To support packing a value `val` of type `T` in `BinVectorFormat`, implement

    destruct(val::T, ::BinVectorFormat)::R

where the returned value `ret::R` must be packable in [`BinaryFormat`](@ref).

### Unpacking
To support unpacking a value of type `T` packed in `BinVectorFormat`, implement

    construct(::Type{T}, ::Vector{UInt8}, ::BinVectorFormat)::T

or make sure that the constructor `T(bytes::Vector{UInt8})` is defined.

### Defaults
`BinVectorFormat` is the default format for `BitVector`. Use

    format(::Type{T}) = BinVectorFormat()

or

    @pack T in BinVectorFormat

to make `BinVectorFormat` the default format for type `T` (if `T` is abstract,
use `{<: T}` to cover all subtypes).
"""
struct BinVectorFormat <: Format end

function pack(io::IO, value, ::BinVectorFormat, scope::Scope)::Nothing
  val = destruct(value, BinVectorFormat(), scope)
  return pack(io, val, BinaryFormat(), scope)
end

function unpack(io::IO, ::Type{T}, ::BinVectorFormat, scope::Scope)::T where {T}
  bytes = unpack(io, BinaryFormat(), scope)
  return construct(T, bytes, BinVectorFormat(), scope)
end


"""
Pack vectors in binary format.  

Built upon the format [`BinVectorFormat`](@ref).

### Packing
To support packing a value `val` of type `T` in `BinArrayFormat`, implement

    destruct(val::T, ::BinArrayFormat)::R

where the returned value `ret::R` must define `Base.size` and must be packable
in [`BinaryFormat`](@ref).

### Unpacking
To support unpacking a value of type `T` packed in `BinArrayFormat`, implement

    construct(::Type{T}, ::BinArrayValue{Vector{UInt8}}, ::BinArrayFormat)::T

or make sure that the constructor `T(val::BinArrayValue{Vector{UInt8}})` is
defined (see [`BinArrayValue`(@ref)]).

### Defaults
`BinArrayFormat` is the default format for `BitArray{N}` for `N > 1`. Use

    format(::Type{T}) = BinArrayFormat()

or

    @pack T in BinArrayFormat

to make `BinVectorFormat` the default format for type `T` (if `T` is abstract,
use `{<: T}` to cover all subtypes).
"""
struct BinArrayFormat <: Format end

"""
Wrapper struct for unpacking values in [`BinArrayFormat`](@ref).

Contains the fields `size` and `data`.
"""
struct BinArrayValue{T}
  datatype::Symbol  # Only metadata, not checked during construction of arrays
  size::NTuple{N, Int} where {N}
  data::T
end

format(::Type{<:BinArrayValue}) = MapFormat()

function valueformat(::Type{<:BinArrayValue}, ::MapFormat, state)
  return state == 3 ? BinaryFormat() : DefaultFormat()
end

function pack(io::IO, value, ::BinArrayFormat, scope::Scope)
  val = destruct(value, BinArrayFormat(), scope)
  datatype = Base.eltype(val) |> string |> Symbol
  pack(io, BinArrayValue(datatype, size(val), val), scope)
  return
end

function unpack(io::IO, ::Type{T}, ::BinArrayFormat, scope::Scope)::T where {T}
  val = unpack(io, BinArrayValue{Vector{UInt8}}, scope)
  return construct(T, val, BinArrayFormat(), scope)
end

