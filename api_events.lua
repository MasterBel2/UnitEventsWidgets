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

-- local data = table.imapToTable(Spring.GetTeamList(), function(index, teamID)
--     return teamID, {}
-- end)

local requiredFrameworkVersion = "Dev"

local data
local updatedThisFrame = {}

function NewUnitData(unitID, unitDefID)
    return {
        unitDefID = Spring.GetUnitDefID(unitID),
        created = { unitTeam = Spring.GetUnitTeam(unitID), frame = Spring.GetGameFrame() },
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

    data = MasterFramework.table.imapToTable(Spring.GetAllUnits(), function(_, unitID)
        return unitID, NewUnitData(unitID, unitDefID)
    end)

    WG.Master_UnitEvents = {
        data = data,
        updatedThisFrame = updatedThisFrame
    }
end

function widget:UnitEnteredLOS(unitID, unitTeam, allyTeam, unitDefID)
    table.insert(UnitData(unitID, unitDefID).enteredLOS, { unitTeam = unitTeam, frame = Spring.GetGameFrame() })
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
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