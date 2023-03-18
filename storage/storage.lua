shell.run("clear")

print("running...")

rednet.open("bottom")
storage = peripheral.wrap("top")

while true do
    _, msg, _ = rednet.receive("storage")

    local mArg = {}
    for w in msg:gmatch("%S+") do
        table.insert(mArg, w)
    end

    local query = mArg[2] or ""
    for i = 3, #mArg do
        query = query.." "..string.lower(mArg[i])
    end

    if mArg[1] == "find" then
        local all = storage.list()
        local foundMatch = false

        for k, item in pairs(all) do
            for l = 2, #mArg do
                local i, j = string.find(item.name, mArg[l])
                if i and j then
                    foundMatch = true
                    break
                end
            end

            if foundMatch then break end
        end

        if foundMatch then
            redstone.setOutput("front", true)
        end

    --search by display name
    elseif mArg[1] == "query" then
        local foundMatch = false

        for i = 1, storage.size() do
            local item = storage.getItemDetail(i)
            if item then
                local i, j = string.find(string.lower(item.displayName), query)
                if i and j then
                    foundMatch = true
                    break
                end
            end
        end

        if foundMatch then
            redstone.setOutput("front", true)
        end

    elseif mArg[1] == "reset" then
        redstone.setOutput("front", false)
    elseif mArg[1] == "light" then
        redstone.setOutput("front", true)
    end
end