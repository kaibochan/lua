local gui = require "gui"

local width, height = term.getSize()

local window = createWindow(term, "window", colors.pink)

local main = Element:new {
    name = "main",
    window = window,
    width = width,
    height = height,
}

local button1 = Text:new {
    name = "button1",
    window = window,
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

registerSelectionCallback("mouse_click", button1, function(element, event, button, x, y)
    if button == 1 then
        button1:setBackgroundColor(2^math.random(15))
    end
end, "buttonClick")

local button2 = Text:new {
    name = "button2",
    window = window,
    parent = main,
    x = 2,
    y = 3,
    text = "kaibochan",
    horizontalAlignment = align.center,
    verticalAlignment = align.center,
    backgroundColor = colors.blue,
    width = 11,
    height = 1,
    padding = 0,
}

registerSelectionCallback("mouse_click", button2, function(element, event, button, x, y)
    if button == 1 then
        button2:setBackgroundColor(2^math.random(15))
    elseif button == 2 then
        button2:setTextColor(2^math.random(15))
    end
end, "buttonClick")

local text = Text:new {
    name = "text",
    window = window,
    parent = main,
    y = 5,
    text = "lorem ipsum",
    horizontalAlignment = align.center,
    verticalAlignment = align.center,
    backgroundColor = colors.red,
    width = 10,
    height = 4,
}

registerSelectionCallback("mouse_drag", text, function(element, event, button, x, y)
    if button == 1 then
        text:setGlobalPos(x, y)
    end
end, "mouseDrag")

local childText = Text:new {
    name = "childText",
    window = window,
    parent = text,
    text = "a",
    x = 2,
    y = 1,
    width = 5,
    height = 1,
    backgroundColor = colors.white,
    textColor = colors.black,
}

registerSelectionCallback("mouse_drag", childText, function(element, event, button, x, y)
    if button == 1 then
        childText:setGlobalPos(x, y)
    end
end, "mouseDrag")

local textBox = Textbox:new {
    name = "textBox1",
    window = window,
    parent = main,
    x = 25,
    y = 2,
    width = 20,
    height = 5,
    backgroundColor = colors.red,
    textColor = colors.orange,
}

while true do
    if selectedElement then
        text:setText(selectedElement.name)
    else
        text:setText("")
    end
    childText:setText(childText.globalX.." "..childText.globalY)
    window:draw()

    parallel.waitForAny(handleInputEvents())
end