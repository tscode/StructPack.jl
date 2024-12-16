
#
# ValFormat
#

"""
Format wrapper that is used to resolve ambiguities for the type
[`Val`](@ref).
"""
struct ValFormat <: Format end

"""
Wrapper that enforces packing / unpacking of a value in a certain format.
"""
struct Val{F <: Format, T}
  value::T
end

Val(val::T, ::F) where {F, T} = Val{F, T}(val)

format(::Type{<:Val}) = ValFormat()

function pack(io::IO, value::Val{F, T}, ::ValFormat) where {F, T}
  return pack(io, value.value, F())
end

function unpack(io::IO, ::Type{Val{F, T}}, ::ValFormat) where {F, T}
  return Val(unpack(io, T, F()), F())
end

function unpack(io::IO, ::Type{Val{F}}, ::ValFormat) where {F <: Format}
  return Val(unpack(io, F()), F())
end

#
# TypeFormat
#

struct TypeParamFormat <: Format end

pack(io::IO, value, ::TypeParamFormat) = pack(io, value)

function unpack(io::IO, ::TypeParamFormat)
  if peekformat(io) == MapFormat()
    unpack(io, TypeValue)
  elseif peekformat(io) == VectorFormat()
    Tuple(unpack(io, Vector))
  else
    unpack(io, Any)
  end
end

struct TypeFormat <: Format end

struct TypeValue
  name::Symbol
  path::Vector{Symbol}
  params::Vector{Val{TypeParamFormat}}
end

# TODO: check if there is a way to find the type of a bitstype type parameter
# (like N in Array{N, F})!
"""
    TypeValue(T)

Construct a [`TypeValue`](@ref) out of the type `T`.

Currently, the following limitations for parameterized types apply:
* If `T` has more type parameters than are explicitly specified \
  (e.g., `T = Array{Float32}`), the specified type parameters must come first \
  (e.g., `T = Array{F, 1} where {F}` would fail).
* Only certain primitive bitstypes are supported as type parameters, like \
  `Bool` or `Int64`. Other bitstypes (like `UInt64` or `Int16`) are converted \
  to Int64 type parameters when unpacking.
"""
function TypeValue(T::Type)
  name = Base.nameof(T)
  path = string(Base.parentmodule(T))
  path = Symbol.(split(path, "."))
  params = typeparams(T)
  params = map(params) do param
    if param isa Type
      Val(TypeValue(param), TypeParamFormat())
    else
      Val(param, TypeParamFormat())
    end
  end
  return TypeValue(name, path, params)
end

format(::Type{TypeValue}) = MapFormat()

pack(io::IO, value, ::TypeFormat)::Nothing = pack(io, TypeValue(value))

function unpack(io::IO, ::TypeFormat)::Type
  value = unpack(io, TypeValue)
  return composetype(value)
end

function typeparams(T)
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
      error("Failed to understand structure of type $T")
    end
  end
  for R in reverse(vars)
    @assert pop!(params) == R "Cannot extract type parameters from type $T"
  end
  return params
end

function composetype(value::TypeValue)::Type
  # Resolve type from module path and name
  T = Main
  for m in value.path
    T = getfield(T, m)::Module
  end
  T = getfield(T, value.name)::Type
  # attach type parameters
  if isempty(value.params)
    T
  else
    params = map(value.params) do param
      return composetypeparam(param.value)
    end
    T{params...}
  end
end

function composetypeparam(value)
  if value isa TypeValue
    composetype(value)
  else
    value
  end
end

format(::Type{<:Type}) = TypeFormat()

function construct(::Type{Type}, S, ::TypeFormat)
  @assert isa(S, Type) "unpacked value $S was expected to be a type"
  return S
end

#
# TypedFormat
#

"""
Format reserved for the type [`Typed`](@ref)
"""
struct TypedFormat{F <: Format} <: Format end

TypedFormat() = TypedFormat{DefaultFormat}()

function pack(io::IO, value, ::TypedFormat{F}) where {F <: Format}
  write(io, 0x82) # fixmap of length 2
  pack(io, :type)
  pack(io, typeof(value))
  pack(io, :value)
  return pack(io, Val(value, F()))
end

function pack(io::IO, value::T, ::TypedFormat{DefaultFormat}) where {T}
  F = typeof(format(T))
  return pack(io, value, TypedFormat{F}())
end

function unpack(io::IO, ::TypedFormat{F}) where {F <: Format}
  byte = read(io, UInt8)
  if byte == 0x82 # expect fixmap of length 2
    key = unpack(io, Symbol)
    @assert key == :type """
    Expected map key :type when unpacking typed value. Got :$key.
    """
    T = unpack(io, Type)
    key = unpack(io, Symbol)
    @assert key == :value """
    Expected map key :value when unpacking typed value. Got :$key.
    """
    unpack(io, T, F())
  else
    byteerror(byte, TypedFormat{F}())
  end
end

function unpack(io::IO, ::Type{T}, ::TypedFormat{F})::T where {T, F <: Format}
  val = unpack(io, TypedFormat{F}())
  @assert val isa T "Expected value type $T when unpacking typed value"
  return val
end

function unpack(io::IO, ::TypedFormat{DefaultFormat})
  byte = read(io, UInt8)
  if byte == 0x82 # expect fixmap of length 2
    key = unpack(io, Symbol)
    @assert key == :type "Expected map key :type when unpacking typed value"
    T = unpack(io, Type)
    key = unpack(io, Symbol)
    @assert key == :value "Expected map key :value when unpacking typed value"
    unpack(io, T)
  else
    byteerror(byte, TypedFormat{DefaultFormat}())
  end
end

#
# StreamFormat
#
struct StreamFormat{S, F <: Format} <: Format end

StreamFormat(S) = StreamFormat{S, DefaultFormat}()

function pack(io::IO, value, ::StreamFormat{S, F}) where {S, F}
  return error(
    """
Packing in StreamFormat requires the package TranscodingStreams to be loaded.
""",
  )
end

function unpack(io::IO, ::StreamFormat{S, F}) where {S, F}
  return error(
    """
Unpacking in StreamFormat requires the package TranscodingStreams to be loaded.
""",
  )
end

#
# AliasFormat
#

struct AliasFormat{S} <: Format end

function pack(io::IO, value::T, ::AliasFormat{S})::Nothing where {S, T}
  val = destruct(value, AliasFormat{S}())
  return pack(io, val)
end

function unpack(io::IO, ::Type{T}, ::AliasFormat{S})::T where {S, T}
  val = unpack(io, S)
  return construct(T, val, AliasFormat{S}())
end

construct(::Type{T}, val, ::AliasFormat) where {T} = T(val)
destruct(val::T, ::AliasFormat{S}) where {S, T} = S(val)
