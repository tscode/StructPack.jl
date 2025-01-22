
"""
Structure holding the type and binary data stored in a msgpack extension object.
"""
struct ExtensionData
  type::Int8
  data::Vector{UInt8}
end

extensiontype(data::ExtensionData) = data.type

"""
Auxiliary format used to unpack generic extension data.

This format cannot be used for packing since the extension type is ambiguous.
"""
struct AnyExtensionFormat <: Format end

function isformatbyte(byte, ::AnyExtensionFormat)
  return 0xd4 <= byte <= 0xd8 || # fixext 1 to 16
         0xc7 <= byte <= 0xc9 # ext 8 to 32
end

"""
Format for supporting the msgpack extension standard.

Built upon the msgpack formats `fixext 1 - 8` and `ext 8 - 32`.

## Defaults
Use

    format(::Type{T}) = ExtensionFormat{I}()

or 

    @pack T in ExtensionFormat{I}

to make [`ExtensionFormat`](@ref) with msgpack extension type `I::Int8` the
default format for type `T`. If `T` is abstract, use `{<: T}` to cover all
subtypes.

## Packing
To support packing values of type `T` in [`ExtensionFormat`](@ref), implement

    destruct(val::T, ::ExtensionFormat{I})::R

where the return value `ret::R` must implement `sizeof(ret)` (number of bytes)
as well as `write(io, ret)`.

## Unpacking
To support unpacking values of type `T` packed in [`ExtensionFormat`](@ref),
implement

    construct(::Type{T}, ::Vector{UInt8}, ::ExtensionFormat{I})::T

or make sure that the constructor `T(::Vector{UInt8})` is defined.
"""
struct ExtensionFormat{I} <: Format
  function ExtensionFormat{J}() where {J}
    type = try
      Int8(J)
    catch err
      error("Invalid type indicator $I for ExtensionFormat (requires Int8)")
    end
    return new{type}()
  end
end

extensiontype(::ExtensionFormat{I}) where {I} = I

function isformatbyte(byte, ::ExtensionFormat)
  return isformatbyte(byte, AnyExtensionFormat())
end

function pack(io::IO, value, fmt::ExtensionFormat{I}, ctx::Context)::Nothing where {I}
  bin = destruct(value, fmt, ctx)
  n = sizeof(bin)
  if n == 1 # fixext 1
    write(io, 0xd4)
    write(io, Int8(I))
  elseif n == 2 # fixext 2
    write(io, 0xd5)
    write(io, Int8(I))
  elseif n == 4 # fixext 4
    write(io, 0xd6)
    write(io, Int8(I))
  elseif n == 8 # fixext 8
    write(io, 0xd7)
    write(io, Int8(I))
  elseif n == 16 # fixext 16
    write(io, 0xd8)
    write(io, Int8(I))
  elseif n <= typemax(UInt8) # ext 8
    write(io, 0xc7)
    write(io, UInt8(n))
    write(io, Int8(I))
  elseif n <= typemax(UInt16) # ext 16
    write(io, 0xc8)
    write(io, UInt16(n) |> hton)
    write(io, Int8(I))
  elseif n <= typemax(UInt32) # ext 32
    write(io, 0xc9)
    write(io, UInt32(n) |> hton)
    write(io, Int8(I))
  else
    packerror("Invalid extension binary length $n")
  end
  write(io, bin)
  return
end

function unpack(io::IO, ::AnyExtensionFormat, ctx::Context)::ExtensionData
  byte = read(io, UInt8)
  if byte == 0xd4 # fixext 1
    n = 1
    type = read(io, Int8)
  elseif byte == 0xd5 # fixext 2
    n = 2
    type = read(io, Int8)
  elseif byte == 0xd6 # fixext 4
    n = 4
    type = read(io, Int8)
  elseif byte == 0xd7 # fixext 8
    n = 8
    type = read(io, Int8)
  elseif byte == 0xd8 # fixext 16
    n = 16
    type = read(io, Int8)
  elseif byte == 0xc7 # ext 8 
    n = read(io, UInt8)
    type = read(io, Int8)
  elseif byte == 0xc8 # ext 16
    n = read(io, UInt16) |> ntoh
    type = read(io, Int8)
  elseif byte == 0xc9 # ext 32
    n = read(io, UInt32) |> ntoh
    type = read(io, Int8)
  else
    byteerror(byte, AnyExtensionFormat)
  end
  return ExtensionData(type, read(io, n))
end

function unpack(io::IO, ::ExtensionFormat{I}, ctx::Context)::ExtensionData{I} where {I}
  data = unpack(io, AnyExtensionFormat(), ctx)
  if extensiontype(data) != I 
    unpackerror("Expected extension type $I, found $(extensiontype(data)).")
  end
  return data.data
end

