
# TODO: Add an example to the documentation
"""
Format that temporarily wraps the io into a `TranscodingStreams` compatible
stream.

The functionality of `StreamFormat` is provided as package extension. It
therefore needs the package `TranscodingStreams` to be loaded.

!!! warn

    When you decide to use StreamFormat, your packed binary will very likely not
    be accessible to generic msgpack deserializers anymore.
"""
struct StreamFormat{S, F <: Format} <: Format end

StreamFormat(S) = StreamFormat{S, DefaultFormat}()

function pack(io::IO, value, ::StreamFormat, scope::Scope)
  return error(
    "StreamFormat requires the package TranscodingStreams to be loaded."
  )
end

function unpack(io::IO, ::StreamFormat, scope::Scope)
  return error(
    "StreamFormat requires the package TranscodingStreams to be loaded."
  )
end

