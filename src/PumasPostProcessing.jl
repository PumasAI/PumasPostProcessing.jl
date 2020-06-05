module PumasPostProcessing

using Pumas, PumasPlots
using PumasPlots.StatsPlots

using Pumas: FittedPumasModel, StatsBase

using Serialization, Markdown

include("utils.jl")
include("reports.jl")
include("jmd.jl")

export to_report_str, report_to_md, report_to_pdf

export embed, param_table, optim_meta_table, metric_table

end
