
##
## Auxiliary functions
##

"""
    insert_context!(ex, rex)

Add the trailing argument `::\$rex` to all toplevel function definitions in
the expression `ex`.
"""
inject_context!(ex, ::Nothing) = nothing

function inject_context!(ex, rex)
  if ex isa Expr
    if ex.head == :function
      if ex.args[1] isa Expr && ex.args[1].head == :where
        arguments = ex.args[1].args[1].args
      else
        arguments = ex.args[1].args
      end
      push!(arguments, Expr(:(::), rex))
    else
      foreach(arg -> inject_context!(arg, rex), ex.args)
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
    parse_context_expr(ex)

Check if `ex` can be understood as context expression and return it if it can.
"""
function parse_context_expr(ex)
  return is_type_expr(ex) ? ex : nothing
end


"""
    parse_typetarget_expr(ex)

Parse the type target expression of the [`@pack`](@ref) macro.

A type target is either
- just a type expression `T`. Then `(type = :T, constraint = nothing)` is returned.
- a subtype selection `{S <: T}`. Then `(type = :S, constraint = :({S <: T}))` is returned.
- an anonymous subtype selection `{<: T}`. Then `(type = S_gen, constraint = :({\$S_gen <: T}))` is returned, where `S_gen` is a generated symbol.

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
      S = Base.gensym(:S)
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
  return
end

"""
    parse_format_expr(ex)

Parse a format expression. A format expression is either a type `F` or
`F{...}`, or an expression with the syntax `F[C]`, which is translated to
`ContextFormat{C, F}`
"""
function parse_format_expr(ex)
  len = ex isa Symbol ? 0 : length(ex.args)
  if is_type_expr(ex)
    return ex

  elseif len == 2 &&
         ex.head == :ref &&
         is_type_expr(ex.args[1]) &&
         is_type_expr(ex.args[2])
    return Expr(
      :curly,
      :(StructPack.ContextFormat),
      ex.args[2],
      ex.args[1],
    )
  end
  return
end

"""
    parse_informat_expr(ex)

Parse an expression of the form `T in F`, where `T` is a valid type target (see
[`parse_typetarget_expr`](@ref)) and `F` is a type expression that corresponds
to a format (see [`parse_format_expr`](@ref)).

Return a named tuple with entries `target` and `format`.
"""
function parse_informat_expr(ex)
  if !(ex isa Expr) || ex.head != :call
    return
  end
  len = length(ex.args)
  if len == 3 && ex.args[1] in [:in, :(=>)]
    target = parse_typetarget_expr(ex.args[2])
    format = parse_format_expr(ex.args[3])
    if !isnothing(target) && !isnothing(format)
      return (; target, format)
    end
  end
  return
end

function code_informat(target, format)
  return quote 
    function StructPack.format(::Type{$(target.type)})
      return $format() 
    end
  end
end

"""
    parse_constructor_expr(ex)

Parse a constructor expression of the form `(a, b, ... ; c, d, ...)` or
`C(a, b, ...; c, d, ...)`. Each name can alternatively be of the form `a::Ta`, `b::Tb, ...` to associate the fieldnames to a type.

Returns the named tuple `(names = (a, b, ...), kwnames = (c, d, ...), types,
constructor = :C)`, where types is a dictionary containing entries `a=>:(Ta), ...`. In a constructor-less expression, `constructor = nothing`.
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
  nkwargs = length(kwnames)
  names = vcat(names, kwnames)

  # Split off possible type information
  names_types = map(names) do name
    if name isa Symbol
      name=>nothing
    elseif name isa Expr &&
      name.head == :(::) &&
      length(name.args) == 2 &&
      name.args[1] isa Symbol &&
      is_type_expr(name.args[2])
      name.args[1]=>name.args[2]
    end
  end

  # Collect all outputs
  if all(!isnothing, names_types)
    names = first.(names_types)
    types = filter(pair -> !isnothing(pair[2]), names_types)
    return (; names, nkwargs, types = Dict(types), constructor)
  end
end

"""
    code_constructor(target, fieldnames, fieldtypes, nkwargs, constructor)

Generate appropriate `fieldnames`, `fieldtypes`, `destruct`, and `construct`
method bodies.
"""
function code_constructor(target, fieldnames, fieldtypes, nkwargs, constructor)
  constructor = isnothing(constructor) ? target.type : constructor
  nargs = length(fieldnames) - nkwargs
  len = length(fieldnames)

  return quote
    function StructPack.fieldnames(::Type{$(target.type)})
      return $(Tuple(fieldnames))
    end

    @generated function StructPack.fieldtypes(::Type{$(target.type)})
      names = $fieldnames
      texprs = map(names) do key
        Base.get($fieldtypes, key) do
          default = Base.fieldtype($(target.type), key)
          :($default)
        end
      end
      return Expr(:tuple, texprs...)
    end

    function StructPack.destruct(val::$(target.type), fmt::StructPack.AbstractStructFormat)
      Iterators.map($fieldnames) do name
        name=>getfield(val, name)
      end
    end

    function StructPack.construct(::Type{$(target.type)}, pairs::Vector, fmt::StructPack.AbstractStructFormat)
      if length(pairs) != $len
        unpackerror("Inconsistent number of arguments during unpacking.")
      end
      args = Iterators.map(last, @view(pairs[1:$nargs]))
      kwargs = @view(pairs[$nargs+1:end])
      $constructor(args...; kwargs...)
    end

    function StructPack.construct(::Type{$(target.type)}, pairs::Tuple, fmt::StructPack.AbstractStructFormat)
      if length(pairs) != $len
        unpackerror("Inconsistent number of arguments during unpacking.")
      end
      args = map(last, pairs[1:$nargs])
      kwargs = pairs[$nargs+1:end]
      $constructor(args...; kwargs...)
    end
  end
end

"""
    parse_typeparams_expr(ex)

Parse a type parameter expression of the form `{A::TA, B::TB}`, where the labels
`A, B, ...` are optional.

Returns a named tuple with fields `names` and `types`, with labels randomly generated if not specified.
"""
function parse_typeparams_expr(ex)
  if !(ex isa Expr && ex.head == :braces)
    return
  end
  pairs = map(ex.args) do arg
    if arg isa Expr && arg.head == :(::)
      if length(arg.args) == 1 &&
         is_type_expr(arg.args[1])
        Base.gensym(:TP) => arg.args[1]
      elseif length(arg.args) == 2 &&
             is_type_expr(arg.args[2]) &&
             (arg.args[1] isa Symbol) 
        arg.args[1] => arg.args[2]
      end
    end
  end
  if all(!isnothing, pairs)
    return (
      names = first.(pairs),
      types = last.(pairs),
    )
  end
end

"""
    code_typeparams(target, tpnames, tptypes, formats)

Generate appropriate `typeparamtypes` and `typeparamformats` method bodies.
"""
function code_typeparams(target, tptypes)
  return quote
    @generated function StructPack.typeparamtypes(::Type{$(target.type)})
      texprs = $tptypes
      return Expr(:tuple, texprs...)
    end
  end
end


"""
    parse_subformat_expr(ex)

Parse a single field format expression of the form `a in F` or `(a, b, ...)
in F`.

Returns a vector of pairs `[:a=>F, :b=>F, ...]` if successful and `nothing` else.
"""
function parse_subformat_expr(ex)
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
    format = parse_format_expr(ex.args[3])
    if !isnothing(format)
      return [field => format for field in fields]
    end
  end
  return
end

"""
    parse_subformats_expr(ex)

Parse a subformat expression specification of the form `[a in Fa, b in Fb,
...]`, where `a, b, ...` correspond to labels and `Fa, Fb, ...` to format types.

Return a dictionary mapping labels to their respective format types.
"""
function parse_subformats_expr(ex)
  if ex isa Expr && ex.head == :vect
    if isempty(ex.args)
      pairs = []
    else
      pairs = mapreduce(vcat, ex.args) do arg
        # TODO: how to propagate errors here?
        parse_subformat_expr(arg)
      end
    end
    return Dict(pairs)
  end
  return
end

"""
    code_subformats(target, fieldnames, tpnames, formats)

Generate appropriate `fieldformats` and `typeparamformats` method bodies.
"""
function code_subformats(target, fieldnames, tpnames, formats)
  statements = []

  # Check whether typeparamformats method should be generated
  gen_tp = !isempty(intersect(keys(formats), tpnames))
  if gen_tp
    block = quote
      @generated function StructPack.typeparamformats(::Type{$(target.type)})
        names = $tpnames
        fexprs = map(names) do key
          F = Base.get($formats, key, :(StructPack.DefaultFormat))
          Expr(:call, F)
        end
        return Expr(:tuple, fexprs...)
      end
    end
    append!(statements, block.args)
  end

  # Check whether fieldformats method should be generated
  # This should be done in two cases:
  #   1) fieldnames have been provided explicitly
  #   2) even if no fieldnames have been provided, formats that are not
  #      assigned to type parameter names have been provided.
  gen_fields = !isnothing(fieldnames) || !isempty(setdiff(keys(formats), tpnames))
  if gen_fields
    if isnothing(fieldnames)
      fieldnames = :(Base.fieldnames($(target.type)))
    end
    block = quote
      @generated function StructPack.fieldformats(::Type{$(target.type)})
        names = $fieldnames
        fexprs = map(names) do key
          F = Base.get($formats, key, :(StructPack.DefaultFormat))
          Expr(:call, F)
        end
        return Expr(:tuple, fexprs...)
      end
    end
    append!(statements, block.args)
  end

  return Expr(:block, statements...)
end

"""
    consume_context_argument(args)

Try to consume an optional context type argument for the [`@pack`](@ref) macro.
Returns the consumed context (if any) and the remaining arguments.
"""
function consume_context_argument(args)
  if length(args) >= 2 &&
     is_type_expr(args[1]) &&
     (!isnothing(parse_typetarget_expr(args[2])) ||
      !isnothing(parse_informat_expr(args[2])))
    args[1], args[2:end]
  else
    nothing, args
  end
end

"""
    consume_argument(f, args)

Try to consume an argument via the parsing function `f`. Returns the  output of
`f` (if any) and the remaining arguments.
"""
function consume_argument(f, args)
  if isempty(args)
    return (nothing, args)
  end
  ret = f(args[1])
  if isnothing(ret)
    return (nothing, args)
  else
    return (ret, args[2:end])
  end
end

function parse_packmacro_arguments(args)
  # Check if the first argument plausably corresponds to a context type
  oargs = args
  context, args = consume_context_argument(args)
  @assert !isempty(args) """
  @pack: Type target argument is missing.
  """

  # Check if an isolated type target (WITHOUT default format) is given
  target, args = consume_argument(parse_typetarget_expr, args)

  if isnothing(target)
    # No, so check if a type target WITH default format is given
    informat, args = consume_argument(parse_informat_expr, args)
    @assert !isnothing(informat) """
    @pack: Type target cannot be determined.
    """
    target = informat.target
    format = informat.format
  else
    format = nothing
  end

  construct, args = consume_argument(parse_constructor_expr, args)
  tparams, args = consume_argument(parse_typeparams_expr, args)
  subformats, args = consume_argument(parse_subformats_expr, args)

  @assert isempty(args) """
  @pack: The following macro arguments could not be consumed: $args
  """
  if all(isnothing, [format, construct, tparams, subformats])
    str = join(oargs, " ")
    @warn """
    The macro call '@pack $str' will be without effect: \
    No default format, constructor, type parameter, or subformat arguments \
    were provided (see the documentation for @pack).
    """
  end
  return (;
    context,
    target,
    format,
    construct,
    tparams,
    subformats,
  )
end

"""
    @pack [context] target [in format] [(constructor...)] [{type parameters...}] [[formats...]]

Convenience macro to generate packing / unpacking code for the types specified
by `target`.

## Arguments

### target
This argument has to be of the form `T`, `{<: T}`, or `{S <: T}`, where `T` is an existing type and `S` is a variable name that can be reused in the constructor (see below).
This is the only mandatory argument of [`@pack`](@ref).

### context
This (optional) argument has to be an existing subtype `C <: Context`, see [`Context`](@ref).
The generated code will be restricted to this context.
Note that no instance of `C` can be passed; an actual type is required.

### format
This (optional) pattern can be used to set the default format of the type target by specializing the function [`format`](@ref).
For instance, `@pack T in F` for `F <: Format` will define `StructPack.format(::Type{T}) = F()`.

The special syntax `F[C]`, where `F <: Format` and `C <: Context`, is available as shortcut for `ContextFormat{C, F}`.
This will mainly be useful for the specification of field and type-parameter formats via `(formats...)`, see below.

### constructor
This (optional) argument affects the functions [`destruct`](@ref), [`construct`](@ref), [`fieldnames`](@ref), and (optionally) [`fieldtypes`](@ref) when a value of type `T` is packed / unpacked in a format `F <: AbstractStructFormat`.
* It can be a list of (keyword) arguments like `(a, b, ...; c, d, ...)`, in which case the constructor `T` is called with the respective arguments in [`construct`](@ref).
* It can be function call expression like `f(a, b, ...; c, d, ...)`, in which case the function `f` is called with the respective arguments in [`construct`](@ref).
In both cases, only the fields `(:a, :b, ..., :c, :d, ...)` are returned by [`fieldnames`](@ref), in this order.
This also affects which fields are packed via [`destruct`](@ref).

If type specifications are present (e.g., `(a::Int, b; c::Float64)`), the respective field types returned by [`fieldtypes`](@ref) are overwritten.

### type parameters
This (optional) argument affects the function [`typeparamtypes`](@ref).
It expects an expression of the form `{A::Ta, B::Tb, ...}`, where the labels
`A, B, ...` are optional and `Ta, Tb, ...` indicate the type of the respective type parameter.

Specification of the type parameter types is necessary if `T` is to be packed / unpacked in [`TypeFormat`](@ref) or a value `val::T` is to be packed / unpacked in [`TypedFormat`](@ref).

As a simple example, consider `@pack {<: Array} {::Type, ::Int}`, which enables packing / unpacking of base array types:

    @pack {<: Array} {::Type, ::Int}
    bytes = pack(Array{Float64, 3})
    unpack(bytes, Type) # sucessfully returns Array{Float64, 3}

### formats
This (optional) argument affects the functions [`fieldformats`](@ref) and [`typeparamformats`](@ref).
It is expected to be a list of format specifications `[a in Fa, b in Fb, C in FC, ...]`, where the labels `a, b, C, ...` refer to either field names of `T` or type parameter names established in the `{type parameters...}` argument, and where `Fa, Fb, FC, ...` are existing subtypes of `Format` (see `in format` above).

For convenience, the syntax `[(a, b, ...) in F]` translates to `[a in F, b in F, ...]`.

## Examples

```julia
using StructPack

struct A
  a :: Int
  b :: Vector{Float64}
  c :: Vector{Float64}
end

A(a, b) = A(a, b, rand(5))

@pack A in StructFormat (a, b) [b in BinVectorFormat]

A(a, b; c) = A(a, b, c)

@pack A in StructFormat (a, b; c) [(b, c) in BinVectorFormat]

myA(a) = A(a, [], [])

@pack A in StructFormat myA(a)
```
"""
macro pack(args...)
  r = parse_packmacro_arguments(args)
  statements = []

  if !isnothing(r.format)
    block = code_informat(r.target, r.format)
    append!(statements, block.args)
  end

  if !isnothing(r.construct)
    block = code_constructor(
      r.target,
      r.construct.names,
      r.construct.types,
      r.construct.nkwargs,
      r.construct.constructor,
    )
    append!(statements, block.args)
  end

  if !isnothing(r.tparams)
    block = code_typeparams(
      r.target,
      r.tparams.types,
    )
    append!(statements, block.args)
  end

  subformats = isnothing(r.subformats) ? Dict() : r.subformats
  fieldnames = isnothing(r.construct) ? nothing : r.construct.names
  tpnames = isnothing(r.tparams) ? [] : r.tparams.names

  block = code_subformats(
    r.target,
    fieldnames,
    tpnames,
    subformats
  )
  append!(statements, block.args)

  block = Expr(:block, statements...)
  inject_context!(block, r.context)
  inject_constraint!(block, r.target.constraint)

  return esc(block)
end
