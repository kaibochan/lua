
--[[
    generalized button creation function
    --text: button text
    --bgColor: normal background color
    --hlColor: highlighted color
    --func: function to call on button click
    --x, y: location to draw button
]]
local function createButton(text, bgColor, hlColor, func, x, y)
    local button = {
        ["text"] = text,
        ["function"] = func,
        ["currentColor"] = bgColor,
        ["backgroundColor"] = bgColor,
        ["highlightColor"] = hlColor,
        ["textColor"] = colors.white,
        ["bounds"] = {
            ["topLeft"] = {
                ["x"] = x,
                ["y"] = y,
            },
            ["bottomRight"] = {
                ["x"] = x + #text - 1,
                ["y"] = y,
            },
        },
    }

    return button
end

--[[
    draws all buttons according to their location, text, and background color
]]
local function drawButtons(display, buttons)
    local currentColor = display.getBackgroundColor()

    for _, button in pairs(buttons) do
        display.setCursorPos(button.bounds.topLeft.x, button.bounds.topLeft.y)
        display.setBackgroundColor(button.currentColor)
        display.setTextColor(button.textColor)
        display.write(button.text)
    end

    display.setBackgroundColor(currentColor)
end

--[[
    highlights the button that is passed in
]]
local function highlightButton(button)
    button.currentColor = button.highlightColor
end

--[[
    unhighlight the button that is passed in
]]
local function unhighlightButton(button)
    button.currentColor = button.backgroundColor
end