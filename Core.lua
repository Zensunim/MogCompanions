local addonName, addon = ...
local ns = select(2,...)
local MogMount = CreateFrame('Frame', 'MogMountAddonFrame', UIParent)

ns.MogMount = MogMount;
local L = MogMountLocales;

local playerName = UnitName("player");
local transmogs = {};
local loaded = false;
local firstLoad = true;
local titleLoaded = false;

local TitleDropdown;

function MogMount:UpdateTitle()
	local SavedCurrentTitle = -1;

	if MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetActiveOutfitID()].Title > 0 then
		SavedCurrentTitle = MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetActiveOutfitID()].Title
	end

	if SavedCurrentTitle ~= nil and GetCurrentTitle() ~= SavedCurrentTitle and (SavedCurrentTitle == -1 or IsTitleKnown(SavedCurrentTitle)) then
		SetCurrentTitle(SavedCurrentTitle);
	end
end

function MogMountBindingClicked()
	MogMountSummon();
end

local function PrintSlashHelp()
	print("|cFF00CCFFMogMount-Zensunim commands:|r");
	print("|cFFFFFFFF/mmz mount|r - "..L["Slash Help Mount"]);
	print("|cFFFFFFFF/mmz options|r - "..L["Slash Help Options"]);
end

local function OpenSettingsToMogMount()
	if MogMountSettingsCategoryID > 0 then
		Settings.OpenToCategory(MogMountSettingsCategoryID);
	end
end

function MogMount:OpenSettings()
	OpenSettingsToMogMount();
end

SLASH_MOGMOUNTZENSUNIM1 = "/mmz";
SlashCmdList["MOGMOUNTZENSUNIM"] = function(msg)
	local command = string.lower(string.match(msg or "", "^%s*(.-)%s*$"));

	if command == "" or command == "help" then
		PrintSlashHelp();
	elseif command == "mount" then
		MogMountSummon();
	elseif command == "options" then
		OpenSettingsToMogMount();
	else
		PrintSlashHelp();
	end
end

SLASH_MOGMOUNTZENSUNIM_MOUNT1 = "/mmzm";
SlashCmdList["MOGMOUNTZENSUNIM_MOUNT"] = function()
	MogMountSummon();
end

local function OnSettingChanged(setting, value)
	MogMountCharacterSaved[setting:GetVariable()] = value;
end

local function CreateDisplayTitle(titleID)
	local title, _ = GetTitleName(titleID);
	local displayTitle = "";

	if titleID == 0 then
		return playerName;
	end

	if title:sub(-1) == " " then
		displayTitle = title..playerName;
	else
		displayTitle = playerName.." "..title;
	end

	return displayTitle;
end

local function SetSelectedTitle(value)
	titleLoaded = false;
	TitleDropdown:SetDefaultText(CreateDisplayTitle(value));
	MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Title = value;
	
	MogMount:UpdateTitle();
end

local function GetTitles()
	TitleDropdown = CreateFrame("DropdownButton", nil, TransmogFrame.CharacterPreview, "WowStyle1DropdownTemplate");

	local function GeneratorFunctionTitles(dropdown, rootDescription)
		rootDescription:CreateButton(playerName, SetSelectedTitle, 0);

		local titlesRaw = {};
		local count = 1;

		for i = 1, GetNumTitles() do
			if IsTitleKnown(i) then
				titlesRaw[count] = {};
				titlesRaw[count].id = i;
				titlesRaw[count].name = CreateDisplayTitle(i);
				count = count + 1;				
			end
		end

		table.sort(titlesRaw, MogMountSortAlphabetical);

		for i = 1, #titlesRaw do
			rootDescription:CreateButton(titlesRaw[i].name, SetSelectedTitle, titlesRaw[i].id);
		end

		local extent = 20;
		local maxCharacters = 20;
		local maxScrollExtent = extent * maxCharacters;
		rootDescription:SetScrollMode(maxScrollExtent);

	end

	TransmogFrame.CharacterPreview.ModelScene.ControlFrame:SetPoint("TOP", 0, -64);

	if MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Title == 0 then
		TitleDropdown:SetDefaultText(playerName);
	else
		TitleDropdown:SetDefaultText(CreateDisplayTitle(MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Title));
	end

	TitleDropdown:SetWidth(240);
	TitleDropdown:SetPoint("TOP", TransmogFrame.CharacterPreview, "TOP", 0, -27);
	TitleDropdown:SetFrameStrata("MEDIUM");
	TitleDropdown:SetFrameLevel(200);
	TitleDropdown.Text:SetJustifyH("CENTER");

	TitleDropdown:SetupMenu(GeneratorFunctionTitles);

	TitleDropdown:SetScript("OnEnter", function()
		GameTooltip:SetOwner(TitleDropdown, "ANCHOR_RIGHT");
		GameTooltip:AddLine(L["Character Title Tooltip"], 1, 1, 1);
		GameTooltip:Show();
	end)

	TitleDropdown:SetScript("OnLeave", function()
		GameTooltip:Hide();
	end)
end

local function OpenKeybindingsToMogMount()
	Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID, "MogMount");
	children = {SettingsPanel.Container.SettingsList.ScrollBox.ScrollTarget:GetChildren()}
	
	for i, child in ipairs(children) do
		children2 = {child:GetChildren()};
		for j, child2 in ipairs(children2) do
			if (child2.Text ~= nil) then
				if child2.Text:GetText() == "MogMount" then
					local initializer = child:GetElementData();
					local data = initializer.data;
					data.expanded = not data.expanded;
					child:SetHeight(child:CalculateHeight());
					child:OnExpandedChanged(data.expanded);
				end
			end
		end
	end
end

function MogMount:OpenKeybinds()
	OpenKeybindingsToMogMount();
end

local function InitTitles(reset)
	if not reset then

		if MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Title == 0 then
			TitleDropdown:SetDefaultText(playerName);
		else
			TitleDropdown:SetDefaultText(CreateDisplayTitle(MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Title));
		end

		TitleDropdown:GenerateMenu();

	else

		GetTitles();

	end
end

function MogMount:OnEvent(event, addOnName)
	if event == "PLAYER_ENTERING_WORLD" and not loaded then

		if MogMountCharacterSaved == nil then
			MogMountCharacterSaved = {};
			MogMountCharacterSaved.Default = {};
			MogMountCharacterSaved.Default.Flying = 0;
			MogMountCharacterSaved.Default.Ground = 0;
			MogMountCharacterSaved.Default.Aquatic = 0;
			MogMountCharacterSaved.Default.Special = 0;
			MogMountCharacterSaved.Default.Alternative = 0;		
		end

		for t = 1, #C_TransmogOutfitInfo.GetOutfitsInfo() do

			local outfitInfo = C_TransmogOutfitInfo.GetOutfitsInfo()[t];	
			MogMount:CreateEmptyOutfit(outfitInfo.outfitID);

		end		

		if MogMountSaved == nil then
			MogMountSaved = {};
			MogMountSaved['MacroID'] = 0;
			MogMountSaved.ShowFlyingInGround = false;
		end

		if MogMountCharacterSaved.Default.Alternative == nil then
			MogMountCharacterSaved.Default.Alternative = 0;
		end

		if MogMountSaved.ShowFlyingInGround == nil then
			MogMountSaved.ShowFlyingInGround = false;
		end

		loaded = true;
	
	end

	if event == "VIEWED_TRANSMOG_OUTFIT_CHANGED" then

		MogMount:CreateEmptyOutfit(C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID());

		MogMount:InitMountSlots(firstLoad);

		InitTitles(firstLoad);

		C_Timer.After(0.1, function()
			UpdateSelectedMountRow();
		end)

		firstLoad = false;

	end		

	if event == "TRANSMOGRIFY_OPEN" then

		C_Timer.After(0.1, function()
			MogMount:InitMountTab();
		end)

	end
end

MogMount:RegisterEvent("ADDON_LOADED")
MogMount:RegisterEvent("PLAYER_ENTERING_WORLD")

MogMount:RegisterEvent("TRANSMOGRIFY_OPEN")
MogMount:RegisterEvent("VIEWED_TRANSMOG_OUTFIT_CHANGED")

-- MogMount:RegisterEvent("TRANSMOGRIFY_CLOSE")
-- MogMount:RegisterEvent("TRANSMOG_SEARCH_UPDATED")
-- MogMount:RegisterEvent("TRANSMOGRIFY_SUCCESS")
-- MogMount:RegisterEvent("TRANSMOG_DISPLAYED_OUTFIT_CHANGED")

MogMount:SetScript("OnEvent", MogMount.OnEvent)
