#aproximates liquid volume at a known pressure and t,
#by using isothermal compressibility


"""
    volume_compress(model,p,T,z=SA[1.0];V0=x0_volume(model,p,T,z,phase=:liquid),max_iters=100)

Main routine to calculate a volume, given a pressure, temperature, composition and intitial volume guess. each step is taken by locally aproximating the EoS as an isothermal compressibility process.
The new volume is calculated by the following recurrence formula:

```julia
v[i+1] = v[i]*exp(β[i]*(p-p(v[i])))
```

In the liquid root region, the iterations follow `v0 < v[i] < v[i+1] < v(p)`, allowing the calculation of the liquid root without entering the metastable region.
"""
function volume_compress(model,p,T,z=SA[1.0];V0=x0_volume(model,p,T,z,phase=:liquid),max_iters=100)
    p,T,V0 = promote(p,T,V0)
    return _volume_compress(model,p,T,z,V0,max_iters)
end

function _volume_compress(model,p,T,z=SA[1.0],V0=x0_volume(model,p,T,z,phase=:liquid),max_iters=100)
    _0 = zero(p+T+first(z))
    _nan = _0/_0
    logV0 = log(V0)
    lb_v = lb_volume(model,z)
    function logstep(_V)
        _V < log(lb_v) && return zero(_V)/zero(_V)
        _V = exp(_V)
        _p,dpdV = p∂p∂V(model,_V,T,z)
        abs(_p-p) < 3eps(p) && return zero(_V)
        _Δ = (p-_p)/(_V*dpdV)
        return _Δ
    end
    q = 0.1 #change to 0 to use vanilla iteration
    function f_fixpoint(_V)
        Δ = logstep(_V)
        _1 = one(Δ)
        Δᵣ = ifelse(abs(Δ) < q,abs(Δ)^Δ,_1)
        vv = _V + Δ*Δᵣ #damping
        return vv
    end
    res = @nan(Solvers.fixpoint(f_fixpoint,logV0,Solvers.SSFixPoint(),rtol = 1e-12,max_iters=max_iters),_nan)
    return exp(res)
end

"""
    volume_virial(model::EoSModel,p,T,z=SA[1.0])
    volume_virial(B::Real,p,T,z=SA[1.0])

Calculates an aproximation to the gas volume at specified pressure, volume and composition, by aproximating:

```julia

Z(v) ≈ 1 + B(T)/v 
```
where `Z` is the compressibility factor and `B` is the second virial coefficient.
If `B>0`, (over the inversion temperature) returns `NaN`. If the solution to the problem is complex (`Z = 1 + B/v` implies solving a quadratic polynomial), returns `-2*B`.

If you pass an `EoSModel` as the first argument, `B` will be calculated from the EoS at the input `T`. You can provide your own second virial coefficient instead of a model.

"""
function volume_virial end

function volume_virial(model::EoSModel,p,T,z=SA[1.0])
    B = second_virial_coefficient(model,T,z)
    return volume_virial(B,p,T,z)
end

function volume_virial(B::Real,p,T,z=SA[1.0])
    _0 = zero(B)
    B > _0 && return _0/_0
    a = p/(R̄*T)
    b = -1
    c = -B
    Δ = b*b-4*a*c
    n = sum(z)
    if Δ <= 0
        #virial approximation could not be calculated
        #return value at spinodal
        return -2*B
    end
    #only the left root has physical meaning
    return (-b + sqrt(b*b-4*a*c))/(2*a)
end

#(z = pV/RT)
#(RT/p = V/z)
"""
    volume(model::EoSModel,p,T,z=SA[1.0];phase=:unknown,threaded=true)

calculates the volume (m³) of the compound modelled by `model` at a certain pressure,temperature and moles.

`phase` is a Symbol that determines the initial volume root to look for:

- If `phase =:liquid` it will return the volume of the phase using a liquid initial point.

- If `phase =:vapor` it will return the volume of the phase using a gas initial point.

The default is `phase =:unknown`. with this, both liquid and volume roots will be calculated, and 
the phase with the least amount of energy is returned.

The calculation of both volume roots can be calculated in serial (`threaded=false`) or in parallel (`threaded=true`)

"""
function volume(model::EoSModel,p,T,z=SA[1.0];phase=:unknown,threaded=true)
    return _volume(model,p,T,z,phase,threaded)
end

function _volume(model::EoSModel,p,T,z=SA[1.0],phase=:unknown,threaded=true)
#Threaded version
    TYPE = typeof(p+T+first(z))
    if phase != :unknown
        V0 = x0_volume(model,p,T,z,phase=phase)
        return _volume_compress(model,p,T,z,V0)
    end
    if threaded     
        Vg0 = x0_volume(model,p,T,z,phase=:v)
        Vl0 = x0_volume(model,p,T,z,phase=:l)
        _Vg = Threads.@spawn _volume_compress(model,$p,$T,$z,$Vg0)
        _Vl = Threads.@spawn _volume_compress(model,$p,$T,$z,$Vl0)
         Vg::TYPE = fetch(_Vg)     
         Vl::TYPE = fetch(_Vl)
    else
        Vg0 = x0_volume(model,p,T,z,phase=:v)
        Vl0 = x0_volume(model,p,T,z,phase=:l)
       
        Vg =  _volume_compress(model,p,T,z,Vg0)
        Vl =  _volume_compress(model,p,T,z,Vl0)        
    end

    #this catches the supercritical phase as well
    
    isnan(Vl) && return Vg
    isnan(Vg) && return Vl

   err() = @error("model $model Failed to converge to a volume root at pressure p = $p [Pa], T = $T [K] and compositions = $z")
    if (isnan(Vl) & isnan(Vg))
        err()
        return zero(TYPE)/zero(TYPE)
    end 
    _dfg,fg =  ∂f(model,Vg,T,z)
    dVg,_ = _dfg
    gg = ifelse(abs((p+dVg)/p) > 0.03,zero(dVg)/one(dVg),fg + p*Vg)
    _dfl,fl =  ∂f(model,Vl,T,z)
    dVl,_ = _dfl
    gl = ifelse(abs((p+dVl)/p) > 0.03,zero(dVl)/one(dVl),fl + p*Vl)
    
    if gg<gl
        return Vg
    else
        return Vl
    end
end

export volume

function crit_volume(model)
    f,_ = x0_crit_pure(model)
    T0 = 1.5*f*T_scale(model)
    B = second_virial_coefficient(model,T0)
    v0 = -B
    Px(_v) = pressure(model,_v,T0)
    p,dp,d2p = Solvers.f∂f∂2f(Px,v0)
    #p- p0 = dp(v-v0) + d2p(v-v0)2
    #Δp = dpΔv + ddpΔv^2/2
    #Δp = Δv(dp + ddp/2 Δv)
    #Δp = 0 -> Δv(dp + ddp/2 Δv) =0 #-> dp + ddp/2 Δv = 0 -> -2*dp/ddp
    #pi = p0 + dp0(v-v0) + d2p(v-v0)^2
    #
    Δv = -2*dp/d2p
    for i in 1:20
    v0 = v0 + Δv
    @show d2p
    p,dp,d2p = Solvers.f∂f∂2f(Px,v0)
    Δv = -2*dp/d2p
    end
    return v0,Δv
end
#
#∂logstep\dV = [dpdv(P-P0) + d2pdv2*V(P - P0)]/[dpdv*V]^2 < 1
#∂logstep\dV = [(P-P0)(dpdv + V*d2pdv2)]/[dpdv*V]^2 < 1

#case 1: P > P0 -> v < v0

