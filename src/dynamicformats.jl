
"""
    iterstate(T::Type, fmt::Format [, ctx::Context])
    
Initialize a state object that is repeatedly updated while iterating over the
entries of values of type `T` when packing and unpacking in format `fmt`.

By default, the initial state is `1` and gets replaced by `state + 1` in
subsequent updates.

This function is only relevant for formats that dynamically make use of the
methods [`keytype`](@ref), [`keyformat`](@ref), [`valuetype`](@ref), or
[`valueformat`](@ref), like [`DynamicVectorFormat`](@ref) and
[`DynamicMapFormat`](@ref).
"""
iterstate(T::Type, ::Format) = 1 
iterstate(T::Type, fmt::Format, ::Context) = iterstate(T, fmt)

"""
    iterstate(T::Type, state, entry, fmt::Format [, ctx::Context])

Return an update of the state object `state` when `T` is packed or unpacked in
the format `fmt`.

The argument `entry` signifies the entry packed / unpacked in the last
iteration and can be used to inform the next iteration state. It will be of
type `valuetype(T, fmt, state, ctx)` in case of [`DynamicVectorFormat`](@ref) and
similarly a key-value pair with types determined by [`keytype`](@ref) and
[`valuetype`](@ref) in case of [`DynamicMapFormat`](@ref).

This approach enables 'dynamic' unpacking where the type / format of an entry
depends on the values unpacked previously. The format [`TypedFormat`](@ref)
exploits this pattern.
"""
iterstate(::Type, state, entry, ::Format) = state + 1

function iterstate(T::Type, state, entry, fmt::Format, ::Context)
  return iterstate(T, state, entry, fmt)
end

"""
Modification of [`VectorFormat`](@ref).

During unpacking, the types and formats of future entries may depend on
past entries via overloading [`iterstate`](@ref).

!!! info

    [`DynamicVectorFormat`](@ref) is currently slower than
    [`VectorFormat`](@ref), even if [`iterstate`](@ref) just enumerates
    indices. In principle, however, the compiler should have all information
    neccessary to optimize [`DynamicVectorFormat`](@ref) in this case and
    bring the performance on par. In the future, we might thus deprecate
    [`DynamicVectorFormat`](@ref) and absorb its functionality into
    [`VectorFormat`](@ref).
"""
struct DynamicVectorFormat <: AbstractVectorFormat end

function pack(io::IO, value::T, fmt::DynamicVectorFormat, ctx::Context) where {T}
  val = destruct(value, fmt, ctx)
  writeheaderbytes(io, val, VectorFormat())
  state = iterstate(T, fmt, ctx)
  for entry in val
    fmt_val = valueformat(T, state, fmt, ctx)
    pack(io, entry, fmt_val, ctx)
    state = iterstate(T, state, entry, fmt, ctx)
  end
  return
end

function unpack(io::IO, ::Type{T}, fmt::DynamicVectorFormat, ctx::Context)::T where {T}
  n = readheaderbytes(io, VectorFormat())
  state = iterstate(T, fmt, ctx)
  entries = Iterators.map(1:n) do _
    S = valuetype(T, state, fmt, ctx)
    fmt_val = valueformat(T, state, fmt, ctx)
    entry = unpack(io, S, fmt_val, ctx)
    state = iterstate(T, state, entry, fmt, ctx)
    return entry
  end
  return construct(T, Generator{T}(entries), fmt, ctx)
end

"""
Modification of [`MapFormat`](@ref).

During unpacking, the types and formats of future entries may depend on
past entries via overloading [`iterstate`](@ref).

!!! info

    [`DynamicMapFormat`](@ref) is currently slower than [`MapFormat`](@ref),
    even if [`iterstate`](@ref) just enumerates indices. In principle,
    however, the compiler should have all information neccessary to optimize
    [`DynamicMapFormat`](@ref) in this case and bring the performance on par.
    In the future, we might thus deprecate [`DynamicMapFormat`](@ref) and absorb
    its functionality into [`MapFormat`](@ref).
"""
struct DynamicMapFormat <: AbstractMapFormat end

const AnyMapFormat = Union{MapFormat, DynamicMapFormat}

function pack(io::IO, value::T, fmt::DynamicMapFormat, ctx::Context) where {T}
  val = destruct(value, fmt, ctx)
  writeheaderbytes(io, val, MapFormat())
  state = iterstate(T, fmt, ctx)
  for entry in val
    fmt_key = keyformat(T, state, fmt, ctx)
    fmt_val = valueformat(T, state, fmt, ctx)
    pack(io, first(entry), fmt_key, ctx)
    pack(io, last(entry), fmt_val, ctx)
    state = iterstate(T, state, entry, fmt, ctx)
  end
  return
end

function unpack(io::IO, ::Type{T}, fmt::DynamicMapFormat, ctx::Context)::T where {T}
  n = readheaderbytes(io, MapFormat())
  state = iterstate(T, fmt, ctx)
  pairs = Iterators.map(1:n) do _
    K = keytype(T, state, fmt, ctx)
    V = valuetype(T, state, fmt, ctx)
    fmt_key = keyformat(T, state, fmt, ctx)
    fmt_val = valueformat(T, state, fmt, ctx)
    key = unpack(io, K, fmt_key, ctx)
    value = unpack(io, V, fmt_val, ctx)
    entry = key=>value
    state = iterstate(T, state, entry, fmt, ctx)
    return entry
  end
  return construct(T, Generator{T}(pairs), fmt, ctx)
end
