
# Generic skip fallback
# 
# TODO: benchmark if it is worth it to replace this by dedicated skip-functions
# for SignedFormat, UnsignedFormat, FloatFormat

function skip(io::IO, fmt::Format)::Nothing
  unpack(io, fmt)
  nothing
end

# Specialized skip implementations

function skip(io::IO, ::NilFormat)::Nothing
  skip(io, 1)
end

function skip(io::IO, ::BoolFormat)::Nothing
  skip(io, 1)
end

function skip(io::IO, fmt::StringFormat)::Nothing
  n = readheaderbytes(io, fmt)
  Base.skip(io, n)
  nothing
end

function skip(io::IO, fmt::BinaryFormat)::Nothing
  n = readheaderbytes(io, fmt)
  Base.skip(io, n)
  nothing
end

function skip(io::IO, fmt::VectorFormat)::Nothing
  n = readheaderbytes(io, fmt)
  foreach(_ -> skip(io), 1:n)
end

function skip(io::IO, fmt::MapFormat)::Nothing
  n = readheaderbytes(io, fmt)
  foreach(_ -> skip(io), 1:2n)
end

function skip(io::IO, fmt::ExtensionFormat)::Nothing
  n, _ = readheaderbytes(io, fmt)
  Base.skip(io, n)
  nothing
end

"""
   skip(io)

Skip the msgpack value at `io`.
"""
function skip(io)
  fmt = peekformat(io)
  skip(io, fmt)
end


"""
    step(io::IO)

Take one step in the msgpack value at `io`.

If the active value is stored in map or vector format, step into it.
Otherwise, skip the element.

Returns the core format of the value skipped or stepped into.

For example, if a msgpack array is stored at `io`, then `step(io); unpack(io)`
will (generically) unpack the first element of the array.
"""
function step(io)
  fmt = peekformat(io)
  if fmt == VectorFormat() || fmt == MapFormat()
    readheaderbytes(io, fmt)
  else
    skip(io)
  end
  fmt
end

