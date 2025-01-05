
"""
    insert_rules!(ex, rex)

Add the trailing argument `::\$rex` to all toplevel function definitions in
the expression `ex`.
"""
function inject_rules!(ex, rex)
  if ex isa Expr
    if ex.head == :function
      if ex.args[1] isa Expr && ex.args[1].head == :where
        arguments = ex.args[1].args[1].args
      else
        arguments = ex.args[1].args
      end
      push!(arguments, Expr(:(::), rex))
    else
      foreach(arg -> inject_rules!(arg, rex), ex.args)
    end
  end
  return
end

"""
    insert_constraint!(ex, cex)

Add the where clause `where {\$cex}` to all toplevel function definitions
in `ex`.
"""
inject_constraint!(_, ::Nothing) = nothing

function inject_constraint!(ex, cex)
  if ex isa Expr
    if ex.head == :function
      if ex.args[1] isa Expr && ex.args[1].head == :where
        push!(ex.args[1].args, cex)
      else
        ex.args[1] = Expr(:where, ex.args[1], cex)
      end
    else
      foreach(arg -> inject_constraint!(arg, cex), ex.args)
    end
  end
  return
end


"""
    is_type_expr(ex)

Check weather the symbol or expression `ex` is a plausible type expression.

Allowed expressions are, for example, `A` (Symbol), `A.B`, or `A.B{C, D, E.F}`.
"""
function is_type_expr(ex, curly = true)
  if ex isa Symbol
    # T
    true
  elseif ex.head == :curly && curly
    # T{F, ...}
    # We are lenient here, because a precise specification of possible types
    # with arbitrary type parameters is hard
    true
  elseif ex.head == :.
    # A.T
    all(ex.args) do ex
      ex isa QuoteNode ? ex.value isa Symbol : is_type_expr(ex, false)
    end
  else
    false
  end
end

"""
    parse_rules_expr(ex)

check if `ex` can be understood as rules expression and return it if it can.
"""
function parse_rules_expr(ex)
  return is_type_expr(ex) ? ex : nothing
end


"""
    parse_typetarget_expr(ex)

Parse the type target expression of the [`@pack`](@ref) macro.

A type target is either
- just a type expression `T`. Then `(type = :T, constraint = nothing)` is returned.
- a subtype selection `{S <: T}`. Then `(type = :S, constraint = :({S <: T}))` is returned.
- an anonymous subtype selection `{<: T}`. Then `(var = S, constraint = :({\$S <: T}))` is returned, where `S` is a generated symbol.

Returns `nothing` if parsing was unsuccessful.
"""
function parse_typetarget_expr(ex)
  len = ex isa Symbol ? 0 : length(ex.args)
  if is_type_expr(ex)
    # T
    return (type = ex, constraint = nothing)
    
  elseif len == 1 && ex.head == :braces
    ex = ex.args[1]
    len = ex isa Symbol ? 0 : length(ex.args)

    if len == 1 &&
       ex.head == :(<:) &&
       is_type_expr(ex.args[1])

      # {<: T}
      S = gensym(:S)
      pushfirst!(ex.args, S)
      return (type = S, constraint = ex)

    elseif len == 2 &&
           ex.head == :(<:) &&
           ex.args[1] isa Symbol &&
           is_type_expr(ex.args[2])

      # {S <: T}
      S = ex.args[1]
      return (type = S, constraint = ex)

    end
  end  
  return nothing
end

"""
    parse_informat_expr(ex)

Parse an expression of the form `T in F`, where `T` is a valid type target (see
[`parse_typetarget_expr`](@ref)) and `F` is a type expression that corresponds
to a format.
"""
function parse_informat_expr(ex)
  if !(ex isa Expr) || ex.head != :call
    return
  end
  len = length(ex.args)
  if len == 3 && ex.args[1] in [:in, :(=>)]
    target = parse_typetarget_expr(ex.args[2])
    format = parse_typetarget_expr(ex.args[3])
    if !isnothing(target) && !isnothing(format) && isnothing(format.constraint)
      return (; target, format = format.type)
    end
  end
  return nothing
end

function code_informat(target, format)
  return quote 
    function Pack.format(::Type{$(target.type)})
      return $format() 
    end
  end
end

"""
    parse_constructor_expr(ex)

Parse a constructor expression of the form `(a, b, ... ; c, d, ...)` or
`C(a, b, ...; c, d, ...)`.

Returns the named triple `(names = (a, b, ...), kwnames = (c, d, ...), and
constructor = :C)`. In a constructor-less expression, `constructor = nothing`.
"""
function parse_constructor_expr(ex)
  if !(ex isa Expr)
    return
  end
  if ex.head == :tuple
    # (a, b, ...; c, d...)
    constructor = nothing # no constructor expression
    if ex.args[1] isa Expr && ex.args[1].head == :parameters
      # (a, b, ...; c, d...)
      names = ex.args[2:end]
      kwnames = ex.args[1].args
    else
      # (a, b, ...)
      names = ex.args
      kwnames = Symbol[]
    end
  elseif ex.head == :block && length(ex.args) == 3
    # (a; b) (is not parsed as tuple and thus is extra case)
    constructor = nothing 
    names = [ex.args[1]]
    kwnames = [ex.args[3]]
  elseif ex.head == :call && ex.args[1] != :in
    # C(a, b, ...; c, d, ...) 
    constructor = ex.args[1]
    if ex.args[2] isa Expr && ex.args[2].head == :parameters
      # C(a, b, ...; c, d, ...)
      names = ex.args[3:end]
      kwnames = ex.args[2].args
    else
      names = ex.args[2:end]
      kwnames = Symbol[]
    end
  else
    return
  end
  # Make sure names and kwnames are actually lists of symbols
  if all(isa.(names, Symbol)) && all(isa.(kwnames, Symbol))
    names = Symbol[name for name in names]
    kwnames = Symbol[name for name in kwnames]
    return (; names, kwnames, constructor)
  end
  return
end

function code_constructor_map(target, format, names, kwnames, constructor)
  @assert eval(format) <: AnyMapFormat """
  Macro constructor currently only works for map formats. Given: $format.
  """
  symbols = (names..., kwnames...)
  constructor = isnothing(constructor) ? target.type : constructor
  len = length(names)
  lenkw = length(kwnames)
  return quote
    function Pack.destruct(val::$(target.type), fmt::$format)
      Iterators.map($symbols) do name
        name=>getfield(val, name)
      end
    end

    function Pack.construct(::Type{$(target.type)}, pairs, fmt::$format)
      @assert length(pairs) == length($symbols) """
      Inconsistent number of arguments during unpacking.
      """
      if $lenkw == 0
        args = Iterators.map(last, pairs)
        $constructor(args...)
      else
        args = Vector(undef, $len)
        kwargs = Vector(undef, $lenkw)
        for (index, pair) in enumerate(pairs)
          if index <= $len
            args[index] = pair[2]
          else
            kwargs[index] = pair
          end
        end
        $constructor(args...; kwargs...)
      end
    end
  end
end

"""
    parse_fieldformat_expr(ex)

Parse a single field format expression of the form `a in F` or `(a, b, ...)
in F`.

Returns a vector of pairs `[a=>F, b=>F, ...]`.
"""
function parse_fieldformat_expr(ex)
  len = ex isa Symbol ? 0 : length(ex.args)
  if len == 3 && ex.args[1] in [:in, :(=>)]
    fieldexpr = ex.args[2]
    if fieldexpr isa Symbol
      fields = [fieldexpr]
    elseif fieldexpr isa Expr &&
       fieldexpr.head == :tuple &&
       all(isa.(fieldexpr.args, Symbol))
      fields = fieldexpr.args
    else
      return
    end
    format = parse_typetarget_expr(ex.args[3])
    if !isnothing(format) && isnothing(format.constraint)
      return [field => format.type for field in fields]
    end
  end
  return
end

"""
    parse_fieldformats_expr(ex)

Parse a field format expression of the form `[a in Fa, b in Fb, ...]`, where `a`
and `b` correspond to keys and `Fa`, `Fb` to format types.
"""
function parse_fieldformats_expr(ex)
  if ex isa Expr && ex.head == :vect
    pairs = mapreduce(vcat, ex.args) do arg
      parse_fieldformat_expr(arg)
    end
    return Dict(pairs)
  end
  return nothing
end

function code_fieldformats(target, format, names, kwnames, formats)
  symbols = (names..., kwnames...)
  fexprs = map(symbols) do key
    F = Base.get(formats, key, :(Pack.DefaultFormat))
    Expr(:call, F)
  end
  formats = Expr(:tuple, fexprs...)
  return quote
    function Pack.valuetype(::Type{$(target.type)}, index, ::$format)
      symbols = $symbols
      return Base.fieldtype($(target.type), symbols[index])
    end

    function Pack.valueformat(::Type{$(target.type)}, index, ::$format)
      formats = $formats
      return formats[index]
    end
  end
end

macro newpack(args...)
  informat = parse_informat_expr(args[1])
  target = informat.target
  format = informat.format
  cons = parse_constructor_expr(args[2])
  formats = parse_fieldformats_expr(args[3])

  block1 = code_informat(target, format)
  block2 = code_constructor_map(target, format, cons.names, cons.kwnames, cons.constructor)
  block3 = code_fieldformats(target, format, cons.names, cons.kwnames, formats)
  # join blocks
  block = Expr(:block, block1.args..., block2.args..., block3.args...)
  # block = block3
  # inject_rules!(block, target.constraint)
  inject_constraint!(block, target.constraint)
  return esc(block)
end

#
# process formats
#

function _isnativeformat(sym::Symbol)
  try
    F = getproperty(Pack, sym)
    F <: Format
  catch
    false
  end
end

function _injectmodule(ex)
  if ex isa Symbol
    _isnativeformat(ex) ? :(Pack.$ex) : ex
  elseif ex isa Expr
    Expr(ex.head, map(_injectmodule, ex.args)...)
  else
    ex
  end
end

function _parsescope(ex)
  len = ex isa Symbol ? 0 : length(ex.args)
  if ex isa Symbol # @pack T args...
    (ex, nothing)
  elseif len == 1 && ex.head == :braces
    ex = ex.args[1]
    len = ex isa Symbol ? 0 : length(ex.args)
    if len == 1 && ex.head == :(<:) # @pack {<: T} args...
      (ex, nothing)
    elseif len == 2 && ex.head == :(<:) && ex.args[1] isa Symbol # @pack {S <: T} args...
      (ex, ex.args[1])
    end
  end
end

_isinformat(::Symbol) = false

function _isinformat(ex::Expr)
  return length(ex.args) == 3 && ex.head == :call && ex.args[1] == :in
end

function _splitinformat(ex::Expr)
  if _isinformat(ex)
    ex.args[2], ex.args[3]
  end
end

function _parseinformat(ex)
  res = _splitinformat(ex)
  if !isnothing(res)
    res[1], _injectmodule(res[2])
  else
    error("Expected syntax \"A\", \"A in B\" or \"A => B\" in Pack.@pack")
  end
end

function _parsescopeformat(ex)
  len = ex isa Symbol ? 0 : length(ex.args)
  result = _parsescope(ex)
  if isnothing(result)
    ex, format = _parseinformat(ex)
    (_parsescope(ex)..., format)
  else
    (result..., nothing)
  end
end

#
# process fields
#

function _parsefieldformat(ex)
  ex, format = _parseinformat(ex)
  if ex isa Symbol # a in F
    [(ex, format)]
  elseif ex.head in [:tuple, :vect] && all(isa.(ex.args, Symbol)) # (a, b) in F
    map(name -> (name, format), ex.args)
  else
    error("Pack.@pack expected entry expression of form \"a [in F]\"")
  end
end

function _parsefieldformats(args)
  entries = (mapreduce(_parsefieldformat, vcat, args; init = []))
  return (; entries...)
end

function _isselection(ex)
  return ex isa Symbol || # a
           (ex isa Expr && ex.head == :tuple) || # (a, b; c) is parsed as tuple
           (ex isa Expr && ex.head == :block) || # (a; b) is not parsed as tuple but as block
           (ex isa Expr && ex.head == :call && ex.args[1] != :in) # C(args...; kwargs...)
end

function _parseselection(ex)
  constructor = nothing
  if ex isa Symbol
    names = ex
    nkwargs = 0
  elseif ex.head == :tuple # (...)
    if ex.args[1] isa Expr && ex.args[1].head == :parameters # (args...; kwargs...)
      names = [ex.args[2:end]; ex.args[1].args]
      nkwargs = length(ex.args[1].args)
    else # (args...)
      names = ex.args
      nkwargs = 0
    end
  elseif ex.head == :block && length(ex.args) == 3 # (a; b) not parsed as tuple
    names = [ex.args[1], ex.args[3]]
    nkwargs = 1
  elseif ex.head == :call && ex.args[1] != :in
    if ex.args[2] isa Expr && ex.args[2].head == :parameters # (args...; kwargs...)
      names = [ex.args[3:end]; ex.args[2].args]
      nkwargs = length(ex.args[2].args)
      constructor = ex.args[1]
    else # (args...)
      names = ex.args[2:end]
      nkwargs = 0
      constructor = ex.args[1]
    end
  else
    error("Pack.@pack expected entry list of form \"{field[s] in F, ...}\"")
  end
  @assert all(isa.(names, Symbol)) """
  Pack.@pack expected symbols that reflect field selection names.
  """
  return Tuple(Symbol.(names)), nkwargs, constructor
end

#
# main macro
#

##
## TODO: Repair @pack RGBA{Float64} in MapFormat
##

"""
    @pack T [in format] [field format customization] [field selection]
"""
macro pack(args...)
  @assert length(args) >= 1 """
  Pack.@pack expects at least one argument ($(length(args)) were given).
  """
  scopeformat_arg = args[1]
  format_args = filter(_isinformat, args[2:end])
  selection_arg = filter(_isselection, args[2:end])

  @assert length(selection_arg) <= 1 """
  Pack.@pack found more than one field selection expression.
  """
  @assert length(format_args) + length(selection_arg) == length(args) - 1 """
  Pack.@pack was unable to parse all argument expressions.
  """

  # Extract the type scope that the packing rules apply to and the (optional)
  # default format.
  body = []
  scope, tvar, fmt = _parsescopeformat(scopeformat_arg)

  # If a default format has been specified in the macro, add the respective
  # method to the body
  if !isnothing(fmt)
    if isnothing(tvar)
      expr = :(Pack.format(::Type{$scope}) = $fmt())
    else
      expr = :(Pack.format(::Type{$tvar}) where {$scope} = $fmt())
    end
    push!(body, expr)
  end

  # If format_args and selection_arg are not empty, additional methods for
  # Pack.destruct, Pack.construct, and Pack.valueformat will be defined.
  # In this case, we introduce a typevariable (if non has been specified by
  # the user).
  if isnothing(tvar) && scope isa Symbol
    tvar = gensym(:S)
    scope = :($scope <: $tvar <: $scope)
  elseif isnothing(tvar)
    tvar = gensym(:S)
    scope = Expr(:(<:), tvar, scope.args[1])
  end

  # Define the methods Pack.destruct and Pack.construct if an explicit
  # field selection has been specified
  if length(selection_arg) == 1
    names, nkwargs, constructor = _parseselection(selection_arg[1])
    destruct = quote
      function Pack.destruct(value::$tvar, ::Pack.MapFormat) where {$scope}
        return Pack._destruct(value, $names)
      end
    end
    construct = quote
      function Pack.construct(
        ::Type{$tvar},
        pairs,
        ::Pack.MapFormat,
      ) where {$scope}
        return Pack._construct($tvar, pairs, $nkwargs, $constructor)
      end
    end
    push!(body, destruct, construct)
  end

  # If either field selections or a field format customizations have been
  # specified, the Pack.valueformat method has to be adapted, since the default
  # cannot be assumed to work anymore
  if length(selection_arg) > 0 || length(format_args) > 0
    if isempty(selection_arg)
      name = :(Base.fieldname($tvar, index))
    else
      name = :($names[index])
    end
    fieldformats = _parsefieldformats(format_args)
    valuetype = quote
      function Pack.valuetype(::Type{$tvar}, index) where {$scope}
        name = $name
        return Base.fieldtype($tvar, name)
      end
    end
    valueformat = quote
      function Pack.valueformat(::Type{$tvar}, index) where {$scope}
        name = $name
        return $(_valueformatexpr(:name, fieldformats))
      end
    end
    push!(body, valuetype, valueformat)
  end

  @assert !isempty(body) "Pack.@pack has received no packing instructions"
  return Expr(:block, body...) |> esc
end

function _valueformatexpr(name, fieldformats)
  expr = nothing
  level = nothing
  for (key, format) in pairs(fieldformats)
    if isnothing(expr)
      expr = Expr(:if, :($name == $(QuoteNode(key))), :($format()))
      level = expr
    else
      tmp = Expr(:elseif, :($name == $(QuoteNode(key))), :($format()))
      push!(level.args, tmp)
      level = tmp
    end
  end
  if isempty(fieldformats)
    expr = :(Pack.DefaultFormat())
  else
    push!(level.args, :(Pack.DefaultFormat()))
  end
  return expr
end

function _destruct(value::T, names) where {T}
  Iterators.map(1:length(names)) do index
    key = names[index]
    val = getfield(value, key)
    return (key, val)
  end
end

function _construct(::Type{T}, pairs, nkwargs, constructor) where {T}
  len = length(pairs)
  @assert len >= nkwargs "inconsistent number of keyword arguments"
  args = []
  kwargs = []
  for (index, pair) in enumerate(pairs)
    if index <= len - nkwargs
      push!(args, pair[2])
    else
      push!(kwargs, pair)
    end
  end
  if isnothing(constructor)
    T(args...; kwargs...)
  else
    constructor(args...; kwargs...)
  end
end
