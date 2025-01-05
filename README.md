
# Pack.jl

This package is for people who want to efficiently serialize their beloved
structures in a simple and transparent way. It operates on top of the binary
[msgpack standard](https://msgpack.org/index.html).

You might like this package because it

- is pure and straightforward julia with no dependencies.
- has an easy interface.
- is very flexible, with context-dependent format choices.
- avoids uncontrolled code execution during unpacking.
- is reasonably fast.
- produces sound msgpack files that can be read universally.

On the other hand, Pack.jl is (probably) not the right choice if you
 
- need to serialize arbitrary julia objects out-of-the-box.
- have enormous files and need lazy loading capabilities.
- want to read arbitrary msgpack files from external sources.

While the functionality to read generic msgpack is included (currently without
support for extensions), you should in this case also consider the excellent
package [MsgPack.jl](https://github.com/JuliaIO/MsgPack.jl), which serves as
inspiration for Pack.jl.

## Rationale

**A lot** of options already exist in julia for data serialization. Besides
the `Serialization` module in `Base`, this includes
[JLD.jl](https://github.com/JuliaIO/JLD.jl),
[JLD2.jl](https://github.com/JuliaIO/JLD2.jl),
[JSON.jl](https://github.com/JuliaIO/JSON.jl),
[JSON3.jl](https://github.com/quinnj/JSON3.jl),
[BSON.jl](https://github.com/JuliaIO/BSON.jl),
[Serde.jl](https://github.com/bhftbootcamp/Serde.jl),
[MsgPack.jl](https://github.com/JuliaIO/MsgPack.jl), and probably many others.
So why does this additional package deserve to exist?

Well, no reason in particular. But in previous projects, I often found myself
in situations where I wanted to permanantly, reliably and efficiently store
custom julia structs that contained binary data. Loading should not be able to
execute arbitrary code, since I would not always trust the source. At the same
time, I wanted enough flexibility to reconstruct a value based on abstract type
information only, in a controlled way.

Oh, and the interface should be straightforward. And the code base should be
transparent and avoid complexities, as far as possible. Ideally, it should also
be compatible to a universally used format. And thus, this package was born.

## Concepts

Have a look at this snippet of code:
```julia
import Pack: MapFormat, VectorFormat, BinArrayFormat

abstract type A end

struct B <: A
  a::Int
  b::Float64
end

struct C <: A
  a::Int
end

struct D
  a::String
  b::Matrix{B}
  d::A
end

D(d; b) = D("default", b, d)


Pack.@pack begin
  {<: A} in MapFormat
  D in MapFormat D(d; b) [b in BinArrayFormat, d in TypedFormat]
end
```

For more examples and information about usage, see the package documentation.

#### Booh! I hate macros :(

If you are not happy with the `@pack` macro, the following code will reproduce
the same functionality:
```julia
# @pack {<: A} in MapFormat
Pack.format(Type{<: A}) = MapFormat()

# @pack D in MapFormat ...
Pack.format(Type{<: B}) = MapFormat()

# ... D(b, d) ...
Pack.destruct(val::D, ::MapFormat) = (val.b, val.d) # only store b and d
Pack.construct(::Type{D}, vals, ::MapFormat) = D(vals[1][2]; b = vals[2][2])
Pack.valuetype(::Type{D}, index, ::MapFormat) = index == 1 ? Matrix{B} : A

# ... [b in BinArrayFormat, d in TypedFormat]
Pack.valueformat(::Type{D}, index, ::MapFormat) = index == 1 ? BinArrayFormat() : TypedFormat()

# Allow constructors of A to be called when unpacking in TypedFormat
Pack.whitelisted(::Type{<:A}) = true
```

<!-- ## Benchmarks -->

<!-- I know, I know, julia folks are addicted to performance. However, performance is not the primary goal of Pack.jl. Decent performance is -->  

## Answers to be questioned

> Is this package well-tested, performance optimized, and 100% production ready?

Well... no. None of the three, probably. But the design should be fixed and the
API stable. Features that are currently not supported are unlikely to make it
into a future release. Unless they fit neatly and don't increase code complexity
by much.

What will make it into future releases is a better out-of-the-box support for
types in `Base`, which is currently very limited but which is easily extensible.
Also, support for additional popular types can easily be added via package
extensions. I will patiently be waiting for corresponding issues and pull
requests.

> Can I trust you that `unpack` does not let chaos and havoc in my digital world?

Certainly not! I tried my best to prevent uncontrolled code execution (by never
using `eval` and by making sure that types are whitelisted before calling their
constructors in `TypedFormat`), but maybe this is not enough. Also, another
package you load and whose data you want to store may extend Pack.jl in a way
that is nasty. So the honest answer is: I don't know.

> It is a bummer that you cannot load structs when the ordering in the msgpack file is not correct...

I tend to agree. It would be easy to solve this problem with a new format,
but I am currently not sure about the best way to incorporate this. The main
hinderance is that such a potential `UnorderedMapFormat` has to be less general
than `MapFormat`, since the type and formats of the key objects cannot be easily
determined. It should thus probably be implemented as `UnorderedStructFormat`
and expect symbols as keys. Along this line, one could also implement `StructFormat`, which is `MapFormat` specialized to symbols as keys.
