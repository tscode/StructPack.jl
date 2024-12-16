
module DatesExt

import Pack: format, construct, StringFormat
using Dates

format(::Type{Date}) = StringFormat()
construct(::Type{Date}, x, ::StringFormat) = Date(x)

format(::Type{DateTime}) = StringFormat()
construct(::Type{DateTime}, x, ::StringFormat) = DateTime(x)

end
