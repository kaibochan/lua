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


local canvas = setDisplay(term, "canvas", colors.white)

local text = Text:new {
    name = "text",
    canvas = canvas,
    width = canvas.width,
    height = canvas.height,
    padding = 0,
    text = paragraph,
    backgroundColor = colors.red,
    textColor = colors.orange,
    horizontalAlignment = align.center,
    verticalAlignment = align.center,
    wrapText = false,
}

local selectedElement

while true do
    canvas:draw()

    local event, data1, data2, data3 = os.pullEvent()
    if event == "mouse_click" then
        selectedElement = getSelectedElement(canvas, data2, data3)
    end

    if selectedElement and selectionCallbacks[event] and selectionCallbacks[event][selectedElement.name] then
        selectionCallbacks[event][selectedElement.name](selectedElement, event, data1, data2, data3)
    end
end