using Test, PumasPostProcessing

# Include tests

include("model.jl") # predefine a model

# @testset "Model serializability" begin
#   include("serialization/model.jl")
# end
@testset "Table execution" begin
  include("reports/tables.jl")
end
@testset "Weaving" begin
  include("reports/jmd.jl")
end
