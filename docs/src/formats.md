
# Formats

```@docs
Pack.Format
```

## Core Formats

```@docs
Pack.CoreFormat
Pack.NilFormat
Pack.BoolFormat
Pack.SignedFormat
Pack.UnsignedFormat
Pack.StringFormat
Pack.VectorFormat
Pack.MapFormat
Pack.BinaryFormat
```

## Array Formats

Besides [`Pack.VectorFormat`](@ref), which directly mirrors the msgpack vector format, Pack.jl also provides convenience formats for storing multidimensional arrays.
```@docs
Pack.ArrayFormat
Pack.BinVectorFormat
Pack.BinArrayFormat
```

## Dynamic Vector and Map Formats

```@docs
Pack.DynamicVectorFormat
Pack.DynamicMapFormat
```

## Extra Formats

```@docs
Pack.TypeFormat
Pack.TypedFormat
```

## Special Formats

```@docs
Pack.DefaultFormat
Pack.AnyFormat
```


