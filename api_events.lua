function widget:GetInfo()
    return {
        name = "Events API",
        desc = "Tracks events",
        author = "MasterBel2",
        version = 0,
        date = "March 2023",
        license = "GNU GPL, v2 or later",
        layer = math.huge
    }
end

-- WARNING: This widget is written with the assumption that unitIDs will not be re-used.
-- THIS IS A FALSE ASSUMPTION.

local requiredFrameworkVersion = "Dev"

local data
local updatedThisFrame = {}

function NewUnitData(unitID, unitDefID)
    return {
        unitDefID = Spring.GetUnitDefID(unitID),
        transferred = {},
        enteredLOS = {},
        leftLOS = {}
    }
end

function UnitData(unitID, unitDefID)
    table.insert(updatedThisFrame, unitID)
    data[unitID] = data[unitID] or NewUnitData(unitID, unitDefID)

    return data[unitID]
end

function widget:Initialize()
    MasterFramework = WG["MasterFramework " .. requiredFrameworkVersion]
    if not MasterFramework then
        error("MasterFramework " .. requiredFrameworkVersion .. " not found!")
    end

    widget:Update()
end

function widget:Update()
    if Spring.GetGameRulesParam("GameID") then
        
        if VFS.FileExists("LuaUI/Config/Events/" .. Spring.GetGameRulesParam("GameID") .. ".lua") then
            local success, cachedData = pcall(Json.decode, VFS.LoadFile("LuaUI/Config/Events/" .. Spring.GetGameRulesParam("GameID") .. ".lua", VFS.RAW_FIRST))
            
            if success and cachedData then
                cachedData.jsonLibDoNotEncodeAsArray = nil
                data = {}
                -- Json converts all our unitIDs to string because we forced it to store as a table so
                -- we convert back when loading

                -- @ Doo suggested """
                --     What if you store this one :
                --     Table[#table +1] = {index = index, value =value}?
                -- """
                for key, value in pairs(cachedData) do
                    data[tonumber(key)] = value
                end
            end
        end
        if not data then
            data = MasterFramework.table.imapToTable(Spring.GetAllUnits(), function(_, unitID)
                return unitID, NewUnitData(unitID, unitDefID)
            end)
        end

        WG.Master_UnitEvents = {
            data = data,
            updatedThisFrame = updatedThisFrame
        }

        widgetHandler:RemoveCallIn("Update")
    end
end

function widget:Shutdown()
    if data and Spring.GetGameRulesParam("GameID") then
        Spring.CreateDir("LuaUI/Config/Events/")
        local file = io.open("LuaUI/Config/Events/" .. Spring.GetGameRulesParam("GameID") .. ".lua", "w")
        -- force Json.encode to encode as a table, not as array, as unitIDs are sparse numbers that should not be encoded as an array
        data.jsonLibDoNotEncodeAsArray = true
        file:write(Json.encode(data))
        file:close()
        data.jsonLibDoNotEncodeAsArray = nil
    end
end

function widget:UnitEnteredLOS(unitID, unitTeam, allyTeam, unitDefID)
    table.insert(UnitData(unitID, unitDefID).enteredLOS, { unitTeam = unitTeam, frame = Spring.GetGameFrame() })
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
    if data[unitID] and data[unitID].created and data[unitID].created.frame ~= Spring.GetGameFrame() then
        Spring.Echo("UnitID " .. unitID .. " reused in frame " .. Spring.GetGameFrame() .. " (original frame " .. data[unitID].created.frame ..")")
    end
    UnitData(unitID, unitDefID).created = { unitTeam = unitTeam, frame = Spring.GetGameFrame() }
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
    UnitData(unitID, unitDefID).finished = { unitTeam = unitTeam, frame = Spring.GetGameFrame() }
end

function widget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
    table.insert(UnitData(unitID, unitDefID).transferred, { newTeam = newTeam, oldTeam = oldTeam, frame = Spring.GetGameFrame() })
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
    UnitData(unitID, unitDefID).destroyed = { unitTeam = unitTeam, attackerTeam = attackerTeam, frame = Spring.GetGameFrame() }
end

function widget:GameFrame(n)
    while #updatedThisFrame > 0 do
        table.remove(updatedThisFrame)
    end
end