local gui = require "gui"

local paragraph1 = 
"Lorem ipsum dolor sit amet, consectetur adipiscing elit.\nPellentesque gravida porttitor elit,"
.."quis blandit erat rutrum in.\nNulla ut rhoncus elit, vel placerat lacus.\nIn hac habitasse pl"
.."atea dictumst.\nDuis non magna felis.\nSed gravida leo rhoncus felis imperdiet lacinia.\nEtiam"
.." vel lorem ligula.\nSuspendisse fringilla ante massa, dictum aliquam sem hendrerit sed.\nNull"
.."am et auctor massa, in accumsan justo.\nCurabitur lobortis dignissim vehicula.\nSed ornare sa"
.."pien tortor, at pellentesque est consequat eget.\nNulla scelerisque aliquam augue, id dapibu"
.."s erat posuere eu.\nProin vel suscipit risus, quis feugiat nisi.\nNam ut metus ut enim bibend"
.."um tempor.\nNam tincidunt efficitur massa.\nSed pulvinar nibh eget ullamcorper tempus.\nIn a o"
.."dio eget neque varius hendrerit pellentesque quis ipsum.\n\n"

local paragraph2 =
"Ut a velit felis.\nMauris erat sapien, pharetra non libero id, auctor vulputate mauris.\nSed "
.."at ullamcorper ante.\nUt nec odio eu eros sodales tempus.\nMaecenas consequat lacus in enim c"
.."ondimentum imperdiet.\nVivamus dapibus auctor leo, eu convallis tortor condimentum eu.\nDonec"
.." ornare libero a tincidunt sodales.\nMorbi elementum odio congue arcu convallis feugiat.\nNam"
.." justo nunc, ullamcorper eget urna ut, fringilla ornare sem.\nFusce bibendum mi nec diam tem"
.."por, a sodales elit ultrices."

local width, height = term.getSize()

local canvas1 = createCanvas(term, "canvas1", colors.white, 1, 1, math.floor(width / 2), height)
local canvas2 = createCanvas(term, "canvas2", colors.black, math.floor(width / 2) + 1, 1, math.floor(width / 2), height)

local txb1 = Textbox:new {
    name = "txb1",
    parent = canvas1,
    canvas = canvas1,
    width = canvas1.width,
    height = canvas1.height,
    padding = 1,
    text = paragraph1,
    backgroundColor = colors.red,
    textColor = colors.orange,
    horizontalAlignment = align.left,
    verticalAlignment = align.top,
    wrapText = false,
}

local txb2 = Textbox:new {
    name = "txb2",
    parent = canvas2,
    canvas = canvas2,
    width = canvas2.width,
    height = canvas2.height,
    padding = 1,
    text = paragraph1,
    backgroundColor = colors.black,
    textColor = colors.white,
    horizontalAlignment = align.left,
    verticalAlignment = align.top,
    wrapText = false,
}


while true do
    canvas1:draw()
    canvas2:draw()

    parallel.waitForAny(handleInputEvents)
end