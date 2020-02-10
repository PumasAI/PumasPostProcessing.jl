using Markdown, Showoff

mdpath = "render.md"

res = res

# Parameter estimate table
function paramtable(
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

    rows = zip(paramnames, paramvals, paramrse, paramconfint) .|> x -> [x...]

    # Push the headers
    pushfirst!(rows, ["Parameter", "Estimate", "RSE", "95% confidence interval"])

    # Materialize a Markdown table, and return it as an MD node.
    return Markdown.Table(rows, align) |> Markdown.MD
end

paramtable(fpm::Pumas.FittedPumasModel; kwargs...) = paramtable(infer(fpm); kwargs...)

function report_optim_meta(res::Pumas.FittedPumasModel)
    return (iterations = res.optim.iterations, time_run = res.optim.time_run, ofv = res.optim.minimum)
end

# TODO:
# - Deviance
# - Shrinkage
# - Condition number
# - Correlations
