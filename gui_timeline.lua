function widget:GetInfo()
	return {
        name      = "Timeline",
        desc      = "Displays events of interest on a timeline",
        author    = "MasterBel2",
        date      = "March 2023",
        license   = "GNU GPL, v2",
        enabled   = true, --enabled by default,
        layer = 0
	}
end

------------------------------------------------------------------------------------------------------------
-- Imports
------------------------------------------------------------------------------------------------------------

local MasterFramework
local requiredFrameworkVersion = "Dev"
local key

------------------------------------------------------------------------------------------------------------
-- Interface Storage
------------------------------------------------------------------------------------------------------------

local initalized

local timeline
local scrollContainer
local scrollContainerGeometryTarget

local pixelsPerMinute = 120
local function frameConversion(n)
    return math.floor(n / (30 * 60) * pixelsPerMinute)
end

------------------------------------------------------------------------------------------------------------
-- Data
------------------------------------------------------------------------------------------------------------

local teams = {}

function widget:GameFrame(n)
    if not initialized then return end
    timeline._readOnly_width.Update(frameConversion(n))

    teams = {}

    for unitID, unitData in pairs(WG.Master_UnitEvents.data) do
        if unitData.destroyed then
            local team = teams[unitData.destroyed.unitTeam] or {}
            local frameN = frameConversion(unitData.destroyed.frame)
            local frameMCost = team[frameN] or 0
            
            team[frameN] = frameMCost + UnitDefs[unitData.unitDefID].metalCost

            teams[unitData.destroyed.unitTeam] = team
        end
    end
end

------------------------------------------------------------------------------------------------------------
-- Interface
------------------------------------------------------------------------------------------------------------

-- Copied from gui_unit_deaths.lua

local function Row(unitDefID)
    local countText = MasterFramework:Text("", MasterFramework:Color(0.5, 0.5, 1, 1))
    local metalText = MasterFramework:Text("", MasterFramework:Color(1, 1, 1, 1))
    local energyText = MasterFramework:Text("", MasterFramework:Color(1, 1, 0, 1))
    local row = MasterFramework:HorizontalStack(
        {
            MasterFramework:Background(MasterFramework:Rect(MasterFramework:AutoScalingDimension(20), MasterFramework:AutoScalingDimension(20)), { MasterFramework:Image("#"..unitDefID) }, MasterFramework:AutoScalingDimension(3)),
            MasterFramework:VerticalStack(
                {
                    MasterFramework:HorizontalStack({ MasterFramework:Text(UnitDefs[unitDefID].translatedHumanName) }, MasterFramework:AutoScalingDimension(8), 0),
                    MasterFramework:HorizontalStack({ countText, metalText, energyText }, MasterFramework:AutoScalingDimension(8), 0)
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

local function Column(unitTeam, backgroundColor)
    local stack = MasterFramework:VerticalStack(
        {},
        MasterFramework:AutoScalingDimension(8),
        0
    )
    local column = MasterFramework:Background(
        MasterFramework:MarginAroundRect(
            stack,
            MasterFramework:AutoScalingDimension(8),
            MasterFramework:AutoScalingDimension(8),
            MasterFramework:AutoScalingDimension(8),
            MasterFramework:AutoScalingDimension(8)
        ),
        { backgroundColor },
        MasterFramework:AutoScalingDimension(3)
    )
    column.stack = stack

    function column:Update(unitRows)
        local newMembers = table.mapToArray(unitRows, function(key, value) return value end)
        table.sort(newMembers, function(first, second)
            return first._row_count < second._row_count
        end)
        column.stack:SetMembers(newMembers)
    end

    return column
end

-- Modified version of MasterFramework:ConstantOffsetAnchor() that doesnt constrain the size of the child.
-- Ideally, this uses a separate element with correct layering.
local function ConstantOffsetAnchor(rectToAnchorTo, anchoredRect, xOffset, yOffset)
	local anchor = MasterFramework:ConstantOffsetAnchor(rectToAnchorTo, anchoredRect, xOffset, yOffset)

	function anchor:Layout(availableWidth, availableHeight)
		rectToAnchorToWidth, rectToAnchorToHeight = rectToAnchorTo:Layout(availableWidth, availableHeight)
		anchoredRectWidth, anchoredRectHeight = anchoredRect:Layout(MasterFramework.viewportWidth, MasterFramework.viewportHeight)
		return rectToAnchorToWidth, rectToAnchorToHeight
	end

	return anchor
end

local function Tooltip(child)
    local isVisible = false

    local teamColumns = table.imapToTable(Spring.GetTeamList(), function(_, teamID)
        local r, g, b, a = Spring.GetTeamColor(teamID)
        return teamID, Column(teamID, MasterFramework:Color(r, g, b, 0.2))
    end)
    local deadUnitsColumnsStack = MasterFramework:HorizontalStack(
        { dummyView },
        MasterFramework:AutoScalingDimension(8),
        0
    )

    local dummyView = MasterFramework:GeometryTarget({ Position = function() end, Layout = function() return 0, 0 end })
    local tooltipVisible = MasterFramework:GeometryTarget(MasterFramework:Background(
        MasterFramework:MarginAroundRect(
            deadUnitsColumnsStack,
            MasterFramework:AutoScalingDimension(8),
            MasterFramework:AutoScalingDimension(8),
            MasterFramework:AutoScalingDimension(8),
            MasterFramework:AutoScalingDimension(8)
        ),
        { MasterFramework:Color(0, 0, 0, 0.7) },
        MasterFramework:AutoScalingDimension(5)
    ))

    local box = MasterFramework:Box(child)
    local anchor = ConstantOffsetAnchor(
        child,
        box,
        0,
        0
    )

    local tooltip = MasterFramework:GeometryTarget(anchor)

    function tooltip:SetCenterXOffset(centerXOffset)
        if isVisible then

            local _, anchorHeight = self:Size()
            local tooltipWidth, _ = tooltipVisible:Size()
            local viewportXOffset, _ = scrollContainer.viewport:GetOffsets()

            anchor:SetOffsets(
                (centerXOffset - viewportXOffset) - tooltipWidth / 2,
                anchorHeight
            )

            local data = table.imapToTable(Spring.GetTeamList(), function(_, teamID) return teamID, {} end)

            for unitID, unitData in pairs(WG.Master_UnitEvents.data) do
                local destroyed = unitData.destroyed
            
                if destroyed then
                    local convertedFrame = frameConversion(destroyed.frame)

                    if (convertedFrame <= (centerXOffset + pixelsPerMinute / 2) and convertedFrame >= (centerXOffset - pixelsPerMinute / 2)) then
                        local unitDefID = unitData.unitDefID
                        local unitTeam = destroyed.unitTeam

                        local count = data[unitTeam][unitDefID] or 0
                        count = count + 1
                        
                        data[unitTeam][unitDefID] = count
                    end
                end
            end

            for teamID, teamColumn in pairs(teamColumns) do
                teamColumn:Update(table.map(data[teamID], function(unitDefID, count)
                    local row = Row(unitDefID)
                    row:SetCount(count)
                    return unitDefID, row
                end))
            end
            deadUnitsColumnsStack:SetMembers(table.mapToArray(table.filter(teamColumns, function(_, column) return #column.stack:GetMembers() > 0 end), function(_, column) return column end))

            if #deadUnitsColumnsStack:GetMembers() == 0 then
                self:Hide()
            end
        end
    end

    function tooltip:Hide()
        isVisible = false
        box:SetChild(dummyView)
    end
    function tooltip:Show()
        if isVisible then return end
        isVisible = true
        box:SetChild(tooltipVisible)
    end

    return tooltip
end

local function Region(child, action)
    local region = MasterFramework.Component(false, true)
    local defaultWidth = pixelsPerMinute
    local selectedRegion
    local hoverX
    local hoverY

    local hover

    hover = MasterFramework:MouseOverResponder(
        child,
        function(responder, x, y)
            if x ~= hoverX then
                local cachedX, _ = responder:CachedPositionTranslatedToGlobalContext()
                hoverX = x
                action(x - cachedX)
                region:NeedsRedraw()
            end
        end,
        function() end,
        function()
            hoverX = nil
            action(nil)
            region:NeedsRedraw()
        end
    )

    function region:Layout(...)
        return hover:Layout(...)
    end
    local cachedX, cachedY
    function region:Position(x, y)
        cachedX, cachedY = x, y
        hover:Position(x, y)
        table.insert(MasterFramework.activeDrawingGroup.drawTargets, self)
    end
    function region:Draw(x, y)
        self:RegisterDrawingGroup()
        local width, height = hover:Size()

        if hoverX then
            local x1 = math.max(cachedX, hoverX - pixelsPerMinute / 2)
            local x2 = math.min(cachedX + width, hoverX + pixelsPerMinute / 2)
            local y1 = cachedY
            local y2 = cachedY + height

            gl.Color(1, 1, 1, 0.1)
            gl.Rect(x1, y1, x2, y2)
        end
    end

    return region
end

local function AbsoluteDimension(value)
    return MasterFramework:Dimension(function(value) return value end, value)
end

local function TakeAvailableWidth(body)
    return {
        Layout = function(_, availableWidth, availableHeight)
            local _, height = body:Layout(availableWidth, availableHeight)
            return availableWidth, height
        end,
        Position = function(_, x, y) body:Position(x, y) end
    }
end

local function Timeline()
    local timeline = { events = {} }
    local height = AbsoluteDimension(6 * #Spring.GetTeamList())
    local width = AbsoluteDimension(frameConversion(Spring.GetGameFrame()))

    timeline._readOnly_width = width

    function timeline:Layout(availableWidth, availableHeight)
        return width(), height()
    end

    local function DrawLinesSpecial()
        local teamCount = #Spring.GetTeamList()

        gl.Color(1, 1, 1, 0.12)
        local visibleWidth, _ = scrollContainerGeometryTarget:Size()
        for i = 1, math.floor(math.max(visibleWidth, width()) / pixelsPerMinute) do
            gl.Vertex(i * pixelsPerMinute, 0)
            gl.Vertex(i * pixelsPerMinute, height())
        end

        gl.Color(1, 1, 1, 0.66)
        gl.Vertex(frameConversion(Spring.GetGameFrame()), 0)
        gl.Vertex(frameConversion(Spring.GetGameFrame()), height())

        for teamID, frames in pairs(teams) do
            gl.Color(Spring.GetTeamColor(teamID))
            for x, height in pairs(frames) do
                gl.Vertex(x, (1 + teamID) * 6 + math.log10(height))
                gl.Vertex(x, (1 + teamID) * 6)
            end
        end
    end

    local cachedX, cachedY
    function timeline:Position(x, y)
        cachedX = x
        cachedY = y

        table.insert(MasterFramework.activeDrawingGroup.drawTargets, self)
    end

    function timeline:Draw()
        gl.PushMatrix()
        gl.Translate(cachedX, cachedY, 0)
        gl.BeginEnd(GL.LINES, DrawLinesSpecial)
        gl.PopMatrix()
    end

    return timeline
end

------------------------------------------------------------------------------------------------------------
-- Setup/Teardown
------------------------------------------------------------------------------------------------------------

local DeferredInit

function widget:Update()
    if DeferredInit then 
        local _DeferredInit = DeferredInit
        DeferredInit = nil -- to allow more graceful shutdown
        _DeferredInit()
        initialized = true
    end
end

function widget:Initialize()
    -- Defer init, since we're on layer 0 but depend on api_events.lua on layer math.huge
    DeferredInit = function()
        MasterFramework = WG["MasterFramework " .. requiredFrameworkVersion]
        if not MasterFramework then
            error("MasterFramework " .. requiredFrameworkVersion .. " not found!")
        end
        
        table = MasterFramework.table

        timeline = Timeline()

        local tooltip

        local region = Region(timeline, function(hoverX)
            if hoverX then
                tooltip:Show()
                tooltip:SetCenterXOffset(hoverX or 0)
            else
                tooltip:Hide()
            end
        end)

        scrollContainer = MasterFramework:HorizontalScrollContainer(region)
        scrollContainer.viewport.disableDrawList = true

        scrollContainerGeometryTarget = MasterFramework:GeometryTarget(TakeAvailableWidth(scrollContainer))

        tooltip = Tooltip(scrollContainerGeometryTarget)

        key = MasterFramework:InsertElement(
            MasterFramework:ResizableMovableFrame(
                "MasterTimeline",
                MasterFramework:PrimaryFrame(
                    MasterFramework:Background(
                        MasterFramework:MarginAroundRect(
                            MasterFramework:Background(
                                tooltip,
                                -- scrollContainer,
                                { MasterFramework:Color(0, 0, 0, 0.7) },
                                MasterFramework:AutoScalingDimension(3)
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
                false
            ),
            "Timeline",
            MasterFramework.layerRequest.bottom()
        )

        self:GameFrame(Spring.GetGameFrame())
    end
end

function widget:Shutdown()
    MasterFramework:RemoveElement(key)
end