serialize("res.jls", res)

@test success(`$(Base.julia_cmd()) -e 'using Pumas, Serialization; res = deserialize("res.jls"); @show res'`) # this can take a while
