
"""
Auxiliary object for unpacking sequential values like vectors or maps.

Implements the `Base` iterator interface and can for most purposes be treated
like a `Base.Generator`. Compared to the latter, it is equipped with additional
element type information from its first type parameter `T`.

In particular, when unpacking a value of type `Generator{T}` in
[`VectorFormat`](@ref) or [`MapFormat`](@ref), the [`valuetype`](@ref),
[`valueformat`](@ref), [`keytype`](@ref), and [`keyformat`](@ref) methods
dispatched on `T` are called to determine how elements are unpacked.
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

function keytype(::Type{Generator{T}}, fmt::Format, state, scope::Scope) where {T}
  return keytype(T, fmt, state, scope)
end

function keyformat(::Type{Generator{T}}, fmt::Format, state, scope::Scope) where {T}
  return keyformat(T, fmt, state, scope)
end

function valuetype(::Type{Generator{T}}, fmt::Format, state, scope::Scope) where {T}
  return valuetype(T, fmt, state, scope)
end

function valueformat(::Type{Generator{T}}, fmt::Format, state, scope::Scope) where {T}
  return valueformat(T, fmt, state, scope)
end

function construct(::Type{Generator{T}}, val::Generator{Generator{T}}, ::Format, scope::Scope) where {T}
  return Generator{T}(val.iter)
end


