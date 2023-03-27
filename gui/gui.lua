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

--[[
    global flags for shift and control being held
]]
shiftHeld = false
ctrlHeld = false

--[[
    currently selected element
]]
selectedElement = nil

--[[
    base level elements, used in handleInputEvents to get selected elements
]]
baseElements = {}

--------------------------------
--Callbacks
--------------------------------

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
function registerGlobalCallback(event, callback, callbackName)
    table.insert(globalCallbacks[event], {callback = callback, callbackName = callbackName})
end

function removeGlobalCallback(event, callbackName)
    for index, callback in ipairs(globalCallbacks[event]) do
        if callback.callbackName == callbackName then
            table.remove(globalCallbacks, index)
        end
    end
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
function registerSelectionCallback(event, element, callback, callbackName)
    table.insert(selectionCallbacks[event], {elementName = element.name, callback = callback, callbackName = callbackName})
end

function removeSelectionCallback(event, element, callbackName)
    for index, callback in ipairs(selectionCallbacks[event]) do
        if callback.elementName == element.name and (callback.callbackName == callbackName or not callback.callbackName) then
            table.remove(selectionCallbacks[event], index)
            break
        end
    end
end

--[[
    register key events for shift and control other elements to reference
]]
registerGlobalCallback("key", function(event, key, isHeld)
    local keyName = keys.getName(key)

    if keyName == "leftShift" or keyName == "rightShift" then
        shiftHeld = true
    elseif keyName == "leftCtrl" or keyName == "rightCtrl" then
        ctrlHeld = true
    end
end, "pressShiftControl")

registerGlobalCallback("key_up", function(event, key)
    local keyName = keys.getName(key)

    if keyName == "leftShift" or keyName == "rightShift" then
        shiftHeld = false
    elseif keyName == "leftCtrl" or keyName == "rightCtrl" then
        ctrlHeld = false
    end
end, "releaseShiftControl")

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

function handleInputEvents()
    local event, data1, data2, data3 = os.pullEvent()
    if globalCallbacks[event] or selectionCallbacks[event] then
        if event == "mouse_click" then
            for _, base in ipairs(baseElements) do
                selectedElement = getSelectedElement(base, data2, data3)
                if selectedElement then
                    break
                end
            end
        end

        for _, callback in ipairs(globalCallbacks[event]) do
            callback.callback(event, data1, data2, data3)
        end

        if selectedElement and selectionCallbacks[event] then
            for _, callback in ipairs(selectionCallbacks[event]) do
                if callback.elementName == selectedElement.name and callback.callback then
                    callback.callback(selectedElement, event, data1, data2, data3)
                end
            end
        end
    end
end

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
--Window
--------------------------------

Window = {
    class = "Window",
    display = nil,
    children = {},
    globalX = 1,
    globalY = 1,
    width = 1,
    height = 1,
    backgroundColor = colors.black,
    cells = {},
}
    
function Window:new (o)
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
    draw children, then draw to parent's Window if parent exists, otherwise draw to display
]]
function Window:draw()

    --reset Window for drawing to
    for x = 1, self.width do
        for y = 1, self.height do
            self.cells[x][y].backgroundColor = self.backgroundColor
            self.cells[x][y].character = " "
        end
    end

    --draw all children to Window cells
    for _, child in ipairs(self.children) do
        child:draw()
    end

    --draw Window cells to the screen
    for y = 1, self.height do
        local characters = ""
        local textColors = ""
        local backgroundColors = ""

        for x = 1, self.width do
            characters = characters .. self.cells[x][y].character
            textColors = textColors .. colors.toBlit(self.cells[x][y].textColor)
            backgroundColors = backgroundColors ..  colors.toBlit(self.cells[x][y].backgroundColor)
        end

        self.display.device.setCursorPos(self.globalX, self.globalY + y - 1)
        self.display.device.blit(characters, textColors, backgroundColors)
    end
end

--[[
    converts to global coordinates and then test for if x and y are within bounds
]]
function Window:selected(x, y)
    return x >= self.globalX and x < self.globalX + self.width and y >= self.globalY and y < self.globalY + self.height
end

--------------------------------
--Element
--------------------------------

Element = Window:new {
    class = "Element",
    window = nil,
    parent = nil,
    x = 1,
    y = 1,
    visible = true,
    transparentBackground = false,
}
    
function Element:new (o)
    o = o or {}

    local gx, gy = o.globalX, o.globalY

    o = Window:new(o)

    --tables are passed by reference so new ones must be created if not passed in
    o.cells = o.cells or {}
    o.children = o.children or {}

    setmetatable(o, self)
    self.__index = self

    if o.window then
        table.insert(o.window.children, o)
    end

    if o.parent and o.parent ~= o.window then
        table.insert(o.parent.children, o)
    end
    
    if not gx and not gy then
        o.globalX, o.globalY = o:getGlobalPos(o.x, o.y)
    else
        o:setGlobalPos(o.globalX, o.globalY)
    end

    return o
end

--[[
    remove element from previous parent and add to new parent, can also be nil to unparent entirely
]]
function Element:setParent(parent)
    self.globalX, self.globalyY = self:getGlobalPos(self.x, self.y)

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
    
    self:setGlobalPos(self.globalX, self.globalY)
end

function Element:setGlobalPos(x, y)
    self.globalX = x
    self.globalY = y

    if self.parent then
        self.x = self.globalX - self.parent.globalX + 1
        self.y = self.globalY - self.parent.globalY + 1
    else
        self.x = self.globalX
        self.y = self.globalY
    end

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
    if self.parent then
        return self.parent.globalX + self.x - 1, self.parent.globalY + self.y - 1
    end

    return self.x, self.y
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
    draw children, then draw to parent's window if parent exists, otherwise draw to display
]]
function Element:draw()
    if not self.visible then
        return
    end

    --lx and ly are local x, y within an element
    for ly = 1, self.height do        
        for lx = 1, self.width do
            local wy = ly + self.globalY - self.window.globalY
            local wx = lx + self.globalX - self.window.globalX

            self.window.cells[wx][wy].character = self.cells[lx][ly].character
            self.window.cells[wx][wy].textColor = self.cells[lx][ly].textColor
            self.window.cells[wx][wy].backgroundColor = self.cells[lx][ly].backgroundColor
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
    newLineTerm = 0,
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
    scrollable = false,
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
        registerSelectionCallback("mouse_scroll", o, Text.textScroll, "textScroll")
    end

    return o
end

function Text:horizontalScroll(scrollDir)
    self.horizontalScrollOffset = self.horizontalScrollOffset + scrollDir

    local maxHorizontalScroll = math.max(self.longestRowLength - self.width + 2 * self.padding, 0)

    if self.horizontalScrollOffset < 0 then
        self.horizontalScrollOffset = 0
    elseif self.horizontalScrollOffset > maxHorizontalScroll then
        self.horizontalScrollOffset = maxHorizontalScroll
    end
    self:updateCells()
end

function Text:verticalScroll(scrollDir)
    self.verticalScrollOffset = self.verticalScrollOffset + scrollDir

    local maxVerticalScroll = math.max(#self.textRows - self.height + 2 * self.padding, 0)

    if self.verticalScrollOffset < 0 then
        self.verticalScrollOffset = 0
    elseif self.verticalScrollOffset > maxVerticalScroll then
        self.verticalScrollOffset = maxVerticalScroll
    end
    self:updateCells()
end

function Text.textScroll(txt, event, scrollDir, x, y)
    if shiftHeld then
        txt:horizontalScroll(scrollDir)
    else
        txt:verticalScroll(scrollDir)
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
    local substring
    local index = 1

    self.longestRowLength = 0

    while stringBegin <= #self.text do
        if newLineIndex and newLineIndex < stringBegin then
            newLineIndex = self.text:find("\n", stringBegin, true)
        end
        
        if newLineIndex and (newLineIndex < stringEnd or not self.wrapText) then
            substring = RowString:new { text = self.text:sub(stringBegin, newLineIndex - 1), newLineTerm = 1 }
            stringBegin = newLineIndex + 1
        elseif not self.wrapText then
            substring = RowString:new { text = self.text:sub(stringBegin), newLineTerm = 0}
            stringBegin = stringBegin + #substring.text
        else
            substring = RowString:new { text = self.text:sub(stringBegin, stringEnd), newLineTerm = 0 }
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
    self:horizontalScroll(0)
    self:verticalScroll(0)
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
    enterSubmits = false,
}

function Textbox:new(o)
    o = o or {}
    o = Text:new(o)

    setmetatable(o, self)
    self.__index = self

    --o:setHorizontalAlignment(o.horizontalAlignment)
    --o:setVerticalAlignment(o.verticalAlignment)

    o:setCursorPos(0)

    if o.name then
        registerSelectionCallback("char", o, Textbox.characterTyped, "characterTyped")
        registerSelectionCallback("key", o, Textbox.keyPressed, "keyPressed")
        registerSelectionCallback("mouse_click", o, Textbox.mouseClicked, "mouseClicked")

        removeSelectionCallback("mouse_scroll", o, "textScroll")
        registerSelectionCallback("mouse_scroll", o, Textbox.textScroll, "textScroll")
    end

    return o
end

--[[
    scroll texbox window and update cursor position
]]
function Textbox.textScroll(txb, event, scrollDir, x, y)
    if shiftHeld then
        txb:eraseCursor()
        txb:horizontalScroll(scrollDir)
        txb:drawCursor()
    else
        txb:eraseCursor()
        txb:verticalScroll(scrollDir)
        txb:drawCursor()
    end
end

--[[
    convert from cursor position to cursor Y value
]]
function Textbox:getCursorPosY()
    return 1 - self:getStartRowIndex() + self.cursorRowIndex
end

--[[
    convert from cursor position to cursor X value
]]
function Textbox:getCursorPosX()
    return 2 - self:getStartSubstringIndex(self.cursorRowIndex) + self.cursorRowOffset
end

--[[
    compute cursorRowIndex and cursorRowOffset based on cursor position
]]
function Textbox:computeRowIndexAndOffset()
    local stringIndex = 0

    for index, textData in ipairs(self.textRows) do
        if stringIndex + #textData.text >= self.cursorPos then
            self.cursorRowIndex = index
            self.cursorRowOffset = self.cursorPos - stringIndex
            break
        else
            stringIndex = stringIndex + #textData.text + textData.newLineTerm
        end
    end
end

--[[
    compute the cursor position based on the cursorRowIndex and cursorRowOffset
]]
function Textbox:computeCursorPos()
    self.cursorPos = 0

    for index = 1, self.cursorRowIndex - 1 do
        self.cursorPos = self.cursorPos + #self.textRows[index].text + self.textRows[index].newLineTerm
    end

    self.cursorPos = self.cursorPos + self.cursorRowOffset
end

--[[
    erase cursor position (overwrite with default background and text color)
]]
function Textbox:eraseCursor()
    local prevCursorX = self:getCursorPosX()
    local prevCursorY = self:getCursorPosY()

    if prevCursorX > 0 and prevCursorX <= self.width and prevCursorY > 0 and prevCursorY <= self.height then
        self.cells[prevCursorX][prevCursorY].backgroundColor = self.backgroundColor
        self.cells[prevCursorX][prevCursorY].textColor = self.textColor
    end
end

--[[
    draw the cursor to the screen
]]
function Textbox:drawCursor()
    local cursorX = self:getCursorPosX()
    local cursorY = self:getCursorPosY()

    if cursorX > 0 and cursorX <= self.width and cursorY > 0 and cursorY <= self.height then
        self.cells[cursorX][cursorY].backgroundColor = self.cursorBackgroundColor
        self.cells[cursorX][cursorY].textColor = self.cursorTextColor
    end
end

--[[
    move the view window along with the cursor
]]
function Textbox:scrollCursorIntoBounds()
    local cursorX = self:getCursorPosX()
    local cursorY = self:getCursorPosY()

    local leftScrollOffset = cursorX - self.padding - 1
    local rightScrollOffset = cursorX - self.width + self.padding  
    local upScrollOffset = cursorY - self.padding - 1
    local downScrollOffset = cursorY - self.height + self.padding

    if leftScrollOffset < 0 then
        self:horizontalScroll(leftScrollOffset)
    elseif rightScrollOffset > 0 then
        self:horizontalScroll(rightScrollOffset)
    end

    if upScrollOffset < 0 then
        self:verticalScroll(upScrollOffset)
    elseif downScrollOffset > 0 then
        self:verticalScroll(downScrollOffset)
    end
end

--[[
    set cursor position to new position
]]
function Textbox:setCursorPos(newCursorPos)
    if newCursorPos < 0 or newCursorPos > #self.text then
        self:drawCursor()
        return
    end

    self:eraseCursor()    

    self.cursorPos = newCursorPos
    self:computeRowIndexAndOffset()

    self:scrollCursorIntoBounds()

    self:drawCursor()
end

--[[
    set cursor position based on an x and y input
]]
function Textbox:setCursorPosXY(x, y)
    self:eraseCursor()

    self.cursorRowIndex = math.min(#self.textRows, math.max(1, y - 1 + self:getStartRowIndex()))
    self.cursorRowOffset = math.min(#self.textRows[self.cursorRowIndex].text, math.max(0, x - 2 + self:getStartSubstringIndex(self.cursorRowIndex)))

    if self.cursorRowOffset == #self.textRows[self.cursorRowIndex].text + self.textRows[self.cursorRowIndex].newLineTerm
    and self.cursorRowIndex < #self.textRows then

        self.cursorRowIndex = self.cursorRowIndex + 1
        self.cursorRowOffset = 0
    end

    self:computeCursorPos()
    self:scrollCursorIntoBounds()

    self:drawCursor()
end

--[[
    insert character at cursor position and increment cursor position
]]
function Textbox:insertCharacter(character)
    self:setText(self.text:sub(0, self.cursorPos)..character..self.text:sub(self.cursorPos + 1))
    self:setCursorPos(self.cursorPos + 1)
end

--[[
    insert characters as they are received at cursor position while incrementing cursor position
]]
function Textbox.characterTyped(txb, event, character)
    txb:insertCharacter(character)
end

--[[
    handle key inputs for textbox element
]]
function Textbox.keyPressed(txb, event, key, isHeld)
    local keyName = keys.getName(key)

    if keyName == "left" and txb.cursorPos > 0 then
        txb:setCursorPos(txb.cursorPos - 1)
    elseif keyName == "right" and txb.cursorPos <= #txb.text then
        txb:setCursorPos(txb.cursorPos + 1)
    elseif keyName == "up" then
        local cursorX = txb:getCursorPosX()
        local cursorY = txb:getCursorPosY()

        txb:setCursorPosXY(cursorX, cursorY - 1)
    elseif keyName == "down" then
        local cursorX = txb:getCursorPosX()
        local cursorY = txb:getCursorPosY()

        txb:setCursorPosXY(cursorX, cursorY + 1)
    elseif keyName == "enter" and not txb.enterSubmits then
        txb:eraseCursor()
        txb:insertCharacter("\n")
    elseif keyName == "backspace" and txb.cursorPos > 0 then
        txb:eraseCursor()
        txb:setText(txb.text:sub(0, txb.cursorPos - 1)..txb.text:sub(txb.cursorPos + 1))
        txb:setCursorPos(txb.cursorPos - 1)
    elseif keyName == "delete" and txb.cursorPos < #txb.text then
        txb:eraseCursor()
        txb:setText(txb.text:sub(0, txb.cursorPos)..txb.text:sub(txb.cursorPos + 2))
        txb:setCursorPos(txb.cursorPos)
    elseif keyName == "home" then
        txb:setCursorPos(txb.cursorPos - txb.cursorRowOffset)
    elseif keyName == "end" then
        txb:setCursorPos(txb.cursorPos - txb.cursorRowOffset + #txb.textRows[txb.cursorRowIndex].text)
    end
end

--[[
    handle mouse clicks for textbox element
]]
function Textbox.mouseClicked(txb, event, button, x, y)
    if button == 1 then
        local lx = 1 + x - txb.globalX
        local ly = 1 + y - txb.globalY

        txb:setCursorPosXY(lx, ly)
    end
end

--[[
    set display and return window linked to it
]]
function createWindow(device, windowName, backgroundColor, x, y, width, height)
    local isMonitor
    if device.__name and device.__name == "monitor" then
        isMonitor = true
    else
        isMonitor = false
    end

    if not x and not y then
        x = 1
        y = 1
    end

    if not width and not height then
        width, height = device.getSize()
    end

    local display = Display:new {
        device = device,
        isMonitor = isMonitor,
        width = width,
        height = height,
    }

    local window = Window:new {
        name = windowName,
        display = display,
        backgroundColor = backgroundColor,
        globalX = x,
        globalY = y,
        width = display.width,
        height = display.height,
    }

    table.insert(baseElements, window)

    return window
end