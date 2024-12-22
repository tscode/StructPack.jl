
"""
    typeparamtype(T::Type, ::Format, index [, ::Scope])

Return the type of the `index`-th type parameter of `T`.

Defaults to `Any`.

This method is consulted when packing / unpacking types via [`TypeFormat`](@ref)
and [`TypedFormat`]. It can be used to insert information about the type
parameters of `T`.
"""
typeparamtype(T::Type, ::Format, index) = Any

function typeparamtype(T::Type, fmt::Format, index, scope::Scope)
  return typeparamtype(T, fmt, index)
end

"""
    typeparamformat(T::Type, index)

Return the type param format of the `index`-th type parameter of `T`

Defaults to `Any`.

This method is consulted when packing / unpacking types via [`TypeFormat`](@ref)
and [`TypedFormat`]. It can be used to insert information about the type
parameters of `T`.

This method is called by `valueformat(TypeParams{T}, fmt, index, scope)`.
"""
typeparamformat(::Type, ::Format, index) = TypedFormat()

function typeparamformat(T::Type, fmt::Format, index, scope::Scope)
  return typeparamformat(T, fmt, index)
end

"""
Auxiliary structure that expresses the parameters of a parametric type in a
format friendly to serialization.
"""
struct TypeParams{T}
  params::Vector{Any}
end

format(::Type{<:TypeParams}) = VectorFormat()

function valuetype(::Type{TypeParams{T}}, fmt::Format, index, scope::Scope) where {T}
  return typeparamtype(T, fmt, index, scope)
end

function valueformat(::Type{TypeParams{T}}, fmt::Format, index, scope::Scope) where {T}
  return typeparamformat(T, fmt, index, scope)
end

destruct(t::TypeParams, ::VectorFormat) = t.params

function construct(::Type{TypeParams{T}}, vals, ::VectorFormat) where {T}
  return TypeParams{T}(collect(vals))
end

"""
    TypeParams()

Create an empty type parameter list.
"""
TypeParams() = TypeParams{Any}([])

"""
    TypeParams(T::Type)

Extract the type parameters of a given type `T` and return a `TypeParams` object.

!!! warning

    Currently, the following limitation holds: If `T` has more type parameters
    than are explicitly specified (`T = Array{Float32}`), the specified
    parameters must come first. For example, `TypeParams(T)` for
    `T = Array{F, 1} where {F}` will fail.
"""
function TypeParams(T::Type)
  params = nothing
  vars = []
  body = T
  while isnothing(params)
    if hasproperty(body, :parameters)
      params = collect(body.parameters)
    elseif hasproperty(body, :body) && hasproperty(body, :var)
      push!(vars, body.var)
      body = body.body
    else
      error("Failed to understand parameter structure of type $T.")
    end
  end
  for R in reverse(vars)
    @assert pop!(params) == R """
    Cannot extract type parameters from type $T.
    """
  end
  params = map(params) do param
    param isa Type ? TypeValue(param) : param
  end
  return TypeParams{T}(params)
end

"""
Auxiliary structure that expresses a type in a format friendly to serialization.
"""
struct TypeValue
  name::Symbol
  path::Vector{Symbol}
  params::TypeParams
end

format(::Type{TypeValue}) = DynamicMapFormat()
iterstate(::Type{TypeValue}, ::DynamicMapFormat) = []
iterstate(::Type{TypeValue}, ::DynamicMapFormat, state, entry) = push!(state, entry[2])

function valuetype(::Type{TypeValue}, ::DynamicMapFormat, state)
  index = length(state) + 1
  if index == 3 # derive the type T (without type parameters) from name and path
    T = composetype(TypeValue(state..., TypeParams()))
    TypeParams{T}
  else
    fieldtype(TypeValue, index)
  end
end

"""
    TypeValue(T::Type)

Create a `TypeValue` object from a given type `T`.

The resulting object can be packed / unpacked in [`MapFormat`](@ref) and can be
converted back to `T` via [`composetype`](@ref).
"""
function TypeValue(T::Type)
  name = Base.nameof(T)
  path = string(Base.parentmodule(T))
  path = Symbol.(split(path, "."))
  params = TypeParams(T)
  return TypeValue(name, path, params)
end

TypeValue(val) = TypeValue(typeof(val))

function composetype(value::TypeValue)::Type
  T = Main
  for m in value.path
    T = getfield(T, m)::Module
  end
  T = getfield(T, value.name)::Type
  params = composetypeparam.(value.params.params)
  return isempty(params) ? T : T{params...}
end

composetypeparam(value) = value 
composetypeparam(value::TypeValue) = composetype(value)
composetypeparam(str::String) = Symbol(str)
composetypeparam(t::Tuple) = composetypeparam.(t)

"""
Wrapper format for storing the value and type of an object.

If a value `val::T` can be packed in the format `F<:Format` and its type `T`
can be packed in [`TypeFormat`](@ref), then packing `val` in `TypedFormat{F}`
enables unpacking via `unpack(io, TypedFormat{F}())`, i.e., without knowledge
of `T`.
"""
struct TypedFormat{F <: Format} <: Format end

TypedFormat() = TypedFormat{DefaultFormat}()

"""
Auxiliary structure that expresses a value and its type in a format friendly
to serialization.
"""
struct TypedValue{F}
  type::TypeValue
  value::Any
end

format(::Type{<: TypedValue}) = DynamicMapFormat()
iterstate(::Type{<: TypedValue}, ::DynamicMapFormat) = []
iterstate(::Type{<: TypedValue}, ::DynamicMapFormat, state, entry) = push!(state, entry[2])

function valueformat(::Type{TypedValue{F}}, ::DynamicMapFormat, state) where {F}
  return length(state) == 0 ? DefaultFormat() : F()
end

function valuetype(::Type{TypedValue{F}}, ::DynamicMapFormat, state) where {F}
  return length(state) == 0 ? TypeValue : composetype(state[1])
end

function pack(io::IO, value, ::TypedFormat{F}, scope::Scope) where {F <: Format}
  pack(io, TypedValue{F}(value), DynamicMapFormat(), scope)
end

function unpack(io::IO, T::Type, ::TypedFormat{F}, scope::Scope) where {F <: Format}
  tval = unpack(io, TypedValue{F}, DynamicMapFormat(), scope)
  @assert tval.value isa T """
  Expected value type $T when unpacking typed value. Found $(typeof(tval.value)).
  """
  return tval.value
end

function unpack(io::IO, fmt::TypedFormat, scope::Scope = DefaultScope())
  return unpack(io, Any, fmt, scope)
end

"""
  TypedValue{F}(val)

Create a `TypedValue` with base format `F`.
"""
TypedValue{F}(val) where {F} = TypedValue{F}(TypeValue(val), val)
