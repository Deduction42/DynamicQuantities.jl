abstract type AbstractAffineDimensions{R} <: AbstractDimensions{R} end

const AbstractQuantityOrArray{T,D} = Union{UnionAbstractQuantity{T,D}, QuantityArray{T,<:Any,D}}
const UnionAffineQuantity{T} = UnionAbstractQuantity{T, <:AbstractAffineDimensions}
const ABSTRACT_AFFINE_QUANTITY_TYPES = (
    (AbstractQuantity{<:Number, <:AbstractAffineDimensions}, Number, Quantity{<:Number, <:AbstractAffineDimensions}),
    (AbstractGenericQuantity{<:Any, <:AbstractAffineDimensions}, Any, GenericQuantity{<:Any, <:AbstractAffineDimensions}),
    (AbstractRealQuantity{<:Real, <:AbstractAffineDimensions}, Real, RealQuantity{<:Real, <:AbstractAffineDimensions})
)
const PLACEHOLDER_SYMBOL = :_

# Break `ustrip` for affine quantities because the operation is unsafe, define the unsafe "affine_ustrip" for this
function ustrip(q::UnionAffineQuantity)
    assert_no_offset(dimension(q))
    return affine_ustrip(q)
end
affine_ustrip(q::UnionAffineQuantity) = q.value
affine_ustrip(q::QuantityArray{<:Any, <:AbstractAffineDimensions}) = q.value
affine_ustrip(q) = ustrip(q)


const AffineOrSymbolicDimensions{R} = Union{AbstractAffineDimensions{R}, AbstractSymbolicDimensions{R}}

"""
    AffineOffsetError{D} <: Exception

Error thrown when attempting an implicit conversion of an `AffineDimensions` 
with a non-zero offset.

!!! warning
    This is an experimental feature and may change in the future.
"""
struct AffineOffsetError{D} <: Exception
    dim::D

    AffineOffsetError(dim) = new{typeof(dim)}(dim)
end

Base.showerror(io::IO, e::AffineOffsetError) = print(io, "AffineOffsetError: ", e.dim, " has a non-zero offset, operation not allowed on affine units. Consider using `uexpand(x)` to explicitly convert")

"""
    AffineDimensions{R}(scale::Float64, offset::Float64, basedim::Dimensions{R}, symbol::Symbol=:_)

AffineDimensions adds a scale and offset to Dimensions{R} allowing the expression of affine transformations of units (for example °C)
The offset parameter is in SI units (i.e. having the dimension of basedim)

!!! warning
    This is an experimental feature and may change in the future.
"""
struct AffineDimensions{R} <: AbstractAffineDimensions{R}
    scale::Float64
    offset::Float64
    basedim::Dimensions{R}
    symbol::Symbol
end

AffineDimensions(; scale=1.0, offset=0.0, basedim, symbol=PLACEHOLDER_SYMBOL) = AffineDimensions(scale, offset, basedim, symbol)
AffineDimensions{R}(; scale=1.0, offset=0.0, basedim, symbol=PLACEHOLDER_SYMBOL) where {R} = AffineDimensions{R}(scale, offset, basedim, symbol)
AffineDimensions(s, o, dims::AbstractDimensions{R}, symbol=PLACEHOLDER_SYMBOL) where {R} = AffineDimensions{R}(s, o, dims, symbol)
AffineDimensions(s, o, q::UnionAbstractQuantity{<:Any,<:AbstractDimensions{R}}, sym=PLACEHOLDER_SYMBOL) where {R} = AffineDimensions{R}(s, o, q, sym)
AffineDimensions(d::Dimensions{R}) where R = AffineDimensions{R}(basedim=d)

# Handle offsets in affine dimensions
function AffineDimensions{R}(s::Real, o::Real, dims::AbstractAffineDimensions, sym=PLACEHOLDER_SYMBOL) where {R}
    new_s = s * affine_scale(dims)
    new_o = affine_offset(dims) + o * affine_scale(dims)
    return AffineDimensions{R}(new_s, new_o, affine_base_dim(dims), sym)
end

function AffineDimensions{R}(s::Real, o::UnionAbstractQuantity, dims::AbstractAffineDimensions, sym=PLACEHOLDER_SYMBOL) where {R}
    new_s = s * affine_scale(dims)
    new_o = affine_offset(dims) + ustrip(uexpand(o))
    return AffineDimensions{R}(new_s, new_o, affine_base_dim(dims), sym)
end

function AffineDimensions{R}(s::Real, o::UnionAbstractQuantity, dims::Dimensions, sym=PLACEHOLDER_SYMBOL) where {R}
    return AffineDimensions{R}(s, ustrip(uexpand(o)), dims, sym)
end

# From two quantities 
function AffineDimensions{R}(s::Real, o::UnionAbstractQuantity, q::UnionAbstractQuantity, sym=PLACEHOLDER_SYMBOL) where {R}
    q_si_origin = uexpand(0 * q)
    o_si_origin = uexpand(0 * o)
    o_difference_to_si = uexpand(o) - o_si_origin
    dimension(q_si_origin) == dimension(o_difference_to_si) || throw(DimensionError(o, q))
    o_si = o_difference_to_si + q_si_origin
    q_si = uexpand(q) - q_si_origin
    return AffineDimensions{R}(s, o_si, q_si, sym)
end

# Base case with SI units
function AffineDimensions{R}(s::Real, o::UnionAbstractQuantity{<:Any,<:Dimensions}, q::UnionAbstractQuantity{<:Any,<:Dimensions}, sym=PLACEHOLDER_SYMBOL) where {R}
    dimension(o) == dimension(q) || throw(DimensionError(o, q))
    return AffineDimensions{R}(s * ustrip(q), ustrip(o), dimension(q), sym)
end

# Offset from real
function AffineDimensions{R}(s::Real, o::Real, q::Q, sym=PLACEHOLDER_SYMBOL) where {R, Q<:UnionAbstractQuantity}
    return AffineDimensions{R}(s, o * q, q, sym)
end

affine_scale(d::AffineDimensions) = d.scale
affine_offset(d::AffineDimensions) = d.offset
affine_base_dim(d::AffineDimensions) = d.basedim
affine_symbol(d::AffineDimensions) = d.symbol

with_type_parameters(::Type{<:AffineDimensions}, ::Type{R}) where {R} = AffineDimensions{R}
@unstable constructorof(::Type{<:AffineDimensions}) = AffineDimensions

function Base.show(io::IO, d::AbstractAffineDimensions)
    if affine_symbol(d) != PLACEHOLDER_SYMBOL
        print(io, affine_symbol(d))
    else
        print(io, "AffineDimensions(scale=", affine_scale(d), ", offset=", affine_offset(d), ", basedim=", affine_base_dim(d), ")")
    end
end

Base.show(io::IO, q::UnionAffineQuantity{<:Real}) = print(io, affine_ustrip(q), " ", dimension(q))
Base.show(io::IO, q::UnionAffineQuantity) = print(io, "(", affine_ustrip(q), ") ", dimension(q))

function assert_no_offset(d::AffineDimensions)
    if !iszero(affine_offset(d))
        throw(AffineOffsetError(d))
    end
end

function change_symbol(d::AffineDimensions{R}, s::Symbol) where R
    return AffineDimensions{R}(scale=affine_scale(d), offset=affine_offset(d), basedim=affine_base_dim(d), symbol=s)
end

change_symbol(q::Q, s::Symbol) where Q <: UnionAbstractQuantity = constructorof(Q)(affine_ustrip(q), change_symbol(dimension(q), s))

"""
    uexpand(q::Q) where {T,R,D<:AbstractAffineDimensions{R},Q<:UnionAbstractQuantity{T,D}}

Expand the affine units in a quantity to their base SI form (with `Dimensions`).
"""
function uexpand(q::Q) where {T,R,D<:AbstractAffineDimensions{R},Q<:UnionAbstractQuantity{T,D}}
    return _unsafe_convert(with_type_parameters(Q, T, Dimensions{R}), q)
end
uexpand(q::QuantityArray{T,N,D}) where {T,N,D<:AbstractAffineDimensions} = uexpand.(q)

for (type, _, _) in ABSTRACT_QUANTITY_TYPES
    @eval begin
        function _unsafe_convert(::Type{Q}, q::UnionAbstractQuantity{<:Any,<:AbstractAffineDimensions}) where {T,D<:Dimensions,Q<:$type{T,D}}
            d = dimension(q)
            v = affine_ustrip(q) * affine_scale(d) + affine_offset(d)
            return constructorof(Q)(convert(T, v), affine_base_dim(d))
        end

        function Base.convert(::Type{Q}, q::UnionAbstractQuantity{<:Any,<:Dimensions}) where {T,Q<:$type{T,AffineDimensions}}
            return convert(with_type_parameters(Q, T, AffineDimensions{DEFAULT_DIM_BASE_TYPE}), q)
        end
        function Base.convert(::Type{Q}, q::UnionAbstractQuantity{<:Any,<:Dimensions}) where {T,R,Q<:$type{T,AffineDimensions{R}}}
            return constructorof(Q)(convert(T, ustrip(q)), AffineDimensions{R}(scale=1, offset=0, basedim=dimension(q)))
        end
        function Base.convert(::Type{Q}, q::UnionAbstractQuantity{<:Any,<:AbstractAffineDimensions}) where {T,D<:Dimensions,Q<:$type{T,D}}
            assert_no_offset(dimension(q))
            return _unsafe_convert(Q, q)
        end
    end
end

# Generate promotion rules for affine dimensions
for D1 in (:AffineDimensions, :Dimensions, :SymbolicDimensions), D2 in (:AffineDimensions, :Dimensions, :SymbolicDimensions)

    # Skip if both are not affine dimensions
    (D1 != :AffineDimensions && D2 != :AffineDimensions) && continue

    # Determine the output type
    OUT_D = (D1 == :AffineDimensions == D2) ? :AffineDimensions : :Dimensions

    @eval function Base.promote_rule(::Type{$D1{R1}}, ::Type{$D2{R2}}) where {R1,R2}
        return $OUT_D{promote_type(R1,R2)}
    end
end

# Generate *,/ operations for affine units
for (type, base_type, _) in ABSTRACT_AFFINE_QUANTITY_TYPES
    # For div, we don't want to go more generic than `Number`
    div_base_type = base_type <: Number ? base_type : Number
    @eval begin
        function Base.:*(l::$type, r::$type)
            l, r = promote_except_value(l, r)
            new_quantity(typeof(l), affine_ustrip(l) * affine_ustrip(r), dimension(l) * dimension(r))
        end
        function Base.:/(l::$type, r::$type)
            l, r = promote_except_value(l, r)
            new_quantity(typeof(l), affine_ustrip(l) / affine_ustrip(r), dimension(l) / dimension(r))
        end
        function Base.div(x::$type, y::$type, r::RoundingMode=RoundToZero)
            x, y = promote_except_value(x, y)
            new_quantity(typeof(x), div(affine_ustrip(x), affine_ustrip(y), r), dimension(x) / dimension(y))
        end

        # The rest of the functions are unchanged because they do not operate on two variables of the custom type
        function Base.:*(l::$type, r::$base_type)
            new_quantity(typeof(l), affine_ustrip(l) * r, dimension(l))
        end
        function Base.:/(l::$type, r::$base_type)
            new_quantity(typeof(l), affine_ustrip(l) / r, dimension(l))
        end
        function Base.div(x::$type, y::$div_base_type, r::RoundingMode=RoundToZero)
            new_quantity(typeof(x), div(affine_ustrip(x), y, r), dimension(x))
        end

        function Base.:*(l::$base_type, r::$type)
            new_quantity(typeof(r), l * affine_ustrip(r), dimension(r))
        end
        function Base.:/(l::$base_type, r::$type)
            new_quantity(typeof(r), l / affine_ustrip(r), inv(dimension(r)))
        end
        function Base.div(x::$div_base_type, y::$type, r::RoundingMode=RoundToZero)
            new_quantity(typeof(y), div(x, affine_ustrip(y), r), inv(dimension(y)))
        end

        function Base.:*(l::$type, r::AbstractDimensions)
            new_quantity(typeof(l), affine_ustrip(l), dimension(l) * r)
        end
        function Base.:/(l::$type, r::AbstractDimensions)
            new_quantity(typeof(l), affine_ustrip(l), dimension(l) / r)
        end

        function Base.:*(l::AbstractDimensions, r::$type)
            new_quantity(typeof(r), affine_ustrip(r), l * dimension(r))
        end
        function Base.:/(l::AbstractDimensions, r::$type)
            new_quantity(typeof(r), inv(affine_ustrip(r)), l / dimension(r))
        end
    end
end

# Support array types

Base.size(q::UnionAffineQuantity) = size(affine_ustrip(q))
Base.length(q::UnionAffineQuantity) = length(affine_ustrip(q))
Base.axes(q::UnionAffineQuantity) = axes(affine_ustrip(q))
Base.iterate(qd::UnionAffineQuantity, maybe_state...) =
    let subiterate=iterate(affine_ustrip(qd), maybe_state...)
        subiterate === nothing && return nothing
        return new_quantity(typeof(qd), subiterate[1], dimension(qd)), subiterate[2]
    end
Base.ndims(::Type{<:UnionAffineQuantity{T}}) where {T} = ndims(T)
Base.ndims(q::UnionAffineQuantity) = ndims(affine_ustrip(q))
Base.broadcastable(q::UnionAffineQuantity{<:Any, <:AbstractAffineDimensions}) = new_quantity(typeof(q), Base.broadcastable(affine_ustrip(q)), dimension(q))
for (type, _, _) in ABSTRACT_AFFINE_QUANTITY_TYPES
    @eval Base.getindex(q::$type) = new_quantity(typeof(q), getindex(affine_ustrip(q)), dimension(q))
    @eval Base.getindex(q::$type, i::Integer...) = new_quantity(typeof(q), getindex(affine_ustrip(q), i...), dimension(q))
    type == AbstractGenericQuantity &&
        @eval Base.getindex(q::$type, i...) = new_quantity(typeof(q), getindex(affine_ustrip(q), i...), dimension(q))
end
QuantityArray(v::QA) where {Q<:UnionAffineQuantity,QA<:AbstractArray{Q}} =
    let
        allequal(dimension.(v)) || throw(DimensionError(first(v), v))
        QuantityArray(affine_ustrip.(v), dimension(first(v)), Q)
    end

"""
    uconvert(qout::UnionAbstractQuantity{<:Any, <:AbstractAffineDimensions}, q::UnionAbstractQuantity{<:Any, <:Dimensions})

You may also convert to a quantity expressed in affine units.
"""
function uconvert(qout::UnionAbstractQuantity{<:Any,<:AffineDimensions}, q::UnionAbstractQuantity{<:Any,<:Dimensions})
    @assert isone(affine_ustrip(qout)) "You passed a quantity with a non-unit value to uconvert."
    dout = dimension(qout)
    dimension(q) == affine_base_dim(dout) || throw(DimensionError(q, qout))
    vout = (affine_ustrip(q) - affine_offset(dout)) / affine_scale(dout)
    return new_quantity(typeof(q), vout, dout)
end

function uconvert(qout::UnionAbstractQuantity{<:Any,<:AffineDimensions}, q::QuantityArray{<:Any,<:Any,<:Dimensions})
    @assert isone(affine_ustrip(qout)) "You passed a quantity with a non-unit value to uconvert."
    dout = dimension(qout)
    dimension(q) == affine_base_dim(dout) || throw(DimensionError(q, qout))
    stripped_q = affine_ustrip(q)
    offset = affine_offset(dout)
    scale = affine_scale(dout)
    vout = @. (stripped_q - offset) / scale
    return QuantityArray(vout, dout, quantity_type(q))
end

# Generic conversions through uexpand
function uconvert(qout::UnionAbstractQuantity{<:Any,<:AbstractSymbolicDimensions}, qin::AbstractQuantityOrArray{<:Any,<:AbstractAffineDimensions})
    uconvert(qout, uexpand(qin))
end
function uconvert(qout::UnionAbstractQuantity{<:Any,<:AbstractAffineDimensions}, qin::AbstractQuantityOrArray{<:Any,<:AbstractSymbolicDimensions})
    uconvert(qout, uexpand(qin))
end
function uconvert(qout::UnionAbstractQuantity{<:Any,<:AbstractAffineDimensions}, qin::AbstractQuantityOrArray{<:Any,<:AbstractAffineDimensions})
    uconvert(qout, uexpand(qin))
end

for (op, combine) in ((:+, :*), (:-, :/))
    @eval function map_dimensions(::typeof($op), args::AffineDimensions...)
        map(assert_no_offset, args)
        return AffineDimensions(
            scale=($combine)(map(affine_scale, args)...), offset=0.0, basedim=map_dimensions($op, map(affine_base_dim, args)...) 
        )
    end
end

# This is required because /(x::Number) results in an error, so it needs to be cased out to inv
function map_dimensions(op::typeof(-), d::AffineDimensions) 
    assert_no_offset(d)
    return AffineDimensions(scale=inv(affine_scale(d)), basedim=map_dimensions(op, affine_base_dim(d)))
end
function map_dimensions(fix1::Base.Fix1{typeof(*)}, l::AffineDimensions{R}) where {R}
    assert_no_offset(l)
    return AffineDimensions(scale=affine_scale(l)^fix1.x, basedim=map_dimensions(fix1, affine_base_dim(l)))
end

# Helper function for conversions
function _no_offset_expand(q::Q) where {T,R,Q<:UnionAbstractQuantity{T,<:AbstractAffineDimensions{R}}}
    return convert(with_type_parameters(Q, T, Dimensions{R}), q)
end

for op in (:+, :-, :mod)
    @eval begin
        function Base.$op(q1::UnionAbstractQuantity{<:Any,<:AffineDimensions}, q2::UnionAbstractQuantity{<:Any,<:AffineDimensions})
            return $op(_no_offset_expand(q1), _no_offset_expand(q2))
        end
    end
end


for op in (:(==), :(≈))
    @eval begin
        function Base.$op(q1::UnionAbstractQuantity{<:Any,<:AffineDimensions}, q2::UnionAbstractQuantity{<:Any,<:AffineDimensions})
            $op(uexpand(q1), uexpand(q2))
        end
        function Base.$op(d1::AffineDimensions, d2::AffineDimensions)
            $op(affine_base_dim(d1), affine_base_dim(d2)) &&
                $op(affine_scale(d1), affine_scale(d2)) &&
                $op(affine_offset(d1), affine_offset(d2))
        end
    end
end

const DEFAULT_AFFINE_QUANTITY_TYPE = with_type_parameters(DEFAULT_QUANTITY_TYPE, DEFAULT_VALUE_TYPE, AffineDimensions{DEFAULT_DIM_BASE_TYPE})

module AffineUnits
    using DispatchDoctor: @unstable


    import ..dimension, ..ustrip, ..uexpand, ..constructorof, ..change_symbol
    import ..affine_scale, ..affine_offset, ..affine_base_dim, ..affine_symbol, ..affine_ustrip
    import ..DEFAULT_AFFINE_QUANTITY_TYPE, ..DEFAULT_DIM_TYPE, ..DEFAULT_VALUE_TYPE, ..DEFAULT_DIM_BASE_TYPE
    import ..PLACEHOLDER_SYMBOL
    import ..Units: UNIT_SYMBOLS, UNIT_VALUES
    import ..Constants: Constants, CONSTANT_SYMBOLS, CONSTANT_VALUES
    import ..Quantity, ..INDEX_TYPE, ..AbstractDimensions, ..AffineDimensions, ..UnionAbstractQuantity
    import ..WriteOnceReadMany

    # Make a standard affine unit out of a quanitity and assign it a symbol
    function _make_affine_dims(q::UnionAbstractQuantity{<:Any}, symbol::Symbol=PLACEHOLDER_SYMBOL)
        q_si = uexpand(q)
        return AffineDimensions{DEFAULT_DIM_BASE_TYPE}(scale=ustrip(q_si), offset=0.0, basedim=dimension(q_si), symbol=symbol)
    end
    function _make_affine_dims(q::UnionAbstractQuantity{<:Any,<:AffineDimensions}, symbol::Symbol=PLACEHOLDER_SYMBOL)
        olddim = dimension(q)
        newscale  = affine_ustrip(q) * olddim.scale
        newoffset = Quantity(olddim.offset, olddim.basedim)
        return AffineDimensions{DEFAULT_DIM_BASE_TYPE}(scale=newscale, offset=newoffset, basedim=olddim.basedim, symbol=symbol)
    end

    #Make a standard affine quanitty out of an arbitrary quantity and assign a symbol
    function _make_affine_quant(q::UnionAbstractQuantity, symbol::Symbol=PLACEHOLDER_SYMBOL)
        return Quantity(one(DEFAULT_VALUE_TYPE), _make_affine_dims(q, symbol))
    end

    const AFFINE_UNIT_SYMBOLS = WriteOnceReadMany(deepcopy(UNIT_SYMBOLS))
    const AFFINE_UNIT_VALUES  = WriteOnceReadMany(map(_make_affine_quant, UNIT_VALUES, UNIT_SYMBOLS))
    const AFFINE_UNIT_MAPPING = WriteOnceReadMany(Dict(s => INDEX_TYPE(i) for (i, s) in enumerate(AFFINE_UNIT_SYMBOLS)))

    function update_external_affine_unit(newdims::AffineDimensions)
        debug_disp(dims::AffineDimensions) = (scale=dims.scale, offset=dims.offset, basedim=dims.basedim)

        #Check to make sure the unit's name is not PLACEHOLDER_SYMBOL (default)
        name = affine_symbol(newdims)
        if name == PLACEHOLDER_SYMBOL
            error("Cannot register an affine dimension without symbol declared")
        end

        ind = get(AFFINE_UNIT_MAPPING, name, INDEX_TYPE(0))
        if !iszero(ind)
            olddims = dimension(AFFINE_UNIT_VALUES[ind])
            if (olddims.scale != newdims.scale) || (olddims.offset != newdims.offset) || (olddims.basedim != newdims.basedim)
                error("Unit `$(name)` already exists as `$(debug_disp(olddims))`, its value cannot be changed to `$(debug_disp(newdims))`")
            end
            return nothing
        end

        new_q = constructorof(DEFAULT_AFFINE_QUANTITY_TYPE)(1.0, newdims)
        push!(AFFINE_UNIT_SYMBOLS, name)
        push!(AFFINE_UNIT_VALUES, new_q)
        AFFINE_UNIT_MAPPING[name] = lastindex(AFFINE_UNIT_SYMBOLS)
        return nothing
    end
    function update_external_affine_unit(name::Symbol, dims::AffineDimensions)
        return update_external_affine_unit(change_symbol(dims, name))
    end
    function update_external_affine_unit(name::Symbol, q::UnionAbstractQuantity)
        return update_external_affine_unit(_make_affine_dims(q, name))
    end

    """
        aff_uparse(s::AbstractString)

    Affine unit parsing function. This works similarly to `uparse`,
    but uses `AffineDimensions` instead of `Dimensions`, and permits affine units such
    as `°C` and `°F`. You may also refer to regular units such as `m` or `s`.
    """
    function aff_uparse(s::AbstractString)
        ex = map_to_scope(Meta.parse(s))
        ex = :($as_affine_quantity($ex))
        q  = eval(ex)
        return Quantity(ustrip(q), change_symbol(dimension(q), Symbol(s)))::DEFAULT_AFFINE_QUANTITY_TYPE
    end

    as_affine_quantity(q::DEFAULT_AFFINE_QUANTITY_TYPE) = q
    as_affine_quantity(x::Number) = convert(DEFAULT_AFFINE_QUANTITY_TYPE, x)
    as_affine_quantity(x) = error("Unexpected type evaluated: $(typeof(x))")

    # String parsing helpers
    @unstable function map_to_scope(ex::Expr)
        if ex.head != :call
            throw(ArgumentError("Unexpected expression: $ex. Only `:call` is expected."))
        end
        ex.args[2:end] = map(map_to_scope, ex.args[2:end])
        return ex
    end

    function map_to_scope(sym::Symbol)
        sym in AFFINE_UNIT_SYMBOLS || throw(ArgumentError("Symbol $sym not found in `AffineUnits`."))
        return lookup_unit(sym)
    end

    map_to_scope(ex) = ex

    function lookup_unit(ex::Symbol)
        i = findfirst(==(ex), AFFINE_UNIT_SYMBOLS)::Int
        return AFFINE_UNIT_VALUES[i]
    end

    # Register standard temperature units
    let
        K  = Quantity(1.0, temperature=1)
        °C = Quantity(1.0, AffineDimensions(scale=1.0, offset=273.15*K, basedim=K, symbol=:°C))
        °F = Quantity(1.0, AffineDimensions(scale=5/9, offset=(-160/9)°C, basedim=°C, symbol=:°F))
        update_external_affine_unit(dimension(°C))
        update_external_affine_unit(:degC, dimension(°C))
        update_external_affine_unit(dimension(°F))
        update_external_affine_unit(:degF, dimension(°F))
    end

    # Register unit symbols as exportable constants
    for (name, val) in zip(AFFINE_UNIT_SYMBOLS, AFFINE_UNIT_VALUES)
        @eval const $name = $val
    end
end

import .AffineUnits: aff_uparse, update_external_affine_unit

"""
    ua"[unit expression]"

Affine unit parsing macro. This works similarly to `u"[unit expression]"`, but uses 
`AffineDimensions` instead of `Dimensions`, and permits affine units such
as `°C` and `°F`. You may also refer to regular units such as `m` or `s`.

!!! warning
    This is an experimental feature and may change in the future.
"""
macro ua_str(s)
    ex = AffineUnits.map_to_scope(Meta.parse(s))
    ex = :($(AffineUnits.as_affine_quantity)($ex))
    ex = :($(change_symbol)($ex, Symbol($s)))
    return esc(ex)
end
