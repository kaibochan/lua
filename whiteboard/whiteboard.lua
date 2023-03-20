local monitor
local pixels = {}

--pixels history is an indexed table that saves
--the x, y, and color of pixels before they are changed
--so we can go back through pixelsHistory and use it to undo
local pixelsHistory = {}
local maxUndo = 100
local historyIndex = 1

local buttons = {}
local drawAction

--ordered colors table with both name and color value available
local orderedColors = {
    {["name"] = "red",      ["color"] = colors.red},
    {["name"] = "orange",   ["color"] = colors.orange},
    {["name"] = "yellow",   ["color"] = colors.yellow},
    {["name"] = "lime",     ["color"] = colors.lime},
    {["name"] = "green",    ["color"] = colors.green},
    {["name"] = "cyan",     ["color"] = colors.cyan},
    {["name"] = "blue",     ["color"] = colors.blue},
    {["name"] = "purple",   ["color"] = colors.purple},
    {["name"] = "magenta",  ["color"] = colors.magenta},
    {["name"] = "pink",     ["color"] = colors.pink},
    {["name"] = "brown",    ["color"] = colors.brown},
    {["name"] = "white",    ["color"] = colors.white},
    {["name"] = "lightGray",["color"] = colors.lightGray},
    {["name"] = "gray",     ["color"] = colors.gray},
    {["name"] = "black",    ["color"] = colors.black},
}

--[[
    generalized setting of data for a double indexed table
]]
local function setValue(tab, i, j, value)
    if not tab[i] then
        table.insert(tab, i, {[j] = value})
    else
        table.insert(tab[i], j, value)
    end
end

--[[
    generalized retrieval of data from a double indexed table
]]
local function getValue(tab, i, j)
    if tab and tab[i] and tab[i][j] then
        return tab[i][j]
    end

    return nil
end

--[[
    add new undo entry and remove oldest if more entries than undoMax
]]
local function addNewHistory()
    table.insert(pixelsHistory, historyIndex, {})
    if #pixelsHistory > maxUndo then
        table.remove(pixelsHistory, maxUndo + 1)
    end

    for i = 1, historyIndex - 1 do
        table.remove(pixelsHistory, 1)
    end

    historyIndex = 1
end

--[[
    save previous pixel color and set pixel to new color
]]
local function setPixel(x, y, color)
    table.insert(pixelsHistory[historyIndex + 1], {["x"] = x, ["y"] = y, ["color"] = pixels[x][y]})
    pixels[x][y] = color
    table.insert(pixelsHistory[historyIndex], {["x"] = x, ["y"] = y, ["color"] = pixels[x][y]})
end

--[[
    creates pixel entries for each pixel on the screen and sets them to white
]]
local function initializePixels()
    local width, height = monitor.getSize()

    addNewHistory()

    for x = 1, width do
        for y = 1, height do
            setValue(pixels, x, y, colors.white)
            table.insert(pixelsHistory[historyIndex], {["x"] = x, ["y"] = y, ["color"] = pixels[x][y]})
        end
    end
end

--[[
    updates whiteboard according to the pixels data table
]]
local function drawPixels()
    local currentColor = monitor.getBackgroundColor()

    local width, height = monitor.getSize()

    for x = 1, width do
        for y = 1, height do
            monitor.setBackgroundColor(getValue(pixels, x, y))
            monitor.setCursorPos(x, y)
            monitor.write(" ")
        end
    end

    monitor.setBackgroundColor(currentColor)
end

--[[
    draws all buttons according to their location, text, and background color
]]
local function drawButtons(display, buttons)
    local currentColor = display.getBackgroundColor()

    for _, button in pairs(buttons) do
        display.setCursorPos(button.bounds.topLeft.x, button.bounds.topLeft.y)
        display.setBackgroundColor(button.currentColor)
        display.setTextColor(button.textColor)
        display.write(button.text)
    end

    display.setBackgroundColor(currentColor)
end

--[[
    update entire whiteboard according to the pixels data table
    and then draw buttons
]]
local function drawWhiteboard()
    drawPixels()
    drawButtons(monitor, buttons)
end

--[[
    sets the pixel at x, y to the currently selected color
]]
local function draw(x, y)
    local color = monitor.getBackgroundColor()

    if pixels[x][y] == color then
        return
    end

    addNewHistory()
    setPixel(x, y, color)

    monitor.setCursorPos(x, y)
    monitor.write(" ")
end

--[[
    highlights the button that is passed in
]]
local function highlightButton(button)
    button.currentColor = button.highlightColor
end

--[[
    unhighlight the button that is passed in
]]
local function unhighlightButton(button)
    button.currentColor = button.backgroundColor
end

--[[
    fills all adjacent, connected pixels of the same color
]]
local function fillArea(startX, startY)
    local color = pixels[startX][startY]

    --if color of pixel selected is the same as the current color then do nothing
    if pixels[startX][startY] == monitor.getBackgroundColor() then
        return
    end

    --toProcess contains potential pixels to be filled
    --nodes contains all already processed pixels to avoid processing again
    local toProcess = {}
    table.insert(toProcess, {["x"] = startX, ["y"] = startY})
    local nodes = {}
    setValue(nodes, startX, startY, color)
    local pixelsToFill = {}

    local width, height = monitor.getSize()
    local x, y

    while #toProcess ~= 0 do
        x = toProcess[1].x
        y = toProcess[1].y

        --if current pixel is of the same color as the pixel selected then add all
        --it's adjacent neighbors to toProcess to be processed in another iteration
        if pixels[x][y] == color then
            --add to pixels to fill
            table.insert(pixelsToFill, {["x"] = x, ["y"] = y})
            
            --add adjacent, unprocessed pixels to toProcess
            if x + 1 <= width and not getValue(nodes, x + 1, y) then
                table.insert(toProcess, {["x"] = x + 1, ["y"] = y})
                setValue(nodes, x + 1, y, color)
            end

            if x - 1 >= 1 and not getValue(nodes, x - 1, y) then
                table.insert(toProcess, {["x"] = x - 1, ["y"] = y})
                setValue(nodes, x - 1, y, color)
            end

            if y + 1 <= height and not getValue(nodes, x, y + 1) then
                table.insert(toProcess, {["x"] = x, ["y"] = y + 1})

                setValue(nodes, x, y + 1, color)
            end

            if y - 1 >= 1 and not getValue(nodes, x, y - 1) then
                table.insert(toProcess, {["x"] = x, ["y"] = y - 1})
                setValue(nodes, x, y - 1, color)
            end
        end
        
        table.remove(toProcess, 1)
    end

    addNewHistory()

    --set all pixels to be filled to the currently selected color
    for _, location in ipairs(pixelsToFill) do
        setPixel(location.x, location.y, monitor.getBackgroundColor())
    end

    drawWhiteboard()
end

--[[
    allow user to clear whiteboard back to default state
]]
local function clear()
    local width, height = monitor.getSize()
    
    addNewHistory()
    
    for x = 1, width do
        for y = 1, height do
            setPixel(x, y, colors.white)
        end
    end

    drawWhiteboard()
end

--[[
    allow user to undo actions that change whiteboard pixels
    such as fill, draw, clear, and load
]]
local function undo()
    if historyIndex >= #pixelsHistory or historyIndex < 1 then
        return
    end

    historyIndex = historyIndex + 1

    for _, pixel in ipairs(pixelsHistory[historyIndex]) do
        pixels[pixel.x][pixel.y] = pixel.color
    end

    drawWhiteboard()
end

--[[
    allow user to redo actions
]]
local function redo()
    if historyIndex > #pixelsHistory or historyIndex <= 1 then
        return
    end
    
    historyIndex = historyIndex - 1

    for _, pixel in ipairs(pixelsHistory[historyIndex]) do
        pixels[pixel.x][pixel.y] = pixel.color
    end

    drawWhiteboard()
end

--[[
    gets all drives connected and returns the file paths for each one
]]
local function getDrivePaths()
    local allPeripherals = peripheral.getNames()
    local drivePaths = {}

    for _, periph in ipairs(allPeripherals) do
        if peripheral.getType(periph) == "drive" then
            table.insert(drivePaths, peripheral.call(periph, "getMountPath"))
        end
    end

    return drivePaths
end

--[[
    allow user to save whiteboard files to drives
    asks for overwrite confirmation if file exists
]]
local function save()
    highlightButton(buttons["save"])
    drawButtons(monitor, buttons)

    --create whiteboard filename, ex: "test" => "test.wtbd"
    write("Enter file name to save whiteboard as: ")
    local fileName = read()
    fileName = fileName..".wtbd"

    local drivePaths = getDrivePaths()

    local fileSaved = false
    local filePath

    --create local file to be moved to drives, local is created first so we can get file size
    local whiteboardFile = fs.open(fileName, "w")
    whiteboardFile.write(textutils.serialise(pixels))
    whiteboardFile.close()

    local confirmation

    --look for existing whiteboard file and replace it if overwriting
    for _, drivePath in ipairs(drivePaths) do
        filePath = drivePath.."/"..fileName

        if fs.exists(filePath) then
            local invalidResponse = true

            --get user overwrite confirmation
            while invalidResponse do
                term.clear()
                term.setCursorPos(1, 1)
                print(fileName.." already exists.")
                write("Do you want to overwrite it? ")

                local completion = require("cc.completion")
                local responses = {"yes", "no"}

                local saveConfirmAutocomplete = function(text)
                    return completion.choice(text, responses)
                end

                confirmation = read(nil, nil, saveConfirmAutocomplete)

                if confirmation == "yes" then
                    fs.delete(filePath)
                    fs.move(fileName, filePath)
                    
                    fileSaved = true
                    invalidResponse = false
                elseif confirmation == "no" then
                    invalidResponse = false
                else
                    term.clear()
                    term.setCursorPos(1, 1)
                    write("Invalid response. Please answer 'yes' or 'no'.")
                    sleep(3)
                end
            end
        end
    end

    --if no already existing whiteboard file then find free space in drives and save
    if not fileSaved and confirmation ~= "no" then
        for _, drivePath in ipairs(drivePaths) do
            filePath = drivePath.."/"..fileName

            if fs.getSize(fileName) <= fs.getFreeSpace(drivePath) then
                fs.move(fileName, filePath)
                fileSaved = true
                break
            end
        end
    end

    --if file has still not been saved, then there was not enough space to save it
    if not fileSaved and confirmation ~= "no" then
        fs.delete(fileName)

        term.clear()
        term.setCursorPos(1, 1)
        write("Not enough space to save "..fileName)
        sleep(3)
    end

    term.clear()
    term.setCursorPos(1, 1)

    unhighlightButton(buttons["save"])
    drawButtons(monitor, buttons)
end

--[[
    allows user to load whiteboard files from the connected drives
]]
local function load()
    highlightButton(buttons["load"])
    drawButtons(monitor, buttons)

    local drivePaths = getDrivePaths()
    local allWhiteboards = {}

    --create file name autocompletion list
    for _, drivePath in ipairs(drivePaths) do
        for _, whiteboardPath in ipairs(fs.find(drivePath.."/*.wtbd")) do
            if whiteboardPath:find("/") and whiteboardPath:find(".", _, true) then
                table.insert(allWhiteboards, whiteboardPath:sub(whiteboardPath:find("/") + 1, whiteboardPath:find(".", _, true) - 1))
            end
        end
    end

    local completion = require("cc.completion")

    local loadAutocomplete = function(text)
        return completion.choice(text, allWhiteboards)
    end

    write("Enter file name to load whiteboard: ")
    local fileName = read(nil, nil, loadAutocomplete)
    fileName = fileName..".wtbd"

    local fileFound = false
    local filePath

    --search for inputted file name across all drives
    for _, drivePath in ipairs(drivePaths) do
        filePath = drivePath.."/"..fileName
        
        if fs.exists(filePath) then
            fileFound = true

            local whiteboardFile = fs.open(filePath, "r")

            local width, height = monitor.getSize()
            
            local loadedPixels = textutils.unserialise(whiteboardFile.readAll())
            addNewHistory()

            for x = 1, width do
                for y = 1, height do
                    setPixel(x, y, loadedPixels[x][y])
                end
            end

            whiteboardFile.close()

            break
        end
    end

    --inform user if file was unable to be found
    if not fileFound then
        term.clear()
        term.setCursorPos(1, 1)
        write(fileName.." does not exist")
        sleep(3)
    end

    term.clear()
    term.setCursorPos(1, 1)

    unhighlightButton(buttons["load"])
    drawWhiteboard()
end

--[[
    allows user to switch drawAction to fill
]]
local function switchToFill()
    drawAction = fillArea

    highlightButton(buttons["fill"])
    unhighlightButton(buttons["pen"])
    drawButtons(monitor, buttons)
end

--[[
    allows user to switch drawAction to pen
]]
local function switchToPen()
    drawAction = draw

    highlightButton(buttons["pen"])
    unhighlightButton(buttons["fill"])
    drawButtons(monitor, buttons)
end

--[[
    generalized button creation function
    --text: button text
    --bgColor: normal background color
    --hlColor: highlighted color
    --func: function to call on button click
    --x, y: location to draw button
]]
local function createButton(text, bgColor, hlColor, func, x, y)
    local button = {
        ["text"] = text,
        ["function"] = func,
        ["currentColor"] = bgColor,
        ["backgroundColor"] = bgColor,
        ["highlightColor"] = hlColor,
        ["textColor"] = colors.white,
        ["bounds"] = {
            ["topLeft"] = {
                ["x"] = x,
                ["y"] = y,
            },
            ["bottomRight"] = {
                ["x"] = x + #text - 1,
                ["y"] = y,
            },
        },
    }

    return button
end

--[[
    creates the whiteboard buttons and saves them to a buttons list
    for ease of evaluating whether or not the user has clicked a button
]]
local function initializeButtons()
    local width, height = monitor.getSize()

    for index, color in ipairs(orderedColors) do
        local switchToColor = function()
            monitor.setBackgroundColor(color.color)
        end

        buttons[color.name] = createButton(" ", color.color, color.color, switchToColor, index, height)
    end

    buttons["clear"] = createButton("clear", colors.black, colors.black, clear, width - 5, 1)
    buttons["undo"] = createButton("undo", colors.black, colors.black, undo, width - 10, 1)
    buttons["redo"] = createButton("redo", colors.black, colors.black, redo, width - 15, 1)
    buttons["save"] = createButton("save", colors.black, colors.red, save, width - 9, height)
    buttons["load"] = createButton("load", colors.black, colors.red, load, width - 4, height)
    buttons["fill"] = createButton("fill", colors.black, colors.red, switchToFill, width - 14, height)
    buttons["pen"] = createButton("pen", colors.black, colors.red, switchToPen, width - 18, height)
end

--[[
    saves the current pixels to local file startup.wtbd
    if file exists upon start of whiteboard program, then load it
]]
local function saveStartupWhiteboard()
    local whiteboardFile = fs.open("startup.wtbd", "w")
    whiteboardFile.write(textutils.serialise(pixels))
    whiteboardFile.close()
end

--[[
    upon the start of the program if startup.wtbd exists
    then it is loaded into pixels data table and drawn
]]
local function loadStartupWhiteboard()
    if fs.exists("startup.wtbd") then
        local whiteboardFile = fs.open("startup.wtbd", "r")
        local width, height = monitor.getSize()

        local loadedPixels = textutils.unserialise(whiteboardFile.readAll())

        for x = 1, width do
            for y = 1, height do
                pixels[x][y] = loadedPixels[x][y]
                table.insert(pixelsHistory[historyIndex], {["x"] = x, ["y"] = y, ["color"] = pixels[x][y]})
            end
        end
    end

    drawWhiteboard()
end

--[[
    returns the x, y location where user touched monitor
    also periodically saves current whiteboard to startup whiteboard
]]
local function getMonitorTouchLocation()
    local event, id, x, y
    
    while event ~= "monitor_touch" do
        local timer = os.startTimer(10)
        
        while event ~= "monitor_touch" and not (event == "timer" and id == timer) do
            event, id, x, y = os.pullEvent()

            if event == "timer" and id == timer then
                saveStartupWhiteboard()
            end
        end
    end

    return x, y
end

--[[
    returns the button that was clicked if any
]]
local function getButtonClicked(x, y)
    local buttonClicked

    for index, button in pairs(buttons) do
        if x >= button.bounds.topLeft.x and y >= button.bounds.topLeft.y
        and x <= button.bounds.bottomRight.x and y <= button.bounds.bottomRight.y then
            buttonClicked = button
            break
        end
    end

    return buttonClicked
end

--[[
    performs the appropriate action upon user touch event
    whether that be switching colors, clicking a button, or drawing
]]
local function evaluateMonitorTouch(x, y)
    local buttonClicked = getButtonClicked(x, y)

    if buttonClicked then
        buttonClicked["function"]()
    else
        drawAction(x, y)
    end
end

local function main()
    term.clear()
    term.setCursorPos(1, 1)

    monitor = peripheral.find("monitor")

    if not monitor then
        error("Monitor is necessary to run Whiteboard program")
    end

    initializePixels()
    initializeButtons()
    switchToPen()
    loadStartupWhiteboard()
    
    monitor.setBackgroundColor(colors.black)
    
    while true do
        local x, y = getMonitorTouchLocation()
        evaluateMonitorTouch(x, y)
    end
end

main()