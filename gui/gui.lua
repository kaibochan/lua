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
    globalX = 1,
    globalY = 1,
    x = 1,
    y = 1,
    width = 1,
    height = 1,
    visible = true,
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
        o.globalX, o.globalY = o:getGlobalPos(o.x, o.y)
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

function Element:setGlobalPos(x, y)
    self.globalX = x
    self.globalY = y

    self.x, self.y = self:getParentLocalPos(x, y)

    for _, child in ipairs(self.children) do
        child:setPos(child.x, child.y)
    end
end

--[[
    sets new position of element relative to parent, children are moved accordingly
]]
function Element:setPos(x, y)
    self.x = x
    self.y = y

    self.globalX, self.globalY = self:getGlobalPos(x, y)

    for _, child in ipairs(self.children) do
        child:setPos(child.x, child.y)
    end
end

--[[
    gets displacement of point x, y relative to global coordinates
]]
function Element:getLocalPos(x, y)
    local lx = x - self.globalX
    local ly = y - self.globalY

    return lx, ly
end

--[[
    gets the local coordinates of an element in relation to it's parent
]]
function Element:getParentLocalPos(x, y)
    --global x, y
    local lx = self.globalX - self.parent.globalX + 1
    local ly = self.globalY - self.parent.globalY + 1

    return lx, ly
end

--[[
    gets the global coordinates of an element
]]
function Element:getGlobalPos(x, y)
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

    return gx, gy
end

--[[
    converts to global coordinates and then test for if x and y are within bounds
]]
function Element:selected(x, y)
    if not self.visible then
        return false
    end

    return x >= self.globalX and x < self.globalX + self.width and y >= self.globalY and y < self.globalY + self.height
end

--[[
    set background color for element
]]
function Element:setBackgroundColor(color)
    for x = 1, self.width do
        for y = 1, self.height do
            self.cells[x][y].backgroundColor = color
        end
    end
end

--[[
    set whether an element is visible or not
]]
function Element:setVisibility(isVisible)
    self.visible = isVisible
end

--[[
    draw children, then draw to parent's canvas if parent exists, otherwise draw to display
]]
function Element:draw()
    if not self.visible then
        return
    end

    --lx and ly are local x, y within an element
    for ly = 1, self.height do
        local characters = ""
        local textColors = ""
        local backgroundColors = ""

        local gy = ly + self.globalY - 1
        local gx = self.globalX

        for lx = 1, self.width do
            --px and py are x, y within parent element

            characters = characters .. self.cells[lx][ly].character
            textColors = textColors .. colors.toBlit(self.cells[lx][ly].textColor)
            backgroundColors = backgroundColors ..  colors.toBlit(self.cells[lx][ly].backgroundColor)
        end

        term.setCursorPos(gx, gy)
        term.blit(characters, textColors, backgroundColors)
    end

    for _, child in ipairs(self.children) do
        child:draw()
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

--[[
    set the text for a Text element
]]
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
    
    while stringBegin <= #text do
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

--[[
    set the text color for a Text element
]]
function Text:setTextColor(color)
    for x = 1, self.width do
        for y = 1, self.height do
            self.cells[x][y].textColor = color
        end
    end
end

--[[
    depth first search to find selected element given an x and y
]]
function getSelectedElement(element, x, y)
    local selectedElement

    --iterate over elements backwards to grab elements drawn on top first
    for i = #element.children, 1, -1 do
        selectedElement = getSelectedElement(element.children[i], x, y)

        if selectedElement then
            return selectedElement
        end
    end

    if element:selected(x, y) then
        return element
    end
end

--[[
    registered callbacks for each user input event
]]
callbacks = {
    ["mouse_click"] = {},
    ["mouse_drag"] = {},
    ["mouse_scroll"] = {},
    ["mouse_up"] = {},
    ["key"] = {},
    ["key_up"] = {},
}

--[[
    register callback functions for various mouse and keyboard events
]]
function registerCallback(event, element, callback)
    if callbacks[event] then
        callbacks[event][element.name] = callback
    else
        callbacks[event] = {[element.name] = callback}
    end
end