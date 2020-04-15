module PumasPostProcessing

using Pumas, PumasPlots, Markdown
using PumasPlots.StatsPlots

using Pumas: FittedPumasModel, StatsBase

StatsBase.aic(fpm::FittedPumasModel) = StatsBase.aic(fpm.model, fpm.data, coef(fpm), fpm.approx, fpm.args...; fpm.kwargs...)
StatsBase.bic(fpm::FittedPumasModel) = StatsBase.bic(fpm.model, fpm.data, coef(fpm), fpm.approx, fpm.args...; fpm.kwargs...)

include("reports.jl")

export to_report_str, report_to_md, report_to_pdf

export embed, param_table, optim_meta_table, metric_table

end
