module Pack

# Interface and abstract type definitions
include("pack.jl")

# Auxiliary type for unpacking msgpack vector / map formats
include("generator.jl")

# Supported packing formats
include("coreformats.jl")
include("anyformat.jl")
include("dynamicformats.jl")
include("arrayformats.jl")
include("typedformat.jl")
include("extraformats.jl")

# Supported julia types
include("basetypes.jl")

# Convenience @pack macro for structs
include("macro.jl")

export @pack

end # module Pack
