
# Pack Any in AnyFormat by default
format(::Type{Any}) = AnyFormat()
construct(::Type{Any}, val, ::AnyFormat) = val

# Pack Nothing in NilFormat by default
format(::Type{Nothing}) = NilFormat()
construct(::Type{Nothing}, ::Nothing, ::NilFormat) = nothing

# Pack Bool in BoolFormat by default
format(::Type{Bool}) = BoolFormat()

# Pack {<: Signed} in SignedFormat by default
format(::Type{<:Signed}) = SignedFormat()

# Pack {<: Unsigned} in UnsignedFormat by default
format(::Type{<:Unsigned}) = UnsignedFormat()

# Pack {<: AbstractFloat} in FloatFormat by default
format(::Type{<:AbstractFloat}) = FloatFormat()

# Pack {<: AbstractString} in StringFormat by default
format(::Type{<:AbstractString}) = StringFormat()

# Pack Symbol in StringFormat by default
format(::Type{Symbol}) = StringFormat()
construct(::Type{Symbol}, x, ::StringFormat) = Symbol(x)

# Pack {<: Tuple} in VectorFormat by default
format(::Type{<:Tuple}) = VectorFormat()

function construct(::Type{T}, vals, ::VectorFormat) where {T <: Tuple}
  return convert(T, (vals...,))
end

# Pack {<: NamedTuple} in MapFormat by default
format(::Type{<:NamedTuple}) = MapFormat()

function construct(::Type{T}, pairs, ::MapFormat) where {T <: NamedTuple}
  values = Iterators.map(last, pairs)
  return T(values)
end

# Pack {<:Pair} in MapFormat by default
format(::Type{<:Pair}) = MapFormat()
destruct(value::Pair, ::MapFormat) = (value,)
construct(P::Type{<:Pair}, pair, ::MapFormat) = P(first(pair)...)
keytype(::Type{P}, _) where {K, V, P <: Pair{K, V}} = K
valuetype(::Type{P}, _) where {K, V, P <: Pair{K, V}} = V

# Pack {<: AbstractDict} in MapFormat by default
format(::Type{<:AbstractDict}) = MapFormat()
destruct(value::AbstractDict, ::MapFormat) = value
construct(D::Type{<:AbstractDict}, pairs, ::MapFormat) = D(pairs)
keytype(::Type{<:AbstractDict{K, V}}, _) where {K, V} = K
valuetype(::Type{<:AbstractDict{K, V}}, _) where {K, V} = V

#
# Generic structs
#

# Support packing structs in VectorFormat
function destruct(value::T, ::VectorFormat) where {T}
  n = Base.fieldcount(T)
  Iterators.map(1:n) do index
    return Base.getfield(value, index)
  end
end

construct(::Type{T}, vals, ::VectorFormat) where {T} = T(vals...)

# Support packing structs in MapFormat
function destruct(value::T, ::MapFormat) where {T}
  n = Base.fieldcount(T)
  Iterators.map(1:n) do index
    key = Base.fieldname(T, index)
    val = Base.getfield(value, index)
    return (key, val)
  end
end

function construct(::Type{T}, pairs, ::MapFormat) where {T}
  values = Iterators.map(last, pairs)
  return T(values...)
end

#
# Vectors
#

# Pack {<: AbstractVector} in VectorFormat by default
format(::Type{<:AbstractVector}) = VectorFormat()
destruct(value::AbstractVector, ::VectorFormat) = value

function construct(::Type{T}, vals, ::VectorFormat) where {T <: AbstractVector}
  return convert(T, collect(vals))
end

valuetype(::Type{T}, _) where {T <: AbstractVector} = eltype(T)

# Support packing {<: Vector} in BinaryFormat for bitstype elements
function destruct(value::Vector{F}, ::BinaryFormat) where {F}
  @assert isbitstype(F) """
  Only vectors with bitstype elements can be packed in BinaryFormat.
  """
  return value
end

function construct(::Type{Vector{F}}, bytes, ::BinaryFormat) where {F}
  @assert isbitstype(F) """
  Only vectors with bitstype elements can be unpacked in BinaryFormat.
  """
  value = reinterpret(F, bytes)
  return convert(Vector{F}, value)
end

# Support packing {<: Vector} in BinVectorFormat for bitstype elements
function construct(::Type{Vector{F}}, bytes, ::BinVectorFormat) where {F}
  vals = reinterpret(F, bytes)
  return convert(Vector{F}, vals)
end

format(::Type{<:BitVector}) = BinVectorFormat()
destruct(value::BitVector, ::BinVectorFormat) = convert(Vector{UInt8}, value)

function construct(::Type{<: BitVector}, val, ::BinVectorFormat)
  return BitArray(val)
end

#
# Arrays
#

# Support packing AbstractArray in VectorFormat
destruct(value::AbstractArray, ::VectorFormat) = value
valuetype(::Type{T}, _) where {T <: AbstractArray} = eltype(T)

# Pack {<: AbstractArray} in ArrayFormat by default
format(::Type{<:AbstractArray}) = ArrayFormat()

function construct(::Type{T}, val, ::ArrayFormat) where {T <: AbstractArray}
  data = collect(val.data)
  return convert(T, reshape(data, val.size...))
end

# Support packing {<: Array} in BinArrayFormat for bitstype elements
function construct(
  ::Type{T},
  val,
  ::BinArrayFormat,
) where {F, T <: AbstractArray{F}}
  data = reinterpret(F, val.data)
  return convert(T, reshape(data, val.size...))
end

# Pack {<: BitArrays} in BinArrayFormat
# TODO: This currently copies the bitarray to an UInt8 array
format(::Type{<:BitArray}) = BinArrayFormat()
destruct(value::BitArray, ::BinArrayFormat) = convert(Array{UInt8}, value)

function construct(::Type{<: BitArray}, val, ::BinArrayFormat)
  return BitArray(reshape(val.data, val.size...))
end

