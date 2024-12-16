
module TranscodingStreamsExt

import Pack: pack, unpack
import Pack: Format, StreamFormat
import TranscodingStreams: TranscodingStream, TOKEN_END

function pack(
  io::IO,
  value,
  ::StreamFormat{S, F},
) where {S <: TranscodingStream, F <: Format}
  stream = S(io)
  pack(stream, value, F())
  write(stream, TOKEN_END)
  return flush(stream)
end

function unpack(
  io::IO,
  ::StreamFormat{S, F},
) where {S <: TranscodingStream, F <: Format}
  stream = S(io)
  return unpack(stream, F())
end

function unpack(
  io::IO,
  ::Type{T},
  ::StreamFormat{S, F},
) where {T, S, F <: Format}
  stream = S(io)
  return unpack(stream, T, F())
end

end
