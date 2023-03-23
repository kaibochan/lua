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
    textRows = {},
    padding = 0,
    horizontalAlignment = align.left,
    verticalAlignment = align.top,
    textColor = colors.white,
}

function Text:new(o)
    o = o or {}
    o = Element:new(o)

    --tables are passed by reference so new ones must be created if not passed in
    o.textRows = o.textRows or {}

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
    set the horizontal alignment and update cells accordingly
]]
function Text:setHorizontalAlignment(alignment)
    self.horizontalAlignment = alignment
    self:setText(self.text)
end

--[[
    set the vertical alignment and update cells accordingly
]]
function Text:setVerticalAlignment(alignment)
    self.verticalAlignment = alignment
    self:setText(self.text)
end

--[[
    set the text for a Text element
]]
function Text:setText(text)
    self.text = text

    for x = 1, self.width do
        for y = 1, self.height do
            self.cells[x][y].character = " "
        end
    end

    self.textRows = {}

    local stringBegin = 1
    local rowWidth = self.width - self.padding * 2
    local stringEnd = stringBegin + rowWidth - 1
    local newLineIndex = self.text:find("\n", stringBegin, true)
    local endsWithNewLine
    local substring
    
    while #self.textRows < self.height - 2 * self.padding and stringBegin <= #self.text do
        if newLineIndex and newLineIndex < stringBegin then
            newLineIndex = self.text:find("\n", stringBegin, true)
        end
        
        endsWithNewLine = false
        if newLineIndex and newLineIndex < stringEnd then
            endsWithNewLine = true
            substring = self.text:sub(stringBegin, newLineIndex - 1)
            stringBegin = newLineIndex + 1
        else
            substring = self.text:sub(stringBegin, stringEnd)
            stringBegin = stringEnd + 1
        end
        
        stringEnd = stringBegin + rowWidth - 1
        
        table.insert(self.textRows, {text = substring, hasNewLine = endsWithNewLine})
    end
    
    local verticalOffset
    if self.verticalAlignment == align.top then
        verticalOffset = self.padding
    elseif self.verticalAlignment == align.center then
        verticalOffset = self.height / 2 - #self.textRows / 2
    elseif self.verticalAlignment == align.bottom then
        verticalOffset = self.height - self.padding - #self.textRows
    end
    
    local horizontalOffsets = {}
    for index, textData in ipairs(self.textRows) do
        if self.horizontalAlignment == align.left then
            table.insert(horizontalOffsets, self.padding)
        elseif self.horizontalAlignment == align.center then
            table.insert(horizontalOffsets, self.width / 2 - #textData.text / 2)
        elseif self.horizontalAlignment == align.right then
            table.insert(horizontalOffsets, self.width - self.padding - #textData.text)
        end
    end

    local substringIndex = 1
    local rowIndex = 1

    for y = 1, self.height do
        if y > verticalOffset and y <= verticalOffset + #self.textRows then
            substringIndex = 1

            for x = 1, self.width do
                if x > horizontalOffsets[rowIndex] and x <= horizontalOffsets[rowIndex] + #self.textRows[rowIndex].text then
                    self.cells[x][y].character = self.textRows[rowIndex].text:sub(substringIndex, substringIndex)
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

Textbox = Text:new{
    cursorPos = 0,
    cursorBackgroundColor = colors.white,
    cursorTextColor = colors.black,
    cursorRowOffset = 0,
    cursorRowIndex = 1,
}

function Textbox:new(o)
    o = o or {}
    o = Text:new(o)

    setmetatable(o, self)
    self.__index = self

    o:setHorizontalAlignment(o.horizontalAlignment)
    o:setVerticalAlignment(o.verticalAlignment)

    registerCallback("char", o, Textbox.characterTyped)
    registerCallback("key", o, Textbox.keyPressed)
end

function Textbox:getCursorPosX()
    return 1
end

function Textbox:getCursorPosY()
    return 1
end

--[[
    different methods for computing the X, Y position of cursor dependent on the alignment
]]
Textbox.cursorPosComputeXY = {
    getCursorPosXLeftAligned = function(txb)
        return txb.padding + txb.cursorRowOffset + 1
    end,
    getCursorPosXRightAligned = function(txb)
        return txb.width - txb.padding - #txb.textRows[txb.cursorRowIndex].text + txb.cursorRowOffset
    end,
    getCursorPosXCenterAligned = function(txb)
        return (txb.width - #txb.textRows[txb.cursorRowIndex].text) / 2 + txb.cursorRowOffset
    end,
    getCursorPosYTopAligned = function(txb)
        return txb.padding + txb.cursorRowIndex
    end,
    getCursorPosYBottomAligned = function(txb)
        return txb.height - txb.padding - #txb.textRows + txb.cursorRowIndex
    end,
    getCursorPosYCenterAligned = function(txb)
        return (txb.height - #txb.textRows) / 2 + txb.cursorRowIndex
    end
}

--[[
    set the horizontal alignment, update cells, and change computation of X position for a given cursorPos
]]
function Textbox:setHorizontalAlignment(alignment)
    Text.setHorizontalAlignment(self, alignment)

    if self.horizontalAlignment == align.left then
        self.getCursorPosX = Textbox.cursorPosComputeXY.getCursorPosXLeftAligned
    elseif self.horizontalAlignment == align.right then
        self.getCursorPosX = Textbox.cursorPosComputeXY.getCursorPosXRightAligned
    elseif self.horizontalAlignment == align.center then
        self.getCursorPosX = Textbox.cursorPosComputeXY.getCursorPosXCenterAligned
    end
end

--[[
    set the vertical alignment, update cells, and change computation of Y position for a given cursorPos
]]
function Textbox:setVerticalAlignment(alignment)
    Text.setVerticalAlignment(self, alignment)

    if self.verticalAlignment == align.left then
        self.getCursorPosY = Textbox.cursorPosComputeXY.getCursorPosYTopAligned
    elseif self.verticalAlignment == align.right then
        self.getCursorPosY = Textbox.cursorPosComputeXY.getCursorPosYBottomAligned
    elseif self.verticalAlignment == align.center then
        self.getCursorPosY = Textbox.cursorPosComputeXY.getCursorPosYCenterAligned
    end
end

function Textbox:setCursorPos(newCursorPos)
    self.cursorPos = newCursorPos

    --update cells
    local cursorX = self:getCursorPosX()
    local cursorY = self:getCursorPosY()

    for x = 1, self.width do
        for y = 1, self.height do
            self.cells[x][y].backgroundColor = self.backgroundColor
            self.cells[x][y].textColor = self.textColor
        end
    end

    self.cells[cursorX][cursorY].backgroundColor = self.cursorBackgroundColor
    self.cells[cursorX][cursorY].textColor = self.cursorTextColor
end

function Textbox:insertCharacter(character)
    self:setText(self.text:sub(0, self.cursorPos)..character..self.text:sub(self.cursorPos + 1))
    self:setCursorPos(self.cursorPos + 1)
end

function Textbox.characterTyped(txb, event, character)
    txb:insertCharacter(character)
end

function Textbox.keyPressed(txb, event, key, isHeld)
    local keyName = keys.getName(key)

    if keyName == "left" and txb.cursorPos > 0 then
        txb:setCursorPos(txb.cursorPos - 1)
    elseif keyName == "right" and txb.cursorPos <= #txb.text then
        txb:setCursorPos(txb.cursorPos + 1)
    elseif keyName == "up" or keyName == "down" then

        local maxTextWidth = txb.width - txb.padding * 2

        local stringIndex = 0
        local rowIndex

        for index, textData in ipairs(txb.textRows) do
            if stringIndex < txb.cursorPos then
                if stringIndex + #textData.text >= txb.cursorPos then
                    rowIndex = index
                else
                    stringIndex = stringIndex + #textData.text
                    if textData.hasNewLine then
                        stringIndex = stringIndex + 1
                    end
                end
            end
        end
        
        txb.cursorRowIndex = rowIndex
        txb.cursorRowOffset = txb.cursorPos - stringIndex

        local previousRow = txb.textRows[rowIndex - 1]
        local currentRow = txb.textRows[rowIndex]
        local nextRow = txb.textRows[rowIndex + 1]
        local cursorOffset = txb.cursorPos - stringIndex

        if keyName == "up" then
            if not previousRow then
                txb:setCursorPos(0)
            else
                --take a second look at this
                if txb.horizontalAlignment == align.left then
                    if cursorOffset > #previousRow.text then
                        txb:setCursorPos(stringIndex - 1)
                    else
                        if previousRow.hasNewLine then
                            cursorOffset = cursorOffset - 1
                        end
                        txb:setCursorPos(stringIndex - #previousRow.text + cursorOffset)
                    end
                elseif txb.horizontalAlignment == align.center then
                    if cursorOffset < (maxTextWidth - #previousRow.text) / 2 then
                        txb:setCursorPos(stringIndex - #previousRow.text - 1)
                    elseif cursorOffset > (maxTextWidth + #previousRow.text) / 2 then
                        txb:setCursorPos(stringIndex - 1)
                    else
                        if previousRow.hasNewLine then
                            cursorOffset = cursorOffset - 1
                        end
                        txb:setCursorPos(stringIndex - #previousRow.text + (#previousRow.text - #currentRow.text) / 2 + cursorOffset)
                    end
                elseif txb.horizontalAlignment == align.right then
                    if cursorOffset < maxTextWidth - #previousRow.text then
                        txb:setCursorPos(stringIndex - #previousRow.text + #currentRow - cursorOffset)
                    else
                        txb:setCursorPos(stringIndex - #previousRow.text - 1)
                    end
                end
            end
        end
    elseif keyName == "enter" then
        txb:insertCharacter("\n")
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
    ["char"] = {},
    ["paste"] = {},
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