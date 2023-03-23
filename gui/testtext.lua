local gui = require "gui"

local paragraph = 
"Lorem ipsum dolor sit amet, consectetur adipiscing elit.\nPellentesque gravida porttitor elit,"
.."quis blandit erat rutrum in.\nNulla ut rhoncus elit, vel placerat lacus.\nIn hac habitasse pl"
.."atea dictumst.\nDuis non magna felis.\nSed gravida leo rhoncus felis imperdiet lacinia.\nEtiam"
.." vel lorem ligula.\nSuspendisse fringilla ante massa, dictum aliquam sem hendrerit sed.\nNull"
.."am et auctor massa, in accumsan justo.\nCurabitur lobortis dignissim vehicula.\nSed ornare sa"
.."pien tortor, at pellentesque est consequat eget.\nNulla scelerisque aliquam augue, id dapibu"
.."s erat posuere eu.\nProin vel suscipit risus, quis feugiat nisi.\nNam ut metus ut enim bibend"
.."um tempor.\nNam tincidunt efficitur massa.\nSed pulvinar nibh eget ullamcorper tempus.\nIn a o"
.."dio eget neque varius hendrerit pellentesque quis ipsum.\n\n"

.."Ut a velit felis.\nMauris erat sapien, pharetra non libero id, auctor vulputate mauris.\nSed "
.."at ullamcorper ante.\nUt nec odio eu eros sodales tempus.\nMaecenas consequat lacus in enim c"
.."ondimentum imperdiet.\nVivamus dapibus auctor leo, eu convallis tortor condimentum eu.\nDonec"
.." ornare libero a tincidunt sodales.\nMorbi elementum odio congue arcu convallis feugiat.\nNam"
.." justo nunc, ullamcorper eget urna ut, fringilla ornare sem.\nFusce bibendum mi nec diam tem"
.."por, a sodales elit ultrices."

local width, height = term.getSize()

local main = Element:new {
    name = "main",
    width = width,
    height = height,
}

local text = Text:new {
    name = "text",
    parent = main,
    width = 30,
    height = 10,
    padding = 1,
    text = paragraph,
    backgroundColor = colors.red,
    textColor = colors.orange,
    wrapText = false,
}

local debug = Text:new {
    name = "debug",
    parent = main,
    x = 31,
    width = width - 30,
    height = 10,
}

local selectedElement = main

local debugText

while true do
    debugText = ""..text.verticalScrollOffset.."\n"..#text.textRows.."\n"..(#text.textRows - text.height + 2 * text.padding)
    debug:setText(debugText)

    main:draw()

    local event, data1, data2, data3 = os.pullEvent()
    if event == "mouse_click" then
        selectedElement = getSelectedElement(main, data2, data3)
    end

    if callbacks[event] and callbacks[event][selectedElement.name] then
        callbacks[event][selectedElement.name](selectedElement, event, data1, data2, data3)
    end
end