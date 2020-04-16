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
    kwargs...
    )

    io = IOBuffer()

    thl = TABLE_HEADER_LEVEL[]
    phl = PLOT_HEADER_LEVEL[]

    df = DataFrame(inspect(res))

    println(io, DEFAULT_REPORT_HEADER[] * "\n\n")

    printlnln(io, JLC("""
        # setup for the notebook
        using Serialization
        fpm = Serialization.deserialize(path_to_artifact(name, number))
        formatter = $(DEFAULT_FORMATTER[])
        Plots.default(legendpos = :outerright)
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

    # Print the optimization metadata.  There are no keywords to forward to this.
    printlnln(io, MD(Header{thl}("Optimization Metadata")))

    printlnln(io, JLC(:(optim_meta_table(fpm))))

    # We're done with the tables; now, we have to handle the plots.
    # This is a bit tricky - pagination has to be done on some of them,
    # specifically individual plots and covariate plots.
    # Additionally, we have to split some plots up; for example, covariates
    # need to be split into categorical (boxplots) and continuous (scatters).

    # To do this splitting for the EBEs, we first need their keys:
    ebe_keys = Symbol.(:η_, keys(empirical_bayes(fpm)))

    cv_keys = PumasPlots.covariate_names(fpm)

    catmap = [(PumasPlots.iscategorical.(getproperty.(Ref(df), cv_keys)))...]

    categorical_cvs = cv_keys[catmap]
    continuous_cvs = cv_keys[.!(catmap)]



    # First, we can plot a few basic things, which don't require grouping.


    # Plot a basic DV v/s IPRED.
    printlnln(io, MD(Header{phl}("DV v/s. PRED")))

    printlnln(io, JLC("""
    @df fpm scatter(:dv, df.dv_pred; markersize = 1)
    Plots.abline!(1, 0; label = "LOI")
    """))

    # Plot conditional weighted residuals v/s time.

    printlnln(io, MD(Header{phl}("CWRES v/s. time")))

    printlnln(io, JLC("""
    @df fpm scatter(:tad, :dv_wres; markersize = 2)
    Plots.hline!([0]; primary = false, linestyle = :dashed, linecolor = :grey)
    """))


    return String(take!(io))

end
