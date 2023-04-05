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
buffers = {}

--------------------------------
--Callbacks
--------------------------------

--[[
    registered callbacks to happen no matter which element is selected
]]
globalCallbacks = {
    ["monitor_touch"] = {},
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
    ["monitor_touch"] = {},
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

function handleMouseClick(buffer, button, x, y)
    return getSelectedElement(buffer, x, y)
end

function handleMonitorTouch(buffer, side, x, y)
    if buffer.display.side == side then
        return getSelectedElement(buffer, x, y)
    end
end

--[[
    depth first search to find selected element given an x and y
]]
function getSelectedElement(buffer, x, y)
    local selectedElement

    --iterate over elements backwards to grab elements drawn on top first
    for i = #buffer.children, 1, -1 do
        selectedElement = getSelectedElement(buffer.children[i], x, y)

        if selectedElement then
            return selectedElement
        end
    end

    if buffer:selected(x, y) then
        return buffer
    end
end

function handleInputEvents()
    local event, data1, data2, data3 = os.pullEvent()
    if globalCallbacks[event] or selectionCallbacks[event] then
        if event == "mouse_click" then
            for _, buffer in ipairs(buffers) do
                selectedElement = handleMouseClick(buffer, data1, data2, data3)
                if selectedElement then
                    break
                end
            end
        elseif event == "monitor_touch" then
            for _, buffer in ipairs(buffers) do
                selectedElement = handleMonitorTouch(buffer, data1, data2, data3)
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
    side = nil,
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
--Buffer
--------------------------------

Buffer = {
    class = "Buffer",
    display = nil,
    children = {},
    globalX = 1,
    globalY = 1,
    width = 1,
    height = 1,
    backgroundColor = colors.black,
    cells = {},
}
    
function Buffer:new (o)
    o = o or {}

    --tables are passed by reference so new ones must be created
    o.cells = o.cells or {}
    o.children = o.children or {}

    setmetatable(o, self)
    self.__index = self

    o:initializeCells()

    return o
end

function Buffer:initializeCells()
    local cell

    for x = 1, self.width do
        for y = 1, self.height do
            cell = Cell:new { backgroundColor = self.backgroundColor }
            if not self.cells[x] then
                table.insert(self.cells, x, {[y] = cell})
            else
                table.insert(self.cells[x], y, cell)
            end
        end
    end
end

--[[
    draw children, then draw to parent's buffer if parent exists, otherwise draw to display
]]
function Buffer:draw()

    --reset buffer for drawing to
    for x = 1, self.width do
        for y = 1, self.height do
            self.cells[x][y].backgroundColor = self.backgroundColor
            self.cells[x][y].character = " "
        end
    end

    --draw all children to buffer cells
    for _, child in ipairs(self.children) do
        child:draw()
    end

    --draw buffer cells to the screen
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
function Buffer:selected(x, y)
    return x >= self.globalX and x < self.globalX + self.width and y >= self.globalY and y < self.globalY + self.height
end

--------------------------------
--Element
--------------------------------

Element = Buffer:new {
    class = "Element",
    buffer = nil,
    parent = nil,
    x = 1,
    y = 1,
    visible = true,
    transparentBackground = false,
}
    
function Element:new (o)
    o = o or {}

    local gx = o.globalX
    local gy = o.globalY

    o = Buffer:new(o)

    --tables are passed by reference so new ones must be created if not passed in
    o.cells = o.cells or {}
    o.children = o.children or {}

    setmetatable(o, self)
    self.__index = self

    if o.buffer then
        table.insert(o.buffer.children, o)
    end

    if o.parent and o.parent ~= o.buffer then
        table.insert(o.parent.children, o)
    end
    
    if not gx and not gy then
        o.globalX, o.globalY = o:getGlobalPos(o.x, o.y)
    else
        o:setGlobalPos(o.globalX, o.globalY)
    end

    return o
end

function Element:setWidth(newWidth)
    self.width = newWidth
    
    self.cells = {}

    self:initializeCells()
end

function Element:setHeight(newHeight)
    self.height = newHeight

    self.cells = {}

    self:initializeCells()
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
    local lx = 1 + x - self.globalX
    local ly = 1 + y - self.globalY

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
    draw children, then draw to parent's buffer if parent exists, otherwise draw to display
]]
function Element:draw()
    if not self.visible then
        return
    end

    --lx and ly are local x, y within an element
    for ly = 1, self.height do        
        for lx = 1, self.width do
            local by = ly + self.globalY - self.buffer.globalY
            local bx = lx + self.globalX - self.buffer.globalX

            if self.cells[lx][ly].backgroundColor ~= 0 and bx >= 1 and bx <= self.buffer.width and by >= 1 and by <= self.buffer.height then
                self.buffer.cells[bx][by].character = self.cells[lx][ly].character
                self.buffer.cells[bx][by].textColor = self.cells[lx][ly].textColor
                self.buffer.cells[bx][by].backgroundColor = self.cells[lx][ly].backgroundColor
            end
        end
    end

    for _, child in ipairs(self.children) do
        child:draw()
    end
end

--------------------------------
--Outline
--------------------------------

Outline = Element:new {

}

function Outline:new(o)
    o = o or {}
    o = Element:new(o)

    setmetatable(o, self)
    self.__index = self

    return o
end

function Outline:initializeCells()
    local cell

    for x = 1, self.width do
        for y = 1, self.height do
            if x == 1 or x == self.width or y == 1 or y == self.height then
                cell = Cell:new { backgroundColor = self.backgroundColor }
            else
                cell = Cell:new { backgroundColor = 0 }
            end
            if not self.cells[x] then
                table.insert(self.cells, x, {[y] = cell})
            else
                table.insert(self.cells[x], y, cell)
            end
        end
    end
end

--------------------------------
--Canvas
--------------------------------

Canvas = Element:new {
    backgroundColor = colors.white,
    currentColor = colors.black,
    maxUndo = 100,
    cellsHistory = {},
    historyIndex = 1,
    currentDrawAction = nil,
    selectionBox = nil,
    copiedCells = nil,
    copiedCellsWidth = 0,
    copiedCellsHeght = 0,
}

function Canvas:new(o)
    o = o or {}

    if not o.backgroundColor then
        o.backgroundColor = Canvas.backgroundColor
    end

    o = Element:new(o)

    setmetatable(o, self)
    self.__index = self

    o:addNewHistory()

    for x = 1, o.width do
        for y = 1, o.height do
            table.insert(o.cellsHistory[o.historyIndex], {["x"] = x, ["y"] = y, ["backgroundColor"] = o.backgroundColor})
        end
    end

    o.selectionBox = Outline:new {
        name = o.name.."_selectionBox",
        parent = o,
        buffer = o.buffer,
        visible = false,
    }

    o.currentDrawAction = Canvas.pen

    if not o.buffer.display.isMonitor then
        registerSelectionCallback("mouse_click", o, Canvas.mouseClick, "mouseClick")
        registerSelectionCallback("mouse_drag", o, Canvas.mouseDrag, "mouseDrag")
        registerSelectionCallback("mouse_up", o, Canvas.mouseUp, "mouseUp")
        registerSelectionCallback("key", o, Canvas.keyPressed, "keyPressed")
        registerSelectionCallback("paste", o, Canvas.paste, "paste")
    else
        registerSelectionCallback("monitor_touch", o, Canvas.monitorTouch, "monitorTouch")
    end

    return o
end

--[[
    sets a specific cell to a given color
    x, y are local x and y values
]]
function Canvas:setCell(x, y, color)
    if self.cells[x][y].backgroundColor == color then
        return
    end

    table.insert(self.cellsHistory[self.historyIndex + 1], {["x"] = x, ["y"] = y, ["backgroundColor"] = self.cells[x][y].backgroundColor})
    self.cells[x][y].backgroundColor = color
    table.insert(self.cellsHistory[self.historyIndex], {["x"] = x, ["y"] = y, ["backgroundColor"] = self.cells[x][y].backgroundColor})
end

function Canvas:addNewHistory()
    table.insert(self.cellsHistory, self.historyIndex, {})
    if #self.cellsHistory > self.maxUndo then
        table.remove(self.cellsHistory, self.maxUndo + 1)
    end

    for i = 1, self.historyIndex - 1 do
        table.remove(self.cellsHistory, 1)
    end

    self.historyIndex = 1
end

--[[
    utility function used for setting values in 2D arrays such as nodes in fill
]]
function Canvas.setValue(tab, i, j, value)
    if not tab[i] then
        table.insert(tab, i, {[j] = value})
    else
        table.insert(tab[i], j, value)
    end
end

--[[
    utility function used for getting values from 2D arrays such as nodes in fill
]]
function Canvas.getValue(tab, i, j)
    if tab and tab[i] and tab[i][j] then
        return tab[i][j]
    end
end

--[[
    changes one cell on the canvas to a different color
    x, y are local x and y values
]]
function Canvas:pen(x, y)
    if x < 1 or x > self.width or y < 1 or y > self.height
    or self.cells[x][y].backgroundColor == self.currentColor then
        return
    end

    self:addNewHistory()
    self:setCell(x, y, self.currentColor)
end

--[[
    uses a flood fill algorithm to fill cells with a given color
    x, y are local x and y values
]]
function Canvas:fill(startX, startY)
    if startX < 1 or startX > self.width or startY < 1 or startY > self.height
    or self.cells[startX][startY].backgroundColor == self.currentColor then
        return
    end

    local colorToReplace = self.cells[startX][startY].backgroundColor

    --toProcess contains potential cells to be filled
    local toProcess = {}
    table.insert(toProcess, {["x"] = startX, ["y"] = startY})
    
    --nodes contains all already processed cells to avoid processing again
    local nodes = {}
    Canvas.setValue(nodes, startX, startY, colorToReplace)

    local cellsToFill = {}
    local x, y

    while #toProcess ~= 0 do
        x = toProcess[1].x
        y = toProcess[1].y

        --[[
            if current cell is of the same color as the cell selected then add all
            it's adjacent neighbors to toProcess to be processed in another iteration
        ]]
        if self.cells[x][y].backgroundColor == colorToReplace then
            table.insert(cellsToFill, {["x"] = x, ["y"] = y})

            --add adjacent, unprocessed pixels to toProcess
            if x + 1 <= self.width and not Canvas.getValue(nodes, x + 1, y) then
                table.insert(toProcess, {["x"] = x + 1, ["y"] = y})
                Canvas.setValue(nodes, x + 1, y, colorToReplace)
            end

            if x - 1 >= 1 and not Canvas.getValue(nodes, x - 1, y) then
                table.insert(toProcess, {["x"] = x - 1, ["y"] = y})
                Canvas.setValue(nodes, x - 1, y, colorToReplace)
            end

            if y + 1 <= self.height and not Canvas.getValue(nodes, x, y + 1) then
                table.insert(toProcess, {["x"] = x, ["y"] = y + 1})
                Canvas.setValue(nodes, x, y + 1, colorToReplace)
            end

            if y - 1 >= 1 and not Canvas.getValue(nodes, x, y - 1) then
                table.insert(toProcess, {["x"] = x, ["y"] = y - 1})
                Canvas.setValue(nodes, x, y - 1, colorToReplace)
            end
        end

        table.remove(toProcess, 1)
    end

    self:addNewHistory()

    --set all cells to be filled to the currently selected color
    for _, location in ipairs(cellsToFill) do
        self:setCell(location.x, location.y, self.currentColor)
    end
end

function Canvas:clear()
    self:addNewHistory()

    for x = 1, self.width do
        for y = 1, self.height do
            self:setCell(x, y, self.backgroundColor)
        end
    end
end

--[[
    undo previous drawing actions
]]
function Canvas:undo()
    if self.historyIndex >= #self.cellsHistory then
        return
    end

    self.historyIndex = self.historyIndex + 1

    for _, cell in ipairs(self.cellsHistory[self.historyIndex]) do
        self.cells[cell.x][cell.y].backgroundColor = cell.backgroundColor
    end
end

--[[
    redo previous drawing actions
]]
function Canvas:redo()
    if self.historyIndex <= 1 then
        return
    end

    self.historyIndex = self.historyIndex - 1

    for _, cell in ipairs(self.cellsHistory[self.historyIndex]) do
        self.cells[cell.x][cell.y].backgroundColor = cell.backgroundColor
    end
end

--[[
    copy selected region (indicated by selectionBox)
]]
function Canvas:copySelection()
    if not self.selectionBox.visible then
        return
    end

    self.copiedCells = {}

    local lx, ly = self.selectionBox:getParentLocalPos()
    lx = lx
    ly = ly

    local xBound = math.min(self.width, lx + self.selectionBox.width - 1)
    local yBound = math.min(self.height, ly + self.selectionBox.height - 1)

    self.copiedCellsWidth = 1 + xBound - lx
    self.copiedCellsHeight = 1 + yBound - ly

    local i, j

    i = 1
    for x = lx, xBound do
        j = 1
        for y = ly, yBound do
            Canvas.setValue(self.copiedCells, i, j, self.cells[x][y].backgroundColor)
            j = j + 1
        end
        i = i + 1
    end
end

--[[
    paste copiied selection to location of selectionBox x and y
]]
function Canvas:pasteSelection()
    if #self.copiedCells == 0 then
        return
    end

    self:addNewHistory()

    local lx, ly = self.selectionBox:getParentLocalPos()
    lx = lx
    ly = ly

    local xBound = math.min(self.width, lx + self.copiedCellsWidth - 1)
    local yBound = math.min(self.height, ly + self.copiedCellsHeight - 1)

    local i, j

    i = 1
    for x = lx, xBound do
        j = 1
        for y = ly, yBound do
            self:setCell(x, y, Canvas.getValue(self.copiedCells, i, j))
            j = j + 1
        end
        i = i + 1
    end
end

function Canvas.keyPressed(cnv, event, key, isHeld)
    local keyName = keys.getName(key)
    if ctrlHeld then
        if keyName == "z" then
            cnv:undo()
        elseif keyName == "y" then
            cnv:redo()
        elseif keyName == "c" then
            cnv:copySelection()
        end
    end
end

function Canvas.monitorTouch(cnv, event, side, x, y)
    cnv.mouseClick(cnv, "mouse_click", 1, x, y)
end

function Canvas.mouseClick(cnv, event, button, x, y)
    if button == 1 then
        local lx = 1 + x - cnv.globalX
        local ly = 1 + y - cnv.globalY

        cnv:currentDrawAction(lx, ly)
    elseif button == 2 then
        cnv.selectionBox.visible = false
        cnv.selectionBox:setGlobalPos(x, y)
        cnv.selectionBox:setWidth(1)
        cnv.selectionBox:setHeight(1)
    end
end

function Canvas.mouseDrag(cnv, event, button, x, y)
    if button == 1 then
        Canvas.mouseClick(cnv, "mouse_click", 1, x, y)
    elseif button == 2 then
        cnv.selectionBox.visible = true

        if x >= cnv.selectionBox.globalX then
            cnv.selectionBox:setWidth(1 + x - cnv.selectionBox.globalX)
        end

        if y >= cnv.selectionBox.globalY then
            cnv.selectionBox:setHeight(1 + y - cnv.selectionBox.globalY)
        end
    end
end

function Canvas.mouseUp(cnv, event, button, x, y)
    if button == 2 then
        
    end
end

function Canvas.paste(cnv, event, paste)
    cnv:pasteSelection()
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
--Button
--------------------------------

Button = Text:new {
    onClickName = nil,
    onClick = nil,
}

function Button:new(o) 
    o = o or {}
    o = Text:new(o)

    setmetatable(o, self)
    self.__index = self

    if not o.buffer.display.isMonitor then
        registerSelectionCallback("mouse_click", o, Button.mouseClick, o.onClickName)
    else
        registerSelectionCallback("monitor_touch", o, Button.monitorTouch, o.onClickName)
    end
end

function Button.mouseClick(btn, event, button, x, y)
    if btn.onClick and button == 1 then
        btn:onClick()
    end
end

function Button.monitorTouch(btn, event, side, x, y)
    if btn.onClick then
        btn:onClick()
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

    selecting = false,
    selectionStartIndex = nil,
    selectionEndIndex = nil,
    selectionBackgroundColor = colors.gray,
    selectionTextColor = colors.lightGray,

    autoComplete = false,
    allAutoCompleteChoices = {},
    currentAutoCompleteChoices = {},
    currentChoiceIndex = nil,
    autoCompletePos = 0,
}

function Textbox:new(o)
    o = o or {}
    o.allAutoCompleteChoices = o.allAutoCompleteChoices or {}
    o.currentAutoCompleteChoices = o.currentAutoCompleteChoices or {}
    o.textWithoutAutoComplete = o.text

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
        registerSelectionCallback("mouse_drag", o, Textbox.mouseDragged, "mouseDragged")

        registerSelectionCallback("monitor_touch", o, Textbox.monitorTouched, "monitorTouched")

        removeSelectionCallback("mouse_scroll", o, "textScroll")
        registerSelectionCallback("mouse_scroll", o, Textbox.textScroll, "textScroll")
    end

    return o
end

--[[
    scroll texbox element and update cursor position
]]
function Textbox.textScroll(txb, event, scrollDir, x, y)
    txb:eraseSelection()
    txb:eraseCursor()
    if shiftHeld then
        txb:horizontalScroll(scrollDir)
    else
        txb:verticalScroll(scrollDir)
    end
    txb:drawSelection()
    txb:drawCursor()
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
function Textbox:computeRowIndexAndOffset(textPosition)
    local stringIndex = 0
    local rowIndex = 1
    local rowOffset = 0

    local foundCursorPos = false

    for index, textData in ipairs(self.textRows) do
        if stringIndex + #textData.text >= textPosition then
            rowIndex = index
            rowOffset = textPosition - stringIndex
            foundCursorPos = true
            break
        else
            stringIndex = stringIndex + #textData.text + textData.newLineTerm
        end
    end

    if not foundCursorPos then
        rowIndex = #self.textRows + 1
        rowOffset = 0
    end

    return rowIndex, rowOffset
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
    erase selection highlighting
]]
function Textbox:eraseSelection()
    if not self.selecting then
        return
    end

    local minSelection = math.min(self.selectionStartIndex, self.selectionEndIndex)
    local maxSelection = math.max(self.selectionStartIndex, self.selectionEndIndex)

    local selectionStartRow, selectionStartOffset = self:computeRowIndexAndOffset(minSelection)
    local selectionEndRow, selectionEndOffset = self:computeRowIndexAndOffset(maxSelection)

    local rowIndex = self:getStartRowIndex()
    local substringIndex

    for y = 1, self.height do
        substringIndex = self:getStartSubstringIndex(rowIndex)

        for x = 1, self.width do
            if selectionStartRow == selectionEndRow and rowIndex == selectionStartRow and substringIndex > selectionStartOffset and substringIndex <= selectionEndOffset
            or selectionStartRow ~= selectionEndRow
            and (rowIndex == selectionStartRow and substringIndex > selectionStartOffset and substringIndex <= #self.textRows[rowIndex].text
            or rowIndex == selectionEndRow and substringIndex > 0 and substringIndex <= selectionEndOffset
            or rowIndex > selectionStartRow and rowIndex < selectionEndRow and substringIndex > 0 and substringIndex <= #self.textRows[rowIndex].text) then
                self.cells[x][y].backgroundColor = self.backgroundColor
                self.cells[x][y].textColor = self.textColor
            end

            substringIndex = substringIndex + 1
        end

        rowIndex = rowIndex + 1
    end
end

--[[
    draw highlighted selection
]]
function Textbox:drawSelection()
    if not self.selecting then
        return
    end

    local minSelection = math.min(self.selectionStartIndex, self.selectionEndIndex)
    local maxSelection = math.max(self.selectionStartIndex, self.selectionEndIndex)

    local selectionStartRow, selectionStartOffset = self:computeRowIndexAndOffset(minSelection)
    local selectionEndRow, selectionEndOffset = self:computeRowIndexAndOffset(maxSelection)

    local rowIndex = self:getStartRowIndex()
    local substringIndex

    for y = 1, self.height do
        substringIndex = self:getStartSubstringIndex(rowIndex)

        for x = 1, self.width do
            if selectionStartRow == selectionEndRow and rowIndex == selectionStartRow and substringIndex > selectionStartOffset and substringIndex <= selectionEndOffset
            or selectionStartRow ~= selectionEndRow
            and (rowIndex == selectionStartRow and substringIndex > selectionStartOffset and substringIndex <= #self.textRows[rowIndex].text
            or rowIndex == selectionEndRow and substringIndex > 0 and substringIndex <= selectionEndOffset
            or rowIndex > selectionStartRow and rowIndex < selectionEndRow and substringIndex > 0 and substringIndex <= #self.textRows[rowIndex].text) then
                self.cells[x][y].backgroundColor = self.selectionBackgroundColor
                self.cells[x][y].textColor = self.selectionTextColor
            end

            substringIndex = substringIndex + 1
        end

        rowIndex = rowIndex + 1
    end
end

--[[
    move the view buffer along with the cursor
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
        self:drawSelection()
        self:drawCursor()
        return
    end

    self:eraseSelection()
    self:eraseCursor()    

    self.cursorPos = newCursorPos
    self.cursorRowIndex, self.cursorRowOffset = self:computeRowIndexAndOffset(self.cursorPos)

    self:scrollCursorIntoBounds()

    self:drawSelection()
    self:drawCursor()
end

--[[
    set cursor position based on an x and y input
]]
function Textbox:setCursorPosXY(x, y)
    self:eraseSelection()
    self:eraseCursor()

    self.cursorRowIndex = math.min(#self.textRows + self.textRows[#self.textRows].newLineTerm, math.max(1, y - 1 + self:getStartRowIndex()))
    self.cursorRowOffset = math.min(#self.textRows[self.cursorRowIndex].text, math.max(0, x - 2 + self:getStartSubstringIndex(self.cursorRowIndex)))

    self:computeCursorPos()
    self:scrollCursorIntoBounds()

    self:drawSelection()
    self:drawCursor()
end

--[[
    insert character at cursor position and increment cursor position
]]
function Textbox:insertCharacter(character)
    if self.selecting then
        local minSelection = math.min(self.selectionStartIndex, self.selectionEndIndex)
        local maxSelection = math.max(self.selectionStartIndex, self.selectionEndIndex)

        self:setCursorPos(minSelection)
        self:eraseSelection()
        self:setText(self.text:sub(0, minSelection)..self.text:sub(maxSelection + 1))
        self:stopSelecting()
    end
    self:setText(self.text:sub(0, self.cursorPos)..character..self.text:sub(self.cursorPos + 1))
    self:setCursorPos(self.cursorPos + 1)
end

function Textbox:findStartOfCurrentWord()
    local spaceIndex
    local nextSpaceIndex = self.textWithoutAutoComplete:find(" ")

    while nextSpaceIndex and nextSpaceIndex <= self.cursorPos do
        spaceIndex = nextSpaceIndex
        nextSpaceIndex = self.textWithoutAutoComplete:find(" ", spaceIndex + 1)
    end

    if not spaceIndex then
        return 1
    end

    return spaceIndex + 1
end

--[[
    reset selection variables
]]
function Textbox:stopSelecting()
    self.selecting = false
    self.selectionStartIndex = nil
    self.selectionEndIndex = nil
end

--[[
    sets the beginning of the selection area
]]
function Textbox:setSelectionStart(textIndex)
    self:eraseSelection()
    self:stopSelecting()
    self.selectionStartIndex = textIndex
end

function Textbox:setSelectionEnd(textIndex)
    self:eraseSelection()
    self.selectionEndIndex = textIndex
    self.selecting = true
    self:drawSelection()
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

    local minSelection, maxSelection
    if txb.selecting then
        minSelection = math.min(txb.selectionStartIndex, txb.selectionEndIndex)
        maxSelection = math.max(txb.selectionStartIndex, txb.selectionEndIndex)
    end

    if ctrlHeld and keyName == "a" then
        txb:setSelectionStart(0)
        txb:setCursorPos(#txb.text - 1)
        txb:setSelectionEnd(txb.cursorPos)
        txb:drawCursor()
    elseif keyName == "left" and txb.cursorPos > 0 then
        if shiftHeld then
            if not txb.selecting then
                txb:setSelectionStart(txb.cursorPos)
            end
            txb:setCursorPos(txb.cursorPos - 1)
            txb:setSelectionEnd(txb.cursorPos)
            txb:drawCursor()
        elseif txb.selecting then
            txb:setCursorPos(minSelection)
            txb:eraseSelection()
            txb:stopSelecting()
            txb:drawCursor()
        else
            txb:setCursorPos(txb.cursorPos - 1)
        end
    elseif keyName == "right" and txb.cursorPos <= #txb.text then
        if shiftHeld then
            if not txb.selecting then
                txb:setSelectionStart(txb.cursorPos)
            end
            txb:setCursorPos(txb.cursorPos + 1)
            txb:setSelectionEnd(txb.cursorPos)
            txb:drawCursor()
        elseif txb.selecting then
            txb:setCursorPos(maxSelection)
            txb:eraseSelection()
            txb:stopSelecting()
            txb:drawCursor()
        else
            txb:setCursorPos(txb.cursorPos + 1)
        end
    elseif keyName == "up" then
        local cursorX = txb:getCursorPosX()
        local cursorY = txb:getCursorPosY()

        if shiftHeld then
            if not txb.selecting then
                txb:setSelectionStart(txb.cursorPos)
            end
            txb:setCursorPosXY(cursorX, cursorY - 1)
            txb:setSelectionEnd(txb.cursorPos)
            txb:drawCursor()
        elseif txb.selecting then
            txb:setCursorPos(minSelection)
            cursorX = txb:getCursorPosX()
            cursorY = txb:getCursorPosY()
            txb:setCursorPosXY(cursorX, cursorY - 1)
            txb:eraseSelection()
            txb:stopSelecting()
            txb:drawCursor()
        else
            txb:setCursorPosXY(cursorX, cursorY - 1)
        end
    elseif keyName == "down" then
        local cursorX = txb:getCursorPosX()
        local cursorY = txb:getCursorPosY()

        if shiftHeld then
            if not txb.selecting then
                txb:setSelectionStart(txb.cursorPos)
            end
            txb:setCursorPosXY(cursorX, cursorY + 1)
            txb:setSelectionEnd(txb.cursorPos)
            txb:drawCursor()
        elseif txb.selecting then
            txb:setCursorPos(maxSelection)
            cursorX = txb:getCursorPosX()
            cursorY = txb:getCursorPosY()
            txb:setCursorPosXY(cursorX, cursorY + 1)
            txb:eraseSelection()
            txb:stopSelecting()
            txb:drawCursor()
        else
            txb:setCursorPosXY(cursorX, cursorY + 1)
        end
    elseif keyName == "enter" and not txb.enterSubmits then
        txb:eraseSelection()
        txb:eraseCursor()
        txb:insertCharacter("\n")
    elseif keyName == "backspace" then
        if txb.selecting then
            txb:setCursorPos(minSelection)
            txb:eraseSelection()
            txb:setText(txb.text:sub(0, minSelection)..txb.text:sub(maxSelection + 1))
            txb:stopSelecting()
            txb:drawCursor()
        elseif txb.cursorPos > 0 then
            txb:eraseSelection()
            txb:eraseCursor()
            txb:setText(txb.text:sub(0, txb.cursorPos - 1)..txb.text:sub(txb.cursorPos + 1))
            txb:setCursorPos(txb.cursorPos - 1)
        end
    elseif keyName == "delete" then
        if txb.selecting then
            txb:setCursorPos(minSelection)
            txb:eraseSelection()
            txb:setText(txb.text:sub(0, minSelection)..txb.text:sub(maxSelection + 1))
            txb:stopSelecting()
            txb:drawCursor()
        elseif txb.cursorPos < #txb.text then
            txb:eraseSelection()
            txb:eraseCursor()
            txb:setText(txb.text:sub(0, txb.cursorPos)..txb.text:sub(txb.cursorPos + 2))
            txb:setCursorPos(txb.cursorPos)
        end
    elseif keyName == "home" then
        if shiftHeld then
            if not txb.selecting then
                txb:setSelectionStart(txb.cursorPos)
            end
            txb:setCursorPos(txb.cursorPos - txb.cursorRowOffset)
            txb:setSelectionEnd(txb.cursorPos)
            txb:drawCursor()
        else
            txb:setCursorPos(txb.cursorPos - txb.cursorRowOffset)
        end
    elseif keyName == "end" then
        if shiftHeld then
            if not txb.selecting then
                txb:setSelectionStart(txb.cursorPos)
            end
            txb:setCursorPos(txb.cursorPos - txb.cursorRowOffset + #txb.textRows[txb.cursorRowIndex].text)
            txb:setSelectionEnd(txb.cursorPos)
            txb:drawCursor()
        else
            txb:setCursorPos(txb.cursorPos - txb.cursorRowOffset + #txb.textRows[txb.cursorRowIndex].text)
        end
    end
end

--[[
    handle monitor touch events
]]
function Textbox.monitorTouched(txb, event, side, x, y)
    Textbox.mouseClicked(txb, "mouse_click", 1, x, y)
end

--[[
    handle mouse clicks for textbox element
]]
function Textbox.mouseClicked(txb, event, button, x, y)
    if button == 1 then
        local lx, ly = txb:getLocalPos(x, y)

        txb:setCursorPosXY(lx, ly)
        txb:setSelectionStart(txb.cursorPos)
        txb:drawCursor()
    end
end

--[[
    handle mouse drag events for textbox element
]]
function Textbox.mouseDragged(txb, event, button, x, y)
    if button == 1 then
        local lx, ly = txb:getLocalPos(x, y)

        txb:setCursorPosXY(lx, ly)
        txb:setSelectionEnd(txb.cursorPos)
        txb:drawCursor()
    end
end

--[[
    set display and return buffer linked to it
]]
function createBuffer(device, bufferName, backgroundColor, x, y, width, height)
    local isMonitor
    local side

    local deviceMT = getmetatable(device)

    if deviceMT and deviceMT.type == "monitor" then
        isMonitor = true
        side = deviceMT.name
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
        side = side,
        width = width,
        height = height,
    }

    local buffer = Buffer:new {
        name = bufferName,
        display = display,
        backgroundColor = backgroundColor,
        globalX = x,
        globalY = y,
        width = display.width,
        height = display.height,
    }

    table.insert(buffers, buffer)

    return buffer
end