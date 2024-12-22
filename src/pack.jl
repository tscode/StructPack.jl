
"""
Abstract format type.

Formats are responsible for reducing the packing and unpacking of julia values
to msgpack primitives.

To implement a custom format `MyFormat`, define the singleton structure

    struct MyFormat <: Format end

and implement the methods `pack(io::IO, value::T, fmt::F, scope::Scope)`
as well as either `unpack(io::IO, T::Type, ::F, ::Scope)::T` or
`unpack(io::IO, ::F, ::Scope)` for all supported types `T`. The latter variant
of [`unpack`](@ref) is a convenience method that ensures that
[`construct`](@ref) is called on its output with the type information `T`
passed.

The `scope` object, which is used to overwrite serialization defaults,
should be passed on to all further calls that are concerned with packing or
unpacking (i.e., [`pack`](@ref), [`unpack`](@ref), [`format`](@ref),
[`destruct`](@ref), and [`construct`](@ref)).
"""
abstract type Format end

"""
Abstract scope type.

A scope can be introduced to enforce custom behavior when packing and unpacking
values.

In particular, a scope can influence which formats are assigned to types (via
[`format`](@ref)) or fields of a struct (via [`valueformat`](@ref)), and they
can influence how objects are processed before packing and after unpacking (via
[`destruct`](@ref) and [`construct`(@ref)]).

The scope-free default definitions of the mentioned methods are used as fallback.
"""
abstract type Scope end

"""
Default scope that provides fallback implementations.

This is only a auxiliary type and should not come into contact with users of
Pack.jl.

!!! warn

    Do not dispatch on `::DefaultScope` to provide global defaults.
    Always use the scope-free methods. For example, use
    `format(::Type{MyType}) = ...` instead of
    `format(::Type{MyType}, ::DefaultScope) = ...` to set a default format for
    `MyType`.
"""
struct DefaultScope <: Scope end

"""
    format(T::Type [, scope::Scope])
    format(::T [, scope::Scope])

Return the format associated to type `T` in `scope`.

The scope-free version of this method must be implemented in order for `pack(io,
value :: T)` and `unpack(io, T)` to work. It is used as fallback for all scopes.

See also [`Format`](@ref) and [`DefaultFormat`](@ref).
"""
function format(T::Type)
  return error("No default format specified for type $T")
end

# Support calling format on values
format(::T, args...) where {T} = format(T, args...)

# Specialize this function to select custom formats in your scope
format(T::Type, ::Scope) = format(T)

"""
    construct(T::Type, val, fmt::Format [, scope::Scope])::T

Postprocess a value `val` unpacked according to `fmt` and return an object
of type `T`. The type of `val` depends on the format `fmt` that was used for
unpacking.

Defaults to `T(val)` but can be overwritten for any combination of `T`, `fmt`,
and `scope`.
"""
construct(T::Type, val, ::Format) = T(val)

# Extend this function to use custom constructors in your scope
construct(T::Type, val, fmt::Format, ::Scope) = construct(T, val, fmt)

"""
    destruct(val::T, fmt::Format [, scope::Scope])

Preprocess a value `val` to prepare packing it in the format `fmt`.

Defaults to `val` but can be overwritten for any combination of `T`, `fmt`,
and `scope`.

Each format has specific requirements regarding the output of this method.
"""
destruct(val, ::Format) = val

# Extend this function to use custom destructors in your scope
destruct(val, fmt::Format, ::Scope) = destruct(val, fmt)

"""
    pack(value, [, scope::Scope])::Vector{UInt8}
    pack(value, [, fmt::Format, scope::Scope])::Vector{UInt8}
    pack(io::IO, args...)::Nothing

Create a binary msgpack representation of `value` according to the given format
`fmt`. If a stream `io` is passed, the representation is written into it.

If no format is provided, it is derived from the type of `value` via
`Pack.format(typeof(value), scope)`. The scope defaults to `DefaultScope()`.

If both a format and a scope are provided, `fmt` is used for packing `value`
while `scope` is passed along to deeper packing calls.
"""
function pack(io::IO, value::T, scope::Scope = DefaultScope())::Nothing where {T}
  return pack(io, value, format(T, scope), scope)
end

function pack(io::IO, value::T, fmt::Format)::Nothing where {T}
  return pack(io, value, fmt, DefaultScope())
end

function pack(value::T, args...)::Vector{UInt8} where {T}
  io = IOBuffer(; write = true, read = false)
  pack(io, value, args...)
  return take!(io)
end

"""
    unpack(bytes::Vector{UInt8}, T::Type [, scope::Scope])::T
    unpack(bytes::Vector{UInt8}, T::Type [, fmt::Format, scope::Scope])::T
    unpack(io::IO, T::Type, args...)::T

Unpack a binary msgpack representation of a value of type `T` in format `fmt`
from a byte vector `bytes` or a stream `io`. The returned value is guaranteed to
be of type `T`.

If no format is provided, it is derived from `T` via `Pack.format(T, scope)`.
The scope defaults to `DefaultScope()`.
"""
function unpack(io::IO, ::Type{T}, scope::Scope = DefaultScope())::T where {T}
  return unpack(io, T, format(T, scope), scope)
end

function unpack(io::IO, ::Type{T}, fmt::Format, scope::Scope = DefaultScope()) where {T}
  val = unpack(io, fmt, scope)
  return construct(T, val, fmt, scope)
end

function unpack(::IO, fmt::Format, scope::Scope = DefaultScope())
  ArgumentError("Generic unpacking in format $fmt not supported") |> throw
end

function unpack(bytes::Vector{UInt8}, args...)
  io = IOBuffer(bytes; write = false, read = true)
  return unpack(io, args...)
end

"""
    unpack(bytes::Vector{UInt8})::Any
    unpack(io::IO)::Any
  
Unpack a binary msgpack value via the special format [`AnyFormat`](@ref).
The returned value can be of any type.
"""
unpack(io::IO) = unpack(io, AnyFormat())

"""
Special format that serves as lazy placeholder for `format(T)` in
situations where the type `T` is not yet known.

!!! warning

    Never define `format(T)` for a type `T` in terms of `DefaultFormat`.
    This will lead to indefinite recursion.
"""
struct DefaultFormat <: Format end

pack(io::IO, val, ::DefaultFormat, scope::Scope) = pack(io, val, scope)

function unpack(io::IO, ::Type{T}, ::DefaultFormat, scope::Scope) where {T}
  return unpack(io, T, scope)
end

"""
    keytype(T::Type, fmt::Format, state [, scope::Scope])::Type

Return the type of the key at iteration state `state` when saving the entries
of `T` in format `fmt`.

This method is used when unpacking values in [`MapFormat`](@ref).

The state object `state` is initialized and iterated by [`iterstate`](@ref).
"""
keytype(::Type, ::Format, state) = Symbol # default to support structs
keytype(T::Type, fmt::Format, state, ::Scope) = keytype(T, fmt, state)

"""
    keyformat(T::Type, fmt::Format, state [, scope::Scope])::Format

Return the format of the key at iteration state `state` when saving the entries
of `T` in format `fmt`.

This method is used when packing or unpacking values in [`MapFormat`](@ref).

The state object `state` is initialized and iterated by [`iterstate`](@ref).
"""
keyformat(T::Type, ::Format, state) = DefaultFormat()
keyformat(T::Type, fmt::Format, state, ::Scope) = keyformat(T, fmt, state)

"""
    valuetype(T::Type, fmt::Format, state [, scope::Scope])::Type

Return the type of the value at iteration state `state` when saving the entries
of `T` in format `fmt`.

This method is used when unpacking values in [`VectorFormat`](@ref) and
[`MapFormat`](@ref).

The state object `state` is initialized and iterated by [`iterstate`](@ref).
"""
valuetype(T::Type, ::Format, state) = Base.fieldtype(T, state)
valuetype(T::Type, fmt::Format, state, ::Scope) = valuetype(T, fmt, state)

"""
    valueformat(T::Type, fmt::Format, state [, scope::Scope])::Format

Return the format of the value at iteration state `state` when saving the
entries of `T` in format `fmt`.

This method is used when packing or unpacking values in [`VectorFormat`](@ref)
or [`MapFormat`](@ref).

The state object `state` is initialized and iterated by [`iterstate`](@ref).
"""
valueformat(T::Type, ::Format, scope) = DefaultFormat()
valueformat(T::Type, fmt::Format, scope, ::Scope) = valueformat(T, fmt, scope)

