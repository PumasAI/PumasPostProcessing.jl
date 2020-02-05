using Test

# Include tests

include("model.jl") # predefine a model

@testset "Model serializability" include("serialization/model.jl")
