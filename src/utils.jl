Base.float(q::Quantity{T}) where {T<:AbstractFloat} = convert(T, q)
Base.convert(::Type{T}, q::Quantity) where {T<:Real} =
    let
        @assert q.valid "Quantity $(q) is invalid!"
        @assert iszero(q.dimensions) "Quantity $(q) has dimensions!"
        return convert(T, q.value)
    end

Base.isfinite(q::Quantity) = isfinite(q.value)
Base.keys(d::Dimensions) = keys(d.data)
Base.values(d::Dimensions) = values(d.data)
Base.iszero(d::Dimensions) = all(iszero, values(d))
Base.getindex(d::Dimensions, k::Int) = d.data[k]
Base.getindex(d::Dimensions, k::Symbol) =
    let
        if k in VALID_KEYS
            return d.data[k]
        elseif k in VALID_SYNONYMS
            return d.data[SYNONYM_MAPPING[k]]
        else
            throw(error("$k is not a valid property of Dimensions."))
        end
    end
Base.getproperty(q::Quantity, k::Symbol) =
    let
        if k == :value
            return getfield(q, :value)
        elseif k == :dimensions
            return getfield(q, :dimensions)
        elseif k == :valid
            return getfield(q, :valid)
        elseif k in VALID_KWARGS
            return getfield(q, :dimensions)[k]
        else
            throw(error("$k is not a valid property of Quantity."))
        end
    end
Base.:(==)(l::Dimensions, r::Dimensions) = all(k -> (l[k] == r[k]), keys(l))
Base.:(==)(l::Quantity, r::Quantity) = l.value == r.value && l.dimensions == r.dimensions && l.valid == r.valid

Base.show(io::IO, d::Dimensions) =
    foreach(keys(d)) do k
        if !iszero(d[k])
            print(io, k)
            pretty_print_exponent(io, d[k])
            print(io, " ")
        end
    end
Base.show(io::IO, q::Quantity) = q.valid ? print(io, q.value, " ", q.dimensions) : print(io, "INVALID")

tryround(x::Rational{Int}) = isinteger(x) ? round(Int, x) : x
pretty_print_exponent(io::IO, x::Rational{Int}) =
    let
        if x >= 0 && isinteger(x)
            print(io, "^", round(Int, x))
        else
            print(io, "^(", tryround(x), ")")
        end
    end
@inline tryrationalize(::Type{T}, x::Rational{T}) where {T<:Integer} = x
@inline tryrationalize(::Type{T}, x::T) where {T<:Integer} = Rational{T}(x)
@inline tryrationalize(::Type{T}, x) where {T<:Integer} = rationalize(T, x)
