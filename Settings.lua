-- Settings.lua
-- Registers all MogCompanions user options with the Retail Settings API.
-- Adds a "MogCompanions" category to the game's Settings panel with:
--   • Default mounts (flying, ground, aquatic, special/repair, alternative)
-- All user-facing strings come from Locales/enUS.lua via MogCompanionsLocales.
-- MogCompanionsSettingsCategoryID is a global used by Core.lua to open the panel.
local _, addon = ...;
local ns = select(2,...);
local MogCompanions = ns.MogCompanions;
local MogCompanionsSettings = CreateFrame('Frame', 'MogCompanionsSettingsFrame', UIParent);
local L = MogCompanionsLocales;

local settingsLoaded = false;

MogCompanionsSettingsCategoryID = 0;

-- ── Default Mount Dropdown Data Providers ───────────────────────────────────
-- Each GetOptionsXxx function returns a Settings control data container used by
-- Settings.CreateDropdown. Entry 0 = "Random" for default mounts;
-- entry 1 = "Default" for per-outfit overrides.
local function GetOptionsFlyingMount()
	local container = Settings.CreateControlTextContainer();

	container:Add(0, "|T134400:18|t "..L["Settings Random Selection Label"]);

	local mounts = MogCompanions:getSortedFlyingMounts()

	for i = 1, #mounts do
		local mount = mounts[i];
		container:Add(mount.id, mount.nameAndIcon);
		if mount.id == MogCompanionsCharacterSaved.Default.Flying then
			-- defaultValue tracking removed (dead code)
		end
	end

	return container:GetData();
end

local function GetOptionsGroundMount()
	local container = Settings.CreateControlTextContainer();

	container:Add(0, "|T134400:18|t "..L["Settings Random Selection Label"]);

	local mounts = MogCompanions:getSortedGroundMounts();

	for i = 1, #mounts do
		local mount = mounts[i];
		container:Add(mount.id, mount.nameAndIcon);
		if mount.id == MogCompanionsCharacterSaved.Default.Ground then
			-- defaultValue tracking removed (dead code)
		end
	end

	return container:GetData();
end

local function GetOptionsAquaticMount()
	local container = Settings.CreateControlTextContainer();
	local mounts = MogCompanions:getSortedAquaticMounts();

	if #mounts > 0 then

		container:Add(0, "|T134400:18|t "..L["Settings Random Selection Label"]);

		for i = 1, #mounts do
			local mount = mounts[i];
			container:Add(mount.id, mount.nameAndIcon);
			if mount.id == MogCompanionsCharacterSaved.Default.Aquatic then
				-- defaultValue tracking removed (dead code)
			end
		end

	else 

		container:Add(0, L["Settings No Applicable Mounts"]);

	end

	return container:GetData();
end

local function GetOptionsSpecialMount()
	local container = Settings.CreateControlTextContainer();
	local mounts = MogCompanions:getSortedSpecialMounts();

	if #mounts > 0 then

		container:Add(0, "|T134400:18|t "..L["Settings Random Selection Label"]);

		for i = 1, #mounts do
			local mount = mounts[i];
			container:Add(mount.id, mount.nameAndIcon);
			if mount.id == MogCompanionsCharacterSaved.Default.Special then
				-- defaultValue tracking removed (dead code)
			end
		end

	else 

		container:Add(0, L["Settings No Applicable Mounts"]);

	end

	return container:GetData();
end

local function GetOptionsAlternativeMount()
	local container = Settings.CreateControlTextContainer();
	local mounts = MogCompanions:getSortedAlternativeMounts();

	if #mounts > 0 then

		container:Add(0, "|T134400:18|t "..L["Settings Random Selection Label"]);

		for i = 1, #mounts do
			local mount = mounts[i];
			container:Add(mount.id, mount.nameAndIcon);
			if mount.id == MogCompanionsCharacterSaved.Default.Alternative then
				-- defaultValue tracking removed (dead code)
			end
		end

	else 

		container:Add(0, L["Settings No Applicable Mounts"]);

	end

	return container:GetData();
end

-- Stub; actual persistence is handled by the Settings API variable binding.
-- Extend this function if side-effects are needed when any setting changes.
local function OnSettingChanged()
	-- No side-effects needed; the Settings API variable binding handles persistence.
end

-- Registers all MogCompanions settings and creates the Settings panel layout.
-- Called once from PLAYER_ENTERING_WORLD after saved variables are loaded.
local function InitSettings()
	local category, layout = Settings.RegisterVerticalLayoutCategory("MogCompanions");

	MogCompanionsSettingsCategoryID = category:GetID();
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["Settings Default Section Title"], ''));
   
	local key1, key2 = GetBindingKey("Mount/Dismount");

	-- Default flying mount

	local variable = "DefaultFlying";
	local defaultValue = 1;
	local name = L["Settings Flying Mount"];
	local tooltip = L["Settings Flying Mount Tooltip"];
	local variableKey = "Flying";
	local variableTable = MogCompanionsCharacterSaved.Default;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
	Settings.CreateDropdown(category, setting, GetOptionsFlyingMount, tooltip);
	setting:SetValueChangedCallback(OnSettingChanged);

	-- Default ground mount

	local variable = "DefaultGround";
	local defaultValue = 1;
	local name = L["Settings Ground Mount"];
	local tooltip = false;
	if key1 or key2 then
		tooltip = L["Settings Ground Mount Tooltip"].."\n\n"..WrapTextInColorCode(L["Settings Ground Mount Keybind Reminder"], "00999999");
	else
		tooltip = L["Settings Ground Mount Tooltip"];
	end

	local variableKey = "Ground";
	local variableTable = MogCompanionsCharacterSaved.Default;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
	Settings.CreateDropdown(category, setting, GetOptionsGroundMount, tooltip);
	setting:SetValueChangedCallback(OnSettingChanged);

	-- Default aquatic mount

	local variable = "DefaultAquatic";
	local defaultValue = 1;
	local name = L["Settings Aquatic Mount"];
	local tooltip = nil;
	if key1 or key2 then
		tooltip = WrapTextInColorCode(L["Settings Aquatic Mount Keybind Reminder"], "00999999");
	end
	local variableKey = "Aquatic";
	local variableTable = MogCompanionsCharacterSaved.Default;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
	Settings.CreateDropdown(category, setting, GetOptionsAquaticMount, tooltip);
	setting:SetValueChangedCallback(OnSettingChanged);

	-- Default special mount

	local variable = "DefaultSpecial";
	local defaultValue = 1;
	local name = L["Settings Special Mount"];
	local tooltip = nil;
	if key1 or key2 then
		tooltip = WrapTextInColorCode(L["Settings Special Mount Keybind Reminder"], "00999999");
	end
	local variableKey = "Special";
	local variableTable = MogCompanionsCharacterSaved.Default;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
   	Settings.CreateDropdown(category, setting, GetOptionsSpecialMount, tooltip);
	setting:SetValueChangedCallback(OnSettingChanged);

	-- Default alternative mount

	local variable = "DefaultAlternative";
	local defaultValue = 1;
	local name = L["Settings Alternative Mount"];
	local tooltip = L["Settings Alternative Mount Tooltip"];
	if key1 or key2 then
		tooltip = L["Settings Alternative Mount Tooltip"].."\n\n"..WrapTextInColorCode(L["Settings Alternative Mount Keybind Reminder"], "00999999");
	else
		tooltip = L["Settings Alternative Mount Tooltip"];
	end
	local variableKey = "Alternative";
	local variableTable = MogCompanionsCharacterSaved.Default;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
   	Settings.CreateDropdown(category, setting, GetOptionsAlternativeMount, tooltip);
	setting:SetValueChangedCallback(OnSettingChanged);

	Settings.RegisterAddOnCategory(category);
end

-- ── Settings Frame Event Handler ──────────────────────────────────────────
-- Waits for PLAYER_ENTERING_WORLD so that saved variables are loaded
-- before InitSettings tries to read MogCompanionsCharacterSaved.
function MogCompanionsSettings:OnEvent(event, addOnName)
	if event == "PLAYER_ENTERING_WORLD" and not settingsLoaded then

		settingsLoaded = true;

		InitSettings();

	end
end

MogCompanionsSettings:RegisterEvent("ADDON_LOADED");
MogCompanionsSettings:RegisterEvent("PLAYER_ENTERING_WORLD");

MogCompanionsSettings:SetScript("OnEvent", MogCompanionsSettings.OnEvent);
