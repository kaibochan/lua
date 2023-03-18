local function sendError(sentFrom, errorMessage, protocol)
    rednet.send(sentFrom, errorMessage, protocol)
end

--true values:  "true",  1
--false values: "false", 0
--note that nil is not a false value, it remains nil
function tobooleanstrict(variable)
    local boolean
    
    if type(variable) == "string" then
        if variable == "true" then
            boolean = true
        elseif variable == "false" then
            boolean = false
        end
    elseif type(variable) == "number" then
        if variable == 1 then
            boolean = true
        elseif variable == 0 then
            boolean = false
        end
    end

    return boolean
end

function validateParameters(actions, sentFrom, action, parameters, protocol)
    --number of parameters does not match
    local numParametersExpected = #actions[action]["parameters"]
    local numParametersGiven = #parameters

    if numParametersExpected ~= numParametersGiven then
        local errorMessage = "error \"Error: "..action.." expected "..numParametersExpected.." parameters, recieved "..numParametersGiven.."\""
        sendError(sentFrom, errorMessage, protocol)
        return
    end

    --parameter types do not match
    for index, parameter in ipairs(actions[action]["parameters"]) do
        local expectedType = parameter["type"]
        local parameterName = parameter["name"]
        local castedParameter

        --parameters is indexed with value 1 since they are removed
        --at the end of the loop, later parameters will shift down
        if expectedType == "number" then
            castedParameter = tonumber(parameters[1])
        elseif expectedType == "boolean" then
            castedParameter = tobooleanstrict(parameters[1])
        elseif expectedType == "string" then
            castedParameter = parameters[1]
        elseif expectedType == "table" then
            castedParameter = textutils.unserialise(parameters[1])
        end

        if not castedParameter then
            local errorMessage = "error \"Error: "..action.." expected type "..expectedType.." for parameter "..parameterName.."\""
            sendError(sentFrom, errorMessage, protocol)
            return
        end

        --replace indexed parameter string value with a named
        --key, value pair of correct type
        --remove at position 1 since the other parameters will shuffle
        --downwards whenever the bottom one is removed
        table.remove(parameters, 1)
        parameters[parameterName] = castedParameter
    end

    return parameters
end

--group together words that have quotations around them
--then remove quotations
function groupQuotedParameters(parameters)
    local joinWords = false
    local foundEndQuote = false
    local quotingTable = false

    local joinedParameters = {}
    local insertIndex = 1

    for index, parameter in ipairs(parameters) do
        --if word begins with a quotation mark, begin joining
        if not quotingTable and parameter:sub(1,1) == "\"" then
            --remove quote at beginning of word
            parameter = parameter:sub(2, #parameter)
            joinWords = true

            --if quoted text is the beginning of a table: "{, set quotingTable flag
            --ignore further quotations until we encounter the end of the quoted table: }"
            if parameter:sub(1,1) == "{" then
                quotingTable = true
            end
        end

        --quotations are ignored while quoting a table
        --}" appears at the end of a quoted table
        if parameter:sub(#parameter, #parameter) == "\"" and not quotingTable
        or parameter:sub(#parameter - 1, #parameter) == "}\"" then
            --remove quotation mark at end of word
            parameter = parameter:sub(1, #parameter - 1)
            foundEndQuote = true
            quotingTable = false
        end

        --if joining words and words have already been added, concatenate
        --otherwise, insert parameter into joinedParameters table
        if joinWords and joinedParameters[insertIndex] then
            joinedParameters[insertIndex] = joinedParameters[insertIndex].." "..parameter
        else
            table.insert(joinedParameters, insertIndex, parameter)
        end

        --if word ends with a quotation mark, stop joining
        if foundEndQuote then
            foundEndQuote = false
            joinWords = false
        end

        --if not joining words then increment insertion point
        if not joinWords then
            insertIndex = insertIndex + 1
        end
    end

    return joinedParameters
end

function parseMessage(actions, sentFrom, message, protocol)
    local words = {}
    for w in message:gmatch("%S+") do
        table.insert(words, w)
    end

    --action does not exist
    if not actions[words[1]] then
        sendError(sentFrom, "error \"Command invalid: "..words[1].."\"", protocol)
        return
    end

    --compose message into an action and its parameters
    local action = words[1]
    local parameters = {}
    for index = 2, #words do
        table.insert(parameters, words[index])
    end

    --group quoted parameters together, such as "oak log"
    parameters = groupQuotedParameters(parameters)

    --validate and store casted parameters
    parameters = validateParameters(actions, sentFrom, action, parameters, protocol)

    return action, parameters
end