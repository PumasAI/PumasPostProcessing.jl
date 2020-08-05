using Markdown

mdpath = "render.md"

res = res

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
Metric                          Value
–––––––––––––––––––––––– –––––––––––––––––––
Iterations                       12
Time run                 0.37180399894714355
Objective function value  8464.875537914886
```
"""
function optim_meta_table(fpm::Pumas.FittedPumasModel; align = [:l, :c])
    iterations, time_run, ofv = optim_meta(fpm)
    return Markdown.MD(
        Markdown.Table(
                [
                ["Metric", "Value"],
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
    individual_wres = plot_grouped(groupby(DataFrame(inspect(fpm)), :id); legend = :none, ) do subdf
                        @df subdf scatter(:time, :dv_wres; legend = :none)
                    end
    individual_dv = plot_grouped(groupby(DataFrame(inspect(res)), :id); legend = :none, xlabel = "time", ylabel = "dv") do subdf
       @df subdf plot(:time, :dv)
       end
    return """
    # Model Report

    ## Parameter Table
    $(param_table(
        fpm;
        descriptions = [
            "Time varying chlorate",
            "Time varying voltage",
            "Evening chloroform",
            "Omega number 1",
            "Omega version 2: the cooler one",
            "Standard deviation from propriety"
        ]
    ))

    ## Model Metrics
    $(metric_table(fpm))

    ## Optimization Metadata
    $(optim_meta_table(fpm))

    \\newpage

    $(embed(etacov(fpm; catmap = (isPM = true, wt = true)); dir = ".", name = "Empirical Bayes covariate estimates"))

    \\newpage

    $(embed(
        resplot(fpm; catmap = (isPM = true, wt = true));
        dir = ".",
        name = "Residuals of covariates",
        head_level = 2,
        caption = "Residuals versus categorical covariates in the model."
    ))

    \\newpage

    $(embed(
        individual_wres;
        dir = ".",
        name = "Per-subject weighted residuals",
        caption = "Continuous weighted residuals plotted against time for individual subjects."
    ))

    \\newpage

    $(embed(
        individual_dv;
        dir = ".",
        name = "Dependent variable per subject",
        caption = "Dependent variable plotted against time for individual subjects."
    ))
    """
end

write("report.md", to_report_str(res))

run(`
    pandoc
        --pdf-engine=xelatex
        -V 'mainfont=DejaVu Sans'
        -V 'geometry:margin=1in'
        report.md
        -o report.pdf
`)

# TODO:
# - Log-likelihood
# - Shrinkage
# - Condition number
# - Correlations
