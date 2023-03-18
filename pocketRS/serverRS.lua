--global peripherals to be used across the action functions
local refindStorageBridge
local inventoryManager
local remoteRSProtocol = "remoteRS"
local chestDirection = "north"

--create parameter objects (a pair of name and type)
local function parameter(name, type)
    return {["name"] = name, ["type"] = type}
end

local function findMatchingItems(itemName)
    local allItems = refindStorageBridge.listItems()
    local matchingItems = {}

    for index, item in ipairs(allItems) do
        if item.displayName:lower():find(itemName) then
            local itemData = {
                ["name"] = item.name,
                ["displayName"] = item.displayName,
                ["amount"] = item.amount,
            }
            table.insert(matchingItems, itemData)
        end
    end

    return matchingItems
end

local function evaluateSelection(selectionList, parameters)
    local selection = parameters["selection"]
    return selectionList[selection]
end

local function subActions()
    local actions = {
        ["select"] = {
            ["function"] = evaluateSelection,
            ["parameters"] = {
                parameter("selection", "number")
            },
        },
    }

    return actions
end

local function request(sentFrom, parameters)
    local actions = subActions()

    local itemName = parameters["itemName"]
    local count = parameters["count"]

    local matchingItems = findMatchingItems(itemName)
    local itemToSend
    
    --if more than one matching item, have user confirm which one
    if #matchingItems > 1 then
        local matchingItemsText = textutils.serialise(matchingItems)
        local message = "select \""..matchingItemsText.."\""
        rednet.send(sentFrom, message, remoteRSProtocol)

        local _, reply = rednet.receive(remoteRSProtocol, 15)
        
        --expected message: select [number]
        local action, selectionParameter = com.parseMessage(actions, sentFrom, reply, remoteRSProtocol)

        if selectionParameter then
            itemToSend = actions[action]["function"](matchingItems, selectionParameter)
        end
    elseif #matchingItems == 1 then
        itemToSend = matchingItems[1]
    else
        local noItemsFoundText = "No items were found that match: "..itemName
        local message = "display \""..noItemsFoundText.."\""
        rednet.send(sentFrom, message, remoteRSProtocol)

        return
    end

    itemToSend.count = count

    if itemToSend.count > itemToSend.amount then
        local notEnoughItemsText = "There was not enough items to fulfill your request of "..itemToSend.count
        local message = "display \""..notEnoughItemsText.."\""
        rednet.send(sentFrom, message, remoteRSProtocol)
    end

    refindStorageBridge.exportItem(itemToSend, chestDirection)
    inventoryManager.addItemToPlayer(chestDirection, itemToSend.amount, _, itemToSend.name)
end

local function store(sentFrom, parameters)

    --debug message
    print("action:\tstore")
    print("parameters:")
    for pName, pValue in pairs(parameters) do
        print("\t"..pName..":\t"..pValue)
    end

end

local function craft(sentFrom, parameters)

    --debug message
    print("action:\tcraft")
    print("parameters:")
    for pName, pValue in pairs(parameters) do
        print("\t"..pName..":\t"..pValue)
    end

end

local function query(sentFrom, parameters)
    local itemName = parameters["itemName"]

    local matchingItems = findMatchingItems(itemName)
    
    local message
    if #matchingItems ~= 0 then
        local matchingItemsText = textutils.serialise(matchingItems)
        message = "query \""..matchingItemsText.."\""
    else
        local noItemsFoundText = "No items were found that match: "..itemName
        message = "display \""..noItemsFoundText.."\""
    end

    rednet.send(sentFrom, message, remoteRSProtocol)
end

local function mainActions()
    local actions = {
        ["request"] = {
            ["function"] = request,
            ["parameters"] = {
                parameter("itemName", "string"),
                parameter("count", "number"),
            },
        },
        ["store"] = {
            ["function"] = store,
            ["parameters"] = {
                parameter("itemName", "string"),
                parameter("count", "number"),
            },
        },
        ["craft"] = {
            ["function"] = craft,
            ["parameters"] = {
                parameter("itemName", "string"),
                parameter("count", "number"),
            },
        },
        ["query"] = {
            ["function"] = query,
            ["parameters"] = {
                parameter("itemName", "string"),
            },
        },
    }

    return actions
end

local function openModem()
    local allPeripherals = peripheral.getNames()

    --search for specifically a wireless modem, not a wired one
    local modem
    local modemLocation
    for index, peri in ipairs(allPeripherals) do
        if peripheral.hasType(peri, "modem") then
            modem = peripheral.wrap(peri)
            if modem.isWireless() then
                modemLocation = peri
            end
        end
    end

    if not modemLocation then
        error("Wireless modem is necessary for the operation of this program")
    end

    rednet.open(modemLocation)
end

function main()
    if not fs.exists("com.lua") then
        error("com.lua is necessary for the operation of this program")
    end

    os.loadAPI("com.lua")

    refindStorageBridge = peripheral.find("rsBridge")
    inventoryManager = peripheral.find("inventoryManager")

    openModem()

    local actions = mainActions()

    while true do
        local sentFrom, message = rednet.receive(remoteRSProtocol)
        local action, parameters = com.parseMessage(actions, sentFrom, message, remoteRSProtocol)

        if action and parameters then
            actions[action]["function"](sentFrom, parameters)
        end
    end
end

main()