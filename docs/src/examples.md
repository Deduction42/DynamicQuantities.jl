# Toy Examples with Code

```julia
using DynamicQuantities
```

## 1. Solving a Chemistry Homework Problem

On your chemistry homework, you are faced with the following problem on the photoelectric effect[^1]:

[^1]: Attribution: [MIT OCW](https://ocw.mit.edu/courses/5-111sc-principles-of-chemical-science-fall-2014/resources/mit5_111f14_lec04soln/)

> In a photoelectric effect experiment, electrons are ejected from a titanium surface (work function ``\Phi = 4.33\mathrm{eV}``) following irradition with UV light.
> The energy of the incident UV light is ``7.2 \cdot 10^{-19} \mathrm{J}`` per photon. Calculate the wavelength of the ejected electrons, in nanometers.

Let's solve this problem with `DynamicQuantities.jl`!
```@repl
using DynamicQuantities
using DynamicQuantities.Constants: h, c, m_e
Φ = 4.33u"Constants.eV" # work function
E = 7.2e-19u"J" # incident energy
p = sqrt(2 * m_e * (E - Φ)) # momentum of ejected electrons
λ = h / p # wavelength of ejected electrons
as_units(λ, us"nm") # return answer in nanometers
```
Since units are automatically propagated, we can verify the dimension of our answer and all intermediates.
Also, using `DynamicQuantities.Constants`, we were able to obtain the (dimensionful!) values of all necessary constants without typing them ourselves.

