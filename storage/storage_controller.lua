local computers = {}

function GetComputers()
    local peripherals = peripheral.getNames()
    
    for k, p in ipairs(peripherals) do
        local i, j = string.find(p, "computer")
        
        if i and j then
            table.insert(computers, peripheral.wrap(p))
        end
    end
end

function ShutdownSystem()
    for k, cpu in ipairs(computers) do
        cpu.shutdown()
    end
end

function TurnOnSystem()
    for k, cpu in ipairs(computers) do
        cpu.turnOn()
    end
end

function RebootSystem()
    ShutdownSystem()
    sleep(5)
    TurnOnSystem()
end

--backup startup.lua
local function backupSU()
    if fs.exists("/disk/startup.lua") then
        fs.copy("/disk/startup.lua", "/disk/startup.lua.bak")
    end
end

--replace temp startup.lua with backed up version
local function restoreSU()
    fs.delete("/disk/startup.lua")
    fs.move("/disk/startup.lua.bak", "/disk/startup.lua")
end

--reboot to have computers run temp startup.lua
function ExecuteSU()
    RebootSystem()
    sleep(5)
end

--all mass file operations are done by
--editing disk/startup.lua and rebooting system
function CopyToAll(filePath, fileName)
    backupSU()
    
    --write copying code to temp startup.lua
    local su = fs.open("/disk/startup.lua", "w")
    su.write("fs.copy(\""..filePath.."\", \"/"..fileName.."\")")
    su.close()

    ExecuteSU()
    restoreSU()
end

function DeleteFromAll(fileName)
    backupSU()

    --write deletion code to temp startup.lua
    local su = fs.open("/disk/startup.lua", "w")
    su.write("fs.delete(\"/"..fileName.."\")")
    su.close()

    ExecuteSU()
    restoreSU()
end

function RunArbitraryCode(filePath)
    backupSU()

    --read in arbitrary code as string
    local codeFile = fs.open(filePath, "r")
    local code = codeFile.readAll()
    codeFile.close()

    --write arbitrary code to temp startup.lua
    local su = fs.open("/disk/startup.lua", "w")
    su.write(code)
    su.close()

    ExecuteSU()
    restoreSU()
end

GetComputers()