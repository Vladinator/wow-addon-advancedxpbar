if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then
	return
end

local addonName = ...
local MAX_LEVEL = MAX_PLAYER_LEVEL_TABLE[#MAX_PLAYER_LEVEL_TABLE]

local ns = CreateFrame("Frame")
ns:SetScript("OnEvent", function(ns, event, ...) ns[event](ns, event, ...) end)
ns.loading = true
ns.bars = {}
ns.zone = {}

local defaults = {
	-- true = only include watched quests, false = all quests regardless if watched or not
	watched = true,
	-- true = include remote zones, false = only quests in current zone
	remote = true,
	-- true = include incomplete quests, false = only completed quests
	incomplete = false,
	-- true = include bonus objectives (since we complete+turn in, we have to display the experience in advance), false = ignore bonus objectives
	bonus = true,
	-- sound and popup alerts
	sound = true,
	popup = true,
	-- statusbar texture and color
	texture = "Interface\\TargetingFrame\\UI-StatusBar",
	color = {0, 1, 0, 1},
}

local config = defaults

local manifest = {
	{
		-- default UI expbar
		frame = "MainMenuExpBar",
		level = 1,
	},
	{
		-- BEB
		frame = "BEBBackground",
	},
	{
		-- Dominos
		frame = function() return type(Dominos) == "table" and type(Dominos.Frame) == "table" and type(Dominos.Frame.Get) == "function" and Dominos.Frame:Get("xp") end,
	},
	{
		-- saftXP_Backdrop
		frame = "saftExperienceBar",
	},
	{
		-- SpartanUI
		frame = "SUI_ExperienceBar",
	},
	{
		-- Xparky
		frame = "XparkyXPAnchor",
	},
	{
		-- XPBarNone
		frame = "XPBarNoneBackground",
	},
}

do
	local popup, last

	-- adapted LevelUpDisplay code to suit our purpose
	do
		local levelUpTexCoords = {
			gLine = { 0.00195313, 0.81835938, 0.01953125, 0.03320313 },
			gLineDelay = 1.5,
		}

		local scripts
		scripts = {
			PlayBanner = function()
				if popup:IsShown() then
					return
				end
				popup:SetHeight(72)
				popup:Show()
				ZoneTextFrame:Hide()
				SubZoneTextFrame:Hide()
			end,
			StopBanner = function()
				popup.hideAnim:Stop()
				popup.levelFrame.levelUp:Stop()
				popup:Hide()
			end,
			ResumeBanner = function(...)
				scripts.PlayBanner(...)
			end,
			PopupShow = function()
				popup.levelFrame.reachedText:SetText("")
				popup.levelFrame.levelText:SetText("")
				popup.levelFrame.singleline:SetText("")
				popup.levelFrame.blockText:SetText("")

				-- override the blizzard code, this works better, timing wise (though, the text should linger a second or two...)
				popup.gLine.grow.anim1:SetStartDelay(0)
				popup.gLine.grow.anim1:SetEndDelay(1)
				popup.gLine2.grow.anim1:SetStartDelay(0)
				popup.gLine2.grow.anim1:SetEndDelay(1)
				popup.blackBg.grow.anim1:SetStartDelay(0)
				popup.blackBg.grow.anim1:SetEndDelay(1)

				popup.levelFrame.levelUp:Play()
			end,
			PopupEvent = function(...)
				scripts.StopBanner(...)
			end,
			AnimOutFinished = function()
				popup:Hide()
			end,
			LinePlay = function()
				popup.blackBg:Show()
				popup.gLine:Show()
				popup.gLine2:Show()
				popup.gLine2.grow:Play()
				popup.blackBg.grow:Play()
			end,
			LevelUpPlay = function()
				popup.gLine.grow:Play()
			end,
			LevelUpFinished = function()
				popup.hideAnim:Play()
			end,
		}

		popup = CreateFrame("Frame", nil, UIParent)
		popup:SetPoint("TOP", 0, -190)
		popup:SetSize(418, 72)
		popup:SetFrameStrata("HIGH")
		popup:SetToplevel(true)
		popup:Hide()
		popup:SetScript("OnShow", scripts.PopupShow)

		popup:SetScript("OnEvent", scripts.PopupEvent)
		popup:RegisterEvent("PLAYER_LEVEL_UP")

		popup.PlayBanner = scripts.PlayBanner
		popup.StopBanner = scripts.StopBanner
		popup.ResumeBanner = scripts.ResumeBanner

		popup.hideAnim = popup:CreateAnimationGroup()
		popup.hideAnim.alpha = popup.hideAnim:CreateAnimation("Alpha")
		popup.hideAnim.alpha:SetFromAlpha(1)
		popup.hideAnim.alpha:SetToAlpha(0)
		popup.hideAnim.alpha:SetDuration(1)
		popup.hideAnim.alpha:SetOrder(1)
		popup.hideAnim.alpha:SetScript("OnFinished", scripts.AnimOutFinished)

		popup.blackBg = popup:CreateTexture(nil, "BACKGROUND")
		popup.blackBg:SetPoint("BOTTOM", 0, 0)
		popup.blackBg:SetSize(326, 103)
		popup.blackBg:SetTexture("Interface\\LevelUp\\LevelUpTex")
		popup.blackBg:SetTexCoord(.00195313, .63867188, .03710938, .23828125)
		popup.blackBg:SetVertexColor(1, 1, 1, .6)
		popup.blackBg.grow = popup.blackBg:CreateAnimationGroup()
		popup.blackBg.grow.anim1 = popup.blackBg.grow:CreateAnimation("Scale")
		popup.blackBg.grow.anim1:SetScale(1, .001)
		popup.blackBg.grow.anim1:SetDuration(0)
		popup.blackBg.grow.anim1:SetStartDelay(levelUpTexCoords.gLineDelay)
		popup.blackBg.grow.anim1:SetOrder(1)
		popup.blackBg.grow.anim1:SetOrigin("BOTTOM", 0, 0)
		popup.blackBg.grow.anim2 = popup.blackBg.grow:CreateAnimation("Scale")
		popup.blackBg.grow.anim2:SetScale(1, 1000)
		popup.blackBg.grow.anim2:SetDuration(.15)
		popup.blackBg.grow.anim2:SetStartDelay(.25)
		popup.blackBg.grow.anim2:SetOrder(2)
		popup.blackBg.grow.anim2:SetOrigin("BOTTOM", 0, 0)

		popup.gLine2 = popup:CreateTexture(nil, "BACKGROUND", nil, 2)
		popup.gLine2:SetPoint("TOP", 0, 0)
		popup.gLine2:SetSize(418, 7)
		popup.gLine2:SetTexture("Interface\\LevelUp\\LevelUpTex")
		popup.gLine2:SetTexCoord(unpack(levelUpTexCoords.gLine))
		popup.gLine2.grow = popup.gLine2:CreateAnimationGroup()
		popup.gLine2.grow.anim1 = popup.gLine2.grow:CreateAnimation("Scale")
		popup.gLine2.grow.anim1:SetScale(.001, 1)
		popup.gLine2.grow.anim1:SetDuration(0)
		popup.gLine2.grow.anim1:SetStartDelay(levelUpTexCoords.gLineDelay)
		popup.gLine2.grow.anim1:SetOrder(1)
		popup.gLine2.grow.anim2 = popup.gLine2.grow:CreateAnimation("Scale")
		popup.gLine2.grow.anim2:SetScale(1000, 1)
		popup.gLine2.grow.anim2:SetDuration(.5)
		popup.gLine2.grow.anim2:SetOrder(2)

		popup.gLine = popup:CreateTexture(nil, "BACKGROUND", nil, 2)
		popup.gLine:SetPoint("BOTTOM", 0, 0)
		popup.gLine:SetSize(418, 7)
		popup.gLine:SetTexture("Interface\\LevelUp\\LevelUpTex")
		popup.gLine:SetTexCoord(unpack(levelUpTexCoords.gLine))
		popup.gLine.grow = popup.gLine:CreateAnimationGroup()
		popup.gLine.grow.anim1 = popup.gLine.grow:CreateAnimation("Scale")
		popup.gLine.grow.anim1:SetScale(.001, 1)
		popup.gLine.grow.anim1:SetDuration(0)
		popup.gLine.grow.anim1:SetStartDelay(levelUpTexCoords.gLineDelay)
		popup.gLine.grow.anim1:SetOrder(1)
		popup.gLine.grow.anim2 = popup.gLine.grow:CreateAnimation("Scale")
		popup.gLine.grow.anim2:SetScale(1000, 1)
		popup.gLine.grow.anim2:SetDuration(.5)
		popup.gLine.grow.anim2:SetOrder(2)
		popup.gLine.grow:SetScript("OnPlay", scripts.LinePlay)

		popup.levelFrame = CreateFrame("Frame", nil, popup)
		popup.levelFrame:SetPoint("CENTER")
		popup.levelFrame:SetSize(418, 72)
		popup.levelFrame:SetAlpha(0)

		popup.levelFrame.levelUp = popup.levelFrame:CreateAnimationGroup()
		popup.levelFrame.levelUp.anim1 = popup.levelFrame.levelUp:CreateAnimation("Alpha")
		popup.levelFrame.levelUp.anim1:SetFromAlpha(0)
		popup.levelFrame.levelUp.anim1:SetToAlpha(1)
		popup.levelFrame.levelUp.anim1:SetDuration(.7)
		popup.levelFrame.levelUp.anim1:SetStartDelay(1.5)
		popup.levelFrame.levelUp.anim1:SetOrder(1)
		popup.levelFrame.levelUp.anim2 = popup.levelFrame.levelUp:CreateAnimation("Alpha")
		popup.levelFrame.levelUp.anim2:SetFromAlpha(1)
		popup.levelFrame.levelUp.anim2:SetToAlpha(0)
		popup.levelFrame.levelUp.anim2:SetDuration(.5)
		popup.levelFrame.levelUp.anim2:SetStartDelay(1.5)
		popup.levelFrame.levelUp.anim2:SetOrder(2)
		popup.levelFrame.levelUp:SetScript("OnPlay", scripts.LevelUpPlay)
		popup.levelFrame.levelUp:SetScript("OnFinished", scripts.LevelUpFinished)

		popup.levelFrame.levelText = popup.levelFrame:CreateFontString(nil, "ARTWORK", "GameFont_Gigantic")
		popup.levelFrame.levelText:SetPoint("BOTTOM", 0, 5)
		popup.levelFrame.levelText:SetTextColor(1, .82, 0)
		popup.levelFrame.levelText:SetJustifyH("CENTER")

		popup.levelFrame.reachedText = popup.levelFrame:CreateFontString(nil, "ARTWORK", "SystemFont_Shadow_Large")
		popup.levelFrame.reachedText:SetPoint("BOTTOM", popup.levelFrame.levelText, "TOP", 0, 5)

		popup.levelFrame.singleline = popup.levelFrame:CreateFontString(nil, "ARTWORK", "GameFont_Gigantic")
		popup.levelFrame.singleline:SetPoint("CENTER", 0, -4)

		popup.levelFrame.blockText = popup.levelFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
		popup.levelFrame.blockText:SetPoint("CENTER", 0, -4)
	end

	local function Popup(level)
		popup:PlayBanner()
		popup.levelFrame.reachedText:SetText("Good News")
		popup.levelFrame.levelText:SetFormattedText("You've enough XP to ding level %d!", level)
	end

	local function Sound()
		local _, race = UnitRace("player")
		local gender = UnitSex("player") == 3 and "Female" or "Male"
		local index = math.random(1, 2)
		PlaySoundFile("Sound\\Interface\\LevelUp.ogg")
		PlaySoundFile(format("Sound\\Character\\%s\\%sVocal%s\\%s%sCheer0%d.ogg", race, race, gender, race, gender, index))
		PlaySoundFile("Sound\\Spells\\FX_HearthstoneVictoryStinger.ogg")
	end

	function ns:PlayAlert(level)
		-- sanity check if there is a point to all this or not
		if not config.popup and not config.sound then
			return false
		end

		-- sanity check the level range
		if type(level) ~= "number" or level < 2 or level > MAX_LEVEL then
			return false
		end

		-- cooldown period
		if last and GetTime() - last < 15 then
			return false
		end

		-- show alert and play sound (3 seconds delay)
		C_Timer.NewTicker(3, function()
			if config.sound then
				Sound()
			end

			if config.popup then
				if config.sound then
					C_Timer.After(1, function() Popup(level) end) -- lazy delay to sync better with the hearthstone victory stinger
				else
					Popup(level)
				end
			end
		end, 1)

		-- start cooldown period
		last = GetTime()
		return true
	end
end

function ns:UpdateZone()
	table.wipe(ns.zone)

	for i = 1, QuestMapUpdateAllQuests(), 1 do
		ns.zone[QuestPOIGetQuestIDByVisibleIndex(i)] = true
	end
end

function ns:CalculateExperience()
	if ns.loading then return 0 end -- loading screen makes calculating values go weird

	local experience = 0

	local playerMoney = GetMoney()
	local backupIndex = GetQuestLogSelection()
	local index, header = 1

	-- updates what quests are for the current zone
	if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
		ns:UpdateZone()
	end

	-- iterate over the quests
	while GetQuestLogTitle(index) do
		SelectQuestLogEntry(index)

		local title, level, suggestedGroup, isHeader, isCollapsed, isCompleted, frequency, questID, startEvent, displayQuestID, isOnMap, hasLocalPOI, isTask, isBounty, isStory, isHidden, isScaling = GetQuestLogTitle(index)
		local isTracked, isRemote = IsQuestWatched(index), not ns.zone[questID]
		isCompleted = (isCompleted and isCompleted > 0) or (GetNumQuestLeaderBoards(index) == 0 and playerMoney >= GetQuestLogRequiredMoney(index) and not startEvent)

		if isHeader then
			header = title
		elseif (config.bonus and isTask) or ((not config.watched or isTracked) and (config.remote or not isRemote) and (config.incomplete or isCompleted)) then
			experience = experience + (GetQuestLogRewardXP() or 0)
		end

		index = index + 1
	end
	SelectQuestLogEntry(backupIndex)

	local currentXP = UnitXP("player")
	local maxXP = UnitXPMax("player")

	if currentXP >= 0 and maxXP > 0 then
		local diff = maxXP - currentXP
		local canLevel = experience >= diff
		local percent

		if diff > 0 then
			percent = experience / diff
		end

		return experience, canLevel, percent
	end

	return experience
end

function ns:UpdateEntry(entry)
	local experience = ns:CalculateExperience()
	local widget = entry.widget
	local statusbar = entry.statusbar
	statusbar:SetFrameStrata(widget:GetFrameStrata())
	statusbar:SetFrameLevel(max(widget:GetFrameLevel() + (entry.level or -1), 0))
	statusbar:SetSize(widget:GetSize())
	statusbar:SetStatusBarTexture(widget:GetStatusBarTexture() or config.texture)
	statusbar:SetMinMaxValues(widget:GetMinMaxValues())
	statusbar:SetValue(widget:GetValue() + experience)
	if experience > 0 then
		statusbar:SetStatusBarColor(unpack(config.color))
	else
		-- TODO: WIP
		local exhaustionStateID = GetRestState()
		if exhaustionStateID == 1 then
			statusbar:SetStatusBarColor(0.0, 0.39, 0.88, 1.0)
		elseif exhaustionStateID == 2 then
			statusbar:SetStatusBarColor(0.58, 0.0, 0.55, 1.0)
		else
			statusbar:SetStatusBarColor(1, 1, 1, 1)
		end
	end
end

function ns:UpdateBars()
	for i = 1, #manifest do
		local entry = manifest[i]

		-- update hooked bars
		if entry.hooked then
			ns:UpdateEntry(entry)
		end
	end
end

function ns:IsWidget(widget, specific)
	return type(widget) == "table" and type(widget.GetObjectType) == "function" and (type(specific) ~= "string" or widget:GetObjectType() == specific)
end

function ns:SetupBar(entry, widget)
	entry.widget = widget

	entry.statusbar = CreateFrame("StatusBar", nil, widget)
	entry.statusbar:SetAllPoints()

	table.insert(ns.bars, entry)
end

function ns:ScanBars()
	for i = 1, #manifest do
		local entry = manifest[i]

		-- skip hooked bars
		if not entry.hooked then
			local frame

			-- find the statusbar frame
			if type(entry.frame) == "function" then
				frame = entry.frame()
			elseif type(entry.frame) == "string" then
				frame = _G[entry.frame]
			end

			-- validate and setup
			if type(frame) == "table" and type(frame.GetObjectType) == "function" and frame:GetObjectType() == "StatusBar" then
				ns:SetupBar(entry, frame)
				entry.hooked = true
			end
		end
	end
end

function ns:DisableAddOn()
	ns:UnregisterAllEvents()
	ns:SetScript("OnEvent", nil)

	for i = 1, #ns.bars do
		ns.bars[i].statusbar:Hide()
	end

	table.wipe(ns.zone)
end

function ns:ON_TOOLTIP()
	if not GameTooltip:IsShown() then return end

	local experience, canLevel, percent = ns:CalculateExperience()

	local DEFAULT_NUM_BARS = 20
	local currentPercent = math.ceil((UnitXP("player") / UnitXPMax("player")) * 100)
	local requiredBarsPercent = math.ceil(((UnitXPMax("player") - UnitXP("player")) * (DEFAULT_NUM_BARS / UnitXPMax("player"))) * 10) / 10

	local text = "|cffFFD200" .. addonName .. "|r"
	text = text .. "\n|cffFFFFFFYou are at " .. currentPercent .. "% XP. You require " .. (100 - currentPercent) .. "% XP to level " .. (ns.level + 1) .. "."
	text = text .. "\nIn other terms you need to fill up " .. requiredBarsPercent .. " bars of XP."

	if experience > 0 then
		text = text .. "\nYour quest log is worth " .. experience .. " XP."

		if percent and percent <= 1 then
			text = text .. " (" .. math.ceil(percent * 100) .. "% of remaining XP)"
		end
	end

	if canLevel then
		text = text .. "|r\n\n|cff00FF00You will level up if you deliver your " .. (config.incomplete and "current " or "completed ") .. "quests!"
	end

	GameTooltip:AddLine("\n" .. text)
	GameTooltip:Show()
end

function ns:ON_EVENT(event, arg1)
	-- loading screen status
	if event == "LOADING_SCREEN_ENABLED" then
		ns.loading = true
	elseif event == "LOADING_SCREEN_DISABLED" then
		ns.loading = false
	end

	-- retrieve level and set flag once we are ready to calculate experience
	ns.level = UnitLevel("player")
	ns.ready = ns.ready or event == "PLAYER_ENTERING_WORLD"

	-- disable the addon?
	if ns.ready and ns.level >= MAX_LEVEL then
		return ns:DisableAddOn()
	end

	-- update the hooked bars
	ns:UpdateBars()

	-- we leveled up, update our level
	if event == "PLAYER_LEVEL_UP" then
		-- TODO: WIP
		C_Timer.After(3, function()
			ns.level = arg1
			ns.block = nil
		end)
	end

	-- check if we can level up with the current experience, and we haven't already notified the player
	if ns.ready and not ns.block then
		local _, canLevel = ns:CalculateExperience()

		if canLevel then
			ns.block = true
			ns:PlayAlert(ns.level + 1)
		end
	end
end

function ns:ADDON_LOADED(event, name)
	if name == addonName then
		-- savedvariable
		local variable = addonName .. "DB"
		config = _G[variable] or config
		_G[variable] = config

		-- events
		local events = {
			"LOADING_SCREEN_ENABLED",
			"LOADING_SCREEN_DISABLED",
			"PLAYER_ENTERING_WORLD",
			"PLAYER_LEVEL_UP",
			"PLAYER_LOGIN",
			"PLAYER_XP_UPDATE",
			"QUEST_LOG_UPDATE",
			"QUEST_WATCH_LIST_CHANGED",
			"SUPER_TRACKED_QUEST_CHANGED",
			"UNIT_PORTRAIT_UPDATE",
			"ZONE_CHANGED_NEW_AREA",
		}

		if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
			events[#events + 1] = "UNIT_ENTERED_VEHICLE"
			events[#events + 1] = "UNIT_EXITED_VEHICLE"
		end

		-- register events
		for i = 1, #events do
			local temp = events[i]
			ns[temp] = ns.ON_EVENT
			ns:RegisterEvent(temp)
		end

		-- apply hooks
		hooksecurefunc("AddQuestWatch", ns.ON_EVENT)
		hooksecurefunc("RemoveQuestWatch", ns.ON_EVENT)

		-- experience bar
		local hooked
		hooksecurefunc(StatusTrackingBarManager, "AddBarFromTemplate", function(_, _, template)
			if hooked or template ~= "ExpStatusBarTemplate" then return end
			hooked = 1
			local bars = StatusTrackingBarManager.bars
			local xpbar = bars[#bars] -- it's always added at the end when this is called
			hooksecurefunc(xpbar.ExhaustionTick, "ExhaustionToolTipText", ns.ON_TOOLTIP)
			xpbar.ExhaustionTick:HookScript("OnEnter", ns.ON_TOOLTIP)
			local entry = manifest[1] -- we keep the main xp bar on top of the manifest
			ns:SetupBar(entry, xpbar.StatusBar)
			entry.hooked = true
		end)
	end

	-- scan for supported addons
	ns:ScanBars()
end

-- get ready to rumble
ns:RegisterEvent("ADDON_LOADED")
