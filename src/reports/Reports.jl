module Reports

using Markdown
using Plots
using ..Pumas
using ..Pumas: FittedPumasModel
using ..PumasPlots
# Parameter estimate table
function param_table(
        inference::Pumas.FittedPumasModelInference;
        ignores = Symbol[],
        align = [:c, :l, :l, :l],
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

    rows = zip(paramnames, formatter.(paramvals), formatter.(paramrse), map(x -> formatter.(x), paramconfint)) .|> x -> [x...]

    @show paramconfint

    # Push the headers
    pushfirst!(rows, ["Parameter", "Estimate", "RSE", "95% confidence interval"])

    # Materialize a Markdown table, and return it as an MD node.
    return Markdown.MD(Markdown.Table(rows, align))
end

param_table(fpm::Pumas.FittedPumasModel; kwargs...) = param_table(infer(fpm); kwargs...)

function optim_meta(res::Pumas.FittedPumasModel)
    return (iterations = res.optim.iterations, time_run = res.optim.time_run, ofv = res.optim.minimum)
end

function optim_meta_table(res::Pumas.FittedPumasModel; align = [:l, :c])
    iterations, time_run, ofv = optim_meta(res)
    return Markdown.MD(
        Markdown.Table(
                [
                ["Parameter", "Value"],
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

function metric_table(
        fpm::FittedPumasModel;
        align = [:l, :c],
        formatter = x -> round(x; sigdigits = 5)
    )
    return Markdown.MD(
        Markdown.Table(
            [
                ["Metric", "Value"],
                ["AIC", formatter(aic(fpm))],
                ["BIC", formatter(bic(fpm))],
                ["Condition number", "Not implemented"],
                ["Deviance", formatter(deviance(fpm))],

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
    $(param_table(fpm))

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

# write("report.md", to_report_str(res))
#
# run(`
#     pandoc
#         --pdf-engine=xelatex
#         -V 'mainfont:DejaVu Sans'
#         -V 'margin:1in'
#         report.md
#         -o report.pdf
# `)

# TODO:
# - Deviance
# - Shrinkage
# - Condition number
# - Correlations
end
