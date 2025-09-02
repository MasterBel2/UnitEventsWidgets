function widget:GetInfo()
    return {
        name = "Unit Deaths",
        desc = "Tracks unit deaths and provides ways to display that data",
        author = "MasterBel2",
        version = 0,
        date = "March 2023",
        license = "GNU GPL, v2 or later",
        layer = 0
    }
end

------------------------------------------------------------------------------------------------------------
-- Imports
------------------------------------------------------------------------------------------------------------

local MasterFramework
local requiredFrameworkVersion = "Dev"
local key

local function isValueNil(_, value)
    return value ~= nil
end

------------------------------------------------------------------------------------------------------------
-- Interface
------------------------------------------------------------------------------------------------------------

local playerColumns = {}

local data

local function identiyTableToArrayMapFunc(_, value)
    return value
end
local function rowSortFunc(first, second)
    return first._row_count < second._row_count
end

local function Row(unitDefID)
    local countText = MasterFramework:Text("", MasterFramework:Color(0.5, 0.5, 1, 1))
    local metalText = MasterFramework:Text("", MasterFramework:Color(1, 1, 1, 1))
    local energyText = MasterFramework:Text("", MasterFramework:Color(1, 1, 0, 1))
    local row = MasterFramework:HorizontalStack(
        {
            MasterFramework:Background(MasterFramework:Rect(MasterFramework:AutoScalingDimension(20), MasterFramework:AutoScalingDimension(20)), { MasterFramework:Image("#"..unitDefID) }, MasterFramework:AutoScalingDimension(3)), -- image rect
            MasterFramework:VerticalStack(
                {
                    MasterFramework:HorizontalStack({ MasterFramework:Text(UnitDefs[unitDefID].translatedHumanName), countText }, MasterFramework:AutoScalingDimension(8), 0),
                    MasterFramework:HorizontalStack({ metalText, energyText }, MasterFramework:AutoScalingDimension(8), 0)
                },
                MasterFramework:AutoScalingDimension(8), 
                0
            )
        },
        MasterFramework:AutoScalingDimension(8),
        1
    )

    row._row_unitDefID = unitDefID

    function row:SetCount(newCount)
        row._row_count = newCount
        countText:SetString(tostring(newCount))
        metalText:SetString(tostring(UnitDefs[unitDefID].metalCost * newCount))
        energyText:SetString(tostring(UnitDefs[unitDefID].energyCost * newCount))
    end

    return row
end

local function TakeAvailableHeight(body)
    local cachedHeight
    local cachedAvailableHeight
    return {
        Layout = function(_, availableWidth, availableHeight)
            local width, height = body:Layout(availableWidth, availableHeight)
            cachedHeight = height
            cachedAvailableHeight = math.max(availableHeight, height)
            return width, cachedAvailableHeight
            -- return body:Layout(availableWidth, availableHeight)
        end,
        Position = function(_, x, y) 
            -- if not cachedAvailableHeight or not cachedHeight then error() end
            body:Position(x, y + cachedAvailableHeight - cachedHeight)
            -- return body:Position(x, y)
        end
    }
end

local function Column(unitTeam, backgroundColor)
    local stack = MasterFramework:VerticalStack(
        {},
        MasterFramework:AutoScalingDimension(8),
        0
    )
    local column = MasterFramework:Background(
        MasterFramework:MarginAroundRect(
            TakeAvailableHeight(MasterFramework:VerticalScrollContainer(stack)),
            MasterFramework:AutoScalingDimension(8),
            MasterFramework:AutoScalingDimension(8),
            MasterFramework:AutoScalingDimension(8),
            MasterFramework:AutoScalingDimension(8)
        ),
        { backgroundColor },
        MasterFramework:AutoScalingDimension(3)
    )
    column.stack = stack
    column.unitRows = {}

    function column:Update(unitRows)
        self.unitRows = unitRows
        local newMembers = table.mapToArray(unitRows, identiyTableToArrayMapFunc)
        table.sort(newMembers, rowSortFunc)
        stack:SetMembers(newMembers)
    end

    return column
end

------------------------------------------------------------------------------------------------------------
-- Data
------------------------------------------------------------------------------------------------------------

local function Update(unitIDs)
    for _, unitID in ipairs(unitIDs) do
        local unitData = WG.Master_UnitEvents.data[unitID]
        local destroyed = unitData.destroyed
        
        if destroyed then
            local unitDefID = unitData.unitDefID
            local unitTeam = destroyed.unitTeam

            local count = data[unitTeam][unitDefID] or 0
            count = count + 1
            
            data[unitTeam][unitDefID] = count
        
            local playerColumn = playerColumns[unitTeam]
        
            if playerColumn then
                local unitRow = playerColumn.unitRows[unitDefID] or Row(unitDefID)
                unitRow:SetCount(count)
        
                playerColumn.unitRows[unitDefID] = unitRow
                local newMembers = table.mapToArray(playerColumn.unitRows, identiyTableToArrayMapFunc)
                table.sort(newMembers, rowSortFunc)
                playerColumn.stack:SetMembers(newMembers)
            end
        end
    end
end

function widget:GameFrame(n)
    if not WG.Master_UnitEvents then
        error("Requires MasterBel2's Events API widget!")
    end
    if #WG.Master_UnitEvents.updatedThisFrame > 0 then
        Update(WG.Master_UnitEvents.updatedThisFrame)
    end
end

------------------------------------------------------------------------------------------------------------
-- Setup/Teardown
------------------------------------------------------------------------------------------------------------

function widget:Initialize()
    MasterFramework = WG["MasterFramework " .. requiredFrameworkVersion]
    if not MasterFramework then
        error("MasterFramework " .. requiredFrameworkVersion .. " not found!")
    end
    
    table = MasterFramework.table
    
    data = table.imapToTable(Spring.GetTeamList(), function(index, teamID)
        return teamID, {}
    end)

    if WG.Master_UnitEvents then -- units are only around after game start, so it's okay that this only triggers 
        Update(table.mapToArray(WG.Master_UnitEvents.data, function(key, _) return key end))
    end

    local topRow = MasterFramework:HorizontalStack(
        {},
        MasterFramework:AutoScalingDimension(8),
        1
    )

    key = MasterFramework:InsertElement(
        MasterFramework:ResizableMovableFrame(
            "MasterUnitDeaths",
            MasterFramework:PrimaryFrame(
                MasterFramework:Background(
                    MasterFramework:MarginAroundRect(
                        MasterFramework:VerticalStack(
                            {
                                topRow,
                                MasterFramework:HorizontalStack(
                                    table.mapToArray(Spring.GetTeamList(), function(index, teamID)
                                        local playerList = Spring.GetPlayerList(teamID)
                                        if not playerList[1] then return end
                                        local name = Spring.GetPlayerInfo(playerList[1])
                                        local r, g, b, a = Spring.GetTeamColor(teamID)
                                        local columnBackgroundColor = MasterFramework:Color(r, g, b, 0.2)
                                        return MasterFramework:HorizontalStack(
                                            {
                                                MasterFramework:CheckBox(10, function(_, checked)
                                                    if checked then
                                                        local column = Column(teamID, columnBackgroundColor)
                                                        playerColumns[teamID] = column

                                                        column:Update(table.map(data[teamID], function(unitDefID, count)
                                                            local row = Row(unitDefID)
                                                            row:SetCount(count)
                                                            return unitDefID, row
                                                        end))
                                                    else
                                                        playerColumns[teamID] = nil
                                                    end

                                                    topRow:SetMembers(table.mapToArray(table.filter(playerColumns, isValueNil), identiyTableToArrayMapFunc))
                                                end),
                                                MasterFramework:Text(name, MasterFramework:Color(r, g, b, a))
                                            },
                                            MasterFramework:AutoScalingDimension(8),
                                            0.5
                                        )
                                    end),
                                    MasterFramework:AutoScalingDimension(8),
                                    0.5
                                )
                            },
                            MasterFramework:AutoScalingDimension(8),
                            0
                        ),
                        MasterFramework:AutoScalingDimension(20),
                        MasterFramework:AutoScalingDimension(20),
                        MasterFramework:AutoScalingDimension(20),
                        MasterFramework:AutoScalingDimension(20)
                    ),
                    { MasterFramework:Color(0, 0, 0, 0.7) },
                    MasterFramework:AutoScalingDimension(5)
                )
            ),
            MasterFramework.viewportWidth * 0.1, MasterFramework.viewportHeight * 0.1, 
            MasterFramework.viewportWidth * 0.8, MasterFramework.viewportHeight * 0.8,
            true
        ),
        "Unit Deaths",
        MasterFramework.layerRequest.bottom()
    )
end

function widget:Shutdown()
    MasterFramework:RemoveElement(key)
end