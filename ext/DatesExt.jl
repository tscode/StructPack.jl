
module DatesExt

import StructPack: format, destruct, construct, StringFormat
using Dates

format(::Type{Date}) = StringFormat()
destruct(date::Date, ::StringFormat) = Base.string(date)
construct(::Type{Date}, x, ::StringFormat) = Date(x)

format(::Type{DateTime}) = StringFormat()
destruct(date::DateTime, ::StringFormat) = Base.string(date)
construct(::Type{DateTime}, x, ::StringFormat) = DateTime(x)

end
