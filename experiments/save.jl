using Pumas, FileIO, BSON, JLD2, Serialization, HDF5, Feather

@noinline function f(x)
    return x + 1
end

function g(x)
    return f(x) - 1
end

serialize("f.jls", f)
serialize("g.jls", g)

@code_llvm deserialize("f.jls")(1)
@code_llvm deserialize("g.jls")(1)

@save "f.jld2" f

@load "f.jld2" f

# If you try to load these files in a new session, they won't
# be loaded correctly, even if you have the same packages running.
# This is not good news.
