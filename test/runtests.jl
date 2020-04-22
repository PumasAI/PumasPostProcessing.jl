using Test

# Include tests

include("model.jl") # predefine a model

@testset "Model serializability" include("serialization/model.jl")

@testset "Table execution" include("reports/tables.jl")
@testset "Weaving" include("reports/jmd.jl")
