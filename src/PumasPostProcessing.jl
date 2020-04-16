module PumasPostProcessing

using Pumas, PumasPlots, Markdown
using PumasPlots.StatsPlots

using Pumas: FittedPumasModel, StatsBase

include("reports.jl")
include("jmd.jl")

export to_report_str, report_to_md, report_to_pdf

export embed, param_table, optim_meta_table, metric_table

end
