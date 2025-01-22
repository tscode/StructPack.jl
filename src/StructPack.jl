module StructPack

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
include("specialformats.jl")

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
       ExtensionFormat,
       AbstractVectorFormat,
       VectorFormat,
       DynamicVectorFormat,
       AbstractMapFormat,
       MapFormat,
       DynamicMapFormat,
       StructFormat,
       UnorderedStructFormat,
       FlexibleStructFormat,
       ArrayFormat,
       BinVectorFormat,
       BinArrayFormat,
       TypeFormat,
       TypedFormat,
       SetContextFormat

export pack, unpack
export @pack

@static if VERSION >= v"1.11"
  include("public.jl")
end

end # module StructPack
