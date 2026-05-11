local _, addon = ...;
local ns = select(2,...);
local MogMount = ns.MogMount;
local MogMountSettings = CreateFrame('Frame', 'MogMountSettingsFrame', UIParent);
local L = MogMountLocales;

local playerName = UnitName("player");
local settingsLoaded = false;
local transmogs = {};

MogMountSettingsCategoryID = 0;

local function GetOptionsFlyingMount()
	local container = Settings.CreateControlTextContainer();

	container:Add(0, "|T134400:18|t "..L["Settings Random Selection Label"]);

	local mounts = MogMount:getSortedFlyingMounts()

	for i = 1, #mounts do
		local mount = mounts[i];
		container:Add(mount.id, mount.nameAndIcon);
		if mount.id == MogMountCharacterSaved.Default.Flying then
			defaultValue = i;
		end
	end

	return container:GetData();
end

local function GetOptionsGroundMount()
	local container = Settings.CreateControlTextContainer();

	container:Add(0, "|T134400:18|t "..L["Settings Random Selection Label"]);

	local mounts = MogMount:getSortedGroundMounts();

	for i = 1, #mounts do
		local mount = mounts[i];
		container:Add(mount.id, mount.nameAndIcon);
		if mount.id == MogMountCharacterSaved.Default.Ground then
			defaultValue = i;
		end
	end

	return container:GetData();
end

local function GetOptionsAquaticMount()
	local container = Settings.CreateControlTextContainer();
	local mounts = MogMount:getSortedAquaticMounts();

	if #mounts > 0 then

		container:Add(0, "|T134400:18|t "..L["Settings Random Selection Label"]);

		for i = 1, #mounts do
			local mount = mounts[i];
			container:Add(mount.id, mount.nameAndIcon);
			if mount.id == MogMountCharacterSaved.Default.Aquatic then
				defaultValue = i;
			end
		end

	else 

		container:Add(0, L["Settings No Applicable Mounts"]);

	end

	return container:GetData();
end

local function GetOptionsSpecialMount()
	local container = Settings.CreateControlTextContainer();
	local mounts = MogMount:getSortedSpecialMounts();

	if #mounts > 0 then

		container:Add(0, "|T134400:18|t "..L["Settings Random Selection Label"]);

		for i = 1, #mounts do
			local mount = mounts[i];
			container:Add(mount.id, mount.nameAndIcon);
			if mount.id == MogMountCharacterSaved.Default.Special then
				defaultValue = i;
			end
		end

	else 

		container:Add(0, L["Settings No Applicable Mounts"]);

	end

	return container:GetData();
end

local function GetOptionsAlternativeMount()
	local container = Settings.CreateControlTextContainer();
	local mounts = MogMount:getSortedAlternativeMounts();

	if #mounts > 0 then

		container:Add(0, "|T134400:18|t "..L["Settings Random Selection Label"]);

		for i = 1, #mounts do
			local mount = mounts[i];
			container:Add(mount.id, mount.nameAndIcon);
			if mount.id == MogMountCharacterSaved.Default.Alternative then
				defaultValue = i;
			end
		end

	else 

		container:Add(0, L["Settings No Applicable Mounts"]);

	end

	return container:GetData();
end

local function OnSettingChanged()
	--
end

local function InitSettings()
	local outfits = C_TransmogOutfitInfo.GetOutfitsInfo();

	for i = 1, #outfits do
		local outfitsInfo = C_TransmogOutfitInfo.GetOutfitInfo(outfits[i].outfitID);
		table.insert(transmogs, outfitsInfo.name);
	end

	local category, layout = Settings.RegisterVerticalLayoutCategory("MogMount");

	MogMountSettingsCategoryID = category:GetID();
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["Settings Default Section Title"], ''));
   
	local key1, key2 = GetBindingKey("Mount/Dismount");

	--

	local variable = "DefaultFlying";
	local defaultValue = 1;
	local name = L["Settings Flying Mount"];
	local tooltip = L["Settings Flying Mount Tooltip"];
	local variableKey = "Flying";
	local variableTable = MogMountCharacterSaved.Default;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
	Settings.CreateDropdown(category, setting, GetOptionsFlyingMount, tooltip);
	setting:SetValueChangedCallback(OnSettingChanged);

	--

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
	local variableTable = MogMountCharacterSaved.Default;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
	Settings.CreateDropdown(category, setting, GetOptionsGroundMount, tooltip);
	setting:SetValueChangedCallback(OnSettingChanged);

	--

	local variable = "DefaultAquatic";
	local defaultValue = 1;
	local name = L["Settings Aquatic Mount"];
	local tooltip = false;
	if key1 or key2 then
		tooltip = WrapTextInColorCode(L["Settings Aquatic Mount Keybind Reminder"], "00999999");
	end
	local variableKey = "Aquatic";
	local variableTable = MogMountCharacterSaved.Default;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
	Settings.CreateDropdown(category, setting, GetOptionsAquaticMount, tooltip);
	setting:SetValueChangedCallback(OnSettingChanged);

	--

	local variable = "DefaultSpecial";
	local defaultValue = 1;
	local name = L["Settings Special Mount"];
	local tooltip = false;
	if key1 or key2 then
		tooltip = WrapTextInColorCode(L["Settings Special Mount Keybind Reminder"], "00999999");
	end
	local variableKey = "Special";
	local variableTable = MogMountCharacterSaved.Default;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
   	Settings.CreateDropdown(category, setting, GetOptionsSpecialMount, tooltip);
	setting:SetValueChangedCallback(OnSettingChanged);

	--

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
	local variableTable = MogMountCharacterSaved.Default;

	local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
   	Settings.CreateDropdown(category, setting, GetOptionsAlternativeMount, tooltip);
	setting:SetValueChangedCallback(OnSettingChanged);		

	--

	local settingsTransmogContainer = CreateFromMixins(SettingsExpandableSectionMixin);

	for t = 1, #C_TransmogOutfitInfo.GetOutfitsInfo() do

		local outfitInfo = C_TransmogOutfitInfo.GetOutfitsInfo()[t];
	
		layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(outfitInfo.name, ''));

		local variable = "Title"..outfitInfo.outfitID;
		local defaultValue = 1;
		local name = L["Settings Character Title"];
		local tooltip = L["Settings Character Title Tooltip"];
		local variableKey = "Title";
		local variableTable = MogMountCharacterSaved["Outfit"..outfitInfo.outfitID];

		local function GetOptionsTitleSettings()
			local container = Settings.CreateControlTextContainer();
			local titles = MogMount:getSortedTitles();

			container:Add(0, playerName);

			for i = 1, #titles do
				local title = titles[i];
				container:Add(title.id, title.name);
				if title.id == MogMountCharacterSaved["Outfit"..outfitInfo.outfitID].Title then
					defaultValue = i;
				end
			end

			return container:GetData();

		end

		local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
		Settings.CreateDropdown(category, setting, GetOptionsTitleSettings, tooltip);
		setting:SetValueChangedCallback(OnSettingChanged);

		--

		local variable = "Flying"..outfitInfo.outfitID;
		local defaultValue = 1;
		local name = L["Settings Flying Mount"];
		local tooltip = false; --"This is a tooltip for the dropdown.";
		local variableKey = "Flying";
		local variableTable = MogMountCharacterSaved["Outfit"..outfitInfo.outfitID];

		local function GetOptionsFlyingMountSettings()
			local container = Settings.CreateControlTextContainer();
			local mounts = MogMount:getSortedFlyingMounts();

			container:Add(1, "|T136243:18|t "..L["Settings Default Selection Label"]);

			for i = 1, #mounts do
				local mount = mounts[i];
				container:Add(mount.id, mount.nameAndIcon);
				if mount.id == MogMountCharacterSaved["Outfit"..outfitInfo.outfitID].Flying then
					defaultValue = i;
				end
			end

			return container:GetData();

		end

		local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue, 240, 640);
		local dropdownTest = Settings.CreateDropdown(category, setting, GetOptionsFlyingMountSettings, tooltip);
		setting:SetValueChangedCallback(OnSettingChanged);

		---

		local variable = "Ground"..outfitInfo.outfitID;
		local defaultValue = 1;
		local name = L["Settings Ground Mount"];
		local tooltip = false;
		local variableKey = "Ground";
		local variableTable = MogMountCharacterSaved["Outfit"..outfitInfo.outfitID];

		local function GetOptionsGroundMountSettings()
			local container = Settings.CreateControlTextContainer();
			local mounts = MogMount:getSortedGroundMounts();

			container:Add(1, "|T136243:18|t "..L["Settings Default Selection Label"]);

			for i = 1, #mounts do
				local mount = mounts[i];
				container:Add(mount.id, mount.nameAndIcon);
				if mount.id == MogMountCharacterSaved["Outfit"..outfitInfo.outfitID].Ground then
					defaultValue = i;
				end
			end

			return container:GetData();

		end

		local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTable, type(defaultValue), name, defaultValue);
		Settings.CreateDropdown(category, setting, GetOptionsGroundMountSettings, tooltip);
		setting:SetValueChangedCallback(OnSettingChanged);

	end

	Settings.RegisterAddOnCategory(category);
end

function MogMountSettings:OnEvent(event, addOnName)
	if event == "PLAYER_ENTERING_WORLD" and not settingsLoaded then

		settingsLoaded = true;

		InitSettings();

	end
end

MogMountSettings:RegisterEvent("ADDON_LOADED");
MogMountSettings:RegisterEvent("PLAYER_ENTERING_WORLD");

MogMountSettings:SetScript("OnEvent", MogMountSettings.OnEvent);
