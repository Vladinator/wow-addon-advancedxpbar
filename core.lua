local addonName = ... ---@type string

local GetQuestLogTitle = GetQuestLogTitle ---@type fun(questID: number): title: string, level: number, suggestedGroup: number, isHeader: boolean, isCollapsed: boolean, isComplete: boolean, frequency: number, questID: number, startEvent: boolean, displayQuestID: number, isOnMap: boolean, hasLocalPOI: boolean, isTask: boolean, isBounty: boolean, isStory: boolean, isHidden: boolean, isScaling: boolean
local GetQuestLogRequiredMoney = GetQuestLogRequiredMoney ---@type fun(): requiredMoney: number
local GetQuestLogSelection = GetQuestLogSelection ---@type fun(): index: number
local SelectQuestLogEntry = SelectQuestLogEntry ---@type fun(index: number)
local GetNumQuestLogEntries = GetNumQuestLogEntries ---@type fun(): numEntries: number, numQuests: number

---@class QuestWatchListItemPolyfill
---@field public id number
---@field public timer number

---@class QuestInfoPolyfill : QuestInfo
---@field public isComplete boolean

---@class QuestLogUtil
local QuestLogUtil
---@class QuestLogUtil
QuestLogUtil = {
	SupportsQuestWatching = function()
		return false
	end,
	---@param questQuery number
	---@return number questIndex, number questID
	GetLegacyIndex = function(questQuery)
		local numEntries = GetNumQuestLogEntries()
		for index = 1, numEntries do
			local _, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(index)
			if not isHeader and questQuery == index then
				return index, questID
			end
		end
		for index = 1, numEntries do
			local _, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(index)
			if not isHeader and questQuery == questID then
				return index, questID
			end
		end
		return 0, 0
	end,
	QuestMapUpdateAllQuests = function()
		if QuestMapUpdateAllQuests then
			QuestMapUpdateAllQuests()
		end
	end,
	---@param index number
	---@return (QuestInfo|QuestInfoPolyfill)? questInfo
	GetInfo = function(index)
		if C_QuestLog.GetInfo then
			return C_QuestLog.GetInfo(index)
		else
			local questIndex = QuestLogUtil.GetLegacyIndex(index)
			local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID, startEvent, displayQuestID, isOnMap, hasLocalPOI, isTask, isBounty, isStory, isHidden, isScaling = GetQuestLogTitle(questIndex)
			if title then
				---@type QuestInfoPolyfill
				return {
					title = title,
					level = level,
					suggestedGroup = suggestedGroup,
					isHeader = isHeader,
					isCollapsed = isCollapsed,
					isComplete = isComplete,
					frequency = frequency,
					questID = questID,
					startEvent = startEvent,
					displayQuestID = displayQuestID,
					isOnMap = isOnMap,
					hasLocalPOI = hasLocalPOI,
					isTask = isTask,
					isBounty = isBounty,
					isStory = isStory,
					isHidden = isHidden,
					isScaling = isScaling,
					questLogIndex = index,
					difficultyLevel = 0,
					isAutoComplete = false,
					isLegendarySort = false,
					overridesSortOrder = false,
					useMinimalHeader = false,
				}
			end
		end
	end,
	---@param index number
	---@return number? questID
	GetQuestIDForQuestWatchIndex = function(index)
		if C_QuestLog.GetQuestIDForQuestWatchIndex then
			return C_QuestLog.GetQuestIDForQuestWatchIndex(index)
		end
	end,
	---@param questID number
	---@return Enum.QuestWatchType? watchType
	GetQuestWatchType = function(questID)
		if C_QuestLog.GetQuestWatchType then
			return C_QuestLog.GetQuestWatchType(questID)
		else
			return 1
		end
	end,
	---@param questID number
	---@return number? requiredMoney
	GetRequiredMoney = function(questID)
		if C_QuestLog.GetRequiredMoney then
			return C_QuestLog.GetRequiredMoney(questID)
		elseif GetQuestLogRequiredMoney then
			local questIndex = QuestLogUtil.GetLegacyIndex(questID)
			local backup = QuestLogUtil.GetSelectedQuest()
			QuestLogUtil.SetSelectedQuest(questIndex)
			local requiredMoney = GetQuestLogRequiredMoney()
			QuestLogUtil.SetSelectedQuest(backup)
			return requiredMoney
		end
	end,
	---@return number? questID
	GetSelectedQuest = function()
		if C_QuestLog.GetSelectedQuest then
			return C_QuestLog.GetSelectedQuest()
		elseif GetQuestLogSelection then
			return GetQuestLogSelection()
		end
	end,
	---@param questID number
	---@return boolean? isComplete
	IsComplete = function(questID)
		if C_QuestLog.IsComplete then
			return C_QuestLog.IsComplete(questID)
		else
			local questInfo = QuestLogUtil.GetInfo(questID)
			if questInfo then
				return questInfo.isComplete
			end
		end
	end,
	---@param questID? number
	SetSelectedQuest = function(questID)
		if not questID then
			return
		end
		if C_QuestLog.SetSelectedQuest then
			return C_QuestLog.SetSelectedQuest(questID)
		elseif SelectQuestLogEntry then
			local questIndex = QuestLogUtil.GetLegacyIndex(questID)
			SelectQuestLogEntry(questIndex)
		end
	end,
	---@param questID? number
	---@return boolean? shouldShow
	ShouldShowQuestRewards = function(questID)
		if not questID then
			return
		end
		if C_QuestLog.ShouldShowQuestRewards then
			return C_QuestLog.ShouldShowQuestRewards(questID)
		end
	end,
}

---@class AddOnFrame : Frame
local ns = CreateFrame("Frame")
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
---@field public widget? StatusBar
---@field public statusbar? StatusBar

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

		popup = CreateFrame("Frame", nil, UIParent) ---@class PopupFrame
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

		popup.hideAnim = popup:CreateAnimationGroup() ---@class PopupFrameHideAnim : AnimationGroup
		popup.hideAnim.alpha = popup.hideAnim:CreateAnimation("Alpha")
		popup.hideAnim.alpha:SetFromAlpha(1)
		popup.hideAnim.alpha:SetToAlpha(0)
		popup.hideAnim.alpha:SetDuration(1)
		popup.hideAnim.alpha:SetOrder(1)
		popup.hideAnim.alpha:SetScript("OnFinished", scripts.AnimOutFinished)

		popup.blackBg = popup:CreateTexture(nil, "BACKGROUND") ---@class PopupFrameBackground : Texture, TextureBase
		popup.blackBg:SetPoint("BOTTOM", 0, 0)
		popup.blackBg:SetSize(326, 103)
		popup.blackBg:SetTexture("Interface\\LevelUp\\LevelUpTex")
		popup.blackBg:SetTexCoord(0.00195313, 0.63867188, 0.03710938, 0.23828125)
		popup.blackBg:SetVertexColor(1, 1, 1, 0.6)
		popup.blackBg.grow = popup.blackBg:CreateAnimationGroup() ---@class PopupFrameBackgroundGrowAnim : AnimationGroup
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

		popup.gLine2 = popup:CreateTexture(nil, "BACKGROUND", nil, 2) ---@class PopupFrameLine : Texture, TextureBase
		popup.gLine2:SetPoint("TOP", 0, 0)
		popup.gLine2:SetSize(418, 7)
		popup.gLine2:SetTexture("Interface\\LevelUp\\LevelUpTex")
		popup.gLine2:SetTexCoord(unpack(levelUpTexCoords.gLine))
		popup.gLine2.grow = popup.gLine2:CreateAnimationGroup() ---@class PopupFrameLineGrowAnim : AnimationGroup
		popup.gLine2.grow.anim1 = popup.gLine2.grow:CreateAnimation("Scale")
		popup.gLine2.grow.anim1:SetScale(0.001, 1)
		popup.gLine2.grow.anim1:SetDuration(0)
		popup.gLine2.grow.anim1:SetStartDelay(levelUpTexCoords.gLineDelay)
		popup.gLine2.grow.anim1:SetOrder(1)
		popup.gLine2.grow.anim2 = popup.gLine2.grow:CreateAnimation("Scale")
		popup.gLine2.grow.anim2:SetScale(1000, 1)
		popup.gLine2.grow.anim2:SetDuration(.5)
		popup.gLine2.grow.anim2:SetOrder(2)

		popup.gLine = popup:CreateTexture(nil, "BACKGROUND", nil, 2) ---@class PopupFrameLine : Texture, TextureBase
		popup.gLine:SetPoint("BOTTOM", 0, 0)
		popup.gLine:SetSize(418, 7)
		popup.gLine:SetTexture("Interface\\LevelUp\\LevelUpTex")
		popup.gLine:SetTexCoord(unpack(levelUpTexCoords.gLine))
		popup.gLine.grow = popup.gLine:CreateAnimationGroup() ---@class PopupFrameLineGrowAnim : AnimationGroup
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

		popup.levelFrame = CreateFrame("Frame", nil, popup) ---@class PopupFrameLevelFrame : Frame
		popup.levelFrame:SetPoint("CENTER")
		popup.levelFrame:SetSize(418, 72)
		popup.levelFrame:SetAlpha(0)

		popup.levelFrame.levelUp = popup.levelFrame:CreateAnimationGroup() ---@class PopupFrameLevelFrameLevelUpAnim : AnimationGroup
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
		popup.levelFrame.levelText:SetFormattedText("You've enough XP to ding level %d!", level) ---@diagnostic disable-line: redundant-parameter
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
		Nightborne = {
			1732019,
			1732020,
			1732395,
			1732395,
		},
		HighmountainTauren = {
			1730523,
			1730524,
			1730897,
			1730898,
		},
		VoidElf = {
			1732774,
			1732775,
			1733152,
			1733153,
		},
		LightforgedDraenei = {
			1731271,
			1731272,
			1731645,
			1731646,
		},
		ZandalariTroll = {
			1903036,
			1903037,
			1903509,
			1903510,
		},
		KulTiran = {
			2531190,
			2531191,
			2491885,
			2491886,
		},
		DarkIronDwarf = {
			1902017,
			1902018,
			1902530,
			1902531,
		},
		Vulpera = {
			3106239,
			3106240,
			3106704,
			3106705,
		},
		MagharOrc = {
			1951430,
			1951432,
			1951431,
			1951433,
		},
		Mechagnome = {
			3107638,
			3107639,
			3107169,
			3107170,
		},
		Dracthyr = {
			4739493,
			4739493,
			4738559,
			4738561,
		},
		EarthenDwarf = {
			6021038,
			6021039,
			6021057,
			6021058,
		},
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
		if type(level) ~= "number" or level < 2 or level > GetMaxLevelForPlayerExpansion() then
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
	QuestLogUtil.QuestMapUpdateAllQuests()
	local i = 0
	while true do
		i = i + 1
		local id = QuestLogUtil.GetQuestIDForQuestWatchIndex(i)
		if not id then
			break
		end
		ns.zone[id] = true
	end
end

---@return number experience, boolean? canLevel, number? percent
function ns:CalculateExperience()

	-- loading screen makes calculating values go weird
	if ns.loading then return 0 end

	local experience = 0
	local playerMoney = GetMoney()
	local backupQuestID = QuestLogUtil.GetSelectedQuest()
	local index = 1
	local header ---@type string?

	-- updates what quests are for the current zone
	ns:UpdateZone()

	-- this tracks if we're on the modern or the legacy client
	local clientCanWatchQuests = QuestLogUtil.SupportsQuestWatching()

	-- iterate over the quests
	repeat

		local questInfo = QuestLogUtil.GetInfo(index)

		if clientCanWatchQuests and not questInfo then
			break
		end

		if questInfo then

			QuestLogUtil.SetSelectedQuest(questInfo.questID)
			QuestLogUtil.ShouldShowQuestRewards(questInfo.questID)

			local isTracked = QuestLogUtil.GetQuestWatchType(questInfo.questID)
			local isRemote = not ns.zone[questInfo.questID]
			local isCompleted = QuestLogUtil.IsComplete(questInfo.questID) or (GetNumQuestLeaderBoards(index) == 0 and playerMoney >= QuestLogUtil.GetRequiredMoney(questInfo.questID) and not questInfo.startEvent)

			if not clientCanWatchQuests then
				isRemote = false
			end

			if questInfo.isHeader then
				header = questInfo.title
			elseif (config.bonus and questInfo.isTask) or ((not config.watched or isTracked) and (config.remote or not isRemote) and (config.incomplete or isCompleted)) then
				experience = experience + (GetQuestLogRewardXP() or 0)
			end

		end

		index = index + 1

		if not clientCanWatchQuests and index > 50 then
			break
		end

	until false

	-- restore the original quest selection
	QuestLogUtil.SetSelectedQuest(backupQuestID)
	QuestLogUtil.ShouldShowQuestRewards(backupQuestID)

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
	if not widget then return end
	local statusbar = entry.statusbar
	if not statusbar then return end
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
	entry.statusbar:SetAllPoints() ---@diagnostic disable-line: missing-parameter
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
	ns:SetScript("OnEvent", nil)
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
	local currentPercent = ceil(UnitXP("player")/UnitXPMax("player")*100)
	local requiredBarsPercent = ceil(((UnitXPMax("player") - UnitXP("player")) * (DEFAULT_NUM_BARS / UnitXPMax("player"))) * 10) / 10

	local text = {}
	text[#text + 1] = format("|cffFFD200%s|r", addonName)
	text[#text + 1] = format("|cffFFFFFFYou are at %d%% XP. You require %d%% XP to level %d.", currentPercent, 100 - currentPercent, ns.level + 1)
	text[#text + 1] = format("You need to fill up %d bars of XP.", requiredBarsPercent)

	if experience > 0 then
		text[#text + 1] = format("Your quest log is worth %d XP.", experience)

		if percent and percent <= 1 then
			text[#text] = format("%s (%d%% of remaining XP)", text[#text], ceil(percent * 100))
		end
	end

	if canLevel then
		text[#text + 1] = "|r"
		text[#text + 1] = ""
		text[#text + 1] = ""
		text[#text + 1] = format("|cff00FF00You will level up if you deliver your %s quests!", config.incomplete and "current" or "completed")
	end

	GameTooltip:AddLine(format("%s%s", "\n", table.concat(text, "\n")))
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
	if ns.ready and ns.level >= GetMaxLevelForPlayerExpansion() then
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
		if C_QuestLog.AddQuestWatch then hooksecurefunc(C_QuestLog, "AddQuestWatch", ns.ON_EVENT) end
		if C_QuestLog.RemoveQuestWatch then hooksecurefunc(C_QuestLog, "RemoveQuestWatch", ns.ON_EVENT) end
		if C_QuestLog.AddWorldQuestWatch then hooksecurefunc(C_QuestLog, "AddWorldQuestWatch", ns.ON_EVENT) end
		if C_QuestLog.RemoveWorldQuestWatch then hooksecurefunc(C_QuestLog, "RemoveWorldQuestWatch", ns.ON_EVENT) end

		-- experience bar
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
