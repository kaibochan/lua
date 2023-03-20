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
    parent = nil,
    children = {},
    x = 1,
    y = 1,
    width = 1,
    height = 1,
    cells = {},
}
    
function Element:new (o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    for x = 1, o.width do
        table.insert(o.cells, x, {})
        for y = 1, o.height do
            table.insert(o.cells[x], y, Cell:new{})
        end
    end

    return o
end

function Element:draw()
    for x = 1, self.width do
        for y = 1, self.height do
            term.setCursorPos(x, y)
            term.setBackgroundColor(self.cells[x][y].backgroundColor)
            term.setTextColor(self.cells[x][y].textColor)
            term.write(self.cells[x][y].character)
        end
    end
end

Text = Element:new{
    text = "",
    padding = 0,
    horizontalAlignment = align.left,
    verticalAlignment = align.top,
    textColor = colors.white,
    transparentBackground = false,
    backgroundColor = colors.black,
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

    local textRows = {}

    local stringBegin = 1
    local rowWidth = o.width - o.padding * 2
    local stringEnd = stringBegin + rowWidth - 1
    local newLineIndex = o.text:find("\n", stringBegin, true)
    local substring
    
    while stringBegin < #o.text do
        if newLineIndex and newLineIndex < stringBegin then
            newLineIndex = o.text:find("\n", stringBegin, true)
        end
        
        if newLineIndex and newLineIndex < stringEnd then
            substring = o.text:sub(stringBegin, newLineIndex)
            stringBegin = newLineIndex + 1
        else
            substring = o.text:sub(stringBegin, stringEnd)
            stringBegin = stringEnd + 1
        end
        
        stringEnd = stringBegin + rowWidth - 1
        
        table.insert(textRows, substring)
    end
    
    local verticalOffset
    if o.verticalAlignment == align.top then
        verticalOffset = o.padding
    elseif o.verticalAlignment == align.center then
        verticalOffset = o.height / 2 - #textRows / 2
    elseif o.verticalAlignment == align.bottom then
        verticalOffset = o.height - o.padding - #textRows
    end
    
    local horizontalOffsets = {}
    for index, text in ipairs(textRows) do
        if o.horizontalAlignment == align.left then
            table.insert(horizontalOffsets, o.padding)
        elseif o.horizontalAlignment == align.center then
            table.insert(horizontalOffsets, o.width / 2 - #textRows[index] / 2)
        elseif o.horizontalAlignment == align.right then
            table.insert(horizontalOffsets, o.width - o.padding - #textRows[index])
        end
    end

    local substringIndex = 1
    local rowIndex = 1

    for y = 1, o.height do
        if y > verticalOffset and y <= verticalOffset + #textRows then
            substringIndex = 1
            
            for x = 1, o.width do
                if x > horizontalOffsets[rowIndex] and x <= horizontalOffsets[rowIndex] + #textRows[rowIndex] then
                    o.cells[x][y].character = textRows[rowIndex]:sub(substringIndex, substringIndex)
                    substringIndex = substringIndex + 1
                end
            end

            rowIndex = rowIndex + 1
        end
    end

    return o
end

text = Text:new{
    text = "abcdefghijklmnopqrstuvwxyz",
    horizontalAlignment = align.center,
    verticalAlignment = align.center,
    backgroundColor = colors.red,
    width = 20,
    height = 10,
    padding = 2,
}

text:draw()