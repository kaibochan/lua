require "gui"

local buffer
local canvas

local penButton
local fillButton
local undoButton
local redoButton

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

function initializeElements()
    local device = peripheral.find("monitor")

    if not device then
        device = term
    end

    buffer = createBuffer(device, "buffer", colors.white)

    whiteboard = Canvas:new {
        name = "whiteboard",
        parent = buffer,
        buffer = buffer,
        width = buffer.width,
        height = buffer.height,
    }

    for index, color in ipairs(orderedColors) do
        switchToColorButton = Button:new {
            name = color.name,
            parent = buffer,
            buffer = buffer,
            backgroundColor = color.color,
            x = index,
            y = buffer.height,
            onClickName = color.name,
            onClick = function(self)
                whiteboard.currentColor = color.color
            end,
        }
    end

    penButton = Button:new {
        name = "pen",
        parent = buffer,
        buffer = buffer,
        text = "pen",
        x = buffer.width - 3,
        y = buffer.height,
        width = 3,
        height =  1,
        onClickName = "switchToPen",
        onClick = function(self)
            whiteboard.currentDrawAction = whiteboard.pen
        end,
    }

    fillButton = Button:new {
        name = "fill",
        parent = buffer,
        buffer = buffer,
        text = "fill",
        x = buffer.width - 8,
        y = buffer.height,
        width = 4,
        height =  1,
        onClickName = "switchToFill",
        onClick = function(self)
            whiteboard.currentDrawAction = whiteboard.fill
        end,
    }

    clearButton = Button:new {
        name = "clear",
        parent = buffer,
        buffer = buffer,
        text = "clear",
        x = buffer.width - 5,
        y = 1,
        width = 5,
        height =  1,
        onClickName = "clear",
        onClick = function(self)
            whiteboard:clear()
        end,
    }

    undoButton = Button:new {
        name = "undo",
        parent = buffer,
        buffer = buffer,
        text = "undo",
        x = buffer.width - 10,
        y = 1,
        width = 4,
        height =  1,
        onClickName = "undo",
        onClick = function(self)
            whiteboard:undo()
        end,
    }

    redoButton = Button:new {
        name = "redo",
        parent = buffer,
        buffer = buffer,
        text = "redo",
        x = buffer.width - 15,
        y = 1,
        width = 4,
        height =  1,
        onClickName = "redo",
        onClick = function(self)
            whiteboard:redo()
        end,
    }
end

local function main()
    initializeElements()

    while true do
        buffer:draw()
        parallel.waitForAny(handleInputEvents)
    end
end

main()