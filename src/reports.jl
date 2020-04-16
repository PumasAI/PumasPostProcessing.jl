using Markdown
using Pumas
using Pumas: FittedPumasModel
using PumasPlots
# Parameter estimate table

"""
    param_table(
        inf::FittedPumasModel[Inference];
        descriptions = [],
        ignores = Symbol[],
        align = [:c, :l, :l, :l],
        formatter = x -> round(x; sigdigits = 5)
    )

Outputs a table containing parameter names, estimates, RSEs,
and confidence intervals.
Optionally, a description of each parameter may also be included,
by passing a Vector of strings to the `descriptions` keyword argument.

An example table looks like this:
```
Parameter Estimate RSE       95% confidence interval
––––––––– –––––––– ––––––––– –––––––––––––––––––––––
  tvcl    4.0811   0.39958   (3.298, 4.8643)
   tvv    63.252   4.4496    (54.531, 71.973)
 pmoncl   -0.67819 0.06144   (-0.79862, -0.55777)
  Ω₁,₁    0.076234 0.02888   (0.019631, 0.13284)
  Ω₂,₂    0.048226 0.021427  (0.0062306, 0.090222)
 σ_prop   0.040753 0.0012053 (0.038391, 0.043116)
 ```
"""
function param_table(
        inference::Pumas.FittedPumasModelInference;
        descriptions = [],
        ignores = Symbol[],
        align = isempty(descriptions) ? [:c, :l, :l, :l] : [:c, :l, :l, :l, :l],
        formatter = x -> round(x; sigdigits = 5)
    )

    # Extract std errors
    standard_errors = stderror(inference)

    # Initialize some storage arrays for data
    paramnames = []
    paramvals = []
    paramrse = []
    paramconfint = []

    # Create the quantile
    quant = quantile(Normal(), inference.level + (1.0 - inference.level)/2)

    # Populate the storage arrays
    for (paramname, paramval) in pairs(coef(inference.fpm))
        std = standard_errors[paramname]
        Pumas._push_varinfo!(paramnames, paramvals, paramrse, paramconfint, paramname, paramval, std, quant)
    end

    isempty(descriptions) || @assert length(descriptions) == length(paramnames)

    rows = if isempty(descriptions)
        zip(paramnames, formatter.(paramvals), formatter.(paramrse), map(x -> formatter.(x), paramconfint))
    else
        zip(paramnames, descriptions, formatter.(paramvals), formatter.(paramrse), map(x -> formatter.(x), paramconfint))
    end .|> x -> [x...]

    # Push the headers
    if isempty(descriptions)
        pushfirst!(rows, ["Parameter", "Estimate", "RSE", "95% confidence interval"])
    else
        pushfirst!(rows, ["Parameter", "Description", "Estimate", "RSE", "95% confidence interval"])
    end

    # Materialize a Markdown table, and return it as an MD node.
    return Markdown.MD(Markdown.Table(rows, align))
end

param_table(fpm::Pumas.FittedPumasModel; kwargs...) = param_table(infer(fpm); kwargs...)

function optim_meta(res::Pumas.FittedPumasModel)
    return (iterations = res.optim.iterations, time_run = res.optim.time_run, ofv = res.optim.minimum)
end

"""
    optim_meta_table(fpm::FittedPumasModel; align = [:l, :c])

Outputs a table containing basic optimization metadata - the number of iterations, the time run, and the objective function value.

An example table looks like this:
```
Metric                                     Value
––––––––––––––––––––––––––––––––––– –––––––––––––––––––
Successful minimization                    true
Likelihood approximation                Pumas.FOCEI
Deviance                                 14234.502
Total number of observation records        1210
Number of actve observation records        1210
Number of subjects                          10
Iterations                                  10
Time run                            0.29492616653442383
Objective function value             8229.16686381138  
```
"""
function optim_meta_table(fpm::Pumas.FittedPumasModel; align = [:l, :c])
    iterations, time_run, ofv = optim_meta(fpm)
    approx = typeof(fpm.approx)
    deviance = round(Pumas.deviance(fpm); sigdigits=round(Int, -log10(Pumas.DEFAULT_ESTIMATION_RELTOL)))
    total_records = sum((length(sub.time) for sub in fpm.data))
    active_records = sum(subject -> sum(name -> count(!ismissing, subject.observations[name]), keys(first(fpm.data).observations)), fpm.data)

    return Markdown.MD(
        Markdown.Table(
                [
                ["Metric", "Value"],
                ["Successful minimization", Pumas.Optim.converged(fpm.optim)],
                ["Likelihood approximation", approx],
                ["Deviance", deviance],
                ["Total number of observation records", total_records],
                ["Number of actve observation records", active_records],
                ["Number of subjects", length(fpm.data)],
                ["Iterations", iterations],
                ["Time run", time_run],
                ["Objective function value", ofv],
            ],
            align
        )
    )
end

function shrinkage_table(fpm::Pumas.FittedPumasModel)

end

"""
metric_table(
        fpm::Pumas.FittedPumasModel;
        align = [:l, :c],
        formatter = x -> round(x; sigdigits = 5)
    )

Outputs a table containing basic statistical metrics about `fpm`.  These are:

- `AIC`: The Akaike information criterion, accessible using `aic(fpm)`.
- `BIC`: The Bayesian information criterion, accessible using `aic(fpm)`.

"""
function metric_table(
        fpm::Pumas.FittedPumasModel;
        align = [:l, :c],
        formatter = x -> round(x; sigdigits = 5)
    )

    esh = Pumas.ϵshrinkage(fpm.model, fpm.data, coef(fpm), fpm.approx, fpm.vvrandeffsorth)
    nsh = Pumas.ηshrinkage(fpm.model, fpm.data, coef(fpm), fpm.approx, fpm.vvrandeffsorth)
    return Markdown.MD(
        Markdown.Table(
            [
                ["Metric", "Value"],
                ["AIC", formatter(aic(fpm))],
                ["BIC", formatter(bic(fpm))],
                ["Condition number", "Not implemented"],
                ["ϵ-shrinkage", map(x -> formatter.(x), values(esh)[1])],
                ["η-shrinkage", map(x -> formatter.(x), values(nsh))]
            ],
            align
        )
    )
end

function embed(
        plot::Plots.Plot;
        dir = ".",
        name = "Figure",
        head_level = 2,
        caption = "Figure"
    )
    path = "$name.pdf" # TODO a more sensible figure path when integrated
    Plots.savefig(plot, joinpath(dir, path))
    return """
    $(repeat("#", head_level)) $name
    ![$caption]($path)

    """
end


function to_report_str(fpm::Pumas.FittedPumasModel; plotsdir = ".")
    return """
    # Model Report

    ## Parameter Table
    $(param_table(
        fpm;
    ))

    ## Model Metrics
    $(metric_table(fpm))

    ## Optimization Metadata
    $(optim_meta_table(fpm))

    \\newpage

    $(embed(etacov(fpm; catmap = (isPM = true, wt = true)); dir = plotsdir, name = "Empirical Bayes covariate estimates"))

    \\newpage

    $(embed(
        resplot(fpm; catmap = (isPM = true, wt = true));
        dir = plotsdir,
        name = "Residuals of covariates",
        head_level = 2,
        caption = "Residuals versus categorical covariates in the model."
    )
    )
    """
end


function report_to_pdf(filename::String, report::String)
    pandoc = open(`
        pandoc
            --pdf-engine=xelatex
            -V 'mainfont=DejaVu Sans'
            -V 'geometry:margin=1in'
            -o report.pdf
    `, "w")

    print(pandoc.in, report)

    close(pandoc.in)

    success(pandoc)

    return filename
end

function report_to_md(filename::String, report::String)
    open(filename, "w") do f
        print(f, report)
    end
    return filename
end


# write("report.md", to_report_str(res))
#


# TODO:
# - Deviance
# - Shrinkage
# - Condition number
# - Correlations
