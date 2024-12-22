
"""
Core format.

All core packing formats have a low-level implementation that complies with one
or more formats of the msgpack specification.

The following core formats are supported out of the box:

- [`NilFormat`](@ref) (msgpack nil)
- [`BoolFormat`](@ref) (msgpack boolean)
- [`SignedFormat`](@ref) (msgpack negative / positive fixint, signed 8-64)
- [`UnsignedFormat`](@ref) (msgpack positive fixint, unsigned 8-64)
- [`StringFormat`](@ref) (msgpack fixstr, str 8-32)
- [`VectorFormat`](@ref) (msgpack fixarray, array 16, array 32)
- [`MapFormat`](@ref) (msgpack fixmap, map 16, map 32)
- [`BinaryFormat`](@ref) (msgpack bin 16, bin 32)
"""
abstract type CoreFormat <: Format end

"""
    isformatbyte(byte, format::Format)

Check if `byte` is compatible with `format`.
"""
function isformatbyte(byte, ::CoreFormat)
  return error("No format byte is specified for this core format")
end

"""
    byteerror(byte, format)

Throw an error indicating that `byte` is not compatible with `format`.
"""
function byteerror(byte, ::F) where {F <: Format}
  msg = "Invalid format byte $byte when unpacking value in format $F"
  throw(ArgumentError(msg))
end

"""
Core format for packing nil / nothing values.

### Packing
All types can be packed in `NilFormat`.

Built upon the msgpack format `nil`.

### Unpacking
To support unpacking a value of type `T` packed in `NilFormat`, implement
  
    construct(::Type{T}, ::Nothing, ::NilFormat)::T

or make sure that the constructor `T()` is defined.

### Defaults
`NilFormat` is the default format of `Nothing`. Use

    format(::Type{T}) = NilFormat()

or

    @pack T in NilFormat

to make `NilFormat` the default format for type `T` (if `T` is abstract, use
`{<: T}` to cover all subtypes).
"""
struct NilFormat <: CoreFormat end

function isformatbyte(byte, ::NilFormat)
  return byte == 0xc0
end

function pack(io::IO, value, ::NilFormat, ::Scope)::Nothing
  write(io, 0xc0)
  return nothing
end

function unpack(io::IO, ::NilFormat, ::Scope)::Nothing
  byte = read(io, UInt8)
  if byte == 0xc0
    nothing
  else
    byteerror(byte, NilFormat())
  end
end

# Default constructor
construct(::Type{T}, ::Nothing, ::NilFormat) where {T} = T()

"""
Core format for packing boolean values.

Built upon the msgpack format `boolean`.

### Packing
To support packing a value `val` of type `T` in `BoolFormat`, implement

    destruct(val::T, ::BoolFormat)::Bool

### Unpacking
To support unpacking a value of type `T` packed in `BoolFormat`, implement
  
    construct(::Type{T}, ::Bool, ::BoolFormat)::T

or make sure that the constructor `T(::Bool)` is defined.

### Defaults
`BoolFormat` is the default format of `Bool`. Use

    format(::Type{T}) = BoolFormat()

or

    @pack T in BoolFormat

to make `BoolFormat` the default format for type `T` (if `T` is abstract, use
`{<: T}` to cover all subtypes).
"""
struct BoolFormat <: CoreFormat end

function isformatbyte(byte, ::BoolFormat)
  return byte == 0xc2 || byte == 0xc3
end

function pack(io::IO, value, ::BoolFormat, ::Scope)::Nothing
  if destruct(value, BoolFormat())
    write(io, 0xc3)
  else
    write(io, 0xc2)
  end
  return nothing
end

function unpack(io::IO, ::BoolFormat, ::Scope)::Bool
  byte = read(io, UInt8)
  if byte == 0xc3
    true
  elseif byte == 0xc2
    false
  else
    byteerror(byte, BoolFormat())
  end
end

"""
Core format for packing signed integer values.

Built upon the msgpack formats `negative fixint`, `positive fixint`,
`signed 8`, `signed 16`, `signed 32`, `signed 64`.

### Packing
To support packing a value `val` of type `T` in `SignedFormat`, implement

    destruct(val::T, ::SignedFormat)::Signed

### Unpacking
To support unpacking a value of type `T` packed in `SignedFormat`, implement
  
    construct(::Type{T}, ::Int64, ::SignedFormat)::T

or make sure that the constructor `T(::Int64)` is defined.

### Defaults
`SignedFormat` is the default format of all subtypes of `Signed`. Use

    format(::Type{T}) = SignedFormat()

or

    @pack T in SignedFormat

to make `SignedFormat` the default format for type `T` (if `T` is abstract, use
`{<: T}` to cover all subtypes).
"""
struct SignedFormat <: CoreFormat end

function isformatbyte(byte, ::SignedFormat)
  return byte <= 0x7f ||  # positive fixint
         byte >= 0xe0 ||  # negative fixint
         0xd0 <= byte <= 0xd3 # signed 8 to 64
end

function pack(io::IO, value, ::SignedFormat, ::Scope)::Nothing
  x = destruct(value, SignedFormat())
  if -32 <= x < 0 # negative fixint
    write(io, reinterpret(UInt8, Int8(x)))
  elseif 0 <= x < 128 # positive fixint
    write(io, UInt8(x))
  elseif typemin(Int8) <= x <= typemax(Int8) # signed 8
    write(io, 0xd0)
    write(io, Int8(x))
  elseif typemin(Int16) <= x <= typemax(Int16) # signed 16
    write(io, 0xd1)
    write(io, Int16(x) |> hton)
  elseif typemin(Int32) <= x <= typemax(Int32) # signed 32
    write(io, 0xd2)
    write(io, Int32(x) |> hton)
  elseif typemin(Int64) <= x <= typemax(Int64) # signed 64
    write(io, 0xd3)
    write(io, Int64(x) |> hton)
  else
    ArgumentError("invalid signed integer $x") |> throw
  end
  return nothing
end

function unpack(io::IO, ::SignedFormat, ::Scope)::Int64
  byte = read(io, UInt8)
  if byte >= 0xe0 # negative fixint
    reinterpret(Int8, byte)
  elseif byte < 128 # positive fixint
    byte
  elseif byte == 0xd0 # signed 8
    read(io, Int8)
  elseif byte == 0xd1 # signed 16
    read(io, Int16) |> ntoh
  elseif byte == 0xd2 # signed 32
    read(io, Int32) |> ntoh
  elseif byte == 0xd3 # signed 64
    read(io, Int64) |> ntoh
  # For compability, also read unsigned values when signed is expected
  elseif byte == 0xcc # unsigned 8
    read(io, UInt8)
  elseif byte == 0xcd # unsigned 16
    read(io, UInt16) |> ntoh
  elseif byte == 0xce # unsigned 32
    read(io, UInt32) |> ntoh
  elseif byte == 0xcf # unsigned 64
    read(io, UInt64) |> ntoh
  else
    byteerror(byte, SignedFormat())
  end
end

destruct(value, ::SignedFormat) = Base.signed(value)

"""
Core format for packing unsigned integer values.

Built upon the msgpack formats `positive fixint`, `unsigned 8`, `unsigned
16`, `unsigned 32`, `unsigned 64`.

### Packing
To support packing a value `val` of type `T` in `UnsignedFormat`, implement

    destruct(val::T, ::UnsignedFormat)::Unsigned

### Unpacking
To support unpacking a value of type `T` packed in `UnsignedFormat`, implement
  
    construct(::Type{T}, ::UInt64, ::UnsignedFormat)::T

or make sure that the constructor `T(::UInt64)` is defined.

### Defaults
`UnsignedFormat` is the default format of all subtypes of `Unsigned`. Use

    format(::Type{T}) = UnsignedFormat()

or

    @pack T in UnsignedFormat

to make `UnsignedFormat` the default format for type `T` (if `T` is abstract, use
`{<: T}` to cover all subtypes).
"""
struct UnsignedFormat <: CoreFormat end

function isformatbyte(byte, ::UnsignedFormat)
  return byte <= 0x7f ||  # positive fixint
         0xcc <= byte <= 0xcf # unsigned 8 to 64
end

function pack(io::IO, value, ::UnsignedFormat, ::Scope)::Nothing
  x = destruct(value, UnsignedFormat())
  if x < 128 # positive fixint
    write(io, UInt8(x))
  elseif x <= typemax(UInt8) # unsigned 8
    write(io, 0xcc)
    write(io, UInt8(x))
  elseif x <= typemax(UInt16) # unsigned 16
    write(io, 0xcd)
    write(io, UInt16(x) |> hton)
  elseif x <= typemax(UInt32) # unsigned 32
    write(io, 0xce)
    write(io, UInt32(x) |> hton)
  elseif x <= typemax(UInt64) # unsigned 64
    write(io, 0xcf)
    write(io, UInt64(x) |> hton)
  else
    ArgumentError("invalid unsigned integer $x") |> throw
  end
  return nothing
end

function unpack(io::IO, ::UnsignedFormat, ::Scope)::UInt64
  byte = read(io, UInt8)
  if byte < 128 # positive fixint
    byte
  elseif byte == 0xcc # unsigned 8
    read(io, UInt8)
  elseif byte == 0xcd # unsigned 16
    read(io, UInt16) |> ntoh
  elseif byte == 0xce # unsigned 32
    read(io, UInt32) |> ntoh
  elseif byte == 0xcf # unsigned 64
    read(io, UInt64) |> ntoh
  else
    byteerror(byte, UnsignedFormat())
  end
end

destruct(x, ::UnsignedFormat) = Base.unsigned(x)

"""
Core format for packing float values.

Built upon the msgpack formats `float 32`, `float 64`.

### Packing
To support packing a value `val` of type `T` in `FloatFormat`, implement

    destruct(val::T, ::FloatFormat)::Union{Float16, Float32, Float64}

### Unpacking
To support unpacking a value of type `T` packed in `FloatFormat`, implement
  
    construct(::Type{T}, ::Float64, ::FloatFormat)::T

or make sure that the constructor `T(::Float64)` is defined.

### Defaults
`FloatFormat` is the default format for `Float16`, `Float32`, and `Float64`. Use

    format(::Type{T}) = FloatFormat()

or

    @pack T in FloatFormat

to make `FloatFormat` the default format for type `T` (if `T` is abstract, use
`{<: T}` to cover all subtypes).
"""
struct FloatFormat <: CoreFormat end

function isformatbyte(byte, ::FloatFormat)
  return byte == 0xca || byte == 0xcb
end

function pack(io::IO, value, ::FloatFormat, ::Scope)::Nothing
  val = destruct(value, FloatFormat())
  if isa(val, Float16) || isa(val, Float32) # float 32
    write(io, 0xca)
    write(io, Float32(val) |> hton)
  else # float 64
    write(io, 0xcb)
    write(io, Float64(val) |> hton)
  end
  return nothing
end

function unpack(io::IO, ::FloatFormat, ::Scope)::Float64
  byte = read(io, UInt8)
  if byte == 0xca ## float 32
    read(io, Float32) |> ntoh
  elseif byte == 0xcb # float 64
    read(io, Float64) |> ntoh
  else
    byteerror(byte, FloatFormat())
  end
end

destruct(value, ::FloatFormat) = Base.float(value)

"""
Core format for packing string values.

Built upon the msgpack formats `fixstr`, `str 8`, `str 16`, `str 32`.

### Packing
To support packing a value `val` of type `T` in `StringFormat`, implement

    destruct(val::T, ::StringFormat)::R

where the returned value `ret::R` must implement `sizeof(ret)` (number of
bytes) as well as `write(io, ret)`.

### Unpacking
To support unpacking a value of type `T` packed in `StringFormat`, implement
  
    construct(:: Type{T}, ::String, ::StringFormat)::T

or make sure that `convert(T, ::String)` is defined.

### Defaults
`StringFormat` is the default format for `Symbol` and all subtypes of
`AbstractString`. Use

    format(:: Type{T}) = StringFormat()

or

    @pack T in StringFormat

to make `StringFormat` the default format for type `T` (if `T` is abstract, use
`{<: T}` to cover all subtypes).
"""
struct StringFormat <: CoreFormat end

function isformatbyte(byte, ::StringFormat)
  return 0xa0 <= byte <= 0xbf || # fixstr
         0xd9 <= byte <= 0xdb # str 8 to 32
end

function pack(io::IO, value, ::StringFormat, ::Scope)::Nothing
  str = destruct(value, StringFormat())
  n = sizeof(str)
  if n < 32 # fixstr format
    write(io, 0xa0 | UInt8(n))
  elseif n <= typemax(UInt8) # str 8 format
    write(io, 0xd9)
    write(io, UInt8(n))
  elseif n <= typemax(UInt16) # str 16 format
    write(io, 0xda)
    write(io, UInt16(n) |> hton)
  elseif n <= typemax(UInt32) # str 32 format
    write(io, 0xdb)
    write(io, UInt32(n) |> hton)
  else
    ArgumentError("Invalid string length $n") |> throw
  end
  write(io, str)
  return nothing
end

function unpack(io::IO, ::StringFormat, ::Scope)::String
  byte = read(io, UInt8)
  n = if 0xa0 <= byte <= 0xbf # fixstr  format
    byte & 0x1f
  elseif byte == 0xd9 # str 8 format
    read(io, UInt8)
  elseif byte == 0xda # str 16 format
    read(io, UInt16) |> ntoh
  elseif byte == 0xdb # str 32 format
    read(io, UInt32) |> ntoh
  else
    byteerror(byte, StringFormat())
  end
  return String(read(io, n))
end

# Default destruct / construct
destruct(value, ::StringFormat) = Base.string(value)
construct(::Type{T}, x, ::StringFormat) where {T} = convert(T, x)

"""
Core format for packing binary values.

Built upon the msgpack formats `bin 8`, `bin 16`, `bin 32`.

### Packing
To support packing a value `val` of type `T` in `BinaryFormat`, implement

    destruct(val::T, ::BinaryFormat)::R

where the returned value `ret::R` must implement `sizeof(ret)` (number of
bytes) as well as `write(io, ret)`.

### Unpacking
To support unpacking a value of type `T` packed in `BinaryFormat`, implement
  
    construct(::Type{T}, ::Vector{UInt8}, ::BinaryFormat)::T

or make sure that the constructor `T(::Vector{UInt8})` is defined.

### Defaults
`BinaryFormat` is the default format for `Pack.Bytes`. Use

    format(::Type{T}) = BinaryFormat()

or

    @pack T in BinaryFormat

to make `BinaryFormat` the default format for type `T` (if `T` is abstract, use
`{<: T}` to cover all subtypes).
"""
struct BinaryFormat <: Format end

function isformatbyte(byte, ::BinaryFormat)
  return 0xc4 <= byte <= 0xc6
end

function pack(io::IO, value, ::BinaryFormat, ::Scope)::Nothing
  bin = destruct(value, BinaryFormat())
  n = sizeof(bin)
  if n <= typemax(UInt8) # bin8
    write(io, 0xc4)
    write(io, UInt8(n))
  elseif n <= typemax(UInt16) # bin16
    write(io, 0xc5)
    write(io, UInt16(n) |> hton)
  elseif n <= typemax(UInt32) # bin32
    write(io, 0xc6)
    write(io, UInt32(n) |> hton)
  else
    ArgumentError("invalid binary length $n") |> throw
  end
  write(io, bin)
  return nothing
end

function unpack(io::IO, ::BinaryFormat, ::Scope)::Vector{UInt8}
  byte = read(io, UInt8)
  n = if byte == 0xc4 # bin8
    read(io, UInt8)
  elseif byte == 0xc5 # bin16
    read(io, UInt16) |> ntoh
  elseif byte == 0xc6 # bin32
    read(io, UInt32) |> ntoh
  else
    byteerror(byte, BinaryFormat())
  end
  return read(io, n)
end

"""
Core format for packing vector values.

Built upon the msgpack formats `fixarray`, `array 16`, `array 32`.

### Packing
To support packing a value `val` of type `T` in `VectorFormat`, implement

    destruct(val::T, ::VectorFormat)::R

where the returned value `ret::R` must implement `length(ret)` (number of
entries) and must be iterable. The formats of the entries of `val` are
determined via [`valueformat`](@ref).

### Unpacking
To support unpacking a value of type `T` packed in `VectorFormat`, implement
  
    construct(::Type{T}, ::Generator{T}, ::VectorFormat)::T

or make sure that the constructor `T(::Generator{T})` is defined (see
[`Generator`](@ref)).

### Defaults
`VectorFormat` is the default format for subtypes of `Tuple` and
`AbstractVector`. Use

    format(::Type{T}) = VectorFormat()

or

    @pack T in VectorFormat

to make `VectorFormat` the default format for type `T` (if `T` is abstract, use
`{<: T}` to cover all subtypes).
"""
struct VectorFormat <: Format end

function isformatbyte(byte, ::VectorFormat)
  return 0x90 <= byte <= 0x9f || # fixarray
         byte == 0xdc || # array 16
         byte == 0xdd # array 32
end

function pack(io::IO, value::T, fmt::VectorFormat, scope::Scope) where {T}
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
  for (state, entry) in enumerate(val)
    fmt_val = valueformat(T, fmt, state, scope)
    pack(io, entry, fmt_val, scope)
  end
  return nothing
end

function unpack(io::IO, ::Type{T}, fmt::VectorFormat, scope::Scope)::T where {T}
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
  entries = Iterators.map(1:n) do state
    S = valuetype(T, fmt, state, scope)
    fmt_val = valueformat(T, fmt, state, scope)
    entry = unpack(io, S, fmt_val, scope)
    return entry
  end
  return construct(T, Generator{T}(entries), fmt, scope)
end

# Support for generic unpacking / AnyFormat
function unpack(io::IO, ::VectorFormat, scope::Scope)::Vector
  byte = read(io, UInt8)
  n = if byte & 0xf0 == 0x90 # fixarray
    byte & 0x0f
  elseif byte == 0xdc # array 16
    read(io, UInt16) |> ntoh
  elseif byte == 0xdd # array 32
    read(io, UInt32) |> ntoh
  else
    byteerror(byte, VectorFormat())
  end
  values = map(1:n) do _
    return unpack(io, AnyFormat(), scope)
  end
  return values
end


"""
Core format for packing map / dictionary values.

Built upon the msgpack formats `fixmap`, `map 16`, `map 32`.

### Packing
To support packing a value `val` of type `T` in `MapFormat`, implement

    destruct(val::T, ::MapFormat)::R

where the returned value `ret::R` must implement `length(ret)` (number of
entries) and must be iterable with pairs as entries. The key / value formats
of the entries of `val` are determined via [`keyformat`](@ref) and
[`valueformat`](@ref).

### Unpacking
To support unpacking a value of type `T` packed in `MapFormat`, implement
  
    construct(::Type{T}, ::Generator{T}, ::MapFormat)::T

or make sure that the constructor `T(::Generator{T})` is defined (see
[`Generator`](@ref)). During unpacking, the respective formats are determined
via [`keyformat`](@ref) and [`valueformat`](@ref) while the types of the entries
to be unpacked are gathered via [`keytype`](@ref) and [`valuetype`](@ref).

### Defaults
`MapFormat` is the default format for subtypes of `NamedTuple` and `Dict`. Use

    format(::Type{T}) = MapFormat()

or

    @pack T in MapFormat

to make `MapFormat` the default format for type `T` (if `T` is abstract, use
`{<: T}` to cover all subtypes).
"""
struct MapFormat <: Format end

function isformatbyte(byte, ::MapFormat)
  return 0x80 <= byte <= 0x8f || # fixmap
         byte == 0xde || # map 16
         byte == 0xdf # map 32
end

function pack(io::IO, value::T, fmt::MapFormat, scope::Scope) where {T}
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

function unpack(io::IO, ::Type{T}, fmt::MapFormat, scope::Scope)::T where {T}
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
  pairs = Iterators.map(1:n) do state
    K = keytype(T, fmt, state, scope)
    V = valuetype(T, fmt, state, scope)
    fmt_key = keyformat(T, fmt, state, scope)
    fmt_val = valueformat(T, fmt, state, scope)
    key = unpack(io, K, fmt_key, scope)
    value = unpack(io, V, fmt_val, scope)
    entry = key=>value
    return entry
  end
  return construct(T, Generator{T}(pairs), MapFormat(), scope)
end

# Support for generic unpacking / AnyFormat
function unpack(io::IO, ::MapFormat, scope::Scope)::Dict
  byte = read(io, UInt8)
  n = if byte & 0xf0 == 0x80
    byte & 0x0f
  elseif byte == 0xde
    read(io, UInt16) |> ntoh
  elseif byte == 0xdf
    read(io, UInt32) |> ntoh
  else
    byteerror(byte, MapFormat())
  end
  pairs = Iterators.map(1:n) do _
    key = unpack(io, AnyFormat(), scope)
    value = unpack(io, AnyFormat(), scope)
    return (key, value)
  end
  return Dict(pairs)
end
