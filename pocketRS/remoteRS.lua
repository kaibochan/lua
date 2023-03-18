local remoteRSProtocol = "remoteRS"

local function throwError(sentFrom, parameters)
    local errorMessage = parameters["errorMessage"]
    error(errorMessage)
end

local function selectItemFromList(sentFrom, parameters)
    local itemList = parameters["itemList"]

    --cursor position of beginning of highlighted index text
    --and end cursor position, so we can read whether user clicked
    --on this selection or not
    local itemSelectBounds = {}

    local firstCursorPos = {}
    local secondCursorPos = {}
    local currentTextColor = term.getTextColor()

    for index, item in ipairs(itemList) do
        --print indexed list with index highlighted red
        term.setTextColor(colors.red)

        firstCursorPos.x, firstCursorPos.y = term.getCursorPos()
        term.write("["..index.."]")
        secondCursorPos.x, secondCursorPos.y = term.getCursorPos()

        term.setTextColor(currentTextColor)

        print("\t"..item.displayName)

        table.insert(itemSelectBounds, index, {["left"] = firstCursorPos, ["right"] = secondCursorPos})
    end

    print("Select an item from the list above")
    local selection
    local button, x, y

    --debug
    for index, bound in ipairs(itemSelectBounds) do
        print(index, bound.left.x, bound.right.x, bound.left.y, bound.right.y)
    end

    while not selection do
        _, button, x, y = os.pullEvent("mouse_click")

        --if user clicks left button then search for which item they clicked
        --using the itemSelectBounds table
        if button == 1 then
            --debug
            print(button, x, y)

            for index, bound in ipairs(itemSelectBounds) do

                --check if mouse_click was within bounds of this item index
                if x >= bound.left.x and x <= bound.right.x
                and y >= bound.left.y and y <= bound.right.y then
                    selection = index
                    break
                end
            end
        end
    end

    local message = "select "..selection
    rednet.send(sentFrom, message, remoteRSProtocol)
end

local function displayQuery(sentFrom, parameters)
    local queryResult = parameters["queryResult"]

    for index, item in ipairs(queryResult) do
        print(item.amount, item.displayName)
    end
end

local function display(sentFrom, parameters)
    local toDisplay = parameters["toDisplay"]
    print(toDisplay)
end

--create parameter objects (a pair of name and type)
local function parameter(name, type)
    return {["name"] = name, ["type"] = type}
end

local actions = {
    ["error"] = {
        ["function"] = throwError,
        ["parameters"] = {
            parameter("errorMessage", "string")
        },
    },
    ["select"] = {
        ["function"] = selectItemFromList,
        ["parameters"] = {
            parameter("itemList", "table")
        },
    },
    ["query"] = {
        ["function"] = displayQuery,
        ["parameters"] = {
            parameter("queryResult", "table")
        },
    },
    ["display"] = {
        ["function"] = display,
        ["parameters"] = {
            parameter("toDisplay", "string")
        },
    },
}

local function openModem()
    local modem = peripheral.find("modem")
    local modemLocation = peripheral.getName(modem)
    
    rednet.open(modemLocation)
end

--quotes are placed around parameters to ensure they are
--grouped properly when parsed out by recieving parties
local function packageArguments()
    local message = arg[1]

    for index = 2, #arg do
        message = message.." ".."\""..arg[index].."\""
    end

    return message
end

function main()
    if not fs.exists("com.lua") then
        error("com.lua is necessary for the operation of this program")
    end

    os.loadAPI("com.lua")

    --should have at least one argument besides the program call
    if #arg == 0 then
        error("Expected at least one argument: action")
    end

    local message = packageArguments()

    openModem()

    rednet.broadcast(message, remoteRSProtocol)
    local sentFrom, reply = rednet.receive(remoteRSProtocol, 5)
    
    if not reply then
        return
    end

    local action, parameters = com.parseMessage(actions, sentFrom, reply, remoteRSProtocol)
    
    if action and parameters then
        actions[action]["function"](sentFrom, parameters)
    end
end

main()