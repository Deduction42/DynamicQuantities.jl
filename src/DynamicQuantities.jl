module DynamicQuantities

export Units, Constants
export AbstractQuantity, AbstractDimensions
export Quantity, Dimensions, DimensionError, ustrip, dimension, valid
export ulength, umass, utime, ucurrent, utemperature, uluminosity, uamount
export uparse, @u_str

include("fixed_rational.jl")
include("types.jl")
include("utils.jl")
include("math.jl")
include("units.jl")
include("constants.jl")
include("uparse.jl")

import Requires: @init, @require
import .Constants: Constants
import .UnitsParse: uparse, @u_str

if !isdefined(Base, :get_extension)
    @init @require Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d" include("../ext/DynamicQuantitiesUnitfulExt.jl")
end

end
