module StructPack

# Interface and abstract type definitions
include("pack.jl")

# Auxiliary type for unpacking msgpack vector / map formats
include("generator.jl")

# Basic packing / unpacking formats
include("coreformats.jl")
include("extensionformat.jl")
include("anyformat.jl")

# Convenience formats
include("dynamicformats.jl")
include("structformat.jl")
include("arrayformats.jl")
include("typedformat.jl")
include("specialformats.jl")

# Support for some basic julia types
include("basetypes.jl")

# Convenience @pack macro for structs
include("macro.jl")

# Skipping and stepping convenience functions
include("skip.jl")

export pack, unpack
export @pack

export Format,
       DefaultFormat,
       AnyFormat,
       NilFormat,
       BoolFormat,
       SignedFormat,
       UnsignedFormat,
       FloatFormat,
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

@static if VERSION >= v"1.11"
  include("public.jl")
end

end # module StructPack
