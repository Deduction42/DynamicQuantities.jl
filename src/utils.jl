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
        @assert q.valid "Quantity $(q) is invalid!"
        @assert iszero(q.dimensions) "Quantity $(q) has dimensions! Use `ustrip` instead."
        return convert(T, q.value)
    end

Base.isfinite(q::Quantity) = isfinite(q.value)
Base.keys(::Dimensions) = DIMENSION_NAMES
Base.iszero(d::Dimensions) = @all_dimensions(iszero, d)
Base.iszero(q::Quantity) = iszero(q.value)
Base.getindex(d::Dimensions, k::Symbol) = getfield(d, k)
Base.:(==)(l::Dimensions, r::Dimensions) = @all_dimensions(==, l, r)
Base.:(==)(l::Quantity, r::Quantity) = l.value == r.value && l.dimensions == r.dimensions && l.valid == r.valid
Base.:(≈)(l::Quantity, r::Quantity) = l.value ≈ r.value && l.dimensions == r.dimensions && l.valid == r.valid
Base.length(::Dimensions) = 1
Base.length(::Quantity) = 1
Base.iterate(d::Dimensions) = (d, nothing)
Base.iterate(::Dimensions, ::Nothing) = nothing
Base.iterate(q::Quantity) = (q, nothing)
Base.iterate(::Quantity, ::Nothing) = nothing

Base.show(io::IO, d::Dimensions) =
    let tmp_io = IOBuffer()
        for k in keys(d)
            if !iszero(d[k])
                print(tmp_io, SYNONYM_MAPPING[k])
                pretty_print_exponent(tmp_io, d[k])
                print(tmp_io, " ")
            end
        end
        s = String(take!(tmp_io))
        s = replace(s, r"^\s*" => "")
        s = replace(s, r"\s*$" => "")
        print(io, s)
    end
Base.show(io::IO, q::Quantity) = q.valid ? print(io, q.value, " ", q.dimensions) : print(io, "INVALID")

string_rational(x::Rational) = isinteger(x) ? string(x.num) : string(x)
string_rational(x::SimpleRatio) = string_rational(x.num // x.den)
pretty_print_exponent(io::IO, x::R) =
    let
        print(io, " ", to_superscript(string_rational(x)))
    end
const SUPERSCRIPT_MAPPING = ['⁰', '¹', '²', '³', '⁴', '⁵', '⁶', '⁷', '⁸', '⁹']
const INTCHARS = ['0' + i for i = 0:9]
to_superscript(s::AbstractString) = join(
    map(replace(replace(s, "-" => "⁻"), r"//" => "ᐟ")) do c
        c ∈ INTCHARS ? SUPERSCRIPT_MAPPING[parse(Int, c)+1] : c
    end
)

tryrationalize(::Type{<:Integer}, x::R) = x
tryrationalize(::Type{<:Integer}, x::Rational) = R(x)
tryrationalize(::Type{<:Integer}, x::Integer) = R(x)
tryrationalize(::Type{<:Integer}, x) = simple_ratio_rationalize(x)
simple_ratio_rationalize(x::R) = x
simple_ratio_rationalize(x::Rational{Int}) = R(x)
simple_ratio_rationalize(x) = isinteger(x) ? R(round(Int, x)) : R(rationalize(Int, x))

ustrip(q::Quantity) = q.value
ustrip(q::Number) = q
dimension(q::Quantity) = q.dimensions
dimension(::Number) = Dimensions()
valid(q::Quantity) = q.valid

ulength(q::Quantity) = q.dimensions.length
umass(q::Quantity) = q.dimensions.mass
utime(q::Quantity) = q.dimensions.time
ucurrent(q::Quantity) = q.dimensions.current
utemperature(q::Quantity) = q.dimensions.temperature
uluminosity(q::Quantity) = q.dimensions.luminosity
uamount(q::Quantity) = q.dimensions.amount
