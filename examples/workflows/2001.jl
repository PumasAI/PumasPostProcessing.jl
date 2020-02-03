using Pumas
using CSV
using DataFrames
using LinearAlgebra

pkdata = CSV.read("drug2.csv")
pkdata[:dv] = pkdata[:DV]
data = read_pumas(pkdata, dvs = [:dv], id = :ID, time = :TIME, amt = :AMT, evid = :EVID,
                          cvs = [:WEIGHT, :SEX])

mdl2001 = @model begin
    @param begin
        TVCL ∈ RealDomain(lower=0.0001, upper=50.0, init=10.0)
        TVVC ∈ RealDomain(lower=0.0001, upper=100.0, init=10.0)
        TVKA ∈ RealDomain(lower=0.0001, upper=5.0, init=0.2)
        Ω ∈ PDiagDomain(init=[0.1,0.1,0.1])
        #Ω ∈ Diagonal(init=[0.09,0.09,0.09])
        σ_prop ∈ RealDomain(lower=0.0001, init=0.1)
    end

    @random begin
        η ~ MvNormal(Ω)
    end

    #@covariates WEIGHT SEX

    @pre begin
        CL = TVCL * exp(η[1]) #* ((WEIGHT/70)^EXP_WT) * (COV_SEX^SEX)
        V = TVVC * exp(η[2])
        KA = TVKA * exp(η[3])
    end

    @vars begin
        conc = Central / V
    end
=
    @dynamics begin
        Depot'   = -KA*Depot
        Central' =  KA*Depot - (CL/V)*Central
    end
#
    #@dynamics ImmediateAbsorptionModel

    @derived begin
        dv ~ @. Normal(conc, sqrt(conc^2*σ_prop))

    end
end

param = init_param(mdl2001)

fit_2001=nothing
@time fit_2001 = fit(mdl2001, data, param, Pumas.FOCEI())
@time inf_2001 = infer(fit_2001)
