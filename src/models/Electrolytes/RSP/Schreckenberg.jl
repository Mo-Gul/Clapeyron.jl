abstract type SchreckenbergModel <: RSPModel end

struct SchreckenbergParam <: EoSParam
    d_T::SingleParam{Float64}
    d_V::SingleParam{Float64}
end

struct Schreckenberg <: SchreckenbergModel
    components::Array{String,1}
    solvents::Union{Array{String,1},Array{Any,1}}
    salts::Array{String,1}
    isolvents::UnitRange{Int}
    isalts::UnitRange{Int}
    stoic_coeff::Array{Float64}
    params::SchreckenbergParam
    absolutetolerance::Float64
    references::Array{String,1}
end

@registermodel Schreckenberg
export Schreckenberg
function Schreckenberg(solvents,salts; userlocations::Vector{String}=String[], verbose::Bool=false)
    ion_groups = GroupParam(salts, ["Electrolytes/properties/salts.csv"]; verbose=verbose)

    salts = ion_groups.components
    stoichiometric_coeff = zeros(length(ion_groups.components),length(ion_groups.flattenedgroups))
    for i in 1:length(salts)
        stoichiometric_coeff[i,:] = ion_groups.n_flattenedgroups[i]
    end

    if isempty(solvents)
        components=deepcopy(salts)
    else
        components = cat(solvents,salts,dims=1)
    end
    
    isolvents = 1:length(solvents)
    isalts = (length(solvents)+1):length(components)

    params = getparams(components, ["Electrolytes/RSP/Schreckenberg.csv"]; userlocations=userlocations, verbose=verbose)
    d_T = params["d_T"]
    d_V = params["d_V"]
    packagedparams = SchreckenbergParam(d_T,d_V)

    references = String[]
    
    model = Schreckenberg(components, solvents, salts, isolvents, isalts, stoichiometric_coeff, packagedparams, 1e-12,references)
    return model
end

function dielectric_constant(model::SchreckenbergModel,V,T,z,_data=nothing)
        z_s = FractionSalt(model,z)
        d_T = model.params.d_T.values
        d_V = model.params.d_V.values
        #d = @. d_V*(d_T/T-1)
        #d = (d .+d')/2
        #x0 = z_s ./ n_solv
        #d̄ = sum(sum(x0[i]*x0[j]*d[i,j] for j ∈ comps) for i ∈ comps)

        n_solv = sum(z_s)
        ρ_solv = n_solv / V
        d̄ = zero(T+first(z_s))

        for i in 1:length(model)
            di = d_V[i]*(d_T[i]/T-1)
            dij,zi = di,z_s[i]
            d̄ += dij*zi*zi
            for j in 1:(j-1)
                dj = d_V[j]*(d_T[j]/T-1)
                dij,zj = 0.5*(di+dj),z_s[j]
                d̄ += 2*dij*zi*zj
            end
        end

    d̄ = d̄/(n_solv*n_solv)
    return 1+ρ_solv*d̄
end

is_splittable(::Schreckenberg) = false