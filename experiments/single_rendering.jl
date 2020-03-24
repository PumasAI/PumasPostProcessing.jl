using Markdown

mdpath = "render.md"

res = res

# Parameter estimate table
function param_table(
        inference::Pumas.FittedPumasModelInference;
        ignores = Symbol[],
        align = [:c, :l, :l, :l]
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

    rows = zip(paramnames, round.(paramvals; sigdigits=5), round.(paramrse; sigdigits=5), paramconfint) .|> x -> [x...]

    # Push the headers
    pushfirst!(rows, ["Parameter", "Estimate", "RSE", "95% confidence interval"])

    # Materialize a Markdown table, and return it as an MD node.
    return Markdown.MD(Markdown.Table(rows, align))
end

param_table(fpm::Pumas.FittedPumasModel; kwargs...) = paramtable(infer(fpm); kwargs...)

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

function embed(plot::Plots.Plot)
    path = "fig-$(gensym()).png" # TODO a more sensible figure path when integrated
    Plots.savefig(plot, path)
    return "![Figure]($path)"
end

function to_report_str(fpm::Pumas.FittedPumasModel)
    return """
    # Model Report

    ## Parameter Table
    $(param_table(fpm))

    ## Optimization Metadata
    $(optim_meta_table(fpm))

    $(embed(convergence(fpm)))
    """
end

write("report.md", to_report_str(res))

# TODO:
# - Deviance
# - Shrinkage
# - Condition number
# - Correlations
