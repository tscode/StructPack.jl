
"""
Abstract format type.

Formats are responsible for reducing the packing and unpacking of julia values
to msgpack primitives.
"""
abstract type Format end

"""
    format(T :: Type)
    format(:: T)

Return the default format associated to type `T`. Must be implemented in order
for `pack(io, value :: T)` and `unpack(io, T)` to work.

See also [`Format`](@ref) and [`DefaultFormat`](@ref).
"""
function format(T::Type)
  return error("No default format specified for type $T")
end

format(::T) where {T} = format(T)

"""
    construct(T :: Type, val, format :: Format)::T

Postprocess a value `val` unpacked in `format` and return an object of type
`T`. The type of `val` depends on `format`.

Defaults to `T(val)` but can be overwritten for any combination of `T` and
`format`.

See [`Format`](@ref) and its subtypes for more information.
"""
construct(::Type{T}, val, ::Format) where {T} = T(val)

"""
    destruct(val, format :: Format)

Preprocess a value `val` to prepare packing it in the format `format`.

Each format has specific requirements regarding the output of `destruct`.
Defaults to `val`.

See [`Format`](@ref) and its subtypes for more information.
"""
destruct(val, ::Format) = val

"""
    pack(value, [format::Format])::Vector{UInt8}
    pack(io::IO, value, [format::Format])::Nothing

Create a binary msgpack representation of `value` in the given `format`. If a
stream `io` is passed, the representation is written to it.

If no explicit format is provided, it is derived from the type of `value` via
[`Pack.format`](@ref).
"""
function pack(io::IO, value::T)::Nothing where {T}
  return pack(io, value, format(T))
end

function pack(value::T, args...)::Vector{UInt8} where {T}
  io = IOBuffer(; write = true, read = false)
  pack(io, value, args...)
  return take!(io)
end

"""
    unpack(io::IO) :: Any
    unpack(bytes::Vector{UInt8}) :: Any

    unpack(io::IO, T::Type, [format::Format]) :: T
    unpack(bytes::Vector{UInt8}, T::Type, [format::Format]) :: T

Unpack a binary msgpack representation of a value of type `T` from a byte vector
`bytes` or a stream `io`.

If no format is provided, it is derived from `T` via [`Pack.format`](@ref).
[`Pack.format`](@ref). The returned value is guaranteed to be of type `T`.

If no format and no type is provided, the format [`AnyFormat`](@ref) is used.
The returned value can be of any type.
"""
function unpack(io::IO, ::Type{T})::T where {T}
  fmt = format(T)
  return unpack(io, T, fmt)
end

function unpack(io::IO, T, fmt::Format)
  val = unpack(io, fmt)
  return construct(T, val, fmt)
end

function unpack(::IO, fmt::Format)
  return ArgumentError("Unpacking in format $fmt not supported") |> throw
end

unpack(io::IO) = unpack(io, AnyFormat())

function unpack(bytes::Vector{UInt8}, args...)
  io = IOBuffer(bytes; write = false, read = true)
  return unpack(io, args...)
end

"""
Special format that serves as lazy placeholder for `Pack.format(T)` in
situations where the type `T` is not yet known.

!!! warning

    Never define `Pack.format(T)` for a type `T` in terms of `DefaultFormat`.
    This will lead to indefinite recursion.
"""
struct DefaultFormat <: Format end

pack(io::IO, val, ::DefaultFormat) = pack(io, val)
unpack(io::IO, ::Type{T}, ::DefaultFormat) where {T} = unpack(io, T)

"""
    keytype(T :: Type, index)

Return the type of the key at `index` in `T`.
"""
keytype(::Type, ::Any) = Symbol

"""
    keyformat(T :: Type, index)

Return the format of the key at `index` in `T`
"""
keyformat(::Type{T}, index) where {T} = DefaultFormat()

"""
    valuetype(T :: Type, index)

Return the type of the value at `index` in `T`.
"""
valuetype(::Type{T}, index) where {T} = Base.fieldtype(T, index)

"""
    valueformat(T :: Type, index)

Return the format of the value at `index` in `T`.
"""
valueformat(::Type{T}, index) where {T} = DefaultFormat()


