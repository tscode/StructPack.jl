
struct StructFormat{F} <: Format end

valuetype(T::Type, name, ::StructFormat) = Base.fieldtype(T, name)
valueformat(::Type, name, ::StructFormat) = DefaultFormat()

destruct(val::T, ::StructFormat) where {T, F} = destruct(val, MapFormat)

function construct(::Type{T}, pairs, ::StructFormat{F}) where {T, F}
  return construct(T, pairs, F)
end

function pack(io::IO, value::T, fmt::StructFormat{MapFormat}, rules::Rules) where {T}
  val = destruct(value, fmt, rules)
  Pack.writeheaderbytes(io, val, MapFormat())
  for pair in val
    fmt_val = Pack.valueformat(T, pair[1], fmt, rules)
    pack(io, pair[1], StringFormat(), rules)
    pack(io, pair[2], fmt_val, rules)
  end
  return nothing
end

function pack(io::IO, value::T, fmt::StructFormat{VectorFormat}, rules::Rules) where {T}
  val = destruct(value, fmt, rules)
  Pack.writeheaderbytes(io, val, VectorFormat())
  for value in val
    fmt_val = Pack.valueformat(T, pair[1], fmt, rules)
    pack(io, pair[2], fmt_val, rules)
  end
  return nothing
end

function unpack(io::IO, ::Type{T}, fmt::StructFormat, rules::Rules)::T where {T}
  n = Pack.readheaderbytes(io, MapFormat())

  @assert n == Base.fieldcount(T) """
  Unexpected number of fields encountered.
  """

  entries = ntuple(Base.fieldcount(T)) do index
    type_val = Pack.valuetype(T, index, fmt, rules)
    fmt_val = Pack.valueformat(T, index, fmt, rules)
    key = unpack(io, Symbol, StringFormat(), rules)
    @assert key == Base.fieldname(T, index) """
    Structformat
    """
    value = unpack(io, type_val, fmt_val, rules)
    return key=>value
  end
  return construct(T, entries, fmt, rules)
end




