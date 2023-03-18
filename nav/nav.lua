local pos
local dir
local globalTarget
local distReq

zero  = vector.new( 0,  0,  0)
one   = vector.new( 1,  1,  1)

east  = vector.new( 1,  0,  0)
up    = vector.new( 0,  1,  0)
south = vector.new( 0,  0,  1)
west  = vector.new(-1,  0,  0)
down  = vector.new( 0, -1,  0)
north = vector.new( 0,  0, -1)

local mapFile

local map = {}

navigableBlocks = {
    "minecraft:air",
    "minecraft:grass",
    "minecraft:tall_grass",
    "minecraft:water",
    "minecraft:lava",
}

failMax = 4096
iterationsMax = 64
stop = false
go = false

--min and max points to stay within while pathfinding
restrictMode = false
minRestrict = nil
maxRestrict = nil

mineMode = false
useMineWhitelist = true

mineWhitelist = {
    "minecraft:cobblestone",
    "minecraft:stone",
    "minecraft:dirt",
    "minecraft:andesite",
    "minecraft:granite",
    "minecraft:diorite",
}

mineBlacklist = {
    "minecraft:bedrock",
    "computercraft:turtle",
    "computercraft:turtle_advanced",
}

local otherTurtles = {}

toBeProcessed = {}

function setMineMode(mode)
    mineMode = mode
end

function useWhitelist()
    useMineWhitelist = true
end

function useBlacklist()
    useMineWhitelist = false
end

function composeMinMaxPoints(p1, p2)
    local minX = math.min(p1.x, p2.x)
    local minY = math.min(p1.y, p2.y)
    local minZ = math.min(p1.z, p2.z)

    local maxX = math.max(p1.x, p2.x)
    local maxY = math.max(p1.y, p2.y)
    local maxZ = math.max(p1.z, p2.z)

    local min = vector.new(minX, minY, minZ)
    local max = vector.new(maxX, maxY, maxZ)

    return min, max
end

function setRestriction(p1, p2)
    restrictMode = true

    minRestrict, maxRestrict = composeMinMaxPoints(p1, p2)
end

function clearRestriction()
    restrictMode = false
    minRestrict = nil
    maxRestrict = nil
end

function loadMap(mapPath)
    if fs.exists(mapPath) then
        mapFile = fs.open(mapPath, "r")
        map = textutils.unserialize(mapFile.readAll())
        mapFile.close()
        if fs.exists(mapPath..".bak") then
            fs.delete(mapPath..".bak")
        end
        fs.copy(mapPath, mapPath..".bak")
    end
end

function mergeMap(mapPath)
    local old_map
    if fs.exists(mapPath) then
        mapFile = fs.open(mapPath, "r")
        old_map = textutils.unserialize(mapFile.readAll())
        mapFile.close()
        if fs.exists(mapPath..".bak") then
            fs.delete(mapPath..".bak")
        end
        fs.copy(mapPath, mapPath..".bak")
    end

    --initialize if no previous map
    if not old_map then
        old_map = {}
    end
    
    --correct old_map
    local loc = vector.new(0, 0, 0)
    for x, yz in pairs(map) do
        for y, zb in pairs(yz) do
            for z, b in pairs(zb) do
                loc.x = x
                loc.y = y
                loc.z = z
                setNode(old_map, loc, b)
            end
        end
    end

    mapFile = fs.open(mapPath, "w")
    if mapFile then
        mapFile.write(textutils.serialize(old_map))
        mapFile.close()
    else
        error("Unable to open map file")
    end
end

function printMap()
    for x, yz in pairs(map) do
        for y, zb in pairs(yz) do
            for z, b in pairs(zb) do
                print("["..x.." "..y.." "..z.."] = "..b)
            end
        end
    end
end


function saveMap(mapPath)
    mapFile = fs.open(mapPath, "w")
    if mapFile then
        mapFile.write(textutils.serialize(map))
        mapFile.close()
    else
        error("Unable to open map file")
    end
end

local function tryMove()
    local pos_
    if turtle.forward() then
        pos_ = vector.new(gps.locate(0.4))
        turtle.back()
    end

    return pos_
end

local function calibrateDir()
    local pos_
    local turns = 0
    while not pos_ and turns <= 3 do
        pos_ = tryMove()
        if not pos_ then
            turtle.turnRight()
            turns = turns + 1
        end
    end

    --fail if unable to get orientation
    if not pos_ then
        while turns > 0 do
            turtle.turnLeft()
            turns = turns - 1
        end
        error("Unable to get orientation")
    end
    
    dir = pos_ - pos

    while turns > 0 do
        turn(-1)
        turns = turns - 1
    end
end

function calibrate()
    --get position
    pos = vector.new(gps.locate(5))

    if not pos then
        error("Unable to get location")
    end

    --get orientation
    calibrateDir()
    inspectAllQuick()
end

function processInspect(success, block)
    if not success then
        block = {["name"] = "minecraft:air"}
    end

    return block
end

function inspect()
    local block = processInspect(turtle.inspect())

    local v = pos + dir
    setBlock(v, block.name)

    if isTurtle(v) then
        table.insert(otherTurtles, v)
    end
end

function inspectUp()
    local block = processInspect(turtle.inspectUp())

    local v = pos + up
    setBlock(v, block.name)
    
    if isTurtle(v) then
        table.insert(otherTurtles, v)
    end
end

function inspectDown()
    local block = processInspect(turtle.inspectDown())

    local v = pos + down
    setBlock(v, block.name)

    if isTurtle(v) then
        table.insert(otherTurtles, v)
    end
end

function inspectHere()
    setBlock(pos, "minecraft:air")
end

function inspectAllQuick()
    inspectHere()
    inspect()
    inspectUp()
    inspectDown()
end

function inspectAll()
    inspectHere()
    inspectUp()
    inspectDown()

    for turns = 0, 3, 1 do
        inspect()
        turn(1)
    end
end

function getPos()
    return pos
end

function getDir()
    return dir
end

function getBlock(loc)
    local x = loc.x
    local y = loc.y
    local z = loc.z

    if x == 0 then x = 2147483647 end
    if y == 0 then y = 2147483647 end
    if z == 0 then z = 2147483647 end

    if map and map[x] and map[x][y]
        and map[x][y][z] then

        return map[x][y][z]
    else
        return nil
    end
end

function isTurtle(node)
    local blockname = getBlock(node)
    if not blockname then
        return false
    end

    if blockname == "computercraft:turtle"
        or blockname == "computercraft:turtle_advanced" then
        
        return true
    end

    return false
end

function isNavigable(node)
    local navigable = false

    local blockname = getBlock(node)
    if not blockname then
        return true
    end

    for index, value in ipairs(navigableBlocks) do
        if blockname == value then
            navigable = true
            break
        end
    end

    return navigable
end

function isMineable(node)
    local blockname = getBlock(node)
    if not blockname then
        return false
    end
    
    if useMineWhitelist then
        for index, value in ipairs(mineWhitelist) do
            if blockname == value then
                return true
            end
        end

        return false
    else
        for index, value in ipairs(mineBlacklist) do
            if blockname == value then
                return false
            end
        end
        
        return true
    end
end

function isWithinRegion(node)
    local withinX = (node.x >= minRestrict.x and node.x <= maxRestrict.x)
    local withinY = (node.y >= minRestrict.y and node.y <= maxRestrict.y)
    local withinZ = (node.z >= minRestrict.z and node.z <= maxRestrict.z)

    return withinX and withinY and withinZ
end

function setBlock(loc, name)
    local x = loc.x
    local y = loc.y
    local z = loc.z

    if x == 0 then x = 2147483647 end
    if y == 0 then y = 2147483647 end
    if z == 0 then z = 2147483647 end

    if not map[x] then
        map[x] = {[y] = {[z] = name}}
    elseif not map[x][y] then
        table.insert(map[x], y, {[z] = name})
    elseif not map[x][y][z] then
        table.insert(map[x][y], z, name)
    else
        map[x][y][z] = name
    end
end

function move()
    if #otherTurtles ~= 0 then
        for i, t in ipairs(otherTurtles) do
            setBlock(t, "minecraft:air")
            otherTurtles[i] = nil
        end
    end

    local v = pos + dir
    inspectAllQuick()
    
    if mineMode and isMineable(v) then
        turtle.dig()
    end

    if turtle.forward() then
        pos = v
        inspectAllQuick()
    else
        return false
    end

    return true
end

--not to be used, only here for the reverse function
function moveBack()

    --removed most duplicate code from move because
    --    there is no inspectBehind function

    if not turtle.back() then
        return false
    end

    pos = pos + dir
    return true
end


function moveUp()
    if #otherTurtles ~= 0 then
        for i, t in ipairs(otherTurtles) do
            setBlock(t, "minecraft:air")
            otherTurtles[i] = nil
        end
    end

    local v = pos + up
    inspectAllQuick()

    if mineMode and isMineable(v) then
        turtle.digUp()
    end

    if turtle.up() then
        pos = v
        inspectAllQuick()
    else
        return false
    end

    return true
end

function moveDown()
    if #otherTurtles ~= 0 then
        for i, t in ipairs(otherTurtles) do
            setBlock(t, "minecraft:air")
            otherTurtles[i] = nil
        end
    end

    local v = pos + down
    inspectAllQuick()
    
    if mineMode and isMineable(v) then
        turtle.digDown()
    end

    if turtle.down() then
        pos = v
        inspectAllQuick()
    else
        return false
    end

    return true
end

-- 1 for right , -1 for left
function turn(t) 
    if t > 0 then
        turtle.turnRight()
    else
        turtle.turnLeft()
    end

    local v = vector.new(0, t, 0)
    dir = dir:cross(v)
end

--the turn functions return true always
--    the boolean value is used in calculating whether
--    or not the turtle was able to follow the actions
function turnLeft()
    turn(-1)
    return true
end

function turnRight()
    turn(1)
    return true
end

function reverse(action)
    reverseActions[action]()
end

function face(newDir)
    if dir == newDir then
        return
    elseif dir == -newDir then
        turnRight()
        turnRight()
    elseif (dir.z * newDir.x) - (dir.x * newDir.z) < 0 then
        turnRight()
    elseif (dir.z * newDir.x) - (dir.x * newDir.z) > 0 then
        turnLeft()
    end
end

function genFacingInstr(d1, d2)
    local instructions = setmetatable({}, instructions_meta)

    if d1.x == -d2.x and d1.z == -d2.z then
        table.insert(instructions, turnRight)
        table.insert(instructions, turnRight)
    elseif (d1.z * d2.x) - (d1.x * d2.z) < 0 then
        table.insert(instructions, turnRight)
    elseif (d1.z * d2.x) - (d1.x * d2.z) > 0 then
        table.insert(instructions, turnLeft)
    end

    return instructions
end

--returns a list of function calls to execute to move from
--    p1 to its adjacent p2 or the length can be queried
--    to get the cost between p1 and p2
--erroneous results will be given if not using adjacent
--    positions to p1
function genAdjMoveInstr(p1, d, p2)
    local displacement = p2 - p1
    local instructions = setmetatable({}, instructions_meta)
    
    if displacement == zero then
        instructions = {}
    elseif displacement.y == 0 then
        instructions = genFacingInstr(d, displacement)
        table.insert(instructions, move)
    elseif displacement.y == 1 then
        table.insert(instructions, moveUp)
    elseif displacement.y == -1 then
        table.insert(instructions, moveDown)
    end

    return instructions
end

--gets the taxicab distance between points p1 and p2
function getDist(p1, p2)
    return math.abs(p2.x - p1.x) + math.abs(p2.y - p1.y) + math.abs(p2.z - p1.z)
end

--gets distance along axis between p1 and p2
function getAxialDist(p1, p2, axis)
    return math.abs(p1[axis] - p2[axis])
end

--allows the turtle to follow instructions in reverse
local reverseActions = {
    [move] = moveBack,
    [moveBack] = move,

    [moveUp] = moveDown,
    [moveDown] = moveUp,

    [turnLeft] = turnRight,
    [turnRight] = turnLeft,
}

actionNames = {
    [move]      = "move",
    [moveUp]    = "moveUp",
    [moveDown]  = "moveDown",
    [turnRight] = "turnRight",
    [turnLeft]  = "turnLeft",
}

--the meta table which describes a set of actions or instructions
instructions_meta = {
    __name = "instructions",

    __tostring = function(tab)
        local out = "Actions:\n"
        for i, action in ipairs(tab) do
            out = out.."\t["..i.."] "..actionNames[action].."\n"
        end
        return out
    end,
    
    --expects a boolean argument, disableFail which specifies
    --    whether or not to continue following instructions
    --    after receiving a fail from an action
    --returns if success status (regardless of disableFail)
    --    and the index of the last successful step completed
    __call = function(tab, ...)
        local disableFail

        if #arg == 0 then
            disableFail = false
        elseif #arg == 1 and type(arg[1]) == "boolean" then
            disableFail = arg[1]
        else
            error("Instruction execution expected 1 or 0 argument(s):\n\tdisableFail (boolean)")
        end

        local success = true
        local lastSuccess

        for i, action in ipairs(tab) do
            if not stop and (disableFail or success) then
                success = action()
                if success then
                    lastSuccess = i
                end
                yeild()
            else
                break
            end
        end

        return success, lastSuccess
    end
}

function stack(tab)
    local stk = tab
    stk.top = function()
        return stk[#stk]
    end
    stk.push = function(v)
        table.insert(tab, v)
    end
    stk.pop = function()
        table.remove(tab)
    end
    stk.empty = function()
        return #stk == 0
    end
    return stk
end

--a node within the allNodes table which has numerous properties
--    that allow us to use the pathfinding algorithm to find an
--    optimal sequence of pathNodes to the target
--for the base node, ppos is nil and direction is set manually after
function pathNode(p, par)
    local d
    if par ~= nil then
        d = vector.new(p.x - par.position.x, 0, p.z - par.position.z)

        if d == zero then
            d = par.direction
        end
    end

    local node = {
        position = p,
        parent = par,
        direction = d,
        targetPos = nil,
        distFromTarget = nil,
        instructions = setmetatable({}, instructions_meta),
        runningCost = nil,
    }

    node.score = function()
        return node.distFromTarget + node.runningCost
    end

    node.marginalCost = function()
        return #node.instructions
    end

    node.calculateRunningCost = function()      
        node.instructions = genAdjMoveInstr(node.parent.position, node.parent.direction,
            node.position)
        node.runningCost = node.parent.runningCost + node.marginalCost()
    end

    setmetatable(node, pathNode_meta)

    return node
end

pathNode_meta = {
    __name = "pathNode",

    __tostring = function(tab)
        local out = "here:   ["..tab.position.x.." "..tab.position.y.." "..tab.position.z.."]\n"..
                    "dir:    ["..tab.direction.x.." "..tab.direction.y.." "..tab.direction.z.."]\n"
        if tab.parent then
            out = out.."parent: ["..tab.parent.position.x.." "..tab.parent.position.y..
                " "..tab.parent.position.z.."]\n"
        end
        if tab.runningCost and tab.distFromTarget then
            out = out.."score: "..tab.score().."\n"
        end
        if tab.runningCost then
            out = out.."Running cost: "..tab.runningCost.."\n"
        end
        out = out..tostring(tab.instructions)
        return  out
    end,

    __lt = function(lhs, rhs)
        if type(lhs) ~= type(rhs) then
            error("Cannot compare "..type(lhs).." and "..type(rhs))
        end

        --known nodes are almost always a better choice than unknown
        if getBlock(lhs.position) and not getBlock(rhs.position) then
            return lhs.score() < 10 * rhs.score()
        elseif not getBlock(lhs.position) and getBlock(rhs.position) then
            return 10 * lhs.score() < rhs.score()
        end

        if lhs.score() == rhs.score() then            
            return lhs.distFromTarget < rhs.distFromTarget
        end

        return lhs.score() < rhs.score()
    end,

    __eq = function(lhs, rhs)
        if type(lhs) ~= type(rhs) then
            error("Cannot compare "..type(lhs).." and "..type(rhs))
        end

        return lhs.position == rhs.position
    end,
}

--find adjacent, navigable nodes to pathNode p
function findAdjNodes(node)
    local adjNodes = {}
    local v

    local testDir = function(direction)
        v = node.position + direction
        if (not node.parent or v ~= node.parent.position) and 
            (isNavigable(v) or (mineMode and isMineable(v))) and
            (not restrictMode or isWithinRegion(v)) then
            
            table.insert(adjNodes, pathNode(v, node))
        end
    end 

    testDir(east)
    testDir(up)
    testDir(south)

    testDir(west)
    testDir(down)
    testDir(north)

    return adjNodes
end

function getNode(nodes, pos)
    local x = pos.x
    local y = pos.y
    local z = pos.z

    if x == 0 then x = 2147483647 end
    if y == 0 then y = 2147483647 end
    if z == 0 then z = 2147483647 end

    if nodes and nodes[x] and nodes[x][y]
        and nodes[x][y][z] then

        return nodes[x][y][z]
    else
        return nil
    end
end

function setNode(nodes, loc, node)
    local x = loc.x
    local y = loc.y
    local z = loc.z

    if x == 0 then x = 2147483647 end
    if y == 0 then y = 2147483647 end
    if z == 0 then z = 2147483647 end

    if not nodes[x] then
        nodes[x] = {[y] = {[z] = node}}
    elseif not nodes[x][y] then
        table.insert(nodes[x], y, {[z] = node})
    elseif not nodes[x][y][z] then
        table.insert(nodes[x][y], z, node)
    else
        nodes[x][y][z] = node
    end
end

function addNode(adj, nodes, toBeProcessed, target)
    --set the distance values
    adj.distFromTarget = getDist(target, adj.position)
    adj.calculateRunningCost()

    --old is not nil if adj is a duplicate node
    --replace old with adj if adj is a better choice otherwise dont add
    local old = getNode(nodes, adj.position)
    if old and not (adj < old) then
        return
    end

    setNode(nodes, adj.position, adj)

    --first loop through to find where to insert new node
    local i = 1
    while (i <= #toBeProcessed) do
        if adj < toBeProcessed[i] then
            break
        end

        i = i + 1
    end

    --insertion is outside of loop just in case #toBeProcessed == 0
    table.insert(toBeProcessed, i, adj)
    i = i + 1 --increment so next loop does not remove this node

    --then continue looping through the rest to ensure no duplicates
    while (i <= #toBeProcessed) do
        if adj == toBeProcessed[i] then
            table.remove(toBeProcessed, i)
            break
        end

        i = i + 1
    end
end

function processNext(nodes, toBeProcessed, target)
    local adjacent = findAdjNodes(toBeProcessed[1])
    table.remove(toBeProcessed, 1)

    for i, adj in ipairs(adjacent) do
        addNode(adj, nodes, toBeProcessed, target)
    end
end

--returns the path which it returns as a stack of pathNodes
function findPath(start_pos, start_dir, target)
    local baseNode = pathNode(start_pos, nil)
    baseNode.distFromTarget = getDist(start_pos, target)
    baseNode.direction = start_dir
    baseNode.runningCost = 0

    toBeProcessed = {baseNode}
    local nodes = {}
    setNode(nodes, start_pos, baseNode)

    local iterations = 0

    while (not go and not stop and #toBeProcessed ~= 0
        and getDist(toBeProcessed[1].position, target) > distReq) do
        
        processNext(nodes, toBeProcessed, target)

        if #toBeProcessed ~= 0 and not getBlock(toBeProcessed[1].position) then
            iterations = iterations + 1
            if iterations >= iterationsMax then
                break
            end
        end

        yeild()
    end

    local node = toBeProcessed[1]

    local path = stack {}
    while node and node ~= baseNode do
        path.push(node)
        node = node.parent
    end

    return path
end

function compilePathInstructions(path)
    local instructions = setmetatable({}, instructions_meta)
    
    while not path.empty() do
        for i, instr in ipairs(path.top().instructions) do
            table.insert(instructions, instr)
        end
        path.pop()
    end

    return instructions
end

function gotoGlobalTarget()
    stop = false
    go = false

    local path
    local instructions
    
    local success = false
    local fails = 0

    while (not go and not stop and (getDist(pos, globalTarget) > distReq or not success)) do
        fails = fails + 1
        path = findPath(pos, dir, globalTarget)
        if not path then
            stop = true
            print("path could not be found")
        end
        instructions = compilePathInstructions(path)
        success = instructions()
    end
    
    return getDist(pos, globalTarget) > distReq
end

function pathFind(t, dist)
    distReq = dist or 0
    globalTarget = t
    parallel.waitForAny(gotoGlobalTarget, listen)
end

function yeild()
    os.queueEvent("empty_event")
    coroutine.yield()
end

function listen()
    local modem = peripheral.wrap("left")
    modem.open(1)

    while not stop do
        local _, _, _, replyFreq, msg = os.pullEvent("modem_message")

        if msg == "stop" then
            stop = true
        elseif msg == "go" then
            go = true
        elseif msg == "where" then
            modem.transmit(replyFreq, _, "position: "..pos.x.." "..pos.y.." "..pos.z)
        elseif msg == "inspect length" then
            print(#toBeProcessed)
        elseif msg == "inspect top" then
            print(toBeProcessed[1])
        end
        coroutine.yield()
    end
end