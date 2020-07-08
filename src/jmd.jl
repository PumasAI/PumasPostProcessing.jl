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
    fpm_path = "data/serialized/fitted_models/",
    descriptions = [],
    catmap = NamedTuple(),
    kwargs...
    )

    serialization_loc = joinpath(fpm_path, "$(name)_$(number).jls")
    mkpath(dirname(serialization_loc))
    if isfile(serialization_loc)
        @warn "A file at $serialization_loc already exists!  Overwriting..."
    else
        @info "Writing fitted Pumas model to $serialization_loc"
    end

    Serialization.serialize(serialization_loc, fpm)

    io = IOBuffer()

    thl = TABLE_HEADER_LEVEL[]
    phl = PLOT_HEADER_LEVEL[]

    df = DataFrame(inspect(fpm))

    println(io, DEFAULT_REPORT_HEADER[] * "\n\n")

    printlnln(io, JLC("""
        # setup for the notebook
        using Pumas, PumasPlots, PumasPostProcessing
        using Plots, StatsPlots
        using Serialization
        fpm = Serialization.deserialize("$serialization_loc")
        # fpm = Main.fpm # TODO FIXME
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

    # First, we find (and plot) the dependent variables.
    # To do this, we must know what the dependent variables are
    # which can be found by looking at the subjects.
    dv_keys = keys(first(fpm.data).observations)

    for dv in dv_keys

        printlnln(io, MD(Header{phl}("Individual plots for dependent variable `$(dv)`")))

        # Plot a basic DV v/s IPRED.
        printlnln(io, MD(Header{phl + 1}("`$(dv)` v/s. IPRED")))

        printlnln(io, JLC("""
        @df fpm scatter(:$(dv), :$(dv)_ipred; xlabel = "$(dv)", ylabel = "$(dv)_ipred")
        Plots.abline!(1, 0; label = "LOI")
        @df fpm plot!(:$(dv), :$(dv)_ipred; seriestype = :Loess)
        """))
        printlnln(io, "\\newpage")

        # Plot a basic DV v/s PRED.

        printlnln(io, MD(Header{phl + 1}("`$(dv)` v/s. PRED")))

        printlnln(io, JLC("""
        @df fpm scatter(:$(dv), :$(dv)_pred; xlabel = "$(dv)", ylabel = "$(dv)_pred")
        Plots.abline!(1, 0; label = "LOI")
        @df fpm plot!(:$(dv), :$(dv)_pred; seriestype = :Loess)
        """))
        printlnln(io, "\\newpage")


        # Plot conditional weighted residuals v/s time.

        printlnln(io, MD(Header{phl + 1}("CWRES of `$(dv)` v/s. time")))

        printlnln(io, JLC("""
        @df fpm scatter(:tad, :$(dv)_wres; xlabel = "Time after dose", ylabel = "Weighted residuals")
        @df fpm plot!(:tad, :$(dv)_wres; seriestype = :Loess)
        Plots.hline!([0]; primary = false, linestyle = :dash, linecolor = :grey)
        """))
        printlnln(io, "\\newpage")
    end

    # To do this splitting for the EBEs, we first need their keys:
    ebe_keys = PumasPlots.ebe_names(fpm)

    cv_keys = PumasPlots.covariate_names(fpm)

    if isempty(cv_keys)
        calculated_catmap = (; zip(cv_keys, PumasPlots.iscategorical.(getproperty.(Ref(df), cv_keys)))...)
        catmap = collect(pairs(merge(calculated_catmap, catmap)))

        categorical_cvs = first.(catmap[last.(catmap)])
        continuous_cvs  = first.(catmap[.!(last.(catmap))])
    else
        @info "Model had no covariates"
        categorical_cvs = []
        continuous_cvs  = []
    end


    # First, we can plot a few basic things, which don't require grouping.



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
                etas = [:$ebe_name],
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
                etas = [:$ebe_name],
                cvs = $keyset,
                catmap = $((; zip(keyset, trues(length(keyset)))...)),
                legend = :none,
            )
            """))
            printlnln(io, "\\newpage")
        end
    end

    # Now, we will go for individual plots
    printlnln(io, MD(Header{phl}("Individual plots")))

    printlnln(io, JLC("""
    individual_df = groupby(DataFrame(inspect(fpm)), :id);
    individuals   = keys(individual_df);
    """))
    printlnln(io, "\\newpage")

    population_grouped_df = groupby(df, :id)
    for dv in dv_keys
        printlnln(io, MD(Header{phl + 1}("Dependent variable $(dv)")))
        for individual_set in paginate(eachindex(keys(population_grouped_df)))
            printlnln(io, JLC("""
            plot_grouped(individual_df[$(individual_set)]) do subdf
                @df subdf plot(:time, :$(dv)_pred; legend = :none, xlabel = "time", ylabel = "$(dv)")
                @df subdf scatter!(:time, :$(dv)_ipred)
                @df subdf plot!(:time, :$(dv)_ipred; seriestype = :Loess)
            end
            """))
            printlnln(io, "\\newpage")
        end
    end

    return String(take!(io))

end
