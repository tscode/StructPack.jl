
"""
Auxiliary object for unpacking sequential values.

Implements the `Base` iterator interface and can for most purposes be treated
like a `Base.Generator`. Compared to the latter, it is equipped with additional
element type information via its first type parameter `T`.

In particular, when unpacking a value of type `Generator{T}` in
[`VectorFormat`](@ref) or [`MapFormat`](@ref), the methods [`valuetype`](@ref),
[`valueformat`](@ref), [`keytype`](@ref), and [`keyformat`](@ref) are called
with type argument `T` to determine how elements are unpacked.
"""
struct Generator{T, I}
  iter::I
  Generator{T}(iter) where {T} = new{T, typeof(iter)}(iter)
end

# Iterators interface
Base.length(gen::Generator) = length(gen.iter)
Base.size(gen::Generator, args...) = size(gen.iter, args...)
Base.iterate(gen::Generator, args...) = iterate(gen.iter, args...)
Base.eltype(::Type{<: Generator{T}}) where {T} = Base.eltype(T)

function Base.IteratorSize(::Type{<: Generator{T, I}}) where {T, I}
  return Base.IteratorSize(I)
end

function keytype(::Type{Generator{T}}, state, fmt::Format, ctx::Context) where {T}
  return keytype(T, state, fmt, ctx)
end

function keyformat(::Type{Generator{T}}, state, fmt::Format, ctx::Context) where {T}
  return keyformat(T, state, fmt, ctx)
end

function valuetype(::Type{Generator{T}}, state, fmt::Format, ctx::Context) where {T}
  return valuetype(T, state, fmt, ctx)
end

function valueformat(::Type{Generator{T}}, state, fmt::Format, ctx::Context) where {T}
  return valueformat(T, state, fmt, ctx)
end

function construct(::Type{Generator{T}}, val::Generator{Generator{T}}, ::Format, ::Context) where {T}
  return Generator{T}(val.iter)
end


