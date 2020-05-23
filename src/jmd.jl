const DEFAULT_REPORT_HEADER = Ref("# Model Report")
const TABLE_HEADER_LEVEL = Ref(2)
const PLOT_HEADER_LEVEL = Ref(2)
const DEFAULT_FORMATTER = Ref("x -> round(x; sigdigits = 5)")

using Markdown: MD, Code, Header

JLC(code::String) = Markdown.MD(Markdown.Code("julia", code))
JLC(code::Expr)   = JLC(string(code))

function printlnln(io::IO, args...)
    println(io, args...)
    println(io)
    return
end

function jmd_report(
    fpm::Pumas.FittedPumasModel, name, number;
    descriptions = [],
    catmap = NamedTuple(),
    kwargs...
    )

    io = IOBuffer()

    thl = TABLE_HEADER_LEVEL[]
    phl = PLOT_HEADER_LEVEL[]

    df = DataFrame(inspect(fpm))

    println(io, DEFAULT_REPORT_HEADER[] * "\n\n")

    printlnln(io, JLC("""
        # setup for the notebook
        using Pumas, PumasPlots, PumasPostProcessing
        using Plots, StatsPlots
        # using Serialization
        # fpm = Serialization.deserialize(path_to_artifact($name, $number))
        fpm = Main.res # TODO FIXME
        formatter = $(DEFAULT_FORMATTER[])
        Plots.default(legend = :outerright, fmt = :pdf)
        """
    ))

    # Print the parameter table first.  The description and formatter are forwarded to this.
    printlnln(io, MD(Header{thl}("Parameter Table")))

    printlnln(io, JLC("""
    param_table(
        fpm;
        formatter = formatter,
        descriptions = $(descriptions)
    )
    """
    ))

    # Print the model's metrics - AIC, BIC, CN and ϵ-shrinkage.
    printlnln(io, MD(Header{thl}("Metric Table")))

    printlnln(io, JLC(:(metric_table(fpm; formatter = formatter))))
    printlnln(io, "\\newpage")

    # Print the optimization metadata.  There are no keywords to forward to this.
    printlnln(io, MD(Header{thl}("Optimization Metadata")))

    printlnln(io, JLC(:(optim_meta_table(fpm))))
    printlnln(io, "\\newpage")

    # We're done with the tables; now, we have to handle the plots.
    # This is a bit tricky - pagination has to be done on some of them,
    # specifically individual plots and covariate plots.
    # Additionally, we have to split some plots up; for example, covariates
    # need to be split into categorical (boxplots) and continuous (scatters).

    # To do this splitting for the EBEs, we first need their keys:
    df_names = string.(names(df))
    ebe_keys = (x -> x[4:end]).(df_names[findall(x -> startswith(x, "η_"), df_names)])


    cv_keys = PumasPlots.covariate_names(fpm)

    calculated_catmap = (; zip(cv_keys, PumasPlots.iscategorical.(getproperty.(Ref(df), cv_keys)))...)
    catmap = collect(pairs(merge(calculated_catmap, catmap)))

    categorical_cvs = first.(catmap[last.(catmap)])
    continuous_cvs  = first.(catmap[.!(last.(catmap))])


    # First, we can plot a few basic things, which don't require grouping.


    # Plot a basic DV v/s IPRED.
    printlnln(io, MD(Header{phl}("DV v/s. IPRED")))

    printlnln(io, JLC("""
    @df fpm scatter(:dv, :dv_ipred; xlabel = "dv", ylabel = "dv_ipred")
    Plots.abline!(1, 0; label = "LOI")
    @df fpm plot!(:dv, :dv_ipred; seriestype = :loess)

    """))
    printlnln(io, "\\newpage")

    # Plot a basic DV v/s PRED.

    printlnln(io, MD(Header{phl}("DV v/s. PRED")))

    printlnln(io, JLC("""
    @df fpm scatter(:dv, :dv_pred; xlabel = "dv", ylabel = "dv_pred")
    Plots.abline!(1, 0; label = "LOI")
    @df fpm plot!(:dv, :dv_pred; seriestype = :loess)
    """))
    printlnln(io, "\\newpage")


    # Plot conditional weighted residuals v/s time.

    printlnln(io, MD(Header{phl}("CWRES v/s. time")))

    printlnln(io, JLC("""
    @df fpm scatter(:tad, :dv_wres; xlabel = "Time after dose", ylabel = "Weighted residuals")
    Plots.hline!([0]; primary = false, linestyle = :dash, linecolor = :grey)
    """))
    printlnln(io, "\\newpage")

    # Now, for the adaptive plots.
    # We begin with etacov, on all covariates.
    # We paginate by eta first (1 eta per page only)
    # and then by covariate (4 per page).

    printlnln(io, MD(Header{phl}("Etas v/s covariates")))

    for ebe_name in ebe_keys
        printlnln(io, MD(Header{phl + 1}("ETA " * string(ebe_name) * " v/s continuous covariates")))
        for keyset in paginate(continuous_cvs)
            printlnln(io, JLC("""
            etacov(
                fpm;
                etas = [$ebe_name],
                cvs = $keyset,
                catmap = $((; zip(keyset, falses(length(keyset)))...)),
                legend = :none,
            )
            """))
            printlnln(io, "\\newpage")
        end
    end

    for ebe_name in ebe_keys
        printlnln(io, MD(Header{phl + 1}("ETA " * string(ebe_name) * " v/s categorical covariates")))
        for keyset in paginate(categorical_cvs)
            printlnln(io, JLC("""
            etacov(
                fpm;
                etas = [$ebe_name],
                cvs = $keyset,
                catmap = $((; zip(keyset, trues(length(keyset)))...)),
                legend = :none,
            )
            """))
            printlnln(io, "\\newpage")
        end
    end



    return String(take!(io))

end
