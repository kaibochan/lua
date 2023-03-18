os.loadAPI("nav.lua")
os.loadAPI("mine.lua")

nav.loadMap("map.txt")
nav.calibrate()



local arg = { ... }

local p1
local p2

local stPos
local prevPos

if #arg == 9 or #arg == 12 then
    p1 = vector.new(arg[1], arg[2], arg[3])
    p2 = vector.new(arg[4], arg[5], arg[6])
    stPos = vector.new(arg[7], arg[8], arg[9])

    if #arg == 12 then
       prevPos = vector.new(arg[10], arg[11], arg[12]) 
    end
else
    error("Expected 9 or 12 arguments:\n"
        .."p1.x p1.y p1.z p2.x p2.y p2.z stPos.x stPos.y stPos.z [prev.x prev.y prev.z]") 
end

mine.initialize(p1, p2, stPos, prevPos)
mine.mineRegion()



nav.saveMap("map.txt")