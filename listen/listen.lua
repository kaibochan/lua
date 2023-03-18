os.loadAPI("nav.lua")
os.loadAPI("mine.lua")

nav.loadMap("map.txt")
nav.calibrate()
--nav.clearRestriction()

listenFreq = tonumber(arg[1])

local modem = peripheral.wrap("left")
modem.open(listenFreq)

local mArg

while true do

    local _, _, _, replyFrequency, message, _ = os.pullEvent("modem_message")
    
    print(message)

    mArg = {}
    for w in message:gmatch("%S+") do
        table.insert(mArg, w)
    end

    --Navigating program
    if mArg[1] == "pathfind" then
        table.remove(mArg, 1)
        
        local target

        if #mArg == 3 then
            target = vector.new(mArg[1], mArg[2], mArg[3])
        else
            error("Expected 3 arguments:\n"
                .."target.x target.y target.z")
        end

        modem.transmit(replyFrequency, listenFreq, "inprogress")
        
        nav.setMineMode(false)
        nav.clearRestriction()

        nav.pathFind(target)

        nav.saveMap("map.txt")

        modem.transmit(replyFrequency, listenFreq, "complete")
        print("complete")

    --Mining program
    elseif mArg[1] == "mineregion" then
        table.remove(mArg, 1)

        local p1
        local p2
        
        local stPos
        local prevPos
        
        if #mArg == 9 or #mArg == 12 then
            p1 = vector.new(mArg[1], mArg[2], mArg[3])
            p2 = vector.new(mArg[4], mArg[5], mArg[6])
            stPos = vector.new(mArg[7], mArg[8], mArg[9])
        
            if #mArg == 12 then
               prevPos = vector.new(mArg[10], mArg[11], mArg[12]) 
            end
        else
            error("Expected 9 or 12 arguments:\n"
                .."p1.x p1.y p1.z p2.x p2.y p2.z stPos.x stPos.y stPos.z [prev.x prev.y prev.z]") 
        end

        modem.transmit(replyFrequency, listenFreq, "inprogress")

        mine.initialize(p1, p2, stPos, prevPos)

        mine.mineRegion()

        nav.saveMap("map.txt")

        modem.transmit(replyFrequency, listenFreq, "complete")
        print("complete")

    elseif mArg[1] == "where" then    
        local p = nav.getPos()
        modem.transmit(replyFrequency, listenFreq, "position: "..p.x.." "..p.y.." "..p.z)
    else
        print("Not a valid command")
    end
end