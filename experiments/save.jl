using Pumas, FileIO, BSON, JLD2, Serialization, HDF5, Feather

f = x -> x+1

g = x -> f(x) + 1

serialize("f.jls", f)
serialize("g.jls", g)

f1 = deserialize("f.jls")
g1 = deserialize("g.jls")

@save "f.jld2" f

@load "f.jld2" f

include("model.jl")

@save "res.jld2" res
@load "res.jld2" res
