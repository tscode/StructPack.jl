
module TranscodingStreamsExt

import Pack: pack, unpack
import Pack: Format, StreamFormat, Scope
import TranscodingStreams: TranscodingStream, TOKEN_END

function pack(
  io::IO,
  value,
  ::StreamFormat{S, F},
  scope::Scope,
) where {S <: TranscodingStream, F <: Format}
  stream = S(io)
  pack(stream, value, F(), scope)
  write(stream, TOKEN_END)
  return flush(stream)
end

function unpack(
  io::IO,
  ::StreamFormat{S, F},
  ::Scope,
) where {S <: TranscodingStream, F <: Format}
  stream = S(io)
  return unpack(stream, F(), scope)
end

function unpack(
  io::IO,
  ::Type{T},
  ::StreamFormat{S, F},
  scope::Scope,
) where {T, S, F <: Format}
  stream = S(io)
  return unpack(stream, T, F(), scope)
end

end
