local inFreq = 100
local outFreq = tonumber(arg[1])
local message = ""

local modem = peripheral.wrap("back")
modem.open(inFreq)

for i, a in ipairs(arg) do
    if i > 1 then
        message = message..a
        if i ~= #arg then
            message = message.." "
        end
    end
end

print(message)

modem.transmit(outFreq, inFreq, message)
local _, _, _, replyFrequency, recievedMessage, _ = os.pullEvent("modem_message")

print(recievedMessage)