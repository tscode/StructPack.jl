module StructPack

# Pack currently uses the scoped values StructPack.context
using Base.ScopedValues

# Interface and abstract type definitions
include("pack.jl")

# Auxiliary type for unpacking msgpack vector / map formats
include("generator.jl")

# Supported packing / unpacking formats
include("coreformats.jl")
include("extensionformat.jl")
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
       TypeFormat,
       TypedFormat

export pack, unpack
export @pack

public Context
public context
public construct, destruct
public valuetype, valueformat, keytype, keyformat
public fieldtypes, fieldnames, fieldformats

end # module StructPack
