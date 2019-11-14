using DataFrames

function compareDataFrames(DataFrame1, DataFrame2)
    newDateFrame = join(DataFrame1, DataFrame2, kind = :cross, makeunique=true)
    return newDateFrame
end
