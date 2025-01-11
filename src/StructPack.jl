module StructPack

# Pack currently uses the scoped values StructPack.scope and StructPack.whitelist
using Base.ScopedValues

# Interface and abstract type definitions
include("pack.jl")

# Auxiliary type for unpacking msgpack vector / map formats
include("generator.jl")

# Supported packing formats
include("coreformats.jl")
include("anyformat.jl")
include("dynamicformats.jl")
include("structformat.jl")
include("arrayformats.jl")
include("typedformat.jl")

# Supported julia types
include("basetypes.jl")

# Convenience @pack macro for structs
include("macro.jl")

export Format,
       DefaultFormat,
       AnyFormat,
       NilFormat,
       BoolFormat,
       SignedFormat,
       UnsignedFormat,
       StringFormat,
       BinaryFormat,
       AbstractVectorFormat,
       VectorFormat,
       DynamicVectorFormat,
       AbstractMapFormat,
       MapFormat,
       DynamicMapFormat,
       StructFormat,
       UnorderedStructFormat,
       ArrayFormat,
       BinVectorFormat,
       BinArrayFormat,
       TypedFormat

export pack, unpack

# public Context

# public construct, destruct
# public valuetype, valueformat, keytype, keyformat
# public fieldtypes, fieldnames, fieldformats
       
# public whitelist, context

end # module StructPack
