using Pumas
using CSV
using DataFrames
using LinearAlgebra

pkdata = CSV.read("drug2.csv")
pkdata[:dv] = pkdata[:DV]
data = read_pumas(pkdata, dvs = [:dv], id = :ID, time = :TIME, amt = :AMT, evid = :EVID,
                          cvs = [:WEIGHT, :SEX])

mdl2006 = @model begin
    @param begin
        TVCL ∈ RealDomain(lower=0.0001, upper=50.0, init=10.0)
        TVVC ∈ RealDomain(lower=0.0001, upper=100.0, init=10.0)
        TVKA ∈ RealDomain(lower=0.0001, upper=5.0, init=0.2)
        TVQ ∈ RealDomain(lower=0.0001, upper=50.0, init=10.0)
        TVVP ∈ RealDomain(lower=0.0001, upper=1000.0, init=100.0)
        EXP_WT ∈ RealDomain(lower=0.0001, upper=3, init=0.75)
        SEX_CL ∈ RealDomain(lower=0.0001, upper=2, init=1)
        Ω ∈ PDiagDomain(init=[0.1,0.1,0.1])
        #Ω ∈ Diagonal(init=[0.09,0.09,0.09])
        σ_prop ∈ RealDomain(lower=0.0001, init=0.1)
        σ_add ∈ RealDomain(lower=0.0001, init=0.1)
    end

    @random begin
        η ~ MvNormal(Ω)
    end

    @covariates WEIGHT SEX

    @pre begin
        CL = TVCL * exp(η[1]) * (WEIGHT/70)^EXP_WT * (SEX_CL^SEX)
        VC = TVVC * exp(η[2])
        KA = TVKA * exp(η[3])
        Q = TVQ
        VP = TVVP
    end

    @vars begin
        conc = Central / VC
    end
#
    @dynamics begin
        Depot'   = -KA*Depot
        Central' =  KA*Depot - (CL/VC)*Central - (Q/VC)*Central + (Q/VP)*Peri
        Peri' =  (Q/VC)*Central - (Q/VP)*Peri
    end
#
    #@dynamics ImmediateAbsorptionModel

    @derived begin
        dv ~ @. Normal(conc, sqrt(conc^2*σ_prop + σ_add))

    end
end

param = init_param(mdl2006)

fit_2006=nothing
@time fit_2006 = fit(mdl2006, data, param, Pumas.FOCEI())
@time inf_2006 = infer(fit_2006)
