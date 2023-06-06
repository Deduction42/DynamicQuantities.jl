using DynamicUnits
using Test

x = Quantity(0.2, length=1, mass=2.5)

@test ulength(x) === 1 // 1
@test umass(x) === 5 // 2
@test valid(x)
@test ustrip(x) === 0.2
@test dimensions(x) == Dimensions(length=1, mass=5 // 2)
@test typeof(x).parameters[1] == Float64

y = x^2

@test ulength(y) === 2 // 1
@test umass(y) === 5 // 1
@test ustrip(y) ≈ 0.04
@test valid(y)
@test typeof(y).parameters[1] == Float64

y = x + x

@test ulength(y) === 1 // 1
@test umass(y) === 5 // 2
@test ustrip(y) ≈ 0.4
@test valid(y)

y = x^2 + x

@test !valid(y)
@test string(x) == "0.2 𝐋^1 𝐌^(5//2)"
@test string(y) == "INVALID"

y = inv(x)

@test ulength(y) === -1 // 1
@test umass(y) === -5 // 2
@test ustrip(y) ≈ 5
@test valid(y)

y = x - x

@test iszero(x) === false
@test iszero(y) === true
@test iszero(y.dimensions) === false

y = x / x

@test iszero(x.dimensions) === false
@test iszero(y.dimensions) === true

y = Quantity(2 // 10, length=1, mass=5 // 2)

@test y ≈ x

y = Quantity(2 // 10, false, length=1, mass=5 // 2)

@test !(y ≈ x)

y = Quantity(2 // 10, length=1, mass=6 // 2)

@test !(y ≈ x)

y = Quantity(2 // 10, length=1, 𝐌=5 // 2)

@test y ≈ x

y = x * Inf

@test isfinite(x)
@test !isfinite(y)

y = x^2.1

@test ulength(y) === 1 * (21 // 10)
@test umass(y) == (5 // 2) * (21 // 10)
@test utime(y) == 0
@test ucurrent(y) == 0
@test utemperature(y) == 0
@test uluminosity(y) == 0
@test uamount(y) == 0
@test ustrip(y) ≈ 0.2^2.1
@test ustrip(y) === 0.2^(21 // 10)

X = randn(10)
uX = X .* Dimensions(length=2.5, luminosity=0.5)

@test eltype(uX) == Quantity{Float64}
@test typeof(sum(uX)) == Quantity{Float64}
@test sum(X) == ustrip(sum(uX))
@test dimensions(prod(uX)) == prod([Dimensions(length=2.5, luminosity=0.5) for i in 1:10])
@test dimensions(X[1]) == Dimensions()

z = Quantity(-52, length=1) * Dimensions(mass=2)
z2 = Dimensions(mass=2) * Quantity(-52, length=1)

@test typeof(z).parameters[1] <: Int
@test z == z2
@test ustrip(z) == -52
@test dimensions(z) == Dimensions(length=1, mass=2)
@test float(z / (z * -1 / 52)) ≈ ustrip(z)

@test 0.5 / Dimensions(length=1) == Quantity(0.5, length=-1)
