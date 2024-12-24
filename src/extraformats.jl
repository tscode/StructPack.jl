
## TODO: generalize the StreamFormat to accept general streams of variable length and store it as a valid binary in the msgpack!
## This would require that we can seek backwards and manipulate the stream...
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

function pack(io::IO, value, ::StreamFormat, rules::Rules)
  return error(
    "StreamFormat requires the package TranscodingStreams to be loaded."
  )
end

function unpack(io::IO, ::StreamFormat, rules::Rules)
  return error(
    "StreamFormat requires the package TranscodingStreams to be loaded."
  )
end

