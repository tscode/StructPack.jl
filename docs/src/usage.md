
```@meta
CurrentModule = StructPack
```

# Usage

In order to serialize or deserialize a value of type `T` via StructPack.jl, a format must be specified. A format is a singleton subtype of [`Format`](@ref).
This can either happen by explicitly providing it when calling [`pack`](@ref) and [`unpack`](@ref), or by setting a default format via overloading [`format`](@ref). Different formats might have different requirements for `T`.

A number of basic julia types already have a default format associated to them and can
be packed / unpacked without further instructions.
```julia
using StructPack

str = "This is a string" # StringFormat by default
tup = ("tuple", 5, false) # VectorFormat by default
ntup = (a = str, b = tup) # StructFormat by default

bytes = pack(ntup)
unpack(bytes, typeof(ntup))

# or alternatively 

io = IOBuffer()
pack(io, ntup)
seekstart(io)
unpack(io, typeof(ntup))
```
When `using StructPack` is issued, the functions [`pack`](@ref) and [`unpack`](@ref), the macro [`@pack`](@ref), and a set of built-in formats is exported.

The type information passed to [`unpack`](@ref) is needed, since no such
information is stored in `bytes`. If it is left out, `Pack.unpack(bytes)` tries
to load `bytes` as generic msgpack object and returns a dictionary (since `ntup` is stored in the msgpack map format). We will [later](#Exploring-the-abstract) see how type information can be stored as well, enabling generic unpacking.

## Custom packing

StructPack.jl gives you several out-of-the-box options how to serialize a custom structure.
```julia
struct MyStruct
  a::Float64
  b::String
end

StructPack.format(::Type{MyStruct}) = MapFormat()
# or
StructPack.format(::Type{MyStruct}) = StructFormat()
# or
StructPack.format(::Type{MyStruct}) = UnorderedStructFormat()
# or
StructPack.format(::Type{MyStruct}) = VectorFormat()

bytes = pack(MyStruct(0., "a string"))
```
In the first three cases, the binary `bytes` will coincide. The difference lies in the unpacking:
[`MapFormat`](@ref) will (by default) not check if the keys in bytes confirm to `:a` and `:b`.
[`StructFormat`](@ref), on the other hand, will perform such a consistency check.
[`UnorderedStructFormat`](@ref) will also perform such a check.
It is slower but can unpack msgpack binaries where the order of the entries are altered.

```julia
bytes1 = pack((a = 0., b = "a string")) # coincides with bytes
bytes2 = pack((ab = 0., ba = "a string"))
bytes3 = pack((b = 0., a = "a string"))

# All of these will work as intended
unpack(bytes1, MyStruct, MapFormat())
unpack(bytes1, MyStruct, StructFormat())
unpack(bytes1, MyStruct, UnorderedStructFormat())

# This will fail for StructFormat and UnorderedStructFormat
unpack(bytes2, MyStruct, MapFormat())

# This will not work as intended for MapFormat and will fail for StructFormat
unpack(bytes3, MyStruct, UnorderedStructFormat())
```
If you choose [`VectorFormat`](@ref), the keys `:a` and `:b` are not stored at all in `bytes`.
Unpacking then only relies on the order of the arguments.
In particular, `pack(MyStruct(0., "b"), VectorFormat()) == pack([0., "b"])`.

To make the specification of default formats more convenient, StructPack.jl also provides the macro [`@pack`](@ref).
```julia
@pack MyStruct in StructFormat
# is equivalent to
StructPack.format(::Type{MyStruct}) = StructFormat()
```
This macro has additional benefits:
If you do not want to store all fields of MyStruct, or use a specific constructor when unpacking, you can easily inform [`@pack`](@ref) in combination with [`StructFormat`](@ref) or [`UnorderedStructFormat`](@ref).
```julia
# Special constructor we want to use during unpacking
MyStruct(a; b) = MyStruct(a, b)
@pack MyStruct in StructFormat (a; b)

# or

# The constructor has a custom name
create_mystruct(; a, b) = MyStruct(a, b)
@pack MyStruct in StructFormat create_mystruct(; a, b)

# or

# We only want to store the field a
MyStruct(a) = MyStruct(a, "b is always the same")
@pack MyStruct in StructFormat (a,)
```
With a bit of additional code we have even more flexibility.
For example, after we have decided to store only the field `MyStruct.a::Float64` anyway, we could just directly use [`FloatFormat`](@ref).
```julia
StructPack.format(::Type{MyStruct}) = FloatFormat()
StructPack.destruct(val::MyStruct, ::FloatFormat) = val.a
StructPack.construct(::Type{MyStruct}, a, ::FloatFormat) = MyStruct(a)
```
The functions [`destruct`](@ref) and [`construct`](@ref) are called before packing and after unpacking.
Consult the docstrings of the various in-built formats to learn about their respective requirements for these functions.

## Parents matter

StructPack.jl strives to be flexible when handling custom structs. In particular, it
disagrees that a given value `val::T` should always be serialized in the same way,
independent of the circumstances.

There are two primary mechanism to enforce context-dependent customizations when packing and unpacking a value:
Via its parent structure, or via [`Context`](@ref) objects.

Here is a simple example where a field (the child) of a struct (the parent)
receives a non-default format.
```julia
struct MyOtherStruct
  a::String           # Default format is StringFormat
  b::Vector{Float32}  # Default format is VectorFormat
end

# We decide that MyStruct.b should rather be stored as binary vector
@pack MyOtherStruct in StructFormat [b in BinVectorFormat]
```
The auxiliary format [`BinVectorFormat`](@ref) causes that `MyOtherStruct.b` will be stored in the msgpack binary format.
Without further effort, this only works for types `Vector{F}` where `isbitstype(F)` is true.

Note that this call to [`@pack`](@ref) can be combined with the specification of a particular constructor (as above).

## Context matters

Another way to modify the format of a given value `val::T` are context objects, realized as singleton subtypes of [`Context`](@ref).
Context objects are particularly useful if you desired to change how `val::T` is serialized throughout (a part of) your code, but are reluctant to modify the global behavior for all values of type `T`.
For example, `T` might belong to a third party package and you do not want to mess with its packing defaults.
```julia
struct MyContext <: StructPack.Context end

# Under MyContext, MyOtherStruct.b is packed in ArrayFormat
# and the field order does not matter for unpacking
@pack MyContext MyOtherStruct in UnorderedStructFormat [b in ArrayFormat]

value = MyOtherStruct("Is my data stored in binary?", rand(Float32, 10))
bytes1 = pack(value, MyContext()) # ArrayFormat is used for field b
bytes2 = pack(value)              # BinVectorFormat is used for field b

# Unpacking must also get informed about the context
unpack(bytes1, MyOtherStruct, MyContext())
unpack(bytes2, MyOtherStruct)
```

Here you have encountered [`ArrayFormat`](@ref).
This auxiliary format is able to store and recover (multidimensional) arrays by also storing the array size (see also [`BinArrayFormat`](@ref)).

For convenience, it is also possible to temporarily alter the default context for a block of code via the scoped value [`context`](@ref).

```julia
using Base.ScopedValues

with(StructPack.context=>MyContext()) do
  bytes = pack(value) # ArrayFormat is used
  unpack(bytes, MyOtherStruct)
end
```
Furthermore, you can dynamically switch the active context during packing / unpacking via the special format [`ContextFormat`](@ref).
Consider the following piece of code.
```julia
struct ParentStruct
  a::MyOtherStruct # Want to use the default context for this one
  b::MyOtherStruct # Want to use MyContext for this one
end

@pack ParentStruct in StructFormat [b in ContextFormat{MyContext}]

# or, if we also want to change the format for the field b from unordered to ordered

@pack ParentStruct in StructFormat [b in ContextFormat{MyContext, StructFormat}]
```
Since [`ContextFormat`](@ref) is a bit unwieldy, the [`@pack`](@ref) macro accepts the abbreviation `F[C]` for `ContextFormat{C, F}`.
Thus, the two packing lines in the code above are equivalent to
```julia
@pack ParentStruct in StructFormat [b in DefaultFormat[MyContext]]
@pack ParentStruct in StructFormat [b in StructFormat[MyContext]]
```

Contexts can reach into and alter nearly each aspect of the serialization, as they penetrate into each relevant packing related call ([`pack`](@ref), [`unpack`](@ref), [`format`](@ref), [`fieldformats`](@ref), ...).
In general, to add a custom rule for your context, you can just overload the respective function with a trailing argument for the context.
For example, the following two lines are equivalent:
```julia
@pack MyContext MyOtherStruct in StructFormat
StructPack.format(::Type{MyOtherStruct}, ::MyContext) = StructFormat()
```
[Below](#A-world-without-macros), we demonstrate in more detail which functions are overloaded when employing the [`@pack`](@ref) macro. 

## Contexts: Case study

As mentioned above, contexts are useful to prevent the following uglyness:
You want to serialize a type `B.A` from a package `B` in another way than the maintainers of package `C` want to serialize `B.A`.
In general, the rule is to never set global default formats for types that you do not own.
Always use the parent-mechanism or a dedicated context for such types.

However, the main reason why I have included contexts into StructPack.jl is a different one.
Imagine you want to save and load project files that capture some aspect of a program you are developing (think of a save state in a game).
The first version, v1, might correspond directly to your project structure.
```julia
struct Project
  a::String
  b::Int
  c::Float64
end

@pack Project in StructFormat

saveproject(path, p::Project) = open(path, "w") do io
  pack(io, p)
end

loadproject(path) = open(path, "r") do io
  unpack(io, Project)
end

saveproject("myproject.pack", Project("test", 5, 0.))
```
Great! For version v2, however, you add a new feature and your project structure changes. It now looks like this:
```julia
struct Project
  c::Float64
  b::Tuple{Int, Int}
  a::String
  d::Bool
end
```
What to do with your now defunct project file `myproject.pack`?
Of course, you could make up a mock structure `ProjectV1` that mirrors the old format and provides a conversion function.
Or you could just unpack `myproject.pack` as a dictionary and convert it back to a struct. 

In complicated settings, however, both of these options are cumbersome.
This is especially true if several structs (that may be children of `Project`) change, maybe only slightly.
You then either have to keep slight variations of countles struct copies around, or have to plow your way through nested dicts.
The same horror continues with the next version v3.

Here, contexts in concert with the [`@pack`](@ref) macro become very useful.
```julia
struct CompatV1V2 <: StructPack.Context end

v1_to_v2(a, b, c) = Project(c, (b, b), a, false)

@pack CompatV1V2 Project in StructFormat v1_to_v2(a, b::Int, c)

loadproject_v2(path) = open(path, "r") do io
  unpack(io, Project, CompatV1V2())
end

p = loadproject_v2("myproject.pack")
```
Note that the context `CompatV1V2` is "ill-defined", in that you cannot pack and consequtively unpack an object of type `Project` in it (since we had to lie about the type of `Project.b`, which is ignored by packing but respected by unpacking).
However, we only need it for loading anway.

The value of this approach might not be too apparent in this simple example, but its composability pays when `Project` contains nested custom structs.
In fact, we could even handle renamed fields quite principled by specializing [`StructPack.fieldnames`](@ref) given the context `CompatV1V2`.

## A world without macros

How does the [`@pack`](@ref) macro work?
Under the hood, it just overloads relevant packing functions.
This means that every effect achievable via [`@pack`](@ref) can quite easily be achieved without macro as well, albeit at the cost of more code.

For example, the macro call
```julia
@pack C A in StructFormat (a, c::Tc; b) [b in Fb]
```
is essentially expanded to
```julia
StructPack.format(::Type{A}, ::C) = StructFormat()

StructPack.destruct(val::A, ::C) = (val.a, val.c, val.b)

function StructPack.construct(::Type{A}, pairs, ::C)
  args = (pairs[1][2], pairs[2][2])
  kwargs = (pairs[3],)
  A(args...; kwargs...)
end

StructPack.fieldnames(::Type{A}, ::C) = (:a, :c, :b)

function StructPack.fieltypes(::Type{A}, ::C)
  # This is actually solved via a generated function, so the calls to fieldtype
  # take place before compile time
  (fieldtype(A, :a), Tc, fieldtype(A, :b))
end

function StructPack.fieldformats(::Type{A}, ::C)
  (DefaultFormat(), DefaultFormat(), Fb())
end
```

## Unpacking the abstract
Until now, we have only considered unpacking when we knew the concrete type of our object beforehand.
This implies heavy limitations.
For example, what would we do in the following situation?

```julia
abstract type Vehicle end

struct Boat <: Vehicle
  a::Int
end

struct Train <: Vehicle
  b::Float64
end

struct Ticket
  price::Float64
  vehicle::Vehicle
end
```
Here we have to call `unpack(..., Vehicle)` at some point, which clearly does not tell us about the underlying msgpack layout beforehand.
To resolve this issue, it is necessary that some type information is stored alongside the value.

In StructPack.jl, this problem is solved via the special auxiliary format [`TypedFormat`](@ref).
```julia
@pack {<: Vehicle} in TypedFormat{StructFormat}

bytes = pack(Boat(42)) # This will be a lot of bytes...
unpack(bytes, Vehicle) # ... but this will work!
```
Now, packing a value of type `Vehicle` will actually store a msgpack map with the two keys `:type` and `:value`, the first of which contains type information sufficient to reconstruct the concrete type.
The value stored behind the key `:value` will be formatted in [`StructFormat`](@ref).

This is very convenient.
However, you should realize that we also approach potential complications.

* The performance of packing and unpacking suffers notably when using [`TypedFormat`](@ref).
  This means that you should avoid storing lots and lots of values in this format. 
* Packing and unpacking in [`TypedFormat`](@ref) becomes more complicated when the abstract type (`Vehicle` in the example above) has type parameters, i.e., if we had defined `Vehicle{A, B}`.
  In this case we also have to serialize `A` and `B` when serializing the type. 
  Since it seems to be impossible to automatically extract necessary information about `A` and `B` (for example, is `A` a type or a symbol?), this information has to be supplied explicitly via [`typeparamtypes`](@ref) and [`typeparamformats`](@ref).


## Generic unpacking

If you want to unpack a generic msgpack binary, you can do so by just leaving out the target type during unpacking.
```julia
val = (:a, 5, (b = 7, c = "c"))
bytes = pack(val)

 # Will return an array, where the last (third) entry is a dict
unpack(bytes)
```
Under the hood, generic unpacking is realized via the special [`AnyFormat`](@ref).
This format currently uses the julia `Array` type for msgpack vectors and `Dict` for msgpack maps.
As a consequence, the ordering of maps is lost and duplicated keys will lead to data loss.

Any valid msgpack value should be correctly unpackable this way.
Otherwise it is considered a bug of StructPack.jl.


## Extensions

Msgpack extensions are implemented via the [`ExtensionFormat`](@ref).
Here is an example how to pack / unpack values of type `Int128` in this format:

```julia
I = Int8(5)

function StructPack.destruct(x::Int128, ::ExtensionFormat{I})
  reinterpret(UInt8, [x])
end

function StructPack.construct(::Type{Int128}, data, ::ExtensionFormat{I})
  reinterpret(Int128, data)[1]
end

val = Int128(10)
bytes = pack(val, ExtensionFormat{I}())
unpack(bytes, Int128, ExtensionFormat{I}())
```

If you unpack a msgpack extension value via the generic [`AnyFormat`](@ref), you will receive an [`ExtensionData`](@ref) object.
