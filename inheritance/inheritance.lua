align = {
    left = "left",
    center = "center",
    right = "right",
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
    alignment = align.left,
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

    local stringBegin = 1
    local textWidth = o.width - o.padding * 2
    local stringEnd = stringBegin + textWidth - 1
    local newLineIndex = o.text:find("\n", stringBegin, true)
    local substring
    local substringIndex = 1

    local textOffset

    for y = 1, o.height do
        if y > o.padding and y <= o.height - o.padding then
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

            stringEnd = stringBegin + textWidth - 1
            substringIndex = 1

            if o.alignment == align.left then
                textOffset = o.padding
            elseif o.alignment == align.center then
                textOffset = o.width / 2 - #substring / 2
            elseif o.alignment == align.right then
                textOffset = o.width - o.padding - #substring
            end

            for x = 1, o.width do
                if x > textOffset and x <= textOffset + #substring then
                    o.cells[x][y].character = substring:sub(substringIndex, substringIndex)
                    substringIndex = substringIndex + 1
                end
            end
        end
    end

    return o
end

text = Text:new{
    text = "text",
    backgroundColor = colors.red,
    width = 10,
    height = 3,
    padding = 1,
}

text:draw()
