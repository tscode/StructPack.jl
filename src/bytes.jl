"""
Convenience wrapper of `Vector{UInt8}` that implements [`BinaryFormat`](@ref).
"""
struct Bytes
  bytes::Vector{UInt8}
end

destruct(x::Bytes, ::BinaryFormat) = x.bytes
construct(::Type{Bytes}, bytes, ::BinaryFormat) = Bytes(bytes)
