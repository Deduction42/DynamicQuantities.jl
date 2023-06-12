macro map_dimensions(f, l...)
    # Create a new Dimensions object by applying f to each key
    output = :(Dimensions())
    for dim in DIMENSION_NAMES
        f_expr = :($f())
        for arg in l
            push!(f_expr.args, :($arg.$dim))
        end
        push!(output.args, f_expr)
    end
    return output |> esc
end
macro all_dimensions(f, l...)
    # Test a function over all dimensions
    output = Expr(:&&)
    for dim in DIMENSION_NAMES
        f_expr = :($f())
        for arg in l
            push!(f_expr.args, :($arg.$dim))
        end
        push!(output.args, f_expr)
    end
    return output |> esc
end

Base.float(q::Quantity{T}) where {T<:AbstractFloat} = convert(T, q)
Base.convert(::Type{T}, q::Quantity) where {T<:Real} =
    let
        @assert iszero(q.dimensions) "Quantity $(q) has dimensions! Use `ustrip` instead."
        return convert(T, q.value)
    end

Base.isfinite(q::Quantity) = isfinite(q.value)
Base.keys(::Dimensions) = DIMENSION_NAMES
Base.iszero(d::Dimensions) = @all_dimensions(iszero, d)
Base.iszero(q::Quantity) = iszero(q.value)
Base.getindex(d::Dimensions, k::Symbol) = getfield(d, k)
Base.:(==)(l::Dimensions, r::Dimensions) = @all_dimensions(==, l, r)
Base.:(==)(l::Quantity, r::Quantity) = l.value == r.value && l.dimensions == r.dimensions
Base.isapprox(l::Quantity, r::Quantity; kws...) = isapprox(l.value, r.value; kws...) && l.dimensions == r.dimensions
Base.length(::Dimensions) = 1
Base.length(::Quantity) = 1
Base.iterate(d::Dimensions) = (d, nothing)
Base.iterate(::Dimensions, ::Nothing) = nothing
Base.iterate(q::Quantity) = (q, nothing)
Base.iterate(::Quantity, ::Nothing) = nothing

Base.zero(::Type{Quantity{T,R}}) where {T,R} = Quantity(zero(T), R)
Base.one(::Type{Quantity{T,R}}) where {T,R} = Quantity(one(T), R)
Base.one(::Type{Dimensions{R}}) where {R} = Dimensions{R}()

Base.zero(::Type{Quantity{T}}) where {T} = zero(Quantity{T,DEFAULT_DIM_TYPE})
Base.one(::Type{Quantity{T}}) where {T} = one(Quantity{T,DEFAULT_DIM_TYPE})

Base.zero(::Type{Quantity}) = zero(Quantity{DEFAULT_VALUE_TYPE})
Base.one(::Type{Quantity}) = one(Quantity{DEFAULT_VALUE_TYPE})
Base.one(::Type{Dimensions}) = one(Dimensions{DEFAULT_DIM_TYPE})

Base.show(io::IO, d::Dimensions) =
    let tmp_io = IOBuffer()
        for k in keys(d)
            if !iszero(d[k])
                print(tmp_io, SYNONYM_MAPPING[k])
                isone(d[k]) || pretty_print_exponent(tmp_io, d[k])
                print(tmp_io, " ")
            end
        end
        s = String(take!(tmp_io))
        s = replace(s, r"^\s*" => "")
        s = replace(s, r"\s*$" => "")
        print(io, s)
    end
Base.show(io::IO, q::Quantity) = print(io, q.value, " ", q.dimensions)

string_rational(x) = isinteger(x) ? string(round(Int, x)) : string(x)
pretty_print_exponent(io::IO, x) = print(io, to_superscript(string_rational(x)))
const SUPERSCRIPT_MAPPING = ['⁰', '¹', '²', '³', '⁴', '⁵', '⁶', '⁷', '⁸', '⁹']
const INTCHARS = ['0' + i for i = 0:9]
to_superscript(s::AbstractString) = join(
    map(replace(replace(s, "-" => "⁻"), r"//" => "ᐟ")) do c
        c ∈ INTCHARS ? SUPERSCRIPT_MAPPING[parse(Int, c)+1] : c
    end
)

tryrationalize(::Type{R}, x::R) where {R} = x
tryrationalize(::Type{R}, x::Union{Rational,Integer}) where {R} = convert(R, x)
tryrationalize(::Type{R}, x) where {R} = isinteger(x) ? convert(R, round(Int, x)) : convert(R, rationalize(Int, x))

Base.showerror(io::IO, e::DimensionError) = print(io, "DimensionError: ", e.q1, " and ", e.q2, " have incompatible dimensions")

Base.convert(::Type{Quantity}, q::Quantity) = q
Base.convert(::Type{Quantity{T}}, q::Quantity) where {T} = Quantity(convert(T, q.value), dimension(q))
Base.convert(::Type{Quantity{T,R}}, q::Quantity) where {T,R} = Quantity(convert(T, q.value), convert(Dimensions{R}, dimension(q)))

Base.convert(::Type{Dimensions}, d::Dimensions) = d
Base.convert(::Type{Dimensions{R}}, d::Dimensions) where {R} = Dimensions{R}(d)

"""
    ustrip(q::Quantity)

Remove the units from a quantity.
"""
ustrip(q::Quantity) = q.value
ustrip(q::Number) = q

"""
    dimension(q::Quantity)

Get the dimensions of a quantity, returning a `Dimensions` object.
"""
dimension(q::Quantity) = q.dimensions
dimension(::Number) = Dimensions()

"""
    ulength(q::Quantity)
    ulength(d::Dimensions)

Get the length dimension of a quantity (e.g., meters^(ulength)).
"""
ulength(q::Quantity) = ulength(dimension(q))
ulength(d::Dimensions) = d.length

"""
    umass(q::Quantity)
    umass(d::Dimensions)

Get the mass dimension of a quantity (e.g., kg^(umass)).
"""
umass(q::Quantity) = umass(dimension(q))
umass(d::Dimensions) = d.mass

"""
    utime(q::Quantity)
    utime(d::Dimensions)

Get the time dimension of a quantity (e.g., s^(utime))
"""
utime(q::Quantity) = utime(dimension(q))
utime(d::Dimensions) = d.time

"""
    ucurrent(q::Quantity)
    ucurrent(d::Dimensions)

Get the current dimension of a quantity (e.g., A^(ucurrent)).
"""
ucurrent(q::Quantity) = ucurrent(dimension(q))
ucurrent(d::Dimensions) = d.current

"""
    utemperature(q::Quantity)
    utemperature(d::Dimensions)

Get the temperature dimension of a quantity (e.g., K^(utemperature)).
"""
utemperature(q::Quantity) = utemperature(dimension(q))
utemperature(d::Dimensions) = d.temperature

"""
    uluminosity(q::Quantity)
    uluminosity(d::Dimensions)

Get the luminosity dimension of a quantity (e.g., cd^(uluminosity)).
"""
uluminosity(q::Quantity) = uluminosity(dimension(q))
uluminosity(d::Dimensions) = d.luminosity

"""
    uamount(q::Quantity)
    uamount(d::Dimensions)

Get the amount dimension of a quantity (e.g., mol^(uamount)).
"""
uamount(q::Quantity) = uamount(dimension(q))
uamount(d::Dimensions) = d.amount
