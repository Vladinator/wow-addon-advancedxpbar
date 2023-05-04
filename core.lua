if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then return end

local addonName = ... ---@type string
local MAX_LEVEL = GetMaxLevelForExpansionLevel(GetClampedCurrentExpansionLevel()) ---@diagnostic disable-line: undefined-global

local ns = CreateFrame("Frame") ---@class AddOnFrame : Frame
ns:SetScript("OnEvent", function(self, event, ...) self[event](self, event, ...) end)
ns.loading = true ---@type boolean
ns.bars = {} ---@type Manifest[]
ns.zone = {} ---@type table<number, true|nil>

---@class Settings
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

---@type Settings
local config = defaults

---@class Manifest
---@field public frame string|fun():StatusBar|false|nil
---@field public level? number
---@field public hooked? boolean
---@field public widget StatusBar
---@field public statusbar StatusBar

---@type Manifest[]
local manifest = {
	{
		-- default UI expbar
		level = 1,
		frame = function()
			local MainMenuExpBar = _G.MainMenuExpBar ---@diagnostic disable-line: undefined-field
			if MainMenuExpBar then
				return MainMenuExpBar
			end
			local StatusTrackingBarManager = _G.StatusTrackingBarManager ---@diagnostic disable-line: undefined-field
			local ExpBarMixin = _G.ExpBarMixin ---@diagnostic disable-line: undefined-field
			if StatusTrackingBarManager and StatusTrackingBarManager.bars and ExpBarMixin then
				for _, bar in ipairs(StatusTrackingBarManager.bars) do
					if bar.OnLoad == ExpBarMixin.OnLoad then
						return bar
					end
				end
			end
		end,
	},
	{
		-- BEB
		frame = "BEBBackground",
	},
	{
		-- Dominos
		frame = function()
			local Dominos = _G.Dominos ---@diagnostic disable-line: undefined-field
			return type(Dominos) == "table" and type(Dominos.Frame) == "table" and type(Dominos.Frame.Get) == "function" and Dominos.Frame:Get("xp")
		end,
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

	local popup ---@class PopupFrame : Frame
	local last ---@type number?

	-- adapted LevelUpDisplay code to suit our purpose
	do

		local levelUpTexCoords = {
			gLine = { 0.00195313, 0.81835938, 0.01953125, 0.03320313 },
			gLineDelay = 1.5,
		}

		local ZoneTextFrame = _G.ZoneTextFrame ---@diagnostic disable-line: undefined-field
		local SubZoneTextFrame = _G.SubZoneTextFrame ---@diagnostic disable-line: undefined-field

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

		---@diagnostic disable-next-line: assign-type-mismatch
		popup = CreateFrame("Frame", nil, UIParent) ---@type PopupFrame
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
		popup.blackBg:SetTexCoord(0.00195313, 0.63867188, 0.03710938, 0.23828125)
		popup.blackBg:SetVertexColor(1, 1, 1, 0.6)
		popup.blackBg.grow = popup.blackBg:CreateAnimationGroup()
		popup.blackBg.grow.anim1 = popup.blackBg.grow:CreateAnimation("Scale")
		popup.blackBg.grow.anim1:SetScale(1, 0.001)
		popup.blackBg.grow.anim1:SetDuration(0)
		popup.blackBg.grow.anim1:SetStartDelay(levelUpTexCoords.gLineDelay)
		popup.blackBg.grow.anim1:SetOrder(1)
		popup.blackBg.grow.anim1:SetOrigin("BOTTOM", 0, 0)
		popup.blackBg.grow.anim2 = popup.blackBg.grow:CreateAnimation("Scale")
		popup.blackBg.grow.anim2:SetScale(1, 1000)
		popup.blackBg.grow.anim2:SetDuration(0.15)
		popup.blackBg.grow.anim2:SetStartDelay(0.25)
		popup.blackBg.grow.anim2:SetOrder(2)
		popup.blackBg.grow.anim2:SetOrigin("BOTTOM", 0, 0)

		popup.gLine2 = popup:CreateTexture(nil, "BACKGROUND", nil, 2)
		popup.gLine2:SetPoint("TOP", 0, 0)
		popup.gLine2:SetSize(418, 7)
		popup.gLine2:SetTexture("Interface\\LevelUp\\LevelUpTex")
		popup.gLine2:SetTexCoord(unpack(levelUpTexCoords.gLine))
		popup.gLine2.grow = popup.gLine2:CreateAnimationGroup()
		popup.gLine2.grow.anim1 = popup.gLine2.grow:CreateAnimation("Scale")
		popup.gLine2.grow.anim1:SetScale(0.001, 1)
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
		popup.gLine.grow.anim1:SetScale(0.001, 1)
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
		popup.levelFrame.levelUp.anim1:SetDuration(0.7)
		popup.levelFrame.levelUp.anim1:SetStartDelay(1.5)
		popup.levelFrame.levelUp.anim1:SetOrder(1)
		popup.levelFrame.levelUp.anim2 = popup.levelFrame.levelUp:CreateAnimation("Alpha")
		popup.levelFrame.levelUp.anim2:SetFromAlpha(1)
		popup.levelFrame.levelUp.anim2:SetToAlpha(0)
		popup.levelFrame.levelUp.anim2:SetDuration(0.5)
		popup.levelFrame.levelUp.anim2:SetStartDelay(1.5)
		popup.levelFrame.levelUp.anim2:SetOrder(2)
		popup.levelFrame.levelUp:SetScript("OnPlay", scripts.LevelUpPlay)
		popup.levelFrame.levelUp:SetScript("OnFinished", scripts.LevelUpFinished)

		popup.levelFrame.levelText = popup.levelFrame:CreateFontString(nil, "ARTWORK", "GameFont_Gigantic")
		popup.levelFrame.levelText:SetPoint("BOTTOM", 0, 5)
		popup.levelFrame.levelText:SetTextColor(1, 0.82, 0)
		popup.levelFrame.levelText:SetJustifyH("CENTER")

		popup.levelFrame.reachedText = popup.levelFrame:CreateFontString(nil, "ARTWORK", "SystemFont_Shadow_Large")
		popup.levelFrame.reachedText:SetPoint("BOTTOM", popup.levelFrame.levelText, "TOP", 0, 5)

		popup.levelFrame.singleline = popup.levelFrame:CreateFontString(nil, "ARTWORK", "GameFont_Gigantic")
		popup.levelFrame.singleline:SetPoint("CENTER", 0, -4)

		popup.levelFrame.blockText = popup.levelFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
		popup.levelFrame.blockText:SetPoint("CENTER", 0, -4)

	end

	---@param level number
	local function Popup(level)
		popup:PlayBanner()
		popup.levelFrame.reachedText:SetText("Good News")
		popup.levelFrame.levelText:SetFormattedText("You've enough XP to ding level %d!", level)
	end

	local SOUND_CHEER_DB = {
		Human = {
			540628,
			540610,
			540694,
			540707,
		},
		Orc = {
			541328,
			541320,
			541435,
			541404,
		},
		Dwarf = {
			540014,
			539977,
			540024,
			540070,
		},
		NightElf = {
			541043,
			541055,
			541138,
			541126,
		},
		Scourge = {
			542697,
			542691,
			542783,
			542781,
		},
		Tauren = {
			542976,
			542985,
			543078,
			543025,
		},
		Gnome = {
			540434,
			540445,
			540493,
			540463,
		},
		Troll = {
			543253,
			543277,
			543331,
			543330,
		},
		Goblin = {
			541890,
			542010,
			541792,
			541848,
		},
		BloodElf = {
			1313578,
			1313579,
			1306474,
			1306475,
		},
		Draenei = {
			539598,
			539601,
			539735,
			539639,
		},
		Worgen = {
			542081,
			542104,
			542207,
			542194,
		},
		Pandaren = {
			636413,
			636415,
			630064,
			630066,
		},
		Nightborne = "BloodElf",
		HighmountainTauren = "Tauren",
		VoidElf = "NightElf",
		LightforgedDraenei = "Draenei",
		ZandalariTroll = "Troll",
		KulTiran = "Human",
		DarkIronDwarf = "Dwarf",
		Vulpera = "Goblin",
		MagharOrc = "Orc",
		Mechagnome = "Gnome",
		Dracthyr = "Human",
	}

	---@param race string
	---@param gender number
	local function PlayRandomCheer(race, gender)
		local files = SOUND_CHEER_DB[race]
		if not files then
			local _, faction = UnitFactionGroup("player")
			return PlayRandomCheer(faction == "Alliance" and "Human" or "Orc", gender)
		end
		if type(files) == "string" then
			return PlayRandomCheer(files, gender)
		end
		local index = gender == 1 and random(1, 2) or random(3, 4)
		local fileID = files[index] or files[1]
		if fileID then
			return PlaySoundFile(fileID, "Master")
		end
	end

	local function Sound()
		local _, race = UnitRace("player")
		PlaySoundFile(567431, "Master")
		PlayRandomCheer(race, UnitSex("player") == 3 and 1 or 2)
		PlaySoundFile(1068315, "Master")
	end

	---@param level number
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
	QuestMapUpdateAllQuests()
	local i = 0
	while true do
		i = i + 1
		local id = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
		if not id then
			break
		end
		ns.zone[id] = true
		-- TODO: C_QuestLog.IsOnMap()
	end
end

function ns:CalculateExperience()

	-- loading screen makes calculating values go weird
	if ns.loading then return 0 end

	local experience = 0
	local playerMoney = GetMoney()
	local backupQuestID = C_QuestLog.GetSelectedQuest()
	local index = 1
	local header ---@type string?

	-- updates what quests are for the current zone
	ns:UpdateZone()

	-- iterate over the quests
	repeat

		local questInfo = C_QuestLog.GetInfo(index)
		if not questInfo then break end

		C_QuestLog.SetSelectedQuest(questInfo.questID)
		C_QuestLog.ShouldShowQuestRewards(questInfo.questID)

		local isTracked = C_QuestLog.GetQuestWatchType(questInfo.questID)
		local isRemote = not ns.zone[questInfo.questID]
		local isCompleted = C_QuestLog.IsComplete(questInfo.questID) or (GetNumQuestLeaderBoards(index) == 0 and playerMoney >= C_QuestLog.GetRequiredMoney(questInfo.questID) and not questInfo.startEvent)

		if questInfo.isHeader then
			header = questInfo.title
		elseif (config.bonus and questInfo.isTask) or ((not config.watched or isTracked) and (config.remote or not isRemote) and (config.incomplete or isCompleted)) then
			experience = experience + (GetQuestLogRewardXP() or 0)
		end

		index = index + 1

	until false

	-- restore the original quest selection
	C_QuestLog.SetSelectedQuest(backupQuestID)
	C_QuestLog.ShouldShowQuestRewards(backupQuestID)

	-- calculate experience differences due to quest experience pool
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

---@param entry Manifest
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
	for _, entry in ipairs(manifest) do
		if entry.hooked then
			ns:UpdateEntry(entry)
		end
	end
end

function ns:IsWidget(widget, specific)
	return type(widget) == "table" and type(widget.GetObjectType) == "function" and (type(specific) ~= "string" or widget:GetObjectType() == specific)
end

---@param entry Manifest
---@param widget StatusBar
function ns:SetupBar(entry, widget)
	entry.widget = widget
	entry.statusbar = CreateFrame("StatusBar", nil, widget)
	entry.statusbar:SetAllPoints()
	table.insert(ns.bars, entry)
end

function ns:ScanBars()
	for _, entry in pairs(manifest) do
		if not entry.hooked then
			local frame ---@type StatusBar|false|nil
			-- find the statusbar frame
			if type(entry.frame) == "function" then
				frame = entry.frame()
			elseif type(entry.frame) == "string" then
				frame = _G[entry.frame]
			end
			-- validate and setup
			if frame and type(frame) == "table" and type(frame.GetObjectType) == "function" and frame:GetObjectType() == "StatusBar" then
				ns:SetupBar(entry, frame)
				entry.hooked = true
			end
		end
	end
end

function ns:DisableAddOn()
	ns:UnregisterAllEvents()
	ns:SetScript("OnEvent", nil) ---@diagnostic disable-line: param-type-mismatch
	for _, bar in ipairs(ns.bars) do
		bar.statusbar:Hide()
	end
	table.wipe(ns.zone)
end

function ns:ON_TOOLTIP()

	if not GameTooltip:IsShown() then
		return
	end

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

---@param event WowEvent
---@param arg1 any
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

---@param event WowEvent
---@param name string
function ns:ADDON_LOADED(event, name)

	if event == "ADDON_LOADED" and name == addonName then

		-- savedvariable
		local variable = format("%sDB", addonName)
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
			"UNIT_PORTRAIT_UPDATE",
			"ZONE_CHANGED_NEW_AREA",
			-- TODO: DEPRECATED?
			"UNIT_ENTERED_VEHICLE",
			"UNIT_EXITED_VEHICLE",
			"SUPER_TRACKED_QUEST_CHANGED",
		}

		-- register events
		for i = 1, #events do
			local temp = events[i]
			ns[temp] = ns.ON_EVENT
			pcall(ns.RegisterEvent, ns, temp)
		end

		-- apply hooks
		hooksecurefunc(C_QuestLog, "AddQuestWatch", ns.ON_EVENT)
		hooksecurefunc(C_QuestLog, "RemoveQuestWatch", ns.ON_EVENT)
		if C_QuestLog.AddWorldQuestWatch then hooksecurefunc(C_QuestLog, "AddWorldQuestWatch", ns.ON_EVENT) end
		if C_QuestLog.RemoveWorldQuestWatch then hooksecurefunc(C_QuestLog, "RemoveWorldQuestWatch", ns.ON_EVENT) end

		-- experience bar
		local StatusTrackingBarManager = _G.StatusTrackingBarManager ---@diagnostic disable-line: undefined-field

		if StatusTrackingBarManager then

			local hooked ---@type boolean

			local function HookStatusTrackingBarContainer(container)
				if hooked or not container or type(container.StatusTrackingBarContainer_OnLoad) ~= "function" then
					return
				end
				for _, xpbar in ipairs(container.bars) do
					if xpbar and xpbar.ExhaustionTick and type(xpbar.ExhaustionTick) == "table" then
						hooked = true
						hooksecurefunc(xpbar.ExhaustionTick, "ExhaustionToolTipText", ns.ON_TOOLTIP)
						xpbar.ExhaustionTick:HookScript("OnEnter", ns.ON_TOOLTIP)
						local entry = manifest[1] -- we keep the main xp bar on top of the manifest
						ns:SetupBar(entry, xpbar.StatusBar)
						entry.hooked = true
						break
					end
				end
			end

			HookStatusTrackingBarContainer(StatusTrackingBarManager.MainStatusTrackingBarContainer)
			-- HookStatusTrackingBarContainer(StatusTrackingBarManager.SecondaryStatusTrackingBarContainer)

			if type(StatusTrackingBarManager.AddBarFromTemplate) == "function" then
				hooksecurefunc(StatusTrackingBarManager, "AddBarFromTemplate", function(_, _, template)
					if hooked or template ~= "ExpStatusBarTemplate" then return end
					hooked = true
					local bars = StatusTrackingBarManager.bars
					local xpbar = bars[#bars] -- it's always added at the end when this is called
					hooksecurefunc(xpbar.ExhaustionTick, "ExhaustionToolTipText", ns.ON_TOOLTIP)
					xpbar.ExhaustionTick:HookScript("OnEnter", ns.ON_TOOLTIP)
					local entry = manifest[1] -- we keep the main xp bar on top of the manifest
					ns:SetupBar(entry, xpbar.StatusBar)
					entry.hooked = true
				end)
			end

		end

	end

	-- scan for supported addons
	ns:ScanBars()

end

-- get ready to rumble
ns:RegisterEvent("ADDON_LOADED")
