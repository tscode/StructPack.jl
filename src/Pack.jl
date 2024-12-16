module Pack

# Interface and abstract type definitions
include("pack.jl")

# Supported packing formats
include("coreformats.jl")
include("anyformat.jl")
include("arrayformats.jl")
include("extraformats.jl")

# Supported julia types
include("basetypes.jl")
include("bytes.jl")

# Convenience @pack macro for structs
include("macro.jl")

export @pack

end # module Pack
