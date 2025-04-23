
"""
Special format that overrides the current context.

In particular, packing (or similarly unpacking) via

    pack(val, SetContextFormat{C, F}(), C2())

is equivalent to

    pack(val, F(), C())

where the original context `C2 <: Context` is ignored.

This format is, for example, useful in combination with [`fieldformats`](@ref),
to enforce that different fields of a struct can be packed / unpacked with
different contexts.
"""
struct SetContextFormat{C<:Context, F<:Format} <: Format end

function SetContextFormat{C}() where {C <: Context}
  return SetContextFormat{C, DefaultFormat}()
end

function pack(io::IO, value, ::SetContextFormat{C, F}, ::Context) where {C, F}
  pack(io, value, F(), C())
end

function unpack(io::IO, ::Type{T}, ::SetContextFormat{C, F}, ::Context) where {T, C, F}
  unpack(io, T, F(), C())
end

function unpack(io::IO, ::SetContextFormat{C, F}, ::Context) where {C, F}
  unpack(io, F(), C())
end

