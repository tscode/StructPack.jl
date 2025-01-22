
"""
    typeparamtypes(T::Type [, ctx::Context])

Return the types of the type parameters of `T` when packing / unpacking under
`ctx`.

If `T` has type parameters, this method **must** be implemented for packing /
unpacking types via [`TypeFormat`](@ref) and [`TypedFormat`](@ref).
"""
function typeparamtypes(T::Type)
  packerror("No type parameter types have been specified for type $T.")
end

typeparamtypes(T::Type, ::Context) = typeparamtypes(T)

"""
    typeparamformats(T::Type [, ctx::Context])

Return the formats of the type parameters of `T` when packing / unpacking under
`ctx`.

Defaults to `DefaultFormat()` for each type parameter.

This method is consulted when packing / unpacking types via [`TypeFormat`](@ref)
and [`TypedFormat`](@ref).
"""
function typeparamformats(::Type{T}) where {T}
  ntuple(_ -> DefaultFormat(), length(typeparamtypes(T)))
end

typeparamformats(T::Type, ::Context) = typeparamformats(T)

"""
Auxiliary structure that expresses the parameters of a parametric type in a
format friendly to serialization.
"""
struct TypeParams{T}
  params::Vector{Any}
end

format(::Type{<:TypeParams}) = VectorFormat()

function valuetype(::Type{TypeParams{T}}, index, ::VectorFormat, ctx::Context) where {T}
  types = typeparamtypes(T, ctx)
  @assert index <= length(types) """
  Too few type parameter types have been specified for type $T.
  """
  return types[index]
end

function valueformat(::Type{TypeParams{T}}, index, ::VectorFormat, ctx::Context) where {T}
  formats = typeparamformats(T, ctx)
  @assert index <= length(formats) """
  Too few type parameter formats have been specified for type $T.
  """
  return formats[index]
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
iterstate(::Type{TypeValue}, state, entry, ::DynamicMapFormat) = push!(state, entry[2])

function valuetype(::Type{TypeValue}, state, ::DynamicMapFormat)
  index = length(state) + 1
  if index == 3 # derive the type T (without type parameters) from name and path
    T = composetype(TypeValue(state..., TypeParams()))
    TypeParams{T}
  else
    fieldtype(TypeValue, index)
  end
end

function Base.show(io::IO, ::MIME"text/plain", val::TypeValue)
  print("TypeValue($(composetype(val)))")
end

"""
Format that is used for packing types.

In order to pack and unpack a type `T::Type` in `TypeFormat`, make sure that
`t = StructPack.TypeValue(T)` works and that `StructPack.composetype(t)`
successfully reconstructs `T`.

If `T` has type parameters, their serialization can be influenced via the
functions [`typeparamtypes`](@ref) and [`typeparamformats`](@ref).

By default, all type parameters are packed / unpacked in [`TypedFormat`](@ref).
"""
struct TypeFormat <: Format end

function pack(io::IO, value, fmt::TypeFormat, ctx::Context)
  val = destruct(value, fmt, ctx)
  pack(io, val, DynamicMapFormat(), ctx)
end

function unpack(io::IO, ::TypeFormat, ctx::Context)
  unpack(io, TypeValue, DynamicMapFormat(), ctx)
end

format(::Type{<: Type}) = TypeFormat()
destruct(T::Type, ::TypeFormat) = TypeValue(T)

function construct(::Type{R}, val::TypeValue, ::TypeFormat) where {R}
  T = composetype(val)
  if !(T isa R) 
    unpackerror("""
    Expected ::$R when upacking value in TypeFormat. Found $T.
    """)
  end
  return T
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
  # When a type parameter that is a type (like Int) is saved via TypedValue,
  # the typed value that is stored is `TypeValue`.
  # Therefore, StructPack.TypedValue gets stored
  path = value.path
  if !isempty(path) && path[1] == "StructPack"
    T = StructPack
    path = path[2:end]
  else
    T = Main
  end
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
Auxiliary structure that expresses a value and its type in a format friendly
to serialization.
"""
struct TypedValue{T, F}
  type::TypeValue
  value::Any
end

"""
  TypedValue{F}(val)

Create a `TypedValue` with value format `F()`.
"""
TypedValue{F}(val::T) where {F, T} = TypedValue{T, F}(TypeValue(val), val)

format(::Type{<: TypedValue}) = DynamicMapFormat()
iterstate(::Type{<: TypedValue}, ::DynamicMapFormat) = []
iterstate(::Type{<: TypedValue}, state, entry, ::DynamicMapFormat) = push!(state, entry[2])

function valueformat(::Type{TypedValue{T, F}}, state, ::DynamicMapFormat) where {T, F}
  return length(state) == 0 ? DefaultFormat() : F()
end

function valuetype(::Type{TypedValue{T, F}}, state, ::DynamicMapFormat) where {T, F}
  if length(state) == 0
    return TypeValue
  else
    S = composetype(state[1])
    @assert S <: T """
    Encountered the unexpected type $S when unpacking a typed value of type $T.
    """
    return S
  end
end

"""
Wrapper format for storing the value and type of an object.

If a value `val::T` can be packed in the format `F<:Format` and its type `T`
can be packed in [`TypeFormat`](@ref), then packing `val` in `TypedFormat{F}`
enables unpacking via `unpack(io, TypedFormat{F}())`, i.e., without knowledge
of `T`.
"""
struct TypedFormat{F <: Format} <: Format end

TypedFormat() = TypedFormat{DefaultFormat}()

function _checkrecursion(T::Type, fmt::Format, ctx::Context)
  if fmt == DefaultFormat() && format(T, ctx) isa TypedFormat
    @error """
    Recursive typed format detected.

    This probably means that you have specified TypedFormat without an \
    underlying base format as the default format for a type.
    To prevent this, only ever use TypedFormat{F} with a given base format F \
    when defining default formats.

    For example, `@pack {<: A} in TypedFormat` or `@pack {<: A} in TypedFormat{DefaultFormat}` \
    will not work, while `@pack {<: A} in TypedFormat{StructFormat}` is okay.
    """
    packerror("Recursive typed packing detected")
  end
end

function pack(io::IO, value::T, ::TypedFormat{F}, ctx::Context) where {T, F <: Format}
  _checkrecursion(T, F(), ctx)
  pack(io, TypedValue{F}(value), DynamicMapFormat(), ctx)
end

function unpack(io::IO, T::Type, ::TypedFormat{F}, ctx::Context) where {F <: Format}
  _checkrecursion(T, F(), ctx)
  tv = unpack(io, TypedValue{T, F}, DynamicMapFormat(), ctx)
  if !(tv.value isa T)
    unpackerror("""
    Expected value type $T when unpacking typed value. Got $(typeof(tv.value)).
    """)
  end
  return tv.value
end

function unpack(io::IO, fmt::TypedFormat, ctx::Context = context[])
  return unpack(io, Any, fmt, ctx)
end

