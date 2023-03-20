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

Text = Element:new{
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
            substring = o.text:sub(stringBegin, newLineIndex - 1)
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

local main = Element:new {
    x = 3,
    y = 2,
    width = 20,
    height = 10,
    backgroundColor = colors.brown
}

local text1 = Text:new {
    parent = main,
    text = "lorem ipsum",
    horizontalAlignment = align.center,
    verticalAlignment = align.center,
    backgroundColor = colors.red,
    width = 11,
    height = 1,
    padding = 0,
}

local text2 = Text:new {
    parent = main,
    y = 3,
    text = "text\ntext",
    horizontalAlignment = align.center,
    verticalAlignment = align.center,
    transparentBackground = true,
    width = 10,
    height = 4,
    padding = 1,
}

main:draw()