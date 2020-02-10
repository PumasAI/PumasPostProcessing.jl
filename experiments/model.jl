# setup code
using Pumas, LinearAlgebra, Random
Random.seed!(1)

model = @model begin
  @param   begin
    tvcl ∈ RealDomain(lower=0)
    tvv ∈ RealDomain(lower=0)
    pmoncl ∈ RealDomain(lower = -0.99)
    Ω ∈ PDiagDomain(2)
    σ_prop ∈ RealDomain(lower=0)
  end

  @random begin
    η ~ MvNormal(Ω)
  end

  @covariates wt isPM

  @pre begin
    CL = tvcl * (1 + pmoncl*isPM) * (wt/70)^0.75 * exp(η[1])
    V  = tvv * (wt/70) * exp(η[2])
  end

  @dynamics Central1
    #@dynamics begin
    #    Central' =  - (CL/V)*Central
    #end

  @derived begin
      cp = @. 1000*(Central / V)
      dv ~ @. Normal(cp, sqrt(cp^2*σ_prop))
    end
end
ev = DosageRegimen(100, time=0, addl=4, ii=24)
s1 = Subject(id=1,  evs=ev, cvs=(isPM=1, wt=70))
param = (
  tvcl = 4.0,
  tvv  = 70,
  pmoncl = -0.7,
  Ω = Diagonal([0.09,0.09]),
  σ_prop = 0.04
  )
obs = simobs(model, s1, param, obstimes=0:1:120)
# plot(obs)
choose_covariates() = (isPM = rand([1, 0]),
              wt = rand(55:80))
pop_with_covariates = Population(map(i -> Subject(id=i, evs=ev, cvs=choose_covariates()),1:10))
obs = simobs(model, pop_with_covariates, param, obstimes=0:1:120)
# plot(obs)
simdf = DataFrame(obs)
simdf.cmt .= 1
first(simdf, 6)
data = read_pumas(simdf, time=:time,cvs=[:isPM, :wt])

res = fit(model,data,param,Pumas.FOCEI())
