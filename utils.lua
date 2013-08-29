function table.map(func, array)
    local new_array = {}
    for i,v in ipairs(array) do
        new_array[i] = func(v)
    end
    return new_array
end

function table.tail(t)
    local function helper(head, ...) return #{...} > 0 and {...} or {} end
    return helper((table.unpack or unpack)(t))
end
