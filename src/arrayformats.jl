
"""
Auxiliary structure that can be used to inject the [`valuetype`](@ref) method of
some type into a call to [`unpack`](@ref).

Currently needed by [`ArrayFormat`](@ref).
"""
struct ValueTypeOf{T}
  value::Any
end

construct(::Type{ValueTypeOf{T}}, val, ::Format) where {T} = ValueTypeOf{T}(val)

valuetype(::Type{ValueTypeOf{T}}, index) where {T} = valuetype(T, index)

function construct(::Type{ValueTypeOf{T}}, val, ::VectorFormat) where {T}
  return ValueTypeOf{T}(val)
end

function construct(::Type{ValueTypeOf{T}}, val, ::MapFormat) where {T}
  return ValueTypeOf{T}(val)
end

#
# BinVector format
#
# destruct: BinaryFormat
# construct: Vector{UInt8}
#

struct BinVectorFormat <: Format end

function pack(io::IO, value, ::BinVectorFormat)::Nothing
  val = destruct(value, BinVectorFormat())
  return pack(io, val, BinaryFormat())
end

function unpack(io::IO, ::Type{T}, ::BinVectorFormat)::T where {T}
  bytes = unpack(io, BinaryFormat())
  return construct(T, bytes, BinVectorFormat())
end

#
# Array format
#
# destruct: size(.), VectorFormat
# construct: eltype(T), ArrayValue
#

struct ArrayFormat <: Format end

struct ArrayValue{T}
  datatype::Symbol
  size::Vector{Int}
  data::T
end

format(::Type{<:ArrayValue}) = MapFormat()

function valueformat(::Type{<:ArrayValue}, index)
  return index == 3 ? VectorFormat() : DefaultFormat()
end

function pack(io::IO, value, ::ArrayFormat)::Nothing
  val = destruct(value, ArrayFormat())
  datatype = Base.eltype(val) |> string |> Symbol
  return pack(io, ArrayValue(datatype, collect(size(val)), val))
end

function unpack(io::IO, ::Type{T}, ::ArrayFormat)::T where {T}
  val = unpack(io, ArrayValue{ValueTypeOf{T}})
  val = ArrayValue(val.datatype, val.size, val.data.value)
  return construct(T, val, ArrayFormat())
end

#
# BinArrayFormat
#
# destruct: size, BinVectorFormat
# construct: BinArrayValue
#

struct BinArrayFormat <: Format end

struct BinArrayValue{T}
  datatype::Symbol   # Not checked during construction of arrays
  size::Vector{Int}
  data::T
end

format(::Type{<:BinArrayValue}) = MapFormat()

function valueformat(::Type{<:BinArrayValue}, index)
  return index == 3 ? BinVectorFormat() : DefaultFormat()
end

function pack(io::IO, value, ::BinArrayFormat)
  val = destruct(value, BinArrayFormat())
  datatype = Base.eltype(val) |> string |> Symbol
  return pack(io, BinArrayValue(datatype, collect(size(val)), val))
end

function unpack(io::IO, ::Type{T}, ::BinArrayFormat)::T where {T}
  val = unpack(io, BinArrayValue{Vector{UInt8}})
  return construct(T, val, BinArrayFormat())
end

