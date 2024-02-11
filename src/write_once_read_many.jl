"""
    WriteOnceReadMany()

Used for storing units, values, symbolic-units.
"""
struct WriteOnceReadMany{V}
    _raw_data::V

    WriteOnceReadMany(_raw_data) = new{typeof(_raw_data)}(_raw_data)
    WriteOnceReadMany{T}() where T = WriteOnceReadMany(T())
end

# Utility functions
for f in (:enumerate, :length, :lastindex)
    @eval begin
        Base.$f(w::WriteOnceReadMany) = $f(w._raw_data)
    end
end

Base.getindex(w::WriteOnceReadMany, i::Union{Integer,Symbol}) = getindex(w._raw_data, i)
Base.get(w::WriteOnceReadMany{<:Dict}, a, b) = get(w._raw_data, a, b)

# Only define setindex! for Dicts, and throw an error if the key already exists
function Base.setindex!(w::DynamicQuantities.WriteOnceReadMany{<:Dict}, i, s::Symbol)
    haskey(w._raw_data, s) && throw("Unit $s already exists at index $(w[s])")
    setindex!(w._raw_data, i, s)
end

Base.iterate(w::WriteOnceReadMany) = iterate(w._raw_data)
Base.iterate(w::WriteOnceReadMany, i::Int) = iterate(w._raw_data, i)

Base.intersect(w::WriteOnceReadMany, v::AbstractSet) = intersect(w._raw_data, v)
Base.intersect(v::AbstractSet, w::WriteOnceReadMany) = intersect(v, w._raw_data)

Base.push!(w::WriteOnceReadMany, val...) = push!(w._raw_data, val...)

for f in (:findfirst, :filter)
    @eval begin
        Base.$f(val::Function, w::WriteOnceReadMany) = $f(val, w._raw_data)
    end
end

