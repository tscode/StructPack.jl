
# StructPack.jl

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

On the other hand, StructPack.jl is (probably) not the right choice if you
 
- need to serialize arbitrary julia objects out-of-the-box.
- have enormous files and need lazy loading capabilities.
- want to read arbitrary msgpack files from external sources.

While the functionality to read generic msgpack is included (currently without
support for extensions), you should in this case also consider the excellent
package [MsgPack.jl](https://github.com/JuliaIO/MsgPack.jl), which serves as
inspiration for StructPack.jl.

## 
The following snippet of code demonstrates some of the features of StructPack.jl.
```julia
using StructPack

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

@pack {<: A} in StructFormat
@pack D in StructFormat D(d; b) [b in BinArrayFormat, d in TypedFormat]
```
For more examples and detailed information about about usage, see the package
documentation.

## Rationale

Julia already offers a wealth of packages that can be used for data serialization and storage. Besides `Base.Serialization`, this includes
[JLD.jl](https://github.com/JuliaIO/JLD.jl),
[JLD2.jl](https://github.com/JuliaIO/JLD2.jl),
[JSON.jl](https://github.com/JuliaIO/JSON.jl),
[JSON3.jl](https://github.com/quinnj/JSON3.jl),
[BSON.jl](https://github.com/JuliaIO/BSON.jl),
[Serde.jl](https://github.com/bhftbootcamp/Serde.jl),
[MsgPack.jl](https://github.com/JuliaIO/MsgPack.jl), and likely many others.
So why does StructPack.jl deserve to exist?

In previous projects, I often found myself in situations where I wanted to
permanantly, reliably and efficiently store custom julia structs that contained
binary data. Loading should not be able to execute arbitrary code, since I would
not always trust the source. At the same time, I wanted enough flexibility to
reconstruct a value based on abstract type information only, in a controlled
way.

Oh, and the interface should be straightforward. And the code base should be
transparent and avoid complexities, as far as possible. Ideally, it should also
be compatible to a universally used format.

Thus, this package was born. May it help you.


<!-- #### Are macros necessary? -->

<!-- If you are not happy with the `@pack` macro due to its intransparency or -->
<!-- limitations, the following will establish the same functionality: -->
<!-- ```julia -->
<!-- # @pack {<: A} in StructFormat -->
<!-- StructPack.format(Type{<: A}) = StructFormat() -->

<!-- # @pack D in StructFormat ... -->
<!-- StructPack.format(Type{<: B}) = StructFormat() -->

<!-- # ... D(d; b) ... -->
<!-- StructPack.destruct(val::D, ::StructFormat) = (:d=>val.d, b=>val.+) -->
<!-- StructPack.construct(::Type{D}, pairs, ::StructFormat) = D(pairs[1][2]; b = pairs[2][2]) -->
<!-- StructPack.fieldtypes(::Type{D}, ::StructFormat) = (Matrix{B}, A) -->

<!-- # ... [b in BinArrayFormat, d in TypedFormat] -->
<!-- StructPack.fieldformats(::Type{D}, ::StructFormat) = (BinArrayFormat(), TypedFormat()) -->

<!-- ## Answers to be questioned -->

<!-- > Is this package well-tested, performance optimized, and 100% production ready? -->

<!-- Well... no. None of the three, probably. But the design should be fixed and the -->
<!-- API stable. Features that are currently not supported are unlikely to make it -->
<!-- into a future release. Unless they fit neatly and don't increase code complexity -->
<!-- by much. -->

<!-- What will make it into future releases is a better out-of-the-box support for -->
<!-- types in `Base`, which is currently very limited but which is easily extensible. -->
<!-- Also, support for additional popular types can easily be added via package -->
<!-- extensions. I will patiently be waiting for corresponding issues and pull -->
<!-- requests. -->

<!-- > Can I trust you that `unpack` does not let chaos and havoc in my digital world? -->

<!-- Certainly not! I tried my best to prevent uncontrolled code execution (by never -->
<!-- using `eval` and by making sure that types are whitelisted before calling their -->
<!-- constructors in `TypedFormat`), but maybe this is not enough. Also, another -->
<!-- package you load and whose data you want to store may extend StructPack.jl in a way -->
<!-- that is nasty. So the honest answer is: I don't know. -->

<!-- > What if I read external msgpack files? Can I generically load them? -->

<!-- I tend to agree. It would be easy to solve this problem with a new format, -->
<!-- but I am currently not sure about the best way to incorporate this. The main -->
<!-- hinderance is that such a potential `UnorderedMapFormat` has to be less general -->
<!-- than `MapFormat`, since the type and formats of the key objects cannot be easily -->
<!-- determined. It should thus probably be implemented as `UnorderedStructFormat` -->
<!-- and expect symbols as keys. Along this line, one could also implement `StructFormat`, which is `MapFormat` specialized to symbols as keys. -->
