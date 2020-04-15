function paginate(keys, good_num::Int = 9)
    return collect(Iterators.partition(keys, good_num))
end

function paginate(keys, good_num::NTuple{2, Int})
    return paginate(keys, prod(good_num))
end
