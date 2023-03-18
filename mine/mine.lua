--min and max bounds of mining area
local min
local max

local majAxis
local minAxis

local initialPos
local initialDir
local initialHeading

local storagePos

local heading

local prevPos
local prevDir
local prevHeading

local currentSlot

local finished = false
local failed = false
local full = false

function initialize(p1, p2, stPos, prev)
    finished = false
    failed = false
    full = false

    nav.useBlacklist()

    min, max = nav.composeMinMaxPoints(p1, p2)
    calcMajorMinorAxes()

    setupInitialState(p1, p2)
    setStoragePos(stPos)

    --get close to starting block without mining blocks unnecessarily
    nav.pathFind(initialPos, 1)
    nav.setMineMode(true)
    reset()

    if prev then
        nav.pathFind(prev)
        correctDir()
        correctHeading()
    end
end

function setupInitialState(p1, p2)
    local initPos = p1

    local initDir = vector.new(0, 0, 0)
    if p2[getMajAxis()] - p1[getMajAxis()] >= 0 then
        initDir[getMajAxis()] = 1
    else
        initDir[getMajAxis()] = -1
    end

    local initHead = vector.new(0, 0, 0)
    if p2[getMinAxis()] - p1[getMinAxis()] >= 0 then
        initHead[getMinAxis()] = 1
    else
        initHead[getMinAxis()] = -1
    end

    initialPos = initPos
    initialDir = initDir
    initialHeading = initHead
end

function setStoragePos(stPos)
    storagePos = stPos
end

function calcMajorMinorAxes()
    if max.x - min.x >= max.z - min.z then
        majAxis = "x"
        minAxis = "z"
    else
        majAxis = "z"
        minAxis = "x"
    end
end

function getMajAxis()
    return majAxis
end

function getMinAxis()
    return minAxis
end

function processItem()
    if not full then
        turtle.select(currentSlot)
        
        if turtle.getItemCount(currentSlot) ~= 0 then
            currentSlot = currentSlot + 1
            if (currentSlot > 16) then
                full = true
            end
        end

        turtle.select(1)
    end
end

--process iteration
function process()
    nav.move()
    processItem()
end

function processDown()
    nav.moveDown()
    processItem()
end

function processUp()
    nav.moveUp()
    processItem()
end

function processHorzEdge()
    prev_d = nav.getDir()
    
    nav.face(heading)
    process()
    nav.face(-prev_d)
end

function processVertEdge()
    processDown()
    nav.face(-nav.getDir())
    heading = -heading
end

function storeItems()
    local success, block = turtle.inspectDown()
    
    if success and (block.tags["forge:chests"] or string.find(block.name, "chest")) then
        currentSlot = 1
        while (currentSlot <= 16) do
            turtle.select(currentSlot)
            turtle.dropDown() 
            currentSlot = currentSlot + 1
        end
    else
        fail()
    end
    
    full = false
    currentSlot = 1
    turtle.select(currentSlot)
end

function storeCurrentState()
    prevPos = nav.getPos()
    prevDir = nav.getDir()
    prevHeading = heading
end

function restorePreviousState()
    nav.pathFind(prevPos)
    nav.face(prevDir)
    heading = prevHeading
end

function gotoInitial()
    nav.pathFind(initialPos)
    nav.face(initialDir)
    heading = initialHeading
end

function reset()
    gotoInitial()
    nav.setMineMode(true)
    nav.setRestriction(min, max)
    currentSlot = 1
end

function gotoStorage()
    nav.clearRestriction()
    nav.setMineMode(false)
    nav.pathFind(storagePos)
end

function fail()
    failed = true
end

function storeAndReturn()
    storeCurrentState()
    gotoInitial()

    gotoStorage()
    storeItems()

    reset()
    restorePreviousState()
end

--gets distance from initialPos along major axis
function getMajDist()
    return nav.getAxialDist(nav.getPos(), initialPos, majAxis)
end

--gets distance from initialPos along minor axis
function getMinDist()
    return nav.getAxialDist(nav.getPos(), initialPos, minAxis)
end

function getYDist()
    return nav.getAxialDist(nav.getPos(), initialPos, "y")
end

function correctDir()
    nav.face(initialDir * (1 - 2 * (getMinDist() % 2)) * (1 - 2 * (getYDist() % 2)))
end

function correctHeading()
    heading = initialHeading * (1 - 2 * (getYDist() % 2))
end

--mine out designated area or return
--    to storage if inventory full
function mineRegion()
    while not finished and not failed do
        if not nav.isWithinRegion(nav.getPos() + nav.getDir()) then
            if not nav.isWithinRegion(nav.getPos() + heading) then
                if not nav.isWithinRegion(nav.getPos() + nav.down) then
                    finished = true
                    gotoInitial()

                    gotoStorage()
                    storeItems()
                else
                    processVertEdge()
                end
            else
                processHorzEdge()
            end
        else
            process()
        end
        
        if full then
            storeAndReturn()
        end
    end
end