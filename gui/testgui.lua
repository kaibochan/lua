local gui = require "gui"

local width, height = term.getSize()

local main = Element:new {
    name = "main",
    width = width,
    height = height,
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

registerCallback("mouse_click", button1, function(element, event, button, x, y)
    if button == 1 then
        button1:setBackgroundColor(2^math.random(15))
    end
end)

local button2 = Text:new {
    name = "button2",
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

registerCallback("mouse_click", button2, function(element, event, button, x, y)
    if button == 1 then
        button2:setBackgroundColor(2^math.random(15))
    elseif button == 2 then
        button2:setTextColor(2^math.random(15))
    end
end)

local text = Text:new {
    name = "text",
    parent = main,
    y = 5,
    text = "lorem ipsum",
    horizontalAlignment = align.center,
    verticalAlignment = align.center,
    backgroundColor = colors.red,
    width = 10,
    height = 4,
}

registerCallback("mouse_drag", text, function(element, event, button, x, y)
    if button == 1 then
        text:setGlobalPos(x, y)
    end
end)

local childText = Text:new {
    name = "childText",
    parent = text,
    text = "a",
    x = 2,
    y = 1,
    width = 5,
    height = 1,
    backgroundColor = colors.white,
    textColor = colors.black,
}

registerCallback("mouse_drag", childText, function(element, event, button, x, y)
    if button == 1 then
        childText:setGlobalPos(x, y)
    end
end)

local textBox = Textbox:new {
    name = "textBox1",
    parent = main,
    x = 25,
    y = 2,
    width = 20,
    height = 5,
    backgroundColor = colors.red,
    textColor = colors.orange,
}

local selectedElement = main

while true do
    text:setText(selectedElement.name)
    childText:setText(childText.globalX.." "..childText.globalY)
    main:draw()

    local event, data1, data2, data3 = os.pullEvent()
    if event == "mouse_click" then
        selectedElement = getSelectedElement(main, data2, data3)
    end

    if callbacks[event] and callbacks[event][selectedElement.name] then
        callbacks[event][selectedElement.name](selectedElement, event, data1, data2, data3)
    end
end