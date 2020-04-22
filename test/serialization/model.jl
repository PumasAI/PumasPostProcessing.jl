using Serialization
serialize("serialized/model.jls", model)
serialize("serialized/fpm.jls", res)

@test success(`$(Base.julia_cmd()) -e 'using Pumas, Serialization; @show(deserialize("serialized/model.jls")); @show(deserialize("serialized/fpm.jls"));'`)
