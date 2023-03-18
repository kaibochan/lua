--different possible groupings and their
--corresponding greetings

--default text displayed when no players
local defaultText = "Welcome to Biopunk"

local defaultSettings = {
    ["scale"] = 1.5,
    ["textColor"] = "lime",
    ["bgColor"] = "black",
}

function findGroup(players, groupings)
    local foundGroup
            
    --iterate through all different groups
    for i, group in ipairs(groupings) do
        foundGroup = true
        
        --iterate through names within the
        --current group, checking for a
        --match, then printing the
        --corresponding greeting
        if #players ==  #group then
            for j, name in ipairs(group) do
                if players[j] ~= name then
                    foundGroup = false
                    break
                end
            end
        else
            foundGroup = false
        end

        if foundGroup then
            return i
        end
    end
end

function loadGreetingFiles()
    --load greeting data from files
    local fileGroupings = fs.open("groupings.txt", "r")
    local groupings = textutils.unserialise(fileGroupings.readAll())
    fileGroupings.close()
    
    local fileGreetings = fs.open("greetings.txt", "r")
    local greetings = textutils.unserialise(fileGreetings.readAll())
    fileGreetings.close()
    
    local fileGreetFormat = fs.open("greetFormat.txt", "r")
    local settings = textutils.unserialise(fileGreetFormat.readAll())
    fileGreetFormat.close()

    return groupings, greetings, settings
end

function main()
    local groupings, greetings, settings = loadGreetingFiles()

    --sort each grouping for easy comparison
    for i, group in ipairs(groupings) do
        table.sort(group)
    end

    --find peripherals
    monitor = peripheral.find("monitor")
    playerDetector = peripheral.find("playerDetector")

    while true do
        --only activate once every 1/8 of a second
        sleep(1/8)
        
        monitor.setCursorPos(1, 1)

        --get a sorted list of nearby players
        local players = playerDetector.getPlayersInCubic(3, 3, 3)
        table.sort(players)
        
        local group = findGroup(players, groupings)
        if group then
            monitor.setTextScale(settings[group].scale)
            monitor.setTextColor(colors[settings[group].textColor])
            monitor.setBackgroundColor(colors[settings[group].bgColor])
            monitor.clear()

            monitor.write(greetings[group])
        else
            --if no players nearby or no matching group found
            --display default text

            monitor.setTextScale(defaultSettings.scale)
            monitor.setTextColor(colors[defaultSettings.textColor])
            monitor.setBackgroundColor(colors[defaultSettings.bgColor])
            monitor.clear()

            monitor.write(defaultText)
        end
    end
end

main()