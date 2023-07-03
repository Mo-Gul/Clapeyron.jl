struct CPLNGEstIdealParam <: EoSParam
    coeffs::SingleParam{NTuple{4,Float64}}
    Mw::SingleParam{Float64}
end

@newmodelsimple CPLNGEstIdeal ReidIdealModel CPLNGEstIdealParam

"""
    CPLNGEstIdeal <: ReidIdealModel
    CPLNGEstIdeal(components; 
    userlocations::Array{String,1}=String[], 
    verbose=false)

## Input parameters

- `Mw`: Single Parameter (`Float64`) - Molecular Weight `[g/mol]`

## Model parameters

- `Mw`: Single Parameter (`Float64`) - Molecular Weight `[g/mol]`
- `coeffs`: Single Parameter (`NTuple{4,Float64}`) - polynomial coefficients

## Description

Estimation of Reid polynomial, using the molecular weight as input:

```
Cpᵢ(T) = aᵢ  + bᵢT + cᵢT^2 + dᵢT^3
Cp(T) = ∑Cpᵢxᵢ
a = -10.9602   * γ₀ + 25.9033
b = 2.1517e-1  * γ₀ - 6.8687e-2 
c = -1.3337e-4 * γ₀ + 8.6387e-5
d = 3.1474e-8  * γ₀ -2.8396e-8
γ₀ = Mw/Mw(air)
```

## References
1. Kareem, L. A., Iwalewa, T. M., & Omeke, J. E. (2014). Isobaric specific heat capacity of natural gas as a function of specific gravity, pressure and temperature. Journal of Natural Gas Science and Engineering, 19, 74–83. [doi:10.1016/j.jngse.2014.04.011]("http://doi.org/10.1016/j.jngse.2014.04.011")
"""
CPLNGEstIdeal

function CPLNGEstIdeal(components::Array{String,1}; userlocations=String[], verbose=false)
    params = getparams(components, ["properties/molarmass.csv"]; userlocations=userlocations, verbose=verbose)
    Mw = params["Mw"]   
    γ₀ = Mw ./ 28.9647
    a = -10.9602   .* γ₀ .+ 25.9033
    b = 2.1517e-1  .* γ₀ .- 6.8687e-2 
    c = -1.3337e-4 .* γ₀ .+ 8.6387e-5
    d = 3.1474e-8  .* γ₀ .- 2.8396e-8
    reid = ReidIdealParam(a,b,c,d,components)
    packagedparams = CPLNGEstIdealParam(reid.coeffs,Mw)
    references = String["10.1016/j.jngse.2014.04.011"]
    return CPLNGEstIdeal(packagedparams; references=references)
end

export CPLNGEstIdeal

#=
a1 = CPLNGEstIdeal(["a1"],userlocations = (;Mw = [20.5200706797]))

=#