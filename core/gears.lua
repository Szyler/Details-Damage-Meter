local _detalhes = 		_G.Details
local addonName, Details222 = ...
local Loc = LibStub("AceLocale-3.0"):GetLocale ( "Details" )

local UnitGUID = UnitGUID
local UnitGroupRolesAssigned = DetailsFramework.UnitGroupRolesAssigned
local select = select
local floor = floor
local GetNumGroupMembers = GetNumGroupMembers

local CONST_INSPECT_ACHIEVEMENT_DISTANCE = 1 --Compare Achievements, 28 yards
local CONST_SPELLBOOK_GENERAL_TABID = 1
local CONST_SPELLBOOK_CLASSSPELLS_TABID = 2

local storageDebug = false --remember to turn this to false!
local instancesToStoreData = _detalhes.InstancesToStoreData

function _detalhes:UpdateGears()
	_detalhes:UpdateParser()
	_detalhes:UpdateControl()
	_detalhes:UpdateCombat()
end

function _detalhes:GetCoreVersion()
	return _detalhes.realversion
end

------------------------------------------------------------------------------------------------------------
--chat hooks

	_detalhes.chat_embed = _detalhes:CreateEventListener()
	_detalhes.chat_embed.startup = true

	_detalhes.chat_embed.hook_settabname = function(frame, name, doNotSave)
		if (not doNotSave) then
			if (_detalhes.chat_tab_embed.enabled and _detalhes.chat_tab_embed.tab_name ~= "") then
				if (_detalhes.chat_tab_embed_onframe == frame) then
					_detalhes.chat_tab_embed.tab_name = name
					_detalhes:DelayOptionsRefresh (_detalhes:GetInstance(1))
				end
			end
		end
	end
	_detalhes.chat_embed.hook_closetab = function(frame, fallback)
		if (_detalhes.chat_tab_embed.enabled and _detalhes.chat_tab_embed.tab_name ~= "") then
			if (_detalhes.chat_tab_embed_onframe == frame) then
				_detalhes.chat_tab_embed.enabled = false
				_detalhes.chat_tab_embed.tab_name = ""
				_detalhes.chat_tab_embed_onframe = nil
				_detalhes:DelayOptionsRefresh (_detalhes:GetInstance(1))
				_detalhes.chat_embed:ReleaseEmbed()
			end
		end
	end
	hooksecurefunc ("FCF_SetWindowName", _detalhes.chat_embed.hook_settabname)
	hooksecurefunc ("FCF_Close", _detalhes.chat_embed.hook_closetab)

	function _detalhes.chat_embed:SetTabSettings (tab_name, is_enabled, is_single)

		local current_enabled_state = _detalhes.chat_tab_embed.enabled
		local current_name = _detalhes.chat_tab_embed.tab_name
		local current_is_single = _detalhes.chat_tab_embed.single_window

		tab_name = tab_name or _detalhes.chat_tab_embed.tab_name
		if (is_enabled == nil) then
			is_enabled = _detalhes.chat_tab_embed.enabled
		end
		if (is_single == nil) then
			is_single = _detalhes.chat_tab_embed.single_window
		end

		_detalhes.chat_tab_embed.tab_name = tab_name or ""
		_detalhes.chat_tab_embed.enabled = is_enabled
		_detalhes.chat_tab_embed.single_window = is_single

		if (current_name ~= tab_name) then
			--rename the tab on chat frame
			local ChatFrame = _detalhes.chat_embed:GetTab (current_name)
			if (ChatFrame) then
				FCF_SetWindowName (ChatFrame, tab_name, false)
			end
		end

		if (is_enabled) then
			--was disabled, so we need to save the current window positions.
			if (not current_enabled_state) then
				local window1 = _detalhes:GetInstance(1)
				if (window1) then
					window1:SaveMainWindowPosition()
					if (window1.libwindow) then
						local pos = window1:CreatePositionTable()
						_detalhes.chat_tab_embed.w1_pos = pos
					end
				end
				local window2 = _detalhes:GetInstance(2)
				if (window2) then
					window2:SaveMainWindowPosition()
					if (window2.libwindow) then
						local pos = window2:CreatePositionTable()
						_detalhes.chat_tab_embed.w2_pos = pos
					end
				end
			elseif (not is_single and current_is_single) then
				local window2 = _detalhes:GetInstance(2)
				if (window2) then
					window2:SaveMainWindowPosition()
					if (window2.libwindow) then
						local pos = window2:CreatePositionTable()
						_detalhes.chat_tab_embed.w2_pos = pos
					end
				end
			end

			--need to make the embed
			_detalhes.chat_embed:DoEmbed()
		else
			--need to release the frame
			if (current_enabled_state) then
				_detalhes.chat_embed:ReleaseEmbed()
			end
		end
	end

	function _detalhes.chat_embed:CheckChatEmbed (is_startup)
		if (_detalhes.chat_tab_embed.enabled) then
			_detalhes.chat_embed:DoEmbed (is_startup)
		end
	end

	--dom
-- 	/run _detalhes.chat_embed:SetTabSettings ("Dano", true, false)
-- 	/run _detalhes.chat_embed:SetTabSettings (nil, false, false)
--	/dump _detalhes.chat_tab_embed.tab_name

	function _detalhes.chat_embed:DelayedChatEmbed (is_startup)
		_detalhes.chat_embed.startup = nil
		_detalhes.chat_embed:DoEmbed()
	end

	function _detalhes.chat_embed:DoEmbed (is_startup)
		if (_detalhes.chat_embed.startup and not is_startup) then
			if (_detalhes.AddOnStartTime + 5 < GetTime()) then
				_detalhes.chat_embed.startup = nil
			else
				return
			end
		end
		if (is_startup) then
			return _detalhes.chat_embed:ScheduleTimer("DelayedChatEmbed", 5)
		end
		local tabname = _detalhes.chat_tab_embed.tab_name

		if (_detalhes.chat_tab_embed.enabled and tabname ~= "") then
			local ChatFrame, ChatFrameTab, ChatFrameBackground = _detalhes.chat_embed:GetTab (tabname)

			if (not ChatFrame) then
				FCF_OpenNewWindow (tabname)
				ChatFrame, ChatFrameTab, ChatFrameBackground = _detalhes.chat_embed:GetTab (tabname)
			end

			if (ChatFrame) then
				for index, t in pairs(ChatFrame.messageTypeList) do
					ChatFrame_RemoveMessageGroup (ChatFrame, t)
					ChatFrame.messageTypeList [index] = nil
				end

				_detalhes.chat_tab_embed_onframe = ChatFrame

				if (_detalhes.chat_tab_embed.single_window) then
					--only one window
					local window1 = _detalhes:GetInstance(1)

					window1:UngroupInstance()
					window1.baseframe:ClearAllPoints()

					window1.baseframe:SetParent(ChatFrame)

					window1.rowframe:SetParent(window1.baseframe)
					window1.rowframe:ClearAllPoints()
					window1.rowframe:SetAllPoints()

					window1.windowSwitchButton:SetParent(window1.baseframe)
					window1.windowSwitchButton:ClearAllPoints()
					window1.windowSwitchButton:SetAllPoints()

					local y_up = window1.toolbar_side == 1 and -20 or 0
					local y_down = (window1.show_statusbar and 14 or 0) + (window1.toolbar_side == 2 and 20 or 0)

					window1.baseframe:SetPoint("topleft", ChatFrameBackground, "topleft", 0, y_up + _detalhes.chat_tab_embed.y_offset)
					window1.baseframe:SetPoint("bottomright", ChatFrameBackground, "bottomright", _detalhes.chat_tab_embed.x_offset, y_down)

					window1:LockInstance (true)
					window1:SaveMainWindowPosition()

					local window2 = _detalhes:GetInstance(2)
					if (window2 and window2.baseframe) then
						if (window2.baseframe:GetParent() == ChatFrame) then
							--need to detach
							_detalhes.chat_embed:ReleaseEmbed (true)
						end
					end

				else
					--window #1 and #2
					local window1 = _detalhes:GetInstance(1)
					local window2 = _detalhes:GetInstance(2)
					if (not window2) then
						window2 = _detalhes:CriarInstancia()
					end

					window1:UngroupInstance()
					window2:UngroupInstance()
					window1.baseframe:ClearAllPoints()
					window2.baseframe:ClearAllPoints()

					window1.baseframe:SetParent(ChatFrame)
					window2.baseframe:SetParent(ChatFrame)
					window1.rowframe:SetParent(window1.baseframe)
					window2.rowframe:SetParent(window2.baseframe)

					window1.windowSwitchButton:SetParent(window1.baseframe)
					window1.windowSwitchButton:ClearAllPoints()
					window1.windowSwitchButton:SetAllPoints()
					window2.windowSwitchButton:SetParent(window2.baseframe)
					window2.windowSwitchButton:ClearAllPoints()
					window2.windowSwitchButton:SetAllPoints()

					window1:LockInstance (true)
					window2:LockInstance (true)

					local statusbar_enabled1 = window1.show_statusbar
					local statusbar_enabled2 = window2.show_statusbar

					Details:Destroy(window1.snap)
					Details:Destroy(window2.snap)
					window1.snap [3] = 2; window2.snap [1] = 1;
					window1.horizontalSnap = true; window2.horizontalSnap = true

					local y_up = window1.toolbar_side == 1 and -20 or 0
					local y_down = (window1.show_statusbar and 14 or 0) + (window1.toolbar_side == 2 and 20 or 0)

					local width = ChatFrameBackground:GetWidth() / 2
					local height = ChatFrameBackground:GetHeight() - y_down + y_up

					window1.baseframe:SetSize(width + (_detalhes.chat_tab_embed.x_offset/2), height + _detalhes.chat_tab_embed.y_offset)
					window2.baseframe:SetSize(width + (_detalhes.chat_tab_embed.x_offset/2), height + _detalhes.chat_tab_embed.y_offset)

					window1.baseframe:SetPoint("topleft", ChatFrameBackground, "topleft", 0, y_up + _detalhes.chat_tab_embed.y_offset)
					window2.baseframe:SetPoint("topright", ChatFrameBackground, "topright", _detalhes.chat_tab_embed.x_offset, y_up + _detalhes.chat_tab_embed.y_offset)

					window1:SaveMainWindowPosition()
					window2:SaveMainWindowPosition()

				--	/dump ChatFrame3Background:GetSize()
				end
			end
		end
	end

	function _detalhes.chat_embed:ReleaseEmbed (second_window)
		--release
		local window1 = _detalhes:GetInstance(1)
		local window2 = _detalhes:GetInstance(2)

		if (second_window) then
			window2:UngroupInstance()
			window2.baseframe:ClearAllPoints()
			window2.baseframe:SetParent(UIParent)
			window2.rowframe:SetParent(UIParent)
			window2.rowframe:ClearAllPoints()
			window2.windowSwitchButton:SetParent(UIParent)
			window2.baseframe:SetPoint("center", UIParent, "center", 200, 0)
			window2.rowframe:SetPoint("center", UIParent, "center", 200, 0)
			window2:LockInstance (false)
			window2:SaveMainWindowPosition()

			local previous_pos = _detalhes.chat_tab_embed.w2_pos
			if (previous_pos) then
				window2:RestorePositionFromPositionTable (previous_pos)
			end
			return
		end
		window1:UngroupInstance();
		window1.baseframe:ClearAllPoints()
		window1.baseframe:SetParent(UIParent)
		window1.rowframe:SetParent(UIParent)
		window1.windowSwitchButton:SetParent(UIParent)
		window1.baseframe:SetPoint("center", UIParent, "center")
		window1.rowframe:SetPoint("center", UIParent, "center")
		window1:LockInstance (false)
		window1:SaveMainWindowPosition()

		local previous_pos = _detalhes.chat_tab_embed.w1_pos
		if (previous_pos) then
			window1:RestorePositionFromPositionTable (previous_pos)
		end

		if (not _detalhes.chat_tab_embed.single_window and window2) then

			window2:UngroupInstance()
			window2.baseframe:ClearAllPoints()
			window2.baseframe:SetParent(UIParent)
			window2.rowframe:SetParent(UIParent)
			window2.windowSwitchButton:SetParent(UIParent);
			window2.baseframe:SetPoint("center", UIParent, "center", 200, 0)
			window2.rowframe:SetPoint("center", UIParent, "center", 200, 0)
			window2:LockInstance (false)
			window2:SaveMainWindowPosition()

			local previous_pos = _detalhes.chat_tab_embed.w2_pos
			if (previous_pos) then
				window2:RestorePositionFromPositionTable (previous_pos)
			end
		end
	end

	function _detalhes.chat_embed:GetTab (tabname)
		tabname = tabname or _detalhes.chat_tab_embed.tab_name
		for i = 1, 20 do
			local tabtext = _G ["ChatFrame" .. i .. "Tab"]
			if (tabtext) then
				if (tabtext:GetText() == tabname) then
					return _G ["ChatFrame" .. i], _G ["ChatFrame" .. i .. "Tab"], _G ["ChatFrame" .. i .. "Background"], i
				end
			end
		end
	end

--[[
	--create a tab on chat
	--FCF_OpenNewWindow(name)
	--rename it? perhaps need to hook
	--FCF_SetWindowName(chatFrame, name, true)    --FCF_SetWindowName(3, "DDD", true)
	--/run local chatFrame = _G["ChatFrame3"]; FCF_SetWindowName(chatFrame, "DDD", true)

	--FCF_SetWindowName(frame, name, doNotSave)
	--API SetChatWindowName(frame:GetID(), name); -- set when doNotSave is false

	-- need to store the chat frame reference
	-- hook set window name and check if the rename was on our window

	--FCF_Close
	-- ^ when the window is closed
--]]

------------------------------------------------------------------------------------------------------------

function _detalhes:SetDeathLogLimit(limit)
	if (limit and type(limit) == "number" and limit >= 8) then
		_detalhes.deadlog_events = limit

		local combatObject = Details:GetCurrentCombat()

		for player_name, event_table in pairs(combatObject.player_last_events) do
			if (limit > #event_table) then
				for i = #event_table + 1, limit do
					event_table [i] = {}
				end
			else
				event_table.n = 1
				for _, t in ipairs(event_table) do
					Details:Destroy(t)
				end
			end
		end

		_detalhes:UpdateParserGears()
	end
end

------------------------------------------------------------------------------------------------------------

function _detalhes:TrackSpecsNow (track_everything)

	local spelllist = _detalhes.SpecSpellList

	if (not track_everything) then
		for _, actor in _detalhes.tabela_vigente[1]:ListActors() do
			if (actor:IsPlayer()) then
				for spellid, spell in pairs(actor:GetSpellList()) do
					if (spelllist [spell.id]) then
						actor:SetSpecId(spelllist[spell.id])
						_detalhes.cached_specs [actor.serial] = actor.spec
						break
					end
				end
			end
		end

		for _, actor in _detalhes.tabela_vigente[2]:ListActors() do
			if (actor:IsPlayer()) then
				for spellid, spell in pairs(actor:GetSpellList()) do
					if (spelllist [spell.id]) then
						actor:SetSpecId(spelllist[spell.id])
						_detalhes.cached_specs [actor.serial] = actor.spec
						break
					end
				end
			end
		end
	else
		local combatlist = {}
		local segmentsTable = Details:GetCombatSegments()
		for _, combat in ipairs(segmentsTable) do
			tinsert(combatlist, combat)
		end
		tinsert(combatlist, _detalhes.tabela_vigente)
		tinsert(combatlist, _detalhes.tabela_overall)

		for _, combat in ipairs(combatlist) do
			for _, actor in combat[1]:ListActors() do
				if (actor:IsPlayer()) then
					for spellid, spell in pairs(actor:GetSpellList()) do
						if (spelllist [spell.id]) then
							actor:SetSpecId(spelllist[spell.id])
							_detalhes.cached_specs [actor.serial] = actor.spec
							break
						end
					end
				end
			end

			for _, actor in combat[2]:ListActors() do
				if (actor:IsPlayer()) then
					for spellid, spell in pairs(actor:GetSpellList()) do
						if (spelllist [spell.id]) then
							actor:SetSpecId(spelllist[spell.id])
							_detalhes.cached_specs [actor.serial] = actor.spec
							break
						end
					end
				end
			end
		end
	end

end

function _detalhes:ResetSpecCache (forced)

	local isininstance = IsInInstance()

	if (forced or (not isininstance and not _detalhes.in_group)) then
		Details:Destroy(_detalhes.cached_specs)

		if (_detalhes.track_specs) then
			local my_spec = DetailsFramework.GetSpecialization()
			if (type(my_spec) == "number") then
				local spec_number = DetailsFramework.GetSpecializationInfo(my_spec)
				if (type(spec_number) == "number") then
					local pguid = UnitGUID(_detalhes.playername)
					if (pguid) then
						_detalhes.cached_specs [pguid] = spec_number
					end
				end
			end
		end

	elseif (_detalhes.in_group and not isininstance) then
		Details:Destroy(_detalhes.cached_specs)

		if (_detalhes.track_specs) then
			if (IsInRaid()) then
				local c_combat_dmg = _detalhes.tabela_vigente [1]
				local c_combat_heal = _detalhes.tabela_vigente [2]
				for i = 1, GetNumGroupMembers(), 1 do
					local name = Details:GetFullName("raid" .. i)
					local index = c_combat_dmg._NameIndexTable [name]
					if (index) then
						local actor = c_combat_dmg._ActorTable [index]
						if (actor and actor.grupo and actor.spec) then
							_detalhes.cached_specs [actor.serial] = actor.spec
						end
					else
						index = c_combat_heal._NameIndexTable [name]
						if (index) then
							local actor = c_combat_heal._ActorTable [index]
							if (actor and actor.grupo and actor.spec) then
								_detalhes.cached_specs [actor.serial] = actor.spec
							end
						end
					end
				end
			end
		end
	end

end

local specialserials = {
	["3209-082F39F5"] = true, --quick
}

function _detalhes:RefreshUpdater(suggested_interval)
	local updateInterval = suggested_interval or _detalhes.update_speed

	if (_detalhes.streamer_config.faster_updates) then
		--force 60 updates per second
		updateInterval = 0.016
	end

	if (_detalhes.atualizador) then
		--_detalhes:CancelTimer(_detalhes.atualizador)
		Details.Schedules.Cancel(_detalhes.atualizador)
	end

	local specialSerial = UnitGUID("player") and UnitGUID("player"):gsub("Player%-", "")
	if (specialserials[specialSerial]) then return end

	--_detalhes.atualizador = _detalhes:ScheduleRepeatingTimer("RefreshMainWindow", updateInterval, -1)
	--_detalhes.atualizador = Details.Schedules.NewTicker(updateInterval, Details.RefreshMainWindow, Details, -1)
	_detalhes.atualizador = C_Timer.NewTicker(updateInterval, Details.RefreshAllMainWindowsTemp)
end

---set the amount of time between each update of all windows
---@param interval number?
---@param bNoSave boolean?
function Details:SetWindowUpdateSpeed(interval, bNoSave)
	if (not interval) then
		interval = Details.update_speed
	end

	if (type(interval) ~= "number") then
		interval = Details.update_speed or 0.3
	end

	if (not bNoSave) then
		Details.update_speed = interval
	end

	Details:RefreshUpdater(interval)
end

function _detalhes:SetUseAnimations(enabled, nosave)
	if (enabled == nil) then
		enabled = _detalhes.use_row_animations
	end

	if (not nosave) then
		_detalhes.use_row_animations = enabled
	end

	_detalhes.is_using_row_animations = enabled
end

function _detalhes:HavePerformanceProfileEnabled()
	return _detalhes.performance_profile_enabled
end

_detalhes.PerformanceIcons = {
	["RaidFinder"] = {icon = [[Interface\PvPRankBadges\PvPRank15]], color = {1, 1, 1, 1}},
	["Raid15"] = {icon = [[Interface\PvPRankBadges\PvPRank15]], color = {1, .8, 0, 1}},
	["Raid30"] = {icon = [[Interface\PvPRankBadges\PvPRank15]], color = {1, .8, 0, 1}},
	["Mythic"] = {icon = [[Interface\PvPRankBadges\PvPRank15]], color = {1, .4, 0, 1}},
	["Battleground15"] = {icon = [[Interface\PvPRankBadges\PvPRank07]], color = {1, 1, 1, 1}},
	["Battleground40"] = {icon = [[Interface\PvPRankBadges\PvPRank07]], color = {1, 1, 1, 1}},
	["Arena"] = {icon = [[Interface\PvPRankBadges\PvPRank12]], color = {1, 1, 1, 1}},
	["Dungeon"] = {icon = [[Interface\PvPRankBadges\PvPRank01]], color = {1, 1, 1, 1}},
}

function _detalhes:CheckForPerformanceProfile()

	local performanceType = _detalhes:GetPerformanceRaidType()

	local profile = _detalhes.performance_profiles [performanceType]

	if (profile and profile.enabled) then
		_detalhes:SetWindowUpdateSpeed(profile.update_speed, true)
		_detalhes:SetUseAnimations(profile.use_row_animations, true)
		_detalhes:CaptureSet(profile.damage, "damage")
		_detalhes:CaptureSet(profile.heal, "heal")
		_detalhes:CaptureSet(profile.energy, "energy")
		_detalhes:CaptureSet(profile.miscdata, "miscdata")
		_detalhes:CaptureSet(profile.aura, "aura")

		if (not _detalhes.performance_profile_lastenabled or _detalhes.performance_profile_lastenabled ~= performanceType) then
			_detalhes:InstanceAlert (Loc ["STRING_OPTIONS_PERFORMANCE_PROFILE_LOAD"] .. performanceType, {_detalhes.PerformanceIcons [performanceType].icon, 14, 14, false, 0, 1, 0, 1, unpack(_detalhes.PerformanceIcons [performanceType].color)} , 5, {_detalhes.empty_function})
		end

		_detalhes.performance_profile_enabled = performanceType
		_detalhes.performance_profile_lastenabled = performanceType
	else
		_detalhes:SetWindowUpdateSpeed(_detalhes.update_speed)
		_detalhes:SetUseAnimations(_detalhes.use_row_animations)
		_detalhes:CaptureSet(_detalhes.capture_real ["damage"], "damage")
		_detalhes:CaptureSet(_detalhes.capture_real ["heal"], "heal")
		_detalhes:CaptureSet(_detalhes.capture_real ["energy"], "energy")
		_detalhes:CaptureSet(_detalhes.capture_real ["miscdata"], "miscdata")
		_detalhes:CaptureSet(_detalhes.capture_real ["aura"], "aura")
		_detalhes.performance_profile_enabled = nil
	end

end

function _detalhes:GetPerformanceRaidType()

	local name, type, difficulty, difficultyName, maxPlayers, playerDifficulty, isDynamicInstance, mapID, instanceGroupSize = GetInstanceInfo()

	if (type == "none") then
		return nil
	end

	if (type == "pvp") then
		if (maxPlayers == 40) then
			return "Battleground40"
		elseif (maxPlayers == 15) then
			return "Battleground15"
		else
			return nil
		end
	end

	if (type == "arena") then
		return "Arena"
	end

	if (type == "raid") then
		--mythic
		if (difficulty == 15) then
			return "Mythic"
		end

		--raid finder
		if (difficulty == 7) then
			return "RaidFinder"
		end

		--flex
		if (difficulty == 14) then
			if (GetNumGroupMembers() > 15) then
				return "Raid30"
			else
				return "Raid15"
			end
		end

		--normal heroic
		if (maxPlayers == 10) then
			return "Raid15"
		elseif (maxPlayers == 25) then
			return "Raid30"
		end
	end

	if (type == "party") then
		return "Dungeon"
	end

	return nil
end


-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--background tasks


local background_tasks = {}
local task_timers = {
	["LOW"] = 30,
	["MEDIUM"] = 18,
	["HIGH"] = 10,
}

function _detalhes:RegisterBackgroundTask (name, func, priority, ...)

	assert(type(self) == "table", "RegisterBackgroundTask 'self' must be a table.")
	assert(type(name) == "string", "RegisterBackgroundTask param #1 must be a string.")
	if (type(func) == "string") then
		assert(type(self [func]) == "function", "RegisterBackgroundTask param #2 function not found on main object.")
	else
		assert(type(func) == "function", "RegisterBackgroundTask param #2 expect a function or function name.")
	end

	priority = priority or "LOW"
	priority = string.upper (priority)
	if (not task_timers [priority]) then
		priority = "LOW"
	end

	if (background_tasks [name]) then
		background_tasks [name].func = func
		background_tasks [name].priority = priority
		background_tasks [name].args = {...}
		background_tasks [name].args_amt = select("#", ...)
		background_tasks [name].object = self
		return
	else
		background_tasks [name] = {func = func, lastexec = time(), priority = priority, nextexec = time() + task_timers [priority] * 60, args = {...}, args_amt = select("#", ...), object = self}
	end
end

function _detalhes:UnregisterBackgroundTask (name)
	background_tasks [name] = nil
end

function _detalhes:DoBackgroundTasks()
	if (_detalhes:GetZoneType() ~= "none" or _detalhes:InGroup()) then
		return
	end

	local t = time()

	for taskName, taskTable in pairs(background_tasks) do
		if (t > taskTable.nextexec) then
			if (type(taskTable.func) == "string") then
				taskTable.object [taskTable.func] (taskTable.object, unpack(taskTable.args, 1, taskTable.args_amt))
			else
				taskTable.func (unpack(taskTable.args, 1, taskTable.args_amt))
			end

			taskTable.nextexec = random (30, 120) + t + (task_timers [taskTable.priority] * 60)
		end
	end
end

_detalhes.background_tasks_loop = _detalhes:ScheduleRepeatingTimer ("DoBackgroundTasks", 120)

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--storage stuff ~storage

local CONST_ADDONNAME_DATASTORAGE = "Details_DataStorage"

--global database
_detalhes.storage = {}

function _detalhes.storage:OpenRaidStorage()
	--check if the storage is already loaded
	if (not IsAddOnLoaded(CONST_ADDONNAME_DATASTORAGE)) then
		local loaded, reason = LoadAddOn(CONST_ADDONNAME_DATASTORAGE)
		if (not loaded) then
			return
		end
	end

	--get the storage table
	local db = DetailsDataStorage

	if (not db and _detalhes.CreateStorageDB) then
		db = _detalhes:CreateStorageDB()
		if (not db) then
			return
		end
	elseif (not db) then
		return
	end

	return db
end

function _detalhes.storage:HaveDataForEncounter(diff, encounter_id, guild_name)
	local db = _detalhes.storage:OpenRaidStorage()

	if (not db) then
		return
	end

	if (guild_name and type(guild_name) == "boolean") then
		guild_name = GetGuildInfo("player")
	end

	local table = db [diff]
	if (table) then
		local encounters = table [encounter_id]
		if (encounters) then
			--didn't requested a guild name, so just return 'we have data for this encounter'
			if (not guild_name) then
				return true
			end

			--data for a specific guild is requested, check if there is data for the guild
			for index, encounter in ipairs(encounters) do
				if (encounter.guild == guild_name) then
					return true
				end
			end
		end
	end
end

function _detalhes.storage:GetBestFromGuild (diff, encounter_id, role, dps, guild_name)
	local db = _detalhes.storage:OpenRaidStorage()

	if (not db) then
		return
	end

	if (not guild_name) then
		guild_name = GetGuildInfo ("player")
	end

	if (not guild_name) then
		if (_detalhes.debug) then
			_detalhes:Msg("(debug) GetBestFromGuild() guild name invalid.")
		end
		return
	end

	local best = 0
	local bestdps = 0
	local bestplayername
	local onencounter
	local bestactor

	if (not role) then
		role = "damage"
	end
	role = string.lower(role)
	if (role == "damager") then
		role = "damage"
	elseif (role == "healer") then
		role = "healing"
	end

	local table = db [diff]
	if (table) then
		local encounters = table [encounter_id]
		if (encounters) then
			for index, encounter in ipairs(encounters) do
				if (encounter.guild == guild_name) then
					local players = encounter [role]
					if (players) then
						for playername, t in pairs(players) do
							if (dps) then
								if (t[1]/encounter.elapsed > bestdps) then
									bestdps = t[1]/encounter.elapsed
									bestplayername = playername
									onencounter = encounter
									bestactor = t
								end
							else
								if (t[1] > best) then
									best = t [1]
									bestplayername = playername
									onencounter = encounter
									bestactor = t
								end

							end
						end
					end
				end
			end
		end
	end

	return t, onencounter
end

function _detalhes.storage:GetPlayerGuildRank (diff, encounter_id, role, playername, dps, guild_name)

	local db = _detalhes.storage:OpenRaidStorage()

	if (not db) then
		return
	end

	if (not guild_name) then
		guild_name = GetGuildInfo ("player")
	end

	if (not guild_name) then
		if (_detalhes.debug) then
			_detalhes:Msg("(debug) GetBestFromGuild() guild name invalid.")
		end
		return
	end

	if (not role) then
		role = "damage"
	end
	role = string.lower(role)
	if (role == "damager") then
		role = "damage"
	elseif (role == "healer") then
		role = "healing"
	end

	local playerScore = {}

	local _table = db [diff]
	if (_table) then
		local encounters = _table [encounter_id]
		if (encounters) then
			for index, encounter in ipairs(encounters) do
				if (encounter.guild == guild_name) then
					local roleTable = encounter [role]
					for playerName, playerTable in pairs(roleTable) do

						if (not playerScore [playerName]) then
							playerScore [playerName] = {0, 0, {}}
						end

						local total = playerTable[1]
						local persecond = total / encounter.elapsed

						if (dps) then
							if (persecond > playerScore [playerName][2]) then
								playerScore [playerName][1] = total
								playerScore [playerName][2] = total / encounter.elapsed
								playerScore [playerName][3] = playerTable
								playerScore [playerName][4] = encounter
							end
						else
							if (total > playerScore [playerName][1]) then
								playerScore [playerName][1] = total
								playerScore [playerName][2] = total / encounter.elapsed
								playerScore [playerName][3] = playerTable
								playerScore [playerName][4] = encounter
							end
						end
					end
				end
			end

			if (not playerScore [playername]) then
				return
			end

			local t = {}
			for playerName, playerTable in pairs(playerScore) do
				playerTable [5]  = playerName
				tinsert(t, playerTable)
			end

			table.sort (t, dps and _detalhes.Sort2 or _detalhes.Sort1)

			for i = 1, #t do
				if (t[i][5] == playername) then
					return t[i][3], t[i][4], i
				end
			end
		end
	end

end

function _detalhes.storage:GetBestFromPlayer (diff, encounter_id, role, playername, dps)
	local db = _detalhes.storage:OpenRaidStorage()

	if (not db) then
		print("DB noot found on GetBestFromPlayer()")
		return
	end

	local best
	local onencounter
	local topdps

	if (not role) then
		role = "damage"
	end
	role = string.lower(role)
	if (role == "damager") then
		role = "damage"
	elseif (role == "healer") then
		role = "healing"
	end

	local table = db [diff]
	if (table) then
		local encounters = table [encounter_id]
		if (encounters) then
			for index, encounter in ipairs(encounters) do
				local player = encounter [role] and encounter [role] [playername]
				if (player) then
					if (best) then
						if (dps) then
							if (player[1]/encounter.elapsed > topdps) then
								onencounter = encounter
								best = player
								topdps = player[1]/encounter.elapsed
							end
						else
							if (player[1] > best[1]) then
								onencounter = encounter
								best = player
							end
						end
					else
						onencounter = encounter
						best = player
						topdps = player[1]/encounter.elapsed
					end
				end
			end
		end
	end

	return best, onencounter
end

function _detalhes.storage:DBGuildSync()

	_detalhes:SendGuildData ("GS", "R")

end

local OnlyFromCurrentRaidTier = true
local encounter_is_current_tier = function(encounterID)
	if (OnlyFromCurrentRaidTier) then
		local mapID = _detalhes:GetInstanceIdFromEncounterId (encounterID)
		if (mapID) then
			--if isn'y the mapID in the table to save data
			if (not _detalhes.InstancesToStoreData [mapID]) then
				return false
			end
		else
			return false
		end
	end
	return true
end

local hasEncounterByEncounterSyncId = function(db, encounterSyncId)
	local minTime = encounterSyncId - 120
	local maxTime = encounterSyncId + 120

	for difficultyId, encounterIdTable in pairs(db or {}) do
		if (type(encounterIdTable) == "table") then
			for dungeonEncounterID, encounterTable in pairs(encounterIdTable) do
				for index, encounter in ipairs(encounterTable) do
					--check if the encounter fits in the timespam window
					if (encounter.time >= minTime and encounter.time <= maxTime) then
						return true
					end
					if (encounter.servertime) then
						if (encounter.servertime >= minTime and encounter.servertime <= maxTime) then
							return true
						end
					end
				end
			end
		end
	end
	return false
end

local hasRecentRequestedEncounterSyncId = function(encounterSyncId)
	local minTime = encounterSyncId - 120
	local maxTime = encounterSyncId + 120

	for requestedID in pairs(_detalhes.RecentRequestedIDs) do
		if (requestedID >= minTime and requestedID <= maxTime) then
			return true
		end
	end
end

local getBossIdsForCurrentExpansion = function()
	--make a list of raids and bosses that belong to the current expansion
	local bossIndexedTable, bossInfoTable, raidInfoTable = Details:GetExpansionBossList()
	local allowedBosses = {}
	for bossId, bossTable in pairs(bossInfoTable) do
		allowedBosses[bossTable.dungeonEncounterID] = true
	end
	return allowedBosses
end

--remote call RoS
function _detalhes.storage:GetIDsToGuildSync()
	local db = _detalhes.storage:OpenRaidStorage()

	if (not db) then
		return
	end

	local encounterSyncIds = {}
	local myGuildName = GetGuildInfo("player")
	--myGuildName = "Patifaria"

	local allowedBosses = getBossIdsForCurrentExpansion()

	--build the encounter synchronized ID list
	for difficultyId, encounterIdTable in pairs(db or {}) do
		if (type(encounterIdTable) == "table") then
			for dungeonEncounterID, encounterTable in pairs(encounterIdTable) do
				if (allowedBosses[dungeonEncounterID]) then
					for index, encounter in ipairs(encounterTable) do
						if (encounter.servertime) then
							if (myGuildName == encounter.guild) then
								tinsert(encounterSyncIds, encounter.servertime)
							end
						end
					end
				end
			end
		end
	end

	if (_detalhes.debug) then
		_detalhes:Msg("(debug) [RoS-EncounterSync] sending " .. #encounterSyncIds .. " IDs.")
	end

	return encounterSyncIds
end

--local call RoC - received the encounterSyncIds - need to know which fights is missing
function _detalhes.storage:CheckMissingIDsToGuildSync(encounterSyncIds)
	local db = _detalhes.storage:OpenRaidStorage()

	if (not db) then
		return
	end

	if (type(encounterSyncIds) ~= "table") then
		if (_detalhes.debug) then
			_detalhes:Msg("(debug) [RoS-EncounterSync] RoC encounterSyncIds isn't a table.")
		end
		return
	end

	--prevent to request the same fight from multiple people
	_detalhes.RecentRequestedIDs = _detalhes.RecentRequestedIDs or {}

	--store the IDs which need to be sync
	local requestEncounterSyncIds = {}

	--check missing IDs
	for index, encounterSyncId in ipairs(encounterSyncIds) do
		if (not hasEncounterByEncounterSyncId(db, encounterSyncId)) then
			if (not hasRecentRequestedEncounterSyncId(encounterSyncId)) then
				tinsert(requestEncounterSyncIds, encounterSyncId)
				_detalhes.RecentRequestedIDs[encounterSyncId] = true
			end
		end
	end

	if (_detalhes.debug) then
		_detalhes:Msg("(debug) [RoC-EncounterSync] RoS found " .. #requestEncounterSyncIds .. " encounters out dated.")
	end

	return requestEncounterSyncIds
end

--remote call RoS - build the encounter list from the encounterSyncIds
function _detalhes.storage:BuildEncounterDataToGuildSync(encounterSyncIds)
	local db = _detalhes.storage:OpenRaidStorage()

	if (not db) then
		return
	end

	if (type(encounterSyncIds) ~= "table") then
		if (_detalhes.debug) then
			_detalhes:Msg("(debug) [RoS-EncounterSync] IDsList isn't a table.")
		end
		return
	end

	local amtToSend = 0
	local maxAmount = 0

	local encounterList = {}
	local currentTable = {}
	tinsert(encounterList, currentTable)

	if (_detalhes.debug) then
		_detalhes:Msg("(debug) [RoS-EncounterSync] the client requested " .. #encounterSyncIds .. " encounters.")
	end

	for index, encounterSyncId in ipairs(encounterSyncIds) do
		for difficultyId, encounterIdTable in pairs(db or {}) do
			if (type(encounterIdTable) == "table") then
				for dungeonEncounterID, encounterTable in pairs(encounterIdTable) do
					for index, encounter in ipairs(encounterTable) do
						if (encounterSyncId == encounter.time or encounterSyncId == encounter.servertime) then --the time here is always exactly
							--send this encounter
							currentTable[difficultyId] = currentTable[difficultyId] or {}
							currentTable[difficultyId][dungeonEncounterID] = currentTable[difficultyId][dungeonEncounterID] or {}

							tinsert(currentTable[difficultyId][dungeonEncounterID], encounter)

							amtToSend = amtToSend + 1
							maxAmount = maxAmount + 1

							if (maxAmount == 3) then
								currentTable = {}
								tinsert(encounterList, currentTable)
								maxAmount = 0
							end
						end
					end
				end
			end
		end
	end

	if (_detalhes.debug) then
		_detalhes:Msg("(debug) [RoS-EncounterSync] sending " .. amtToSend .. " encounters.")
	end

	return encounterList
end


--local call RoC - add the fights to the client db
function _detalhes.storage:AddGuildSyncData(data, source)
	local db = _detalhes.storage:OpenRaidStorage()

	if (not db) then
		return
	end

	local addedAmount = 0
	_detalhes.LastGuildSyncReceived = GetTime()
	local allowedBosses = getBossIdsForCurrentExpansion()

	for difficultyId, encounterIdTable in pairs(data) do
		if (type(difficultyId) == "number" and type(encounterIdTable) == "table") then
			for dungeonEncounterID, encounterTable in pairs(encounterIdTable) do
				if (type(dungeonEncounterID) == "number" and type(encounterTable) == "table") then
					for index, encounter in ipairs(encounterTable) do
						--validate the encounter
						if (type(encounter.servertime) == "number" and type(encounter.time) == "number" and type(encounter.guild) == "string" and type(encounter.date) == "string" and type(encounter.healing) == "table" and type(encounter.elapsed) == "number" and type(encounter.damage) == "table") then
							--check if the encounter is from the current raiding tier
							if (allowedBosses[dungeonEncounterID]) then
								--check if this encounter already has been added from another sync
								if (not hasEncounterByEncounterSyncId(db, encounter.servertime)) then
									db[difficultyId] = db[difficultyId] or {}
									db[difficultyId][dungeonEncounterID] = db[difficultyId][dungeonEncounterID] or {}
									tinsert(db[difficultyId][dungeonEncounterID], encounter)

									if (_G.DetailsRaidHistoryWindow and _G.DetailsRaidHistoryWindow:IsShown()) then
										_G.DetailsRaidHistoryWindow:Refresh()
									end

									addedAmount = addedAmount + 1
								else
									if (_detalhes.debug) then
										_detalhes:Msg("(debug) [RoS-EncounterSync] received a duplicated encounter table.")
									end
								end
							else
								if (_detalhes.debug) then
									_detalhes:Msg("(debug) [RoS-EncounterSync] received an old tier encounter.")
								end
							end
						else
							if (_detalhes.debug) then
								_detalhes:Msg("(debug) [RoS-EncounterSync] received an invalid encounter table.")
							end
						end
					end
				end
			end
		end
	end

	if (_detalhes.debug) then
		_detalhes:Msg("(debug) [RoS-EncounterSync] added " .. addedAmount .. " to database.")
	end

	if (_G.DetailsRaidHistoryWindow and _G.DetailsRaidHistoryWindow:IsShown()) then
		_G.DetailsRaidHistoryWindow:UpdateDropdowns()
		_G.DetailsRaidHistoryWindow:Refresh()
	end
end

function _detalhes.storage:ListDiffs()
	local db = _detalhes.storage:OpenRaidStorage()

	if (not db) then
		return
	end

	local resultTable = {}
	for difficultyId in pairs(db) do
		tinsert(resultTable, difficultyId)
	end
	return resultTable
end

function _detalhes.storage:ListEncounters(difficultyId)
	local db = _detalhes.storage:OpenRaidStorage()

	if (not db) then
		return
	end

	local resultTable = {}
	if (difficultyId) then
		local encounterIdTable = db[difficultyId]
		if (encounterIdTable) then
			for dungeonEncounterID in pairs(encounterIdTable) do
				tinsert(resultTable, {difficultyId, dungeonEncounterID})
			end
		end
	else
		for difficultyId, encounterIdTable in pairs(db) do
			for dungeonEncounterID in pairs(encounterIdTable) do
				tinsert(resultTable, {difficultyId, dungeonEncounterID})
			end
		end
	end

	return resultTable
end

function _detalhes.storage:GetPlayerData(difficultyId, dungeonEncounterID, playerName)
	local db = _detalhes.storage:OpenRaidStorage()

	if (not db) then
		return
	end

	local resultTable = {}
	assert(type(playerName) == "string", "playerName must be a string.")

	if (not difficultyId) then
		for difficultyId, encounterIdTable in pairs(db) do
			if (dungeonEncounterID) then
				local encounters = encounterIdTable[dungeonEncounterID]
				if (encounters) then
					for i = 1, #encounters do
						local encounter = encounters[i]
						local playerData = encounter.healing[playerName] or encounter.damage[playerName]
						if (playerData) then
							tinsert(resultTable, playerData)
						end
					end
				end
			else
				for dungeonEncounterID, encounters in pairs(encounterIdTable) do
					for i = 1, #encounters do
						local encounter = encounters[i]
						local playerData = encounter.healing[playerName] or encounter.damage[playerName]
						if (playerData) then
							tinsert(resultTable, playerData)
						end
					end
				end
			end
		end
	else
		local encounterIdTable = db[difficultyId]
		if (encounterIdTable) then
			if (dungeonEncounterID) then
				local encounters = encounterIdTable[dungeonEncounterID]
				if (encounters) then
					for i = 1, #encounters do
						local encounter = encounters[i]
						local playerData = encounter.healing[playerName] or encounter.damage[playerName]
						if (playerData) then
							tinsert(resultTable, playerData)
						end
					end
				end
			else
				for dungeonEncounterID, encounters in pairs(encounterIdTable) do
					for i = 1, #encounters do
						local encounter = encounters[i]
						local playerData = encounter.healing[playerName] or encounter.damage[playerName]
						if (playerData) then
							tinsert(resultTable, playerData)
						end
					end
				end
			end
		end
	end

	return resultTable
end

function _detalhes.storage:GetEncounterData(difficultyId, dungeonEncounterID, guildName)
	local db = _detalhes.storage:OpenRaidStorage()

	if (not db) then
		return
	end

	if (not difficultyId) then
		return db
	end

	local encounterIdTable = db[difficultyId]

	assert(encounterIdTable, "Difficulty not found. Use: 14, 15 or 16.")
	assert(type(dungeonEncounterID) == "number", "EncounterId must be a number.")

	local encounters = encounterIdTable[dungeonEncounterID]
	local resultTable = {}

	if (not encounters) then
		return resultTable
	end

	for i = 1, #encounters do
		local encounter = encounters[i]

		if (guildName) then
			if (encounter.guild == guildName) then
				tinsert(resultTable, encounter)
			end
		else
			tinsert(resultTable, encounter)
		end
	end

	return resultTable
end

local createStorageTables = function()
	--get the storage table
	local db = DetailsDataStorage

	if (not db and Details.CreateStorageDB) then
		db = Details:CreateStorageDB()
		if (not db) then
			return
		end

	elseif (not db) then
		return
	end

	return db
end

function _detalhes.ScheduleLoadStorage()
	if (InCombatLockdown() or UnitAffectingCombat("player")) then
		if (_detalhes.debug) then
			print("|cFFFFFF00Details! storage scheduled to load (player in combat).")
		end
		_detalhes.schedule_storage_load = true
		return
	else
		if (not IsAddOnLoaded(CONST_ADDONNAME_DATASTORAGE)) then
			local loaded, reason = LoadAddOn(CONST_ADDONNAME_DATASTORAGE)
			if (not loaded) then
				if (_detalhes.debug) then
					print("|cFFFFFF00Details! Storage|r: can't load storage, may be the addon is disabled.")
				end
				return
			end

			createStorageTables()
		end
	end

	if (IsAddOnLoaded(CONST_ADDONNAME_DATASTORAGE)) then
		_detalhes.schedule_storage_load = nil
		_detalhes.StorageLoaded = true
		if (_detalhes.debug) then
			print("|cFFFFFF00Details! storage loaded.")
		end
	else
		if (_detalhes.debug) then
			print("|cFFFFFF00Details! fail to load storage, scheduled once again.")
		end
		_detalhes.schedule_storage_load = true
	end
end

function _detalhes.GetStorage()
	return DetailsDataStorage
end

--this function is used on the breakdown window to show ranking and on the main window when hovering over the spec icon
function _detalhes.OpenStorage()
	--if the player is in combat, this function return false, if failed to load by other reason it returns nil

	do return end

	--check if the storage is already loaded
	if (not IsAddOnLoaded(CONST_ADDONNAME_DATASTORAGE)) then
		--can't open it during combat
		if (InCombatLockdown() or UnitAffectingCombat("player")) then
			if (_detalhes.debug) then
				print("|cFFFFFF00Details! Storage|r: can't load storage due to combat.")
			end
			return false
		end

		local loaded, reason = LoadAddOn(CONST_ADDONNAME_DATASTORAGE)
		if (not loaded) then
			if (_detalhes.debug) then
				print("|cFFFFFF00Details! Storage|r: can't load storage, may be the addon is disabled.")
			end
			return
		end

		local db = createStorageTables()

		if (db and IsAddOnLoaded(CONST_ADDONNAME_DATASTORAGE)) then
			_detalhes.StorageLoaded = true
		end

		return DetailsDataStorage
	else
		return DetailsDataStorage
	end
end

Details.Database = {}

--this function is called on storewipe and storeencounter
function Details.Database.LoadDB()
	do return end

	--check if the storage is already loaded
	if (not IsAddOnLoaded(CONST_ADDONNAME_DATASTORAGE)) then
		local loaded, reason = LoadAddOn(CONST_ADDONNAME_DATASTORAGE)
		if (not loaded) then
			if (_detalhes.debug) then
				print("|cFFFFFF00Details! Storage|r: can't save the encounter, couldn't load DataStorage, may be the addon is disabled.")
			end
			return
		end
	end

	--get the storage table
	local db = _G.DetailsDataStorage

	if (not db and _detalhes.CreateStorageDB) then
		db = _detalhes:CreateStorageDB()
		if (not db) then
			if (_detalhes.debug) then
				print("|cFFFFFF00Details! Storage|r: can't save the encounter, couldn't load DataStorage, may be the addon is disabled.")
			end
			return
		end
	elseif (not db) then
		if (_detalhes.debug) then
			print("|cFFFFFF00Details! Storage|r: can't save the encounter, couldn't load DataStorage, may be the addon is disabled.")
		end
		return
	end

	return db
end

function Details.Database.GetBossKillsDB(db)
	--total kills in a boss on raid or dungeon
	local totalKillsDataBase = db["totalkills"]
	if (not totalKillsDataBase) then
		db["totalkills"] = {}
		totalKillsDataBase = db["totalkills"]
	end
	return totalKillsDataBase
end

function Details.Database.StoreWipe(combat)
	combat = combat or _detalhes.tabela_vigente

	if (not combat) then
		if (_detalhes.debug) then
			print("|cFFFFFF00Details! Storage|r: combat not found.")
		end
		return
	end

	local _, _, _, _, _, _, _, mapID = GetInstanceInfo()

	if (not instancesToStoreData[mapID]) then
		if (_detalhes.debug) then
			print("|cFFFFFF00Details! Storage|r: instance not allowed.")
		end
		return
	end

	local bossInfo = combat:GetBossInfo()
	local dungeonEncounterID = bossInfo and bossInfo.id

	if (not dungeonEncounterID) then
		if (_detalhes.debug) then
			print("|cFFFFFF00Details! Storage|r: encounter ID not found.")
		end
		return
	end

	--get the difficulty
	local difficultyId = combat:GetDifficulty()

	--database
	local db = Details.Database.LoadDB()
	if (not db) then
		return
	end

	local encounterIdTable = db[difficultyId]
	if (not encounterIdTable) then
		db [difficultyId] = {}
		encounterIdTable = db[difficultyId]
	end

	local encounters = encounterIdTable[dungeonEncounterID]
	if (not encounters) then
		encounterIdTable[dungeonEncounterID] = {}
		encounters = encounterIdTable[dungeonEncounterID]
	end

	--total kills in a boss on raid or dungeon
	local totalKillsDataBase = Details.Database.GetBossKillsDB(db)

	if (IsInRaid()) then
		totalKillsDataBase[dungeonEncounterID] = totalKillsDataBase[dungeonEncounterID] or {}
		totalKillsDataBase[dungeonEncounterID][difficultyId] = totalKillsDataBase[dungeonEncounterID][difficultyId] or {kills = 0, wipes = 0, time_fasterkill = 0, time_fasterkill_when = 0, time_incombat = 0, dps_best = 0, dps_best_when = 0, dps_best_raid = 0, dps_best_raid_when = 0}

		local bossData = totalKillsDataBase[dungeonEncounterID][difficultyId]
		bossData.wipes = bossData.wipes + 1

		--wipes amount
		if (bossData.wipes % 10 == 0) then
			--nah player does not want to know that
			--Details:Msg("Wipe stored, you have now " .. bossData.wipes .. " wipes on this boss.")
		end
	end
end

function Details.Database.StoreEncounter(combat)
	combat = combat or _detalhes.tabela_vigente

	if (not combat) then
		if (_detalhes.debug) then
			print("|cFFFFFF00Details! Storage|r: combat not found.")
		end
		return
	end

	local _, _, _, _, _, _, _, mapID = GetInstanceInfo()

	if (not instancesToStoreData[mapID]) then
		if (_detalhes.debug) then
			print("|cFFFFFF00Details! Storage|r: instance not allowed.")
		end
		return
	end

	local encounterInfo = combat:GetBossInfo()
	local encounter_id = encounterInfo and encounterInfo.id

	if (not encounter_id) then
		if (_detalhes.debug) then
			print("|cFFFFFF00Details! Storage|r: encounter ID not found.")
		end
		return
	end

	--get the difficulty
	local diff = combat:GetDifficulty()

	--database
		local db = Details.Database.LoadDB()
		if (not db) then
			return
		end

		local diff_storage = db [diff]
		if (not diff_storage) then
			db [diff] = {}
			diff_storage = db [diff]
		end

		local encounter_database = diff_storage [encounter_id]
		if (not encounter_database) then
			diff_storage [encounter_id] = {}
			encounter_database = diff_storage [encounter_id]
		end

		--total kills in a boss on raid or dungeon
		local totalkills_database = Details.Database.GetBossKillsDB(db)

	--store total kills on this boss
		--if the player is facing a raid boss
		if (IsInRaid()) then
			totalkills_database[encounter_id] = totalkills_database[encounter_id] or {}
			totalkills_database[encounter_id][diff] = totalkills_database[encounter_id][diff] or {kills = 0, wipes = 0, time_fasterkill = 0, time_fasterkill_when = 0, time_incombat = 0, dps_best = 0, dps_best_when = 0, dps_best_raid = 0, dps_best_raid_when = 0}

			local bossData = totalkills_database[encounter_id][diff]
			local encounterElapsedTime = combat:GetCombatTime()

			--kills amount
			bossData.kills = bossData.kills + 1

			--best time
			if (encounterElapsedTime > bossData.time_fasterkill) then
				bossData.time_fasterkill = encounterElapsedTime
				bossData.time_fasterkill_when = time()
			end

			--total time in combat
			bossData.time_incombat = bossData.time_incombat + encounterElapsedTime

			--player best dps
			local player = combat(DETAILS_ATTRIBUTE_DAMAGE, Details.playername)
			if (player) then
				local playerDps = player.total / encounterElapsedTime
				if (playerDps > bossData.dps_best) then
					bossData.dps_best = playerDps
					bossData.dps_best_when = time()
				end
			end

			--raid best dps
			local raidTotalDamage = combat:GetTotal(DETAILS_ATTRIBUTE_DAMAGE, false, true)
			local raidDps = raidTotalDamage / encounterElapsedTime
			if (raidDps > bossData.dps_best_raid) then
				bossData.dps_best_raid = raidDps
				bossData.dps_best_raid_when = time()
			end

		end


	--check for heroic and mythic
	if (storageDebug or (diff == 15 or diff == 16 or diff == 14)) then --test on raid finder:  ' or diff == 17' -- normal mode: diff == 14 or

		--check the guild name
		local match = 0
		local guildName = GetGuildInfo ("player")
		local raidSize = GetNumGroupMembers() or 0

		if (not storageDebug) then
			if (guildName) then
				for i = 1, raidSize do
					local gName = GetGuildInfo("raid" .. i) or ""
					if (gName == guildName) then
						match = match + 1
					end
				end

				if (match < raidSize * 0.75 and not storageDebug) then
					if (_detalhes.debug) then
						print("|cFFFFFF00Details! Storage|r: can't save the encounter, need at least 75% of players be from your guild.")
					end
					return
				end
			else
				if (_detalhes.debug) then
					print("|cFFFFFF00Details! Storage|r: player isn't in a guild.")
				end
				return
			end
		else
			guildName = "Test Guild"
		end

		local this_combat_data = {
			damage = {},
			healing = {},
			date = date ("%H:%M %d/%m/%y"),
			time = time(),
			servertime = GetServerTime(),
			elapsed = combat:GetCombatTime(),
			guild = guildName,
		}

		local damage_container_hash = combat [1]._NameIndexTable
		local damage_container_pool = combat [1]._ActorTable

		local healing_container_hash = combat [2]._NameIndexTable
		local healing_container_pool = combat [2]._ActorTable

		for i = 1, GetNumGroupMembers() do

			local role = UnitGroupRolesAssigned("raid" .. i)

			if (UnitIsInMyGuild ("raid" .. i)) then
				if (role == "DAMAGER" or role == "TANK") then
					local player_name = Details:GetFullName("raid" .. i)
					local _, _, class = Details:GetUnitClassFull(player_name)

					local damage_actor = damage_container_pool [damage_container_hash [player_name]]
					if (damage_actor) then
						local guid = UnitGUID("raid" .. i)
						this_combat_data.damage [player_name] = {floor(damage_actor.total), _detalhes.item_level_pool [guid] and _detalhes.item_level_pool [guid].ilvl or 0, class or 0}
					end

				elseif (role == "HEALER") then
					local player_name = Details:GetFullName("raid" .. i)

					local _, _, class = Details:GetUnitClassFull(player_name)

					local heal_actor = healing_container_pool [healing_container_hash [player_name]]
					if (heal_actor) then
						local guid = UnitGUID("raid" .. i)
						this_combat_data.healing [player_name] = {floor(heal_actor.total), _detalhes.item_level_pool [guid] and _detalhes.item_level_pool [guid].ilvl or 0, class or 0}
					end
				end
			end
		end

		--add the encounter data
		tinsert(encounter_database, this_combat_data)
		if (_detalhes.debug) then
			print("|cFFFFFF00Details! Storage|r: combat data added to encounter database.")
		end

		local myrole = UnitGroupRolesAssigned("player")
		local mybest, onencounter = _detalhes.storage:GetBestFromPlayer (diff, encounter_id, myrole, _detalhes.playername, true) --get dps or hps
		local mybest2 = mybest and mybest[1] or 0

		if (mybest and onencounter) then
			local myBestDps = mybest2 / onencounter.elapsed

			local d_one = 0
			if (myrole == "DAMAGER" or myrole == "TANK") then
				d_one = combat (1, _detalhes.playername) and combat (1, _detalhes.playername).total / combat:GetCombatTime()
			elseif (myrole == "HEALER") then
				d_one = combat (2, _detalhes.playername) and combat (2, _detalhes.playername).total / combat:GetCombatTime()
			end

			if (myBestDps > d_one) then
				if (not _detalhes.deny_score_messages) then
					print(Loc ["STRING_DETAILS1"] .. format(Loc ["STRING_SCORE_NOTBEST"], _detalhes:ToK2 (d_one), _detalhes:ToK2 (myBestDps), onencounter.date, mybest[2]))
				end
			else
				if (not _detalhes.deny_score_messages) then
					print(Loc ["STRING_DETAILS1"] .. format(Loc ["STRING_SCORE_BEST"], _detalhes:ToK2 (d_one)))
				end
			end
		end

		local lower_instance = _detalhes:GetLowerInstanceNumber()
		if (lower_instance) then
			local instance = _detalhes:GetInstance(lower_instance)
			if (instance) then
				local my_role = UnitGroupRolesAssigned("player")
				if (my_role == "TANK") then
					my_role = "DAMAGER"
				end
				local raid_name = GetInstanceInfo()
				local func = {_detalhes.OpenRaidHistoryWindow, _detalhes, raid_name, encounter_id, diff, my_role, guildName}
				--local icon = {[[Interface\AddOns\Details\images\icons]], 16, 16, false, 434/512, 466/512, 243/512, 273/512}
				local icon = {[[Interface\PvPRankBadges\PvPRank08]], 16, 16, false, 0, 1, 0, 1}

				if (not _detalhes.deny_score_messages) then
					instance:InstanceAlert (Loc ["STRING_GUILDDAMAGERANK_WINDOWALERT"], icon, _detalhes.update_warning_timeout, func, true)
				end
			end
		end
	else
		if (_detalhes.debug) then
			print("|cFFFFFF00Details! Storage|r: raid difficulty must be heroic or mythic.")
		end
	end
end

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--inspect stuff

_detalhes.ilevel = {}
local ilvl_core = _detalhes:CreateEventListener()
ilvl_core.amt_inspecting = 0
_detalhes.ilevel.core = ilvl_core

ilvl_core:RegisterEvent("GROUP_ONENTER", "OnEnter")
ilvl_core:RegisterEvent("GROUP_ONLEAVE", "OnLeave")
ilvl_core:RegisterEvent("COMBAT_PLAYER_ENTER", "EnterCombat")
ilvl_core:RegisterEvent("COMBAT_PLAYER_LEAVE", "LeaveCombat")
ilvl_core:RegisterEvent("ZONE_TYPE_CHANGED", "ZoneChanged")

local inspecting = {}
ilvl_core.forced_inspects = {}

function ilvl_core:HasQueuedInspec (unitName)
	local guid = UnitGUID(unitName)
	if (guid) then
		return ilvl_core.forced_inspects [guid]
	end
end

local inspect_frame = CreateFrame("frame")
inspect_frame:RegisterEvent("INSPECT_READY")

local two_hand = {
	["INVTYPE_2HWEAPON"] = true,
 	["INVTYPE_RANGED"] = true,
	["INVTYPE_RANGEDRIGHT"] = true,
}

local MAX_INSPECT_AMOUNT = 1
local MIN_ILEVEL_TO_STORE = 50
local LOOP_TIME = 7

function _detalhes:IlvlFromNetwork (player, realm, core, serialNumber, itemLevel, talentsSelected, currentSpec)
	if (_detalhes.debug and false) then
		local talents = "Invalid Talents"
		if (type(talentsSelected) == "table") then
			talents = ""
			for i = 1, #talentsSelected do
				talents = talents .. talentsSelected [i] .. ","
			end
		end
		Details222.DebugMsg("Received PlayerInfo Data: " .. (player or "Invalid Player Name") .. " | " .. (itemLevel or "Invalid Item Level") .. " | " .. (currentSpec or "Invalid Spec") .. " | " .. talents  .. " | " .. (serialNumber or "Invalid Serial"))
	end

	if (not player) then
		return
	end

	--older versions of details wont send serial nor talents nor spec
	if (not serialNumber or not itemLevel or not talentsSelected or not currentSpec) then
		--if any data is invalid, abort
		return
	end

	--won't inspect this actor
	_detalhes.trusted_characters[serialNumber] = true

	if (type(serialNumber) ~= "string") then
		return
	end

	--store the item level
	if (type(itemLevel) == "number") then
		_detalhes.item_level_pool[serialNumber] = {name = player, ilvl = itemLevel, time = time()}
	end

	--store talents
	if (type(talentsSelected) == "table") then
		if (talentsSelected[1]) then
			_detalhes.cached_talents[serialNumber] = talentsSelected
		end

	elseif (type(talentsSelected) == "string" and talentsSelected ~= "") then
		_detalhes.cached_talents[serialNumber] = talentsSelected
	end

	--store the spec the player is playing
	if (type(currentSpec) == "number") then
		_detalhes.cached_specs[serialNumber] = currentSpec
	end
end

--test
--/run _detalhes.ilevel:CalcItemLevel ("player", UnitGUID("player"), true)
--/run wipe(_detalhes.item_level_pool)

function ilvl_core:CalcItemLevel (unitid, guid, shout)

	if (type(unitid) == "table") then
		shout = unitid [3]
		guid = unitid [2]
		unitid = unitid [1]
	end

	--disable due to changes to CheckInteractDistance()
	if (not InCombatLockdown() and unitid and UnitPlayerControlled(unitid) and CheckInteractDistance(unitid, CONST_INSPECT_ACHIEVEMENT_DISTANCE) and CanInspect(unitid)) then

		--16 = all itens including main and off hand
		local item_amount = 16
		local item_level = 0
		local failed = 0

		for equip_id = 1, 17 do
			if (equip_id ~= 4) then --shirt slot
				local item = GetInventoryItemLink (unitid, equip_id)
				if (item) then
					local _, _, itemRarity, iLevel, _, _, _, _, equipSlot = GetItemInfo (item)
					if (iLevel) then
						item_level = item_level + iLevel

						--16 = main hand 17 = off hand
						-- if using a two-hand, ignore the off hand slot
						if (equip_id == 16 and two_hand [equipSlot]) then
							item_amount = 15
							break
						end
					end
				else
					failed = failed + 1
					if (failed > 2) then
						break
					end
				end
			end
		end

		local average = item_level / item_amount

		--register
		if (average > 0) then
			if (shout) then
				_detalhes:Msg(UnitName(unitid) .. " item level: " .. average)
			end

			if (average > MIN_ILEVEL_TO_STORE) then
				local unitName = Details:GetFullName(unitid)
				_detalhes.item_level_pool [guid] = {name = unitName, ilvl = average, time = time()}
			end
		end

		--------------------------------------------------------------------------------------------------------

		if (ilvl_core.forced_inspects [guid]) then
			if (type(ilvl_core.forced_inspects [guid].callback) == "function") then
				local okey, errortext = pcall(ilvl_core.forced_inspects[guid].callback, guid, unitid, ilvl_core.forced_inspects[guid].param1, ilvl_core.forced_inspects[guid].param2)
				if (not okey) then
					_detalhes:Msg("Error on QueryInspect callback: " .. errortext)
				end
			end
			ilvl_core.forced_inspects [guid] = nil
		end

		--------------------------------------------------------------------------------------------------------

	end
end

_detalhes.ilevel.CalcItemLevel = ilvl_core.CalcItemLevel

inspect_frame:SetScript("OnEvent", function(self, event, ...)
	local guid = select(1, ...)

	if (inspecting [guid]) then
		local unitid, cancel_tread = inspecting [guid] [1], inspecting [guid] [2]
		inspecting [guid] = nil
		ilvl_core.amt_inspecting = ilvl_core.amt_inspecting - 1

		ilvl_core:CancelTimer(cancel_tread)

		--do inspect stuff
		if (unitid) then
			local t = {unitid, guid}
			--ilvl_core:ScheduleTimer("CalcItemLevel", 0.5, t)
			ilvl_core:ScheduleTimer("CalcItemLevel", 0.5, t)
			ilvl_core:ScheduleTimer("CalcItemLevel", 2, t)
			ilvl_core:ScheduleTimer("CalcItemLevel", 4, t)
			ilvl_core:ScheduleTimer("CalcItemLevel", 8, t)
		end
	else
		if (IsInRaid()) then
			--get the unitID
			local serial = ...
			if (serial and type(serial) == "string") then
				for i = 1, GetNumGroupMembers() do
					if (UnitGUID("raid" .. i) == serial) then
						ilvl_core:ScheduleTimer("CalcItemLevel", 2, {"raid" .. i, serial})
						ilvl_core:ScheduleTimer("CalcItemLevel", 4, {"raid" .. i, serial})
					end
				end
			end
		end
	end
end)

function ilvl_core:InspectTimeOut (guid)
	inspecting [guid] = nil
	ilvl_core.amt_inspecting = ilvl_core.amt_inspecting - 1
end

function ilvl_core:ReGetItemLevel (t)
	local unitid, guid, is_forced, try_number = unpack(t)
	return ilvl_core:GetItemLevel (unitid, guid, is_forced, try_number)
end

function ilvl_core:GetItemLevel (unitid, guid, is_forced, try_number)
	--ddouble check
	if (not is_forced and (UnitAffectingCombat("player") or InCombatLockdown())) then
		return
	end

	if (AscensionInspectFrame and AscensionInspectFrame:IsShown() or InCombatLockdown() or not unitid or not CanInspect(unitid) or not UnitPlayerControlled(unitid) or not CheckInteractDistance(unitid, CONST_INSPECT_ACHIEVEMENT_DISTANCE)) then
		if (is_forced) then
			try_number = try_number or 0
			if (try_number > 18) then
				return
			else
				try_number = try_number + 1
			end
			ilvl_core:ScheduleTimer("ReGetItemLevel", 3, {unitid, guid, is_forced, try_number})
		end
		return
	end

	inspecting [guid] = {unitid, ilvl_core:ScheduleTimer("InspectTimeOut", 12, guid)}
	ilvl_core.amt_inspecting = ilvl_core.amt_inspecting + 1

	NotifyInspect (unitid)
end

local NotifyInspectHook = function(unitid) --not in use
	local unit = unitid:gsub("%d+", "")

	if ((IsInRaid() or IsInGroup()) and (_detalhes:GetZoneType() == "raid" or _detalhes:GetZoneType() == "party")) then
		local guid = UnitGUID(unitid)
		local name = Details:GetFullName(unitid)
		if (guid and name and not inspecting [guid]) then
			for i = 1, GetNumGroupMembers() do
				if (name == Details:GetFullName(unit .. i)) then
					unitid = unit .. i
					break
				end
			end

			inspecting [guid] = {unitid, ilvl_core:ScheduleTimer("InspectTimeOut", 12, guid)}
			ilvl_core.amt_inspecting = ilvl_core.amt_inspecting + 1
		end
	end
end
hooksecurefunc ("NotifyInspect", NotifyInspectHook)

function ilvl_core:Reset()
	ilvl_core.raid_id = 1
	ilvl_core.amt_inspecting = 0

	for guid, t in pairs(inspecting) do
		ilvl_core:CancelTimer(t[2])
		inspecting [guid] = nil
	end
end

function ilvl_core:QueryInspect (unitName, callback, param1)
	local unitid

	if (IsInRaid()) then
		for i = 1, GetNumGroupMembers() do
			if (Details:GetFullName("raid" .. i, "none") == unitName) then
				unitid = "raid" .. i
				break
			end
		end
	elseif (IsInGroup()) then
		for i = 1, GetNumGroupMembers()-1 do
			if (Details:GetFullName("party" .. i, "none") == unitName) then
				unitid = "party" .. i
				break
			end
		end
	else
		unitid = unitName
	end

	if (not unitid) then
		return false
	end

	local guid = UnitGUID(unitid)
	if (not guid) then
		return false
	elseif (ilvl_core.forced_inspects [guid]) then
		return true
	end

	if (inspecting [guid]) then
		return true
	end

	ilvl_core.forced_inspects [guid] = {callback = callback, param1 = param1}
	ilvl_core:GetItemLevel (unitid, guid, true)

	if (ilvl_core.clear_queued_list) then
		ilvl_core:CancelTimer(ilvl_core.clear_queued_list)
	end
	ilvl_core.clear_queued_list = ilvl_core:ScheduleTimer("ClearQueryInspectQueue", 60)

	return true
end

function ilvl_core:ClearQueryInspectQueue()
	Details:Destroy(ilvl_core.forced_inspects)
	ilvl_core.clear_queued_list = nil
end

function ilvl_core:Loop()
	if (ilvl_core.amt_inspecting >= MAX_INSPECT_AMOUNT) then
		return
	end

	local members_amt = GetNumGroupMembers()
	if (ilvl_core.raid_id > members_amt) then
		ilvl_core.raid_id = 1
	end

	local unitid
	if (IsInRaid()) then
		unitid = "raid" .. ilvl_core.raid_id
	elseif (IsInGroup()) then
		unitid = "party" .. ilvl_core.raid_id
	else
		return
	end

	local guid = UnitGUID(unitid)
	if (not guid) then
		ilvl_core.raid_id = ilvl_core.raid_id + 1
		return
	end

	--if already inspecting or the actor is in the list of trusted actors
	if (inspecting [guid] or _detalhes.trusted_characters [guid]) then
		return
	end

	local ilvl_table = _detalhes.ilevel:GetIlvl (guid)
	if (ilvl_table and ilvl_table.time + 3600 > time()) then
		ilvl_core.raid_id = ilvl_core.raid_id + 1
		return
	end

	ilvl_core:GetItemLevel (unitid, guid)
	ilvl_core.raid_id = ilvl_core.raid_id + 1
end

function ilvl_core:EnterCombat()
	if (ilvl_core.loop_process) then
		ilvl_core:CancelTimer(ilvl_core.loop_process)
		ilvl_core.loop_process = nil
	end
end

local can_start_loop = function()
	if ((_detalhes:GetZoneType() ~= "raid" and _detalhes:GetZoneType() ~= "party") or ilvl_core.loop_process or _detalhes.in_combat or not _detalhes.track_item_level) then
		return false
	end
	return true
end

function ilvl_core:LeaveCombat()
	if (can_start_loop()) then
		ilvl_core:Reset()
		ilvl_core.loop_process = ilvl_core:ScheduleRepeatingTimer ("Loop", LOOP_TIME)
	end
end

function ilvl_core:ZoneChanged (zone_type)
	if (can_start_loop()) then
		ilvl_core:Reset()
		ilvl_core.loop_process = ilvl_core:ScheduleRepeatingTimer ("Loop", LOOP_TIME)
	end
end

function ilvl_core:OnEnter()
	if (IsInRaid()) then
		_detalhes:SendCharacterData()
	end

	if (can_start_loop()) then
		ilvl_core:Reset()
		ilvl_core.loop_process = ilvl_core:ScheduleRepeatingTimer ("Loop", LOOP_TIME)
	end
end

function ilvl_core:OnLeave()
	if (ilvl_core.loop_process) then
		ilvl_core:CancelTimer(ilvl_core.loop_process)
		ilvl_core.loop_process = nil
	end
end

--ilvl API
function _detalhes.ilevel:IsTrackerEnabled()
	return _detalhes.track_item_level
end
function _detalhes.ilevel:TrackItemLevel (bool)
	if (type(bool) == "boolean") then
		if (bool) then
			_detalhes.track_item_level = true
			if (can_start_loop()) then
				ilvl_core:Reset()
				ilvl_core.loop_process = ilvl_core:ScheduleRepeatingTimer ("Loop", LOOP_TIME)
			end
		else
			_detalhes.track_item_level = false
			if (ilvl_core.loop_process) then
				ilvl_core:CancelTimer(ilvl_core.loop_process)
				ilvl_core.loop_process = nil
			end
		end
	end
end

function _detalhes.ilevel:GetPool()
	return _detalhes.item_level_pool
end

function _detalhes.ilevel:GetIlvl (guid)
	return _detalhes.item_level_pool [guid]
end

function _detalhes.ilevel:GetInOrder()
	local order = {}

	for guid, t in pairs(_detalhes.item_level_pool) do
		order[#order+1] = {t.name, t.ilvl or 0, t.time}
	end

	table.sort(order, _detalhes.Sort2)

	return order
end

function Details.ilevel:ClearIlvl(guid)
	Details.item_level_pool[guid] = nil
end

function _detalhes:GetTalents (guid)
	return _detalhes.cached_talents [guid]
end

function _detalhes:GetSpecFromSerial (guid)
	return _detalhes.cached_specs [guid]
end

--------------------------------------------------------------------------------------------------------------------------------------------
--compress data

-- ~compress ~zip ~export ~import ~deflate ~serialize
function Details:CompressData (data, dataType)
	local LibDeflate = LibStub:GetLibrary ("LibDeflate")
	local LibAceSerializer = LibStub:GetLibrary ("AceSerializer-3.0")

	--check if there isn't funtions in the data to export
	local dataCopied = DetailsFramework.table.copytocompress({}, data)

	if (LibDeflate and LibAceSerializer) then
		local dataSerialized = LibAceSerializer:Serialize (dataCopied)
		if (dataSerialized) then
			local dataCompressed = LibDeflate:CompressDeflate (dataSerialized, {level = 9})
			if (dataCompressed) then
				if (dataType == "print") then
					local dataEncoded = LibDeflate:EncodeForPrint (dataCompressed)
					return dataEncoded

				elseif (dataType == "comm") then
					local dataEncoded = LibDeflate:EncodeForWoWAddonChannel (dataCompressed)
					return dataEncoded
				end
			end
		end
	end
end

function Details:DecompressData (data, dataType)
	local LibDeflate = LibStub:GetLibrary ("LibDeflate")
	local LibAceSerializer = LibStub:GetLibrary ("AceSerializer-3.0")

	if (LibDeflate and LibAceSerializer) then

		local dataCompressed

		if (dataType == "print") then

			data = DetailsFramework:Trim (data)

			dataCompressed = LibDeflate:DecodeForPrint (data)
			if (not dataCompressed) then
				Details:Msg("couldn't decode the data.")
				return false
			end

		elseif (dataType == "comm") then
			dataCompressed = LibDeflate:DecodeForWoWAddonChannel (data)
			if (not dataCompressed) then
				Details:Msg("couldn't decode the data.")
				return false
			end
		end
		local dataSerialized = LibDeflate:DecompressDeflate (dataCompressed)

		if (not dataSerialized) then
			Details:Msg("couldn't uncompress the data.")
			return false
		end

		local okay, data = LibAceSerializer:Deserialize (dataSerialized)
		if (not okay) then
			Details:Msg("couldn't unserialize the data.")
			return false
		end

		return data
	end
end

local function GetRoleFromSpecInfo(specInfo)
	if specInfo.Healer then
		return "HEALER"
	elseif specInfo.Tank then
		return "TANK"
	else
		return "DAMAGER"
	end
end

Details.specToRole = {}
Details.validSpecIds = {}

Details.textureToSpec = {}
Details.specToTexture = {}

for _, class in ipairs(CLASS_SORT_ORDER) do
    local specs = C_ClassInfo.GetAllSpecs(class)
    for _, spec in ipairs(specs) do
        local specInfo = C_ClassInfo.GetSpecInfo(class, spec)
		local thumbnail = ClassTalentUtil.GetThumbnailAtlas(class, spec)
		Details.validSpecIds[specInfo.ID] = true
        Details.specToRole[specInfo.ID] = GetRoleFromSpecInfo(specInfo)
		Details.textureToSpec[thumbnail] = specInfo.ID
		Details.specToTexture[specInfo.ID] = thumbnail
    end
end

--oldschool talent tree
do
	function _detalhes:GetRoleFromSpec (specId)
		return Details.specToRole [specId] or "NONE"
	end

	function Details.IsValidSpecId (specId)
		return Details.validSpecIds [specId]
	end

	function Details.GetClassicSpecByTalentTexture (talentTexture)
		return Details.textureToSpec [talentTexture] or nil
	end
end

--fill the passed table with spells from talents and spellbook, affect only the active spec
function Details.FillTableWithPlayerSpells(completeListOfSpells)
	for tab = 2, GetNumSpellTabs() do
        local name, _, offset, numSpells = GetSpellTabInfo(tab)

        if name and name ~= "Internal" and name ~= "Ascension Vanity Items" then
            for i = offset + 1, offset + numSpells do
                local spellName, rank = GetSpellInfo(i, BOOKTYPE_SPELL)

                if spellName then
                    local link = GetSpellLink(spellName, rank)
                    if link then
                        local spellID = tonumber(link:match("spell:(%d*)"))
                        if spellID and not IsPassiveSpellID(spellID) then
                            if LIB_OPEN_RAID_MULTI_OVERRIDE_SPELLS and LIB_OPEN_RAID_MULTI_OVERRIDE_SPELLS[spellID] then
                                for _, overrideSpellID in pairs(LIB_OPEN_RAID_MULTI_OVERRIDE_SPELLS[spellID]) do
                                    completeListOfSpells[overrideSpellID] = true
                                end
                            else
                                completeListOfSpells[spellID] = true
                            end
                        end
                    end
                end
            end
        end
    end
end

function Details.SavePlayTimeOnClass()
	local className = select(2, UnitClass("player"))
	if (className) then
		--played time by  expansion
		local expansionLevel = GetExpansionLevel()

		local expansionTable = Details.class_time_played[expansionLevel]
		if (not expansionTable) then
			expansionTable = {}
			Details.class_time_played[expansionLevel] = expansionTable
		end

		local playedTime = expansionTable[className] or 0
		expansionTable[className] = playedTime + GetTime() - Details.GetStartupTime()
	end
end

function Details.GetPlayTimeOnClass()
	local className = select(2, UnitClass("player"))
	if (className) then
		--played time by  expansion
		local expansionLevel = GetExpansionLevel()

		local expansionTable = Details.class_time_played[expansionLevel]
		if (not expansionTable) then
			expansionTable = {}
			Details.class_time_played[expansionLevel] = expansionTable
		end

		local playedTime = expansionTable[className]
		if (playedTime) then
			playedTime = playedTime + (GetTime() - Details.GetStartupTime())
			return playedTime
		end
	end
	return 0
end

function Details.GetPlayTimeOnClassString()
    local playedTime = Details.GetPlayTimeOnClass()
    local days = floor(playedTime / 86400) .. " days"
    playedTime = playedTime % 86400
    local hours = floor(playedTime / 3600) .. " hours"
    playedTime = playedTime % 3600
    local minutes = floor(playedTime / 60) .. " minutes"

	local expansionLevel = GetExpansionLevel()
	local expansionName = _G["EXPANSION_NAME" .. GetExpansionLevel()]

    return "|cffffff00Time played this class (" .. expansionName .. "): " .. days .. " " .. hours .. " " .. minutes
end

hooksecurefunc("ChatFrame_DisplayTimePlayed", function()
	if (Details.played_class_time) then
		C_Timer.After(0, function()
			print(Details.GetPlayTimeOnClassString() .. " \ncommand: /details playedclass")
		end)
	end
end)

--game freeze prevention, there are people calling UpdateAddOnMemoryUsage() making the game client on the end user to freeze, this is bad, really bad.
--Details! replace the function call with one that do the same thing, but warns the player if the function freezes the client too many times.
--this feature is disabled by default, to enable it, type /run Details.check_stuttering = true and reload the game
local stutterCounter = 0
local bigStutterCounter = 0
local UpdateAddOnMemoryUsage_Original = _G.UpdateAddOnMemoryUsage
Details.UpdateAddOnMemoryUsage_Original = _G.UpdateAddOnMemoryUsage

Details.UpdateAddOnMemoryUsage_Custom = function()
	local currentTime = debugprofilestop()
	UpdateAddOnMemoryUsage_Original()
	local deltaTime = debugprofilestop() - currentTime

	if (deltaTime > 16) then
		local callStack = debugstack(2, 0, 4)
		--ignore if is coming from the micro menu tooltip
		if (callStack:find("MainMenuBarPerformanceBarFrame_OnEnter")) then
			return
		end

		if (deltaTime >= 500) then
			bigStutterCounter = bigStutterCounter + 1
			if (bigStutterCounter >= 6) then
				Details:Msg("an addon made your game freeze for more than a half second, use '/details perf' to know more.")
				bigStutterCounter = -10000 --make this msg appear only once
			end
		end

		stutterCounter = stutterCounter + 1
		local stutterDegree = 0
		if (stutterCounter > 60) then
			if (deltaTime < 48) then
				Details:Msg("some addon may be causing small framerate stuttering, use '/details perf' to know more.")
				stutterDegree = 1

			elseif (deltaTime <= 100) then
				Details:Msg("some addon may be causing framerate drops, use '/details perf' to know more.")
				stutterDegree = 2

			else
				Details:Msg("some addon might be causing performance issues, use '/details perf' to know more.")
				stutterDegree = 3
			end

			stutterCounter = -10000  --make this msg appear only once
		end

		Details.performanceData = {
			deltaTime = deltaTime,
			callStack = callStack,
			culpritFunc = "_G.UpdateAddOnMemoryUsage()",
			culpritDesc = "Calculates memory usage of addons",
		}
	end
end

Details.performanceData = {
	deltaTime = 0,
	callStack = "",
	culpritFunc = "",
	culpritDesc = "",
}

function CopyText(text) --[[GLOBAL]]
	if (not Details.CopyTextField) then
		Details.CopyTextField = CreateFrame("Frame", "DetailsCopyText", UIParent, "BackdropTemplate")
		Details.CopyTextField:SetHeight(14)
		Details.CopyTextField:SetWidth(120)
		Details.CopyTextField:SetPoint("center", UIParent, "center")
		Details.CopyTextField:SetBackdrop(backdrop)

		DetailsFramework:ApplyStandardBackdrop(Details.CopyTextField)

		tinsert(UISpecialFrames, "DetailsCopyText")

		Details.CopyTextField.textField = CreateFrame("editbox", nil, Details.CopyTextField, "BackdropTemplate")
		Details.CopyTextField.textField:SetPoint("topleft", Details.CopyTextField, "topleft")
		Details.CopyTextField.textField:SetAutoFocus(false)
		Details.CopyTextField.textField:SetFontObject("GameFontHighlightSmall")
		Details.CopyTextField.textField:SetAllPoints()
		Details.CopyTextField.textField:EnableMouse(true)

		Details.CopyTextField.textField:SetScript("OnEnterPressed", function()
			Details.CopyTextField.textField:ClearFocus()
			Details.CopyTextField:Hide()
		end)

		Details.CopyTextField.textField:SetScript("OnEscapePressed", function()
			Details.CopyTextField.textField:ClearFocus()
			Details.CopyTextField:Hide()
		end)

		Details.CopyTextField.textField:SetScript("OnChar", function()
			Details.CopyTextField.textField:ClearFocus()
			Details.CopyTextField:Hide()
		end)
	end

	C_Timer.After(0.1, function()
		Details.CopyTextField:Show()
		Details.CopyTextField.textField:SetFocus()
		Details.CopyTextField.textField:SetText(text)
		Details.CopyTextField.textField:HighlightText()
	end)
end


-------------------------------------------------------------------------
--> cache maintenance

function Details222.Cache.DoMaintenance()
	local currentTime = time()
	local delay = 1036800 --12 days

	if (currentTime > Details.latest_spell_pool_access + delay) then
		local spellIdPoolBackup = DetailsFramework.table.copy({}, Details.spell_pool)

		Details:Destroy(Details.spell_pool)

		--preserve ignored spells spellId
		for spellId in pairs(Details.spellid_ignored) do
			Details.spell_pool[spellId] = spellIdPoolBackup[spellId]
		end

		Details.latest_spell_pool_access = currentTime
		Details:Destroy(spellIdPoolBackup)
	end

	if (currentTime > Details.latest_npcid_pool_access + delay) then
		local npcIdPoolBackup = DetailsFramework.table.copy({}, Details.npcid_pool)

		Details:Destroy(Details.npcid_pool)

		--preserve ignored npcs npcId
		for npcId in pairs (Details.npcid_ignored) do
			Details.npcid_pool[npcId] = npcIdPoolBackup[npcId]
		end
		Details.latest_npcid_pool_access = currentTime
		Details:Destroy(npcIdPoolBackup)
	end

	if (currentTime > Details.latest_encounter_spell_pool_access + delay) then
		Details:Destroy(Details.encounter_spell_pool)
		Details.latest_encounter_spell_pool_access = currentTime
	end

	if (Details.boss_mods_timers and Details.boss_mods_timers.latest_boss_mods_access) then
		if (currentTime > Details.boss_mods_timers.latest_boss_mods_access + delay) then
			Details:Destroy(Details.boss_mods_timers.encounter_timers_bw)
			Details:Destroy(Details.boss_mods_timers.encounter_timers_dbm)
			Details.boss_mods_timers.latest_boss_mods_access = currentTime
		end
	end

	--latest_shield_spellid_cache_access
	--shield_spellid_cache
end