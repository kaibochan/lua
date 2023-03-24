--[[
    registered callbacks to happen no matter which element is selected
]]
globalCallbacks = {
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
function registerGlobalCallback(event, callback)
    table.insert(globalCallbacks[event], callback)
end

--[[
    registered callbacks for each user input event, only occurs if element is selected
]]
selectionCallbacks = {
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
    register callback functions for various mouse and keyboard events for a given element
]]
function registerSelectionCallback(event, element, callback)
    if selectionCallbacks[event] then
        selectionCallbacks[event][element.name] = callback
    else
        selectionCallbacks[event] = {[element.name] = callback}
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
    alignment options for text elements and derivatives
]]
align = {
    top = "top",
    left = "left",
    center = "center",
    right = "right",
    bottom = "bottom",
}

--------------------------------
--Display
--------------------------------

Display = {
    device = nil,
    isMonitor = false,
    width = 1,
    height = 1,
}

function Display:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

--------------------------------
--Cell
--------------------------------

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


--------------------------------
--Canvas
--------------------------------

Canvas = {
    class = "Canvas",
    display = nil,
    children = {},
    width = 1,
    height = 1,
    backgroundColor = colors.black,
    cells = {},
}
    
function Canvas:new (o)
    o = o or {}

    --tables are passed by reference so new ones must be created
    o.cells = o.cells or {}
    o.children = o.children or {}

    setmetatable(o, self)
    self.__index = self

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

--[[
    draw children, then draw to parent's canvas if parent exists, otherwise draw to display
]]
function Canvas:draw()

    --reset canvas for drawing to
    for x = 1, self.width do
        for y = 1, self.height do
            self.cells[x][y].backgroundColor = self.backgroundColor
            self.cells[x][y].character = " "
        end
    end

    --draw all children to canvas cells
    for _, child in ipairs(self.children) do
        child:draw()
    end

    --draw canvas cells to the screen
    for y = 1, self.height do
        local characters = ""
        local textColors = ""
        local backgroundColors = ""

        for x = 1, self.width do
            characters = characters .. self.cells[x][y].character
            textColors = textColors .. colors.toBlit(self.cells[x][y].textColor)
            backgroundColors = backgroundColors ..  colors.toBlit(self.cells[x][y].backgroundColor)
        end

        self.display.device.setCursorPos(1, y)
        self.display.device.blit(characters, textColors, backgroundColors)
    end
end

--[[
    converts to global coordinates and then test for if x and y are within bounds
]]
function Canvas:selected(x, y)
    return true
end

--------------------------------
--Element
--------------------------------

Element = Canvas:new {
    class = "Element",
    canvas = nil,
    parent = nil,
    globalX = 1,
    globalY = 1,
    x = 1,
    y = 1,
    visible = true,
    transparentBackground = false,
}
    
function Element:new (o)
    o = o or {}
    o = Canvas:new(o)

    --tables are passed by reference so new ones must be created if not passed in
    o.cells = o.cells or {}
    o.children = o.children or {}

    setmetatable(o, self)
    self.__index = self

    if o.canvas then
        table.insert(o.canvas.children, o)
    end

    if o.parent then
        table.insert(o.parent.children, o)
        o.globalX, o.globalY = o:getGlobalPos(o.x, o.y)
    end

    return o
end

--[[
    remove element from previous parent and add to new parent, can also be nil to unparent entirely
]]
function Element:setParent(parent)
    if self.parent then
        for index, child in self.parent.children do
            if child == self then
                table.remove(self.parent.children, index)
                break
            end
        end
    end

    if parent then
        table.insert(self.parent.children, self)
    end
    
    self.globalX, self.globalY = self:getGlobalPos(o.x, o.y)
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
        for lx = 1, self.width do
            local gy = ly + self.globalY - 1
            local gx = lx + self.globalX - 1

            self.canvas.cells[gx][gy].character = self.cells[lx][ly].character
            self.canvas.cells[gx][gy].textColor = self.cells[lx][ly].textColor
            self.canvas.cells[gx][gy].backgroundColor = self.cells[lx][ly].backgroundColor
        end
    end

    for _, child in ipairs(self.children) do
        child:draw()
    end
end

--------------------------------
--Text
--------------------------------

RowString = {
    text = "",
    hasNewLine = false,
    __index = function(tab, k)
        if k > 0 and k <= #tab.text then
            return tab.text:sub(k, k)
        end
        return " "
    end,
}
setmetatable(RowString, RowString)

function RowString:new(o)
    o = o or {}
	setmetatable(o, self)
	return o
end

TextRows = {
    __index = function(tab, k)
        return RowString
    end
}

function TextRows:new(o)
    o = o or {}
	setmetatable(o, self)
	return o
end

Text = Element:new {
    class = "Text",
    textColor = colors.white,
    text = "",
    textRows = {},
    padding = 0,
    horizontalAlignment = align.left,
    verticalAlignment = align.top,
    verticalOffset = 0,
    horizontalOffsets = {},
    scrollable = false,
    shiftHeld = false,
    verticalScrollOffset = 0,
    wrapText = true,
    horizontalScrollOffset = 0,
    longestRowLength = 0,
}

function Text:new(o)
    o = o or {}
    o = Element:new(o)

    --tables are passed by reference so new ones must be created
    o.textRows = TextRows:new()
    o.horizontalOffsets = {}

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

    o:setStartRowIndexFunction()
    o:setStartSubstringIndexFunction()
    o:setText(o.text)

    if o.name then
        registerSelectionCallback("key", o, Text.pressShift)
        registerSelectionCallback("mouse_scroll", o, Text.textScroll)
        registerSelectionCallback("key_up", o, Text.releaseShift)
    end

    return o
end

function Text.pressShift(txt, event, key, isHeld)
    if keys.getName(key) == "leftShift" or keys.getName(key) == "rightShift" then
        txt.shiftHeld = true
    end
end

function Text.textScroll(txt, event, scrollDir, x, y)
    if txt.shiftHeld then
        txt.horizontalScrollOffset = txt.horizontalScrollOffset + scrollDir

        local maxHorizontalScroll = math.max(txt.longestRowLength - txt.width + 2 * txt.padding, 0)

        if txt.horizontalScrollOffset < 0 then
            txt.horizontalScrollOffset = 0
        elseif txt.horizontalScrollOffset > maxHorizontalScroll then
            txt.horizontalScrollOffset = maxHorizontalScroll
        else
            txt:updateCells()
        end
    else
        txt.verticalScrollOffset = txt.verticalScrollOffset + scrollDir

        local maxVerticalScroll = math.max(#txt.textRows - txt.height + 2 * txt.padding, 0)

        if txt.verticalScrollOffset < 0 then
            txt.verticalScrollOffset = 0
        elseif txt.verticalScrollOffset > maxVerticalScroll then
            txt.verticalScrollOffset = maxVerticalScroll
        else
            txt:updateCells()
        end
    end
end

function Text.releaseShift(txt, event, key)
    if keys.getName(key) == "leftShift" or keys.getName(key) == "rightShift" then
        txt.shiftHeld = false
    end
end

--[[
    black magic is used to compute the substringIndex and rowIndex offsets dependent on the alignment and current scroll offset
]]
Text.computeIndex = {
    getStartSubstringIndexLeftAligned = function(txt, rowIndex)
        return 1 - txt.padding + txt.horizontalScrollOffset
    end,
    getStartSubstringIndexRightAligned = function(txt, rowIndex)
        return 1 + txt.padding + #txt.textRows[rowIndex].text - txt.width + txt.horizontalScrollOffset
        + math.min(0, -txt.longestRowLength + txt.width - 2 * txt.padding)
    end,
    getStartSubstringIndexCenterAligned = function(txt, rowIndex)
        return 1 - txt.padding + math.ceil((#txt.textRows[rowIndex].text - txt.width + 2 * txt.padding) / 2) + txt.horizontalScrollOffset
        + math.min(0, math.floor((-txt.longestRowLength + txt.width - 2 * txt.padding) / 2))
    end,
    getStartRowIndexTopAligned = function(txt)
        return 1 - txt.padding + txt.verticalScrollOffset
    end,
    getStartRowIndexBottomAligned = function(txt)
        return 1 + txt.padding + #txt.textRows - txt.height + txt.verticalScrollOffset
        + math.min(0, -#txt.textRows + txt.height - 2 * txt.padding)
    end,
    getStartRowIndexCenterAligned = function(txt)
        return 1 - txt.padding + math.ceil((#txt.textRows - txt.height + 2 * txt.padding) / 2) + txt.verticalScrollOffset
        + math.min(0, math.floor((-#txt.textRows + txt.height - 2 * txt.padding) / 2))
    end,
}

function Text:setStartSubstringIndexFunction()
    if self.horizontalAlignment == align.left then
        self.getStartSubstringIndex = Text.computeIndex.getStartSubstringIndexLeftAligned
    elseif self.horizontalAlignment == align.right then
        self.getStartSubstringIndex = Text.computeIndex.getStartSubstringIndexRightAligned
    elseif self.horizontalAlignment == align.center then
        self.getStartSubstringIndex = Text.computeIndex.getStartSubstringIndexCenterAligned
    end
end

function Text:setStartRowIndexFunction()
    if self.verticalAlignment == align.top then
        self.getStartRowIndex = Text.computeIndex.getStartRowIndexTopAligned
    elseif self.verticalAlignment == align.bottom then
        self.getStartRowIndex = Text.computeIndex.getStartRowIndexBottomAligned
    elseif self.verticalAlignment == align.center then
        self.getStartRowIndex = Text.computeIndex.getStartRowIndexCenterAligned
    end
end

--[[
    set the horizontal alignment and update cells accordingly
]]
function Text:setHorizontalAlignment(alignment)
    self.horizontalAlignment = alignment
    self:setStartSubstringIndexFunction()
    self:updateCells()
end

--[[
    set the vertical alignment and update cells accordingly
]]
function Text:setVerticalAlignment(alignment)
    self.verticalAlignment = alignment
    self:setStartRowIndexFunction()
    self:updateCells()
end

--[[
    update rows of text according to current text string and whether to wrap text or not
]]
function Text:updateTextRows()
    self.textRows = TextRows:new()

    local stringBegin = 1
    local rowWidth = self.width - self.padding * 2
    local stringEnd = stringBegin + rowWidth - 1
    local newLineIndex = self.text:find("\n", stringBegin, true)
    local endsWithNewLine
    local substring
    local index = 1

    self.longestRowLength = 0

    while stringBegin <= #self.text do
        if newLineIndex and newLineIndex < stringBegin then
            newLineIndex = self.text:find("\n", stringBegin, true)
        end
        
        if newLineIndex and (newLineIndex < stringEnd or not self.wrapText) then
            substring = RowString:new { text = self.text:sub(stringBegin, newLineIndex - 1), hasNewLine = true }
            stringBegin = newLineIndex + 1
        elseif not self.wrapText then
            substring = RowString:new { text = self.text:sub(stringBegin) }
            stringBegin = stringBegin + #substring.text
        else
            substring = RowString:new { text = self.text:sub(stringBegin, stringEnd) }
            stringBegin = stringEnd + 1
        end
        
        stringEnd = stringBegin + rowWidth - 1
        
        table.insert(self.textRows, substring)

        if #self.textRows[index].text > self.longestRowLength then
            self.longestRowLength = #self.textRows[index].text
        end

        index = index + 1
    end
end

--[[
    update vertical and horizontal offsets according to alignment and text
]]
-- function Text:updateOffsets()
--     if self.verticalAlignment == align.top then
--         self.verticalOffset = self.padding
--     elseif self.verticalAlignment == align.center then
--         self.verticalOffset = (self.height - #self.textRows) / 2
--     elseif self.verticalAlignment == align.bottom then
--         self.verticalOffset = self.height - self.padding - #self.textRows
--     end

--     self.horizontalOffsets = {}
--     for index, textData in ipairs(self.textRows) do
--         if self.horizontalAlignment == align.left then
--             table.insert(self.horizontalOffsets, self.padding)
--         elseif self.horizontalAlignment == align.center then
--             table.insert(self.horizontalOffsets, self.width / 2 - #textData.text / 2)
--         elseif self.horizontalAlignment == align.right then
--             table.insert(self.horizontalOffsets, self.width - self.padding - #textData.text)
--         end
--     end
-- end

--[[
    update cells according to current scroll position, alignment, and text
]]
-- function Text:updateCells()
--     local substringIndex = 1
--     local rowIndex = 1 + self.verticalScrollOffset

--     for x = 1, self.width do
--         for y = 1, self.height do
--             self.cells[x][y].character = " "
--         end
--     end

--     for y = 1, self.height do
--         if y + self.verticalScrollOffset > self.verticalOffset and y + self.verticalScrollOffset <= self.verticalOffset + #self.textRows
--         and rowIndex <= #self.textRows and y <= self.height - self.padding then
--             substringIndex = 1 + self.horizontalScrollOffset

--             for x = 1, self.width do
--                 if substringIndex <= #self.textRows[rowIndex].text and x + self.horizontalScrollOffset > self.horizontalOffsets[rowIndex]
--                 and x + self.horizontalScrollOffset <= self.horizontalOffsets[rowIndex] + #self.textRows[rowIndex].text and x <= self.width - self.padding then

--                     self.cells[x][y].character = self.textRows[rowIndex].text:sub(substringIndex, substringIndex)
--                     substringIndex = substringIndex + 1
--                 end
--             end

--             rowIndex = rowIndex + 1
--         end
--     end
-- end

--[[
    write characters to cells data table according to scroll offsets and alignments
]]
function Text:updateCells()
    local rowIndex = self:getStartRowIndex()
    local substringIndex

    for y = 1, self.height do
        substringIndex = self:getStartSubstringIndex(rowIndex)

        if y > self.padding and y < self.height - self.padding + 1 then
            for x = 1, self.width do
                if x > self.padding and x < self.width - self.padding + 1 then
                    if self.textRows[rowIndex][substringIndex] == "" then
                        error(""..rowIndex..", "..substringIndex..", "..#self.textRows..", "..#self.textRows[rowIndex].text)
                    end
                    self.cells[x][y].character = self.textRows[rowIndex][substringIndex]
                end

                substringIndex = substringIndex + 1
            end
        end

        rowIndex = rowIndex + 1
    end
end

--[[
    set the text for a Text element
]]
function Text:setText(text)
    self.text = text

    self:updateTextRows()
    --self:updateOffsets()
    self:updateCells()
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

--------------------------------
--Textbox
--------------------------------

Textbox = Text:new{
    class = "Textbox",
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

    if o.name then
        registerSelectionCallback("char", o, Textbox.characterTyped)
        registerSelectionCallback("key", o, Textbox.keyPressed)
    end

    return o
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

    if self.verticalAlignment == align.top then
        self.getCursorPosY = Textbox.cursorPosComputeXY.getCursorPosYTopAligned
    elseif self.verticalAlignment == align.bottom then
        self.getCursorPosY = Textbox.cursorPosComputeXY.getCursorPosYBottomAligned
    elseif self.verticalAlignment == align.center then
        self.getCursorPosY = Textbox.cursorPosComputeXY.getCursorPosYCenterAligned
    end
end

function Textbox:computeRowIndexAndOffset()
    local stringIndex = 0

    for index, textData in ipairs(self.textRows) do
        if stringIndex < self.cursorPos then
            if stringIndex + #textData.text >= self.cursorPos then
                self.cursorRowIndex = index
                self.cursorRowOffset = self.cursorPos - stringIndex
                break
            else
                stringIndex = stringIndex + #textData.text
                if textData.hasNewLine then
                    stringIndex = stringIndex + 1
                end
            end
        end
    end
end

function Textbox:setCursorPos(newCursorPos)
    self.cursorPos = newCursorPos
    self:computeRowIndexAndOffset()

    --update cells
    local cursorX = self:getCursorPosX()
    local cursorY = self:getCursorPosY()

    for x = 1, self.width do
        for y = 1, self.height do
            self.cells[x][y].backgroundColor = self.backgroundColor
            self.cells[x][y].textColor = self.textColor
        end
    end

    if cursorX > 0 and cursorX <= self.width and cursorY > 0 and cursorY <= self.height then
        self.cells[cursorX][cursorY].backgroundColor = self.cursorBackgroundColor
        self.cells[cursorX][cursorY].textColor = self.cursorTextColor
    end
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
        local previousRow = txb.textRows[txb.cursorRowIndex - 1]
        local currentRow = txb.textRows[txb.cursorRowIndex]
        local nextRow = txb.textRows[txb.cursorRowIndex + 1]

        if keyName == "up" then
            if not previousRow then
                txb:setCursorPos(0)
            else
                --take a second look at this
                if txb.horizontalAlignment == align.left then
                    if txb.cursorRowOffset > #previousRow.text then
                        txb:setCursorPos(txb.cursorPos - txb.cursorRowOffset - 1)
                    else
                        if previousRow.hasNewLine then
                            txb:setCursorPos(txb.cursorPos - 1 - #previousRow.text)
                        else
                            txb:setCursorPos(txb.cursorPos - #previousRow.text)
                        end
                    end
                elseif txb.horizontalAlignment == align.center then
                    if txb.cursorRowOffset < (maxTextWidth - #previousRow.text) / 2 then
                        txb:setCursorPos(txb.cursorPos - txb.cursorRowOffset - #previousRow.text - 1)
                    elseif txb.cursorRowOffset > (maxTextWidth + #previousRow.text) / 2 then
                        txb:setCursorPos(txb.cursorPos - txb.cursorRowOffset - 1)
                    else
                        if previousRow.hasNewLine then
                            txb:setCursorPos(txb.cursorPos - 1 - #previousRow.text + (#previousRow.text - #currentRow.text) / 2)
                        else
                            txb:setCursorPos(txb.cursorPos - #previousRow.text + (#previousRow.text - #currentRow.text) / 2)
                        end
                    end
                elseif txb.horizontalAlignment == align.right then
                    if txb.cursorRowOffset < maxTextWidth - #previousRow.text then
                        txb:setCursorPos(txb.cursorPos - 2 * txb.cursorRowOffset - #previousRow.text + #currentRow)
                    else
                        txb:setCursorPos(txb.cursorPos - txb.cursorRowOffset - #previousRow.text - 1)
                    end
                end
            end
        end
    elseif keyName == "enter" then
        txb:insertCharacter("\n")
    end
end

function setDisplay(device, canvasName, backgroundColor)
    local isMonitor
    if device.__name and device.__name == "monitor" then
        isMonitor = true
    else
        isMonitor = false
    end

    local width, height = device.getSize()

    local display = Display:new {
        device = device,
        isMonitor = isMonitor,
        width = width,
        height = height,
    }

    return Canvas:new {
        name = canvasName,
        display = display,
        backgroundColor = backgroundColor,
        width = display.width,
        height = display.height,
    }
end