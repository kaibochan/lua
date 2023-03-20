align = {
    top = "top",
    left = "left",
    center = "center",
    right = "right",
    bottom = "bottom",
}

Cell = {
    backgroundColor = colors.black,
    textColor = colors.white,
    character = " ",
}

function Cell:new (o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

Element = {
    class = "Element",
    parent = nil,
    children = {},
    x = 1,
    y = 1,
    width = 1,
    height = 1,
    backgroundColor = colors.black,
    transparentBackground = false,
    cells = {},
}
    
function Element:new (o)
    o = o or {}

    --tables are passed by reference so new ones must be created if not passed in
    o.cells = o.cells or {}
    o.children = o.children or {}

    setmetatable(o, self)
    self.__index = self

    if o.parent then
        table.insert(o.parent.children, o)
    end

    local cell

    for x = 1, o.width do
        for y = 1, o.height do
            cell = Cell:new{backgroundColor = o.backgroundColor}
            if not o.cells[x] then
                table.insert(o.cells, x, {[y] = cell})
            else
                table.insert(o.cells[x], y, cell)
            end
        end
    end

    return o
end

function Element:selected(x, y)
    --global x, y
    local gx, gy

    local element = self
    gx = element.x
    gy = element.y
    while element.parent do
        gx = gx + element.parent.x - 1
        gy = gy + element.parent.y - 1
        element = element.parent
    end

    return x >= gx and x < gx + self.width and y >= gy and y < gy + self.height
end

function Element:setBackgroundColor(color)
    for x = 1, self.width do
        for y = 1, self.height do
            self.cells[x][y].backgroundColor = color
        end
    end
end

function Element:draw()
    for _, child in ipairs(self.children) do
        child:draw()
    end

    local px, py

    --code is repeated here so we don't run the parent check (width * height) times, only once
    if self.parent then
        --lx and ly are local x, y within an element
        for lx = 1, self.width do
            for ly = 1, self.height do
                --px and py are x, y within parent element
                px = lx + self.x - 1
                py = ly + self.y - 1

                if not self.transparentBackground then
                    self.parent.cells[px][py].backgroundColor = self.cells[lx][ly].backgroundColor
                end
                self.parent.cells[px][py].textColor = self.cells[lx][ly].textColor
                self.parent.cells[px][py].character = self.cells[lx][ly].character
            end
        end
    else
        --lx and ly are local x, y within an element
        for lx = 1, self.width do
            for ly = 1, self.height do
                --px and py are x, y within parent element
                px = lx + self.x - 1
                py = ly + self.y - 1

                term.setCursorPos(px, py)
                term.setBackgroundColor(self.cells[lx][ly].backgroundColor)
                term.setTextColor(self.cells[lx][ly].textColor)
                term.write(self.cells[lx][ly].character)
            end
        end
    end
end

Text = Element:new {
    class = "Text",
    text = "",
    padding = 0,
    horizontalAlignment = align.left,
    verticalAlignment = align.top,
    textColor = colors.white,
}

function Text:new(o)
    o = o or {}
    o = Element:new(o)

    setmetatable(o, self)
    self.__index = self

    for x = 1, o.width do
        for y = 1, o.height do
            o.cells[x][y] = Cell:new{
                backgroundColor = o.backgroundColor,
                textColor = o.textColor,
            }
        end
    end

    o:setText(o.text)

    return o
end

function Text:setText(text)
    for x = 1, self.width do
        for y = 1, self.height do
            self.cells[x][y].character = " "
        end
    end

    local textRows = {}

    local stringBegin = 1
    local rowWidth = self.width - self.padding * 2
    local stringEnd = stringBegin + rowWidth - 1
    local newLineIndex = text:find("\n", stringBegin, true)
    local substring
    
    while stringBegin < #text do
        if newLineIndex and newLineIndex < stringBegin then
            newLineIndex = text:find("\n", stringBegin, true)
        end
        
        if newLineIndex and newLineIndex < stringEnd then
            substring = text:sub(stringBegin, newLineIndex - 1)
            stringBegin = newLineIndex + 1
        else
            substring = text:sub(stringBegin, stringEnd)
            stringBegin = stringEnd + 1
        end
        
        stringEnd = stringBegin + rowWidth - 1
        
        table.insert(textRows, substring)
    end
    
    local verticalOffset
    if self.verticalAlignment == align.top then
        verticalOffset = self.padding
    elseif self.verticalAlignment == align.center then
        verticalOffset = self.height / 2 - #textRows / 2
    elseif self.verticalAlignment == align.bottom then
        verticalOffset = self.height - self.padding - #textRows
    end
    
    local horizontalOffsets = {}
    for index, _ in ipairs(textRows) do
        if self.horizontalAlignment == align.left then
            table.insert(horizontalOffsets, self.padding)
        elseif self.horizontalAlignment == align.center then
            table.insert(horizontalOffsets, self.width / 2 - #textRows[index] / 2)
        elseif self.horizontalAlignment == align.right then
            table.insert(horizontalOffsets, self.width - self.padding - #textRows[index])
        end
    end

    local substringIndex = 1
    local rowIndex = 1

    for y = 1, self.height do
        if y > verticalOffset and y <= verticalOffset + #textRows then
            substringIndex = 1

            for x = 1, self.width do
                if x > horizontalOffsets[rowIndex] and x <= horizontalOffsets[rowIndex] + #textRows[rowIndex] then
                    self.cells[x][y].character = textRows[rowIndex]:sub(substringIndex, substringIndex)
                    substringIndex = substringIndex + 1
                end
            end

            rowIndex = rowIndex + 1
        end
    end
end

function Text:setTextColor(color)
    for x = 1, self.width do
        for y = 1, self.height do
            self.cells[x][y].textColor = color
        end
    end
end

function getSelectedElement(element, x, y)
    local selectedElement

    for _, child in ipairs(element.children) do
        if #child.children ~= 0 then
            selectedElement = getSelectedElement(child, x, y)
        end
        if not selectedElement and child:selected(x, y) then
            return child
        end
    end

    if element:selected(x, y) then
        return element
    end
end

local callbacks = {
    ["mouse_click"] = {},
    ["mouse_drag"] = {},
    ["mouse_scroll"] = {},
    ["mouse_up"] = {},
    ["key"] = {},
    ["key_up"] = {},
}

function registerCallback(event, element, callback)
    if callbacks[event] then
        callbacks[event][element.name] = callback
    else
        callbacks[event] = {[element.name] = callback}
    end
end

local width, height = term.getSize()

local main = Element:new {
    name = "main",
    width = width,
    height = height,
    backgroundColor = colors.brown
}

registerCallback("mouse_click", main, mainClick)

local button1 = Text:new {
    name = "button1",
    parent = main,
    x = 2,
    text = "lorem ipsum",
    horizontalAlignment = align.center,
    verticalAlignment = align.center,
    backgroundColor = colors.red,
    width = 11,
    height = 1,
    padding = 0,
}

local function button1Click(button, x, y)
    if button == 1 then
        button1:setBackgroundColor(2^math.random(15))
    end
end

registerCallback("mouse_click", button1, button1Click)

local button2 = Text:new {
    name = "button2",
    parent = main,
    x = 5,
    y = 3,
    text = "kaibochan",
    horizontalAlignment = align.center,
    verticalAlignment = align.center,
    backgroundColor = colors.blue,
    width = 11,
    height = 1,
    padding = 0,
}

local function button2Click(button, x, y)
    if button == 1 then
        button2:setBackgroundColor(2^math.random(15))
    elseif button == 2 then
        button2:setTextColor(2^math.random(15))
    end
end

registerCallback("mouse_click", button2, button2Click)

local text = Text:new {
    name = "text",
    parent = main,
    y = 5,
    text = "lorem ipsum",
    horizontalAlignment = align.center,
    verticalAlignment = align.center,
    transparentBackground = true,
    width = 20,
    height = 4,
}

local selectedElement = main


while true do
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()

    text:setText(selectedElement.name)
    main:draw()

    local event, button, x, y = os.pullEvent()
    if event == "mouse_click" then
        selectedElement = getSelectedElement(main, x, y)
        if callbacks[event][selectedElement.name] then
            callbacks[event][selectedElement.name](button, x, y)
        end
    end
end