abstract type BerthelotModel <: vdWModel end

struct BerthelotParam <: EoSParam
    a::PairParam{Float64}
    b::PairParam{Float64}
    Tc::SingleParam{Float64}
    Pc::SingleParam{Float64}
    Vc::SingleParam{Float64}
    Mw::SingleParam{Float64}
end

struct Berthelot{T <: IdealModel,α,c,M} <: BerthelotModel
    components::Array{String,1}
    icomponents::UnitRange{Int}
    alpha::α
    mixing::M
    translation::c
    params::BerthelotParam
    idealmodel::T
    references::Array{String,1}
end

@registermodel Berthelot
export Berthelot

"""
    Berthelot(components::Vector{String};
    idealmodel=BasicIdeal,
    alpha = NoAlpha,
    mixing = vdW1fRule,
    activity=nothing,
    translation=NoTranslation,
    userlocations=String[], 
    ideal_userlocations=String[],
    alpha_userlocations = String[],
    mixing_userlocations = String[],
    activity_userlocations = String[],
    translation_userlocations = String[],
    verbose=false)

## Input parameters
- `Tc`: Single Parameter (`Float64`) - Critical Temperature `[K]`
- `Pc`: Single Parameter (`Float64`) - Critical Pressure `[Pa]`
- `Mw`: Single Parameter (`Float64`) - Molecular Weight `[g/mol]`
- `vc`: Single Parameter (`Float64`) - Molar Volume `[m^3/mol]`
- `k`: Pair Parameter (`Float64`)

## Model Parameters
- `a`: Pair Parameter (`Float64`)
- `b`: Pair Parameter (`Float64`)
- `Tc`: Single Parameter (`Float64`) - Critical Temperature `[K]`
- `Pc`: Single Parameter (`Float64`) - Critical Pressure `[Pa]`
- `Vc`: Single Parameter (`Float64`) - Molar Volume `[m^3/mol]`
- `Mw`: Single Parameter (`Float64`) - Molecular Weight `[g/mol]`


## Input models
- `idealmodel`: Ideal Model
- `alpha`: Alpha model
- `mixing`: Mixing model
- `activity`: Activity Model, used in the creation of the mixing model.
- `translation`: Translation Model

## Description

Berthelot Equation of state.

```
a = 8*Pc*Vc^2
b = Vc/3
P = RT/(V-Nb) + a•α(T)/V²
```

## References

1. Berthelot, D. (1899). Sur une méthode purement physique pour la détermination des poids moléculaires des gaz et des poids atomiques de leurs éléments. Journal de Physique Théorique et Appliquée, 8(1), 263–274. doi:10.1051/jphystap:018990080026300

"""
Berthelot

function Berthelot(components::Vector{String}; idealmodel=BasicIdeal,
    alpha = ClausiusAlpha,
    mixing = vdW1fRule,
    activity=nothing,
    translation=NoTranslation,
    userlocations=String[], 
    ideal_userlocations=String[],
    alpha_userlocations = String[],
    mixing_userlocations = String[],
    activity_userlocations = String[],
    translation_userlocations = String[],
    verbose=false)
    params = getparams(components, ["properties/critical.csv", "properties/molarmass.csv","SAFT/PCSAFT/PCSAFT_unlike.csv"]; userlocations=userlocations, verbose=verbose)
    k  = params["k"]
    pc = params["pc"]
    Mw = params["Mw"]
    Tc = params["Tc"]
    Vc = params["vc"]
    init_mixing = init_model(mixing,components,activity,mixing_userlocations,activity_userlocations,verbose)
    a,b = ab_premixing(Berthelot,init_mixing,Tc,pc,Vc,k)
    init_idealmodel = init_model(idealmodel,components,ideal_userlocations,verbose)
    init_translation = init_model(translation,components,translation_userlocations,verbose)
    init_alpha = init_model(alpha,components,alpha_userlocations,verbose)
    icomponents = 1:length(components)
    packagedparams = BerthelotParam(a,b,Tc,pc,Vc,Mw)
    references = String["10.1051/jphystap:018990080026300"]
    model = Berthelot(components,icomponents,init_alpha,init_mixing,init_translation,packagedparams,init_idealmodel,references)
    return model
end

function ab_premixing(model::Type{<:BerthelotModel},mixing::MixingRule,Tc,pc,vc,kij)
    _Vc = vc.values
    _pc = pc.values
    @show _Vc
    components = vc.components
    a = epsilon_LorentzBerthelot(SingleParam("a",components, @. 3*_pc*_Vc*_Vc),kij)
    b = sigma_LorentzBerthelot(SingleParam("b",components, @. _Vc/3))
    return a,b
end

function pure_cubic_zc(model::BerthelotModel)
    return only(model.params.Pc.values)*only(model.params.Vc.values)/(R̄*only(model.params.Tc.values))
end

function a_res(model::BerthelotModel, V, T, z,_data = data(model,V,T,z))
    n,ā,b̄,c̄ = _data
    Vc = 3*b̄
    pcvc = ā*T/3/Vc
    R = (8/3)*pcvc
    #R = R̄
    RT⁻¹ = 1/(R*T)
    ρt = (V/n+c̄)^(-1) # translated density
    ρ  = n/V
    return -log(1+(c̄-b̄)*ρ) - ā*ρt*RT⁻¹
    #
    #return -log(V-n*b̄) - ā*n/(R̄*T*V) + log(V)
end   

function x0_crit_pure(model::CubicModel)
    lb_v = lb_volume(model)
    (1.0, log10(lb_v/0.3))
end