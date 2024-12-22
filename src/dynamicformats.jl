
"""
    iterstate(T::Type, fmt::Format [, scope::Scope])
    
Initialize a state object that is repeatedly updated while iterating over the
entries of values of type `T` when packing and unpacking in format `fmt`.

By default, the initial state is `1` and gets replaced by `state + 1` in
subsequent updates.

This function is only relevant for formats that dynamically make use of the
methods [`keytype`](@ref), [`keyvalue`](@ref), [`valuetype`](@ref), or
[`valueformat`](@ref), like [`DynamicVectorFormat`](@ref) and
[`DynamicMapFormat`](@ref).
"""
iterstate(T::Type, ::Format) = 1 
iterstate(T::Type, ::Format, state::Int, entry) = state + 1

"""
    iterstate(T::Type, fmt::Format, state, entry [, scope::Scope])

Return an update of the state object `state` when `T` is unpacked in the format
`fmt`.

The argument `entry` signifies the entry packed / unpacked in the last
iteration and can be used to inform the next iteration state. It will be of
type `valuetype(T, fmt, state, scope)` in case of [`DynamicVectorFormat`](@ref) and
a key-value pair with types determined by [`keytype`](@ref) and [`valuetype`]
(@ref) in case of [`DynamicMapFormat`](@ref).

This approach enables 'dynamic' unpacking where the type / format of an entry
depends on the values unpacked previously. The format [`TypedFormat`](@ref)
exploits this pattern.
"""
iterstate(T::Type, fmt::Format, ::Scope) = iterstate(T, fmt)

function iterstate(T::Type, fmt::Format, state, entry, ::Scope)
  return iterstate(T, fmt, state, entry)
end

"""
Modification of [`VectorFormat`](@ref).

During unpacking, the types and formats of future entries may depend on
past entries via overloading [`iterstate`](@ref).

!!! info

    `DynamicVectorFormat` is currently slower than [`VectorFormat`](@ref),
    even if [`iterstate`](@ref) just enumerates indices. In principle, however,
    the compiler should have all information neccessary to optimize
    `DynamicVectorFormat` in this case and bring the performance on
    par. In the future, we might thus deprecate `DynamicVectorFormat` and
    absorb its functionality into `VectorFormat`.
"""
struct DynamicVectorFormat <: Format end

const AnyVectorFormat = Union{VectorFormat, DynamicVectorFormat}

function pack(io::IO, value::T, fmt::DynamicVectorFormat, scope::Scope) where {T}
  val = destruct(value, fmt, scope)
  n = length(val)
  if n < 16 # fixarray
    write(io, 0x90 | UInt8(n))
  elseif n <= typemax(UInt16) # array16
    write(io, 0xdc)
    write(io, UInt16(n) |> hton)
  elseif n <= typemax(UInt32) # array32
    write(io, 0xdd)
    write(io, UInt32(n) |> hton)
  else
    ArgumentError("invalid array length $n") |> throw
  end
  state = iterstate(T, fmt, scope)
  for entry in val
    fmt_val = valueformat(T, fmt, state, scope)
    pack(io, entry, fmt_val, scope)
    state = iterstate(T, fmt, state, entry, scope)
  end
  return nothing
end

function unpack(io::IO, ::Type{T}, fmt::DynamicVectorFormat, scope::Scope)::T where {T}
  byte = read(io, UInt8)
  n = if byte & 0xf0 == 0x90 # fixarray
    Int(byte & 0x0f)
  elseif byte == 0xdc # array 16
    Int(read(io, UInt16) |> ntoh)
  elseif byte == 0xdd # array 32
    Int(read(io, UInt32) |> ntoh)
  else
    byteerror(byte, fmt)
  end
  state = iterstate(T, fmt, scope)
  entries = Iterators.map(1:n) do _
    S = valuetype(T, fmt, state, scope)
    fmt_val = valueformat(T, fmt, state, scope)
    entry = unpack(io, S, fmt_val, scope)
    state = iterstate(T, fmt, state, entry, scope)
    return entry
  end
  return construct(T, Generator{T}(entries), fmt, scope)
end

"""
Modification of [`MapFormat`](@ref).

During unpacking, the types and formats of future entries may depend on
past entries via overloading [`iterstate`](@ref).

!!! info

    `DynamicMapFormat` is currently slower than [`MapFormat`](@ref),
    even if [`iterstate`](@ref) just enumerates indices. In principle, however,
    the compiler should have all information neccessary to optimize
    `DynamicMapFormat` in this case and bring the performance on
    par. In the future, we might thus deprecate `DynamicMapFormat` and
    absorb its functionality into `MapFormat`.
"""
struct DynamicMapFormat <: Format end

const AnyMapFormat = Union{MapFormat, DynamicMapFormat}

function pack(io::IO, value::T, fmt::DynamicMapFormat, scope::Scope) where {T}
  val = destruct(value, fmt, scope)
  n = length(val)
  if n < 16 # fixmap
    write(io, 0x80 | UInt8(n))
  elseif n <= typemax(UInt16) # map 16
    write(io, 0xde)
    write(io, UInt16(n) |> hton)
  elseif n <= typemax(UInt32) # map 32
    write(io, 0xdf)
    write(io, UInt32(n) |> hton)
  else
    ArgumentError("invalid map length $n") |> throw
  end
  state = iterstate(T, fmt, scope)
  for entry in val
    fmt_key = keyformat(T, fmt, state, scope)
    fmt_val = valueformat(T, fmt, state, scope)
    pack(io, first(entry), fmt_key, scope)
    pack(io, last(entry), fmt_val, scope)
    state = iterstate(T, fmt, state, entry, scope)
  end
  return nothing
end

function unpack(io::IO, ::Type{T}, fmt::DynamicMapFormat, scope::Scope)::T where {T}
  byte = read(io, UInt8)
  n = if byte & 0xf0 == 0x80
    byte & 0x0f
  elseif byte == 0xde
    read(io, UInt16) |> ntoh
  elseif byte == 0xdf
    read(io, UInt32) |> ntoh
  else
    byteerror(byte, fmt)
  end
  state = iterstate(T, fmt, scope)
  pairs = Iterators.map(1:n) do _
    K = keytype(T, fmt, state, scope)
    V = valuetype(T, fmt, state, scope)
    fmt_key = keyformat(T, fmt, state, scope)
    fmt_val = valueformat(T, fmt, state, scope)
    key = unpack(io, K, fmt_key, scope)
    value = unpack(io, V, fmt_val, scope)
    entry = key=>value
    state = iterstate(T, fmt, state, entry, scope)
    return entry
  end
  return construct(T, Generator{T}(pairs), fmt, scope)
end
