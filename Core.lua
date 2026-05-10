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

local MogMountFrame;
local flyingMountFrame, flyingMountTexture, flyingMountBorder, flyingMountBorderTexture, flyingMountBorderHighlightTexture;
local groundMountFrame, groundMountTexture, groundMountBorder, groundMountBorderTexture, groundMountBorderHighlightTexture;

local FlyingMountPreview, GroundMountPreview;
local FlyingMountModel, GroundMountModel;

local FlyingMountListScrollBox, FlyingMountSelectionBehavior;

local GroundMountListScrollView, GroundMountListScrollBox, GroundMountListScrollBar, GroundMountSelectionBehavior;

local FlyingMountClear, GroundMountClear;
local SetSelectedFlyingMount, SetSelectedGroundMount;

local SetupReminderFrame;
local MountListSearchBox, FilterDropdown;

MogMount.MountSearchString = "";

MogMountSelectedMount = {}
MogMountSelectedMount.Flying = {}
MogMountSelectedMount.Ground = {}



function getEmptyMountIcon()

	local factionName = UnitFactionGroup("Player");
	local _, raceName, raceID = UnitRace("Player");

	local emptyFlyingMountIcon = 0;
	local emptyGroundMountIcon = 0;

	if raceID == 1 then 	-- Human
		emptyFlyingMountIcon = 773274;
		emptyGroundMountIcon = 2143092;
	elseif raceID == 2 then -- Orc
		emptyFlyingMountIcon = 773276;
		emptyGroundMountIcon = 132224;
	elseif raceID == 3 then -- Dwarf
		emptyFlyingMountIcon = 294468;
		emptyGroundMountIcon = 132248;
	elseif raceID == 4 then -- Night Elf
		emptyFlyingMountIcon = 2020396;
		emptyGroundMountIcon = 132225;
	elseif raceID == 5 then -- Undead
		emptyFlyingMountIcon = 1321546;
		emptyGroundMountIcon = 132264;
	elseif raceID == 6 then -- Tauren
		emptyFlyingMountIcon = 773276;
		emptyGroundMountIcon = 132243;
	elseif raceID == 7 then -- Gnome
		emptyFlyingMountIcon = 132240;
		emptyGroundMountIcon = 132247;
	elseif raceID == 8 then -- Troll
		emptyFlyingMountIcon = 1321546;
		emptyGroundMountIcon = 132253;
	elseif raceID == 9 then -- Goblin
		emptyFlyingMountIcon = 6126218;
		emptyGroundMountIcon = 1408996;
	elseif raceID == 10 then -- Blood Elf
		emptyFlyingMountIcon = 132188;
		emptyGroundMountIcon = 132227;
	elseif raceID == 11 then -- Draenei
		emptyFlyingMountIcon = 132191;
		emptyGroundMountIcon = 132254; --132260
	elseif raceID == 22 then -- Worgen
		emptyFlyingMountIcon = 2020396;
		emptyGroundMountIcon = 132261;
	elseif raceID == 24 or raceID == 25 or raceID == 26 then -- Pandaren
		emptyFlyingMountIcon = 648627;
		emptyGroundMountIcon = 656344;
	elseif raceID == 27 then -- Nightborne
		emptyFlyingMountIcon = 132265;
		emptyGroundMountIcon = 1781067;
	elseif raceID == 29 then -- Void Elf
		emptyFlyingMountIcon = 464141;
		emptyGroundMountIcon = 1786404;
	elseif raceID == 30 then -- Lightforged Draenei
		emptyFlyingMountIcon = 1570763;
		emptyGroundMountIcon = 1713157;
	elseif raceID == 31 then -- Zandalari Troll
		emptyFlyingMountIcon = 1624590;
		emptyGroundMountIcon = 1869253;
	elseif raceID == 32 then -- Kul Tiran
		emptyFlyingMountIcon = 773275;
		emptyGroundMountIcon = 2238243;
	elseif raceID == 34 then -- Dark Iron Dwarf
		emptyFlyingMountIcon = 526578;
		emptyGroundMountIcon = 1992951;	
	elseif raceID == 35 then -- Vulpera
		emptyFlyingMountIcon = 1929247;
		emptyGroundMountIcon = 3045400;
	elseif raceID == 36 then -- Maghar Orc
		emptyFlyingMountIcon = 298596;
		emptyGroundMountIcon = 1937816;
	elseif raceID == 37 then -- Mechagnome
		emptyFlyingMountIcon = 2574427;
		emptyGroundMountIcon = 3041211;	
	elseif raceID == 52 or raceID == 70 then -- Dracthyr
		emptyFlyingMountIcon = 4622497;
		emptyGroundMountIcon = 4731151;
	elseif raceID == 84 or raceID == 85 then -- Earthen
		emptyFlyingMountIcon = 5306251;
		emptyGroundMountIcon = 5767167;
	else
		emptyFlyingMountIcon = 773274;
		emptyGroundMountIcon = 2143092;
	end		

	return emptyFlyingMountIcon, emptyGroundMountIcon;

end



local function UpdateTitle()

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



function MogMountSummonFlying()

	if MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetActiveOutfitID()].Flying > 1 then
		C_MountJournal.SummonByID(MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetActiveOutfitID()].Flying);
	elseif MogMountCharacterSaved.Default.Flying <= 1 then
		local randomMount = MogMount:getRandomMount("flying");
		C_MountJournal.SummonByID(randomMount.id);
	else
		C_MountJournal.SummonByID(MogMountCharacterSaved.Default.Flying);
	end

end



function MogMountSummonGround()

	if MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetActiveOutfitID()].Ground > 1 then
		C_MountJournal.SummonByID(MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetActiveOutfitID()].Ground);
	elseif MogMountCharacterSaved.Default.Ground <= 1 then
		local randomMount = MogMount:getRandomMount("ground");
		C_MountJournal.SummonByID(randomMount.id);
	else
		C_MountJournal.SummonByID(MogMountCharacterSaved.Default.Ground);
	end

end



function MogMountSummonAquatic()

	if MogMountCharacterSaved.Default.Aquatic <= 1 then
		local randomMount = MogMount:getRandomMount("aquatic");
		C_MountJournal.SummonByID(randomMount.id);
	else
		C_MountJournal.SummonByID(MogMountCharacterSaved.Default.Aquatic);
	end

end



function MogMountSummonSpecial()

	if MogMountCharacterSaved.Default.Special <= 1 then
		local randomMount = MogMount:getRandomMount("special");
		C_MountJournal.SummonByID(randomMount.id);
	else
		C_MountJournal.SummonByID(MogMountCharacterSaved.Default.Special);
	end

end



function MogMountSummonAlternative()

	C_MountJournal.SummonByID(MogMountCharacterSaved.Default.Alternative);

end



function MogMountSummon()
	
	if CanExitVehicle() then

		VehicleExit();

	elseif IsMounted() then

		-- Dismount
		Dismount();

	elseif IsSwimming() and IsControlKeyDown() then

		-- Aquatic mount
		MogMountSummonAquatic();

	elseif IsShiftKeyDown() then

		-- Repair bear, yak, or long boi
		MogMountSummonSpecial();

	elseif IsAltKeyDown() then

		-- Alternative mount, whatever the player wants it to be
		MogMountSummonAlternative();

	elseif IsFlyableArea() and not IsControlKeyDown() then

		-- Flyable
		MogMountSummonFlying();

	else

		-- Ground or when control key is pressed
		MogMountSummonGround();

	end

	UpdateTitle();

end

local function OpenSettingsToMogMountSlash()
	Settings.OpenToCategory("MogMount");
end

local function PrintSlashHelp()
	print("|cFF00CCFFMogMount-Zensunim commands:|r");
	print("|cFFFFFFFF/mmz mount|r - "..L["Slash Help Mount"]);
	print("|cFFFFFFFF/mmz options|r - "..L["Slash Help Options"]);
	print("|cFFFFFFFF/mmz hs|r - "..L["Slash Help Hearthstone"]);
end

SLASH_MOGMOUNTZENSUNIM1 = "/mmz";
SlashCmdList["MOGMOUNTZENSUNIM"] = function(msg)
	local command = string.lower(string.match(msg or "", "^%s*(.-)%s*$"));

	if command == "" or command == "help" then
		PrintSlashHelp();
	elseif command == "mount" then
		MogMountSummon();
	elseif command == "options" then
		OpenSettingsToMogMountSlash();
	elseif command == "hs" then
		print(L["Slash Hearthstone Placeholder"]);
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
	
	UpdateTitle();

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



local function OpenSettingsToMogMount()

	if MogMountSettingsCategoryID > 0 then
   		Settings.OpenToCategory(MogMountSettingsCategoryID);
   	end

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



local function ToggleReminder()
	if MissingKeybindOrMacro() then
		SetupReminderFrame:Show();
		ShortcutSettings:Hide();
		MountListSearchBox:Hide();
		FilterDropdown:Hide();
	else
		SetupReminderFrame:Hide();
		ShortcutSettings:Show();
		MountListSearchBox:Show();
		FilterDropdown:Show();			
	end
end



local function CreateMacroButton(Parent)

	macroId = false;

	for i = 1, 120 do
		if C_Macro.GetMacroName(i) == "MogMount" then
			macroId = i;
		end
	end

	if not macroId then
		macroId = CreateMacro("MogMount", 1769015, "/mmz mount", nil);
	end

	MogMountSaved["MacroID"] = macroId;
	PickupMacro(macroId);

	GameTooltip:SetOwner(Parent, "ANCHOR_CURSOR_RIGHT");
	GameTooltip:AddLine(L["Drop Macro Tooltip"], 1, 1, 1);
	GameTooltip:Show();

	local MacroDropEventFrame = CreateFrame("EventFrame")
	MacroDropEventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")

	MacroDropEventFrame:SetScript("OnEvent", function(self, event, slot)
		if slot then
			local actionType, id, subType = GetActionInfo(slot)
			if actionType == "macro" then
				ToggleReminder();
				MacroDropEventFrame:UnregisterAllEvents();
				MacroDropEventFrame = nil;
			end
		end
	end)

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



local function InitTransmog(reset)

	if reset then

		local point, relativeTo, relativePoint, xOfs, yOfs = TransmogFrame.CharacterPreview.RightSlots:GetPoint();
		TransmogFrame.CharacterPreview.RightSlots:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs + 80);

		MogMountFrame = CreateFrame("Frame", "MogMountFrame", TransmogFrame.CharacterPreview.RightSlots);
		MogMountFrame:SetFrameStrata("MEDIUM");
		MogMountFrame:SetSize(44, 120);

		local point, relativeTo, relativePoint, xOfs, yOfs = TransmogFrame.CharacterPreview.RightSlots:GetPoint();
		MogMountFrame:SetPoint("TOPLEFT", TransmogFrame.CharacterPreview.RightSlots, "BOTTOMLEFT", xOfs + 35, yOfs - 124);
		
		-- Flying Mount Frame

		flyingMountFrame = CreateFrame("Frame", "FlyingMountFrame", MogMountFrame);
		flyingMountFrame:SetFrameStrata("MEDIUM");
		flyingMountFrame:SetSize(44, 44);

		local point, relativeTo, relativePoint, xOfs, yOfs = MogMountFrame:GetPoint();
		flyingMountFrame:SetPoint("TOPLEFT", MogMountFrame, "TOPLEFT", 0, 0);
		flyingMountFrame:Show();

		flyingMountTexture = flyingMountFrame:CreateTexture(nil,"BACKGROUND");

		-- Flying Mount Border

		borderSize = 59;
		borderOffset = 7;

		appearanceSlotInfo, illusionSlotInfo = C_TransmogOutfitInfo.GetAllSlotLocationInfo();

		flyingMountBorder = CreateFrame("Frame", "FlyingMountBorder", flyingMountFrame);
		flyingMountBorder:SetFrameStrata("HIGH");
		flyingMountBorder:SetSize(borderSize, borderSize);

		flyingMountBorderTexture = flyingMountBorder:CreateTexture(nil,"BACKGROUND");
		flyingMountBorderTexture:SetAtlas("transmog-gearSlot-default");
		flyingMountBorderTexture:SetAllPoints(flyingMountBorder);
		flyingMountBorder.texture = flyingMountBorderTexture;

		local point, relativeTo, relativePoint, xOfs, yOfs = flyingMountFrame:GetPoint();
		flyingMountBorder:SetPoint("TOPLEFT", flyingMountFrame, "TOPLEFT", borderOffset * -1, borderOffset);
		flyingMountBorder:Show();

		--

		flyingMountBorderHighlight = CreateFrame("Frame", "FlyingMountBorderHighlight", flyingMountFrame);
		flyingMountBorderHighlight:SetFrameStrata("HIGH");
		flyingMountBorderHighlight:SetSize(borderSize, borderSize);
		
		flyingMountBorderHighlightTexture = flyingMountBorderHighlight:CreateTexture(nil,"BACKGROUND");
		flyingMountBorderHighlightTexture:SetAtlas("transmog-gearSlot-default");
		flyingMountBorderHighlightTexture:SetAllPoints(flyingMountBorderHighlight);
		flyingMountBorderHighlightTexture:SetBlendMode("ADD");
		flyingMountBorderHighlight.texture = flyingMountBorderHighlightTexture;
		
		local point, relativeTo, relativePoint, xOfs, yOfs = flyingMountFrame:GetPoint();
		flyingMountBorderHighlight:SetPoint("TOPLEFT", flyingMountFrame, "TOPLEFT", borderOffset * -1, borderOffset);
		flyingMountBorderHighlight:Hide();

		FlyingMountClear = CreateFrame("Button", "FlyingMountClearButton", flyingMountBorder, "UIResetButtonTemplate");
		FlyingMountClear:SetPoint("CENTER", flyingMountBorder, "TOPRIGHT", -8, -8);

		FlyingMountClear:SetScript("OnEnter", function()
			GameTooltip:SetOwner(FlyingMountClear, "ANCHOR_RIGHT");
			GameTooltip:SetText(L["Item Slot Flying Mount Clear Tooltip"]);
			GameTooltip:Show();
			FlyingMountClear:Show();
		end)

		FlyingMountClear:SetScript("OnLeave", function()
			FlyingMountClear:Hide();
			GameTooltip:Hide();
		end)

		FlyingMountClear:SetScript("OnClick", function()
			SetSelectedFlyingMount(1);
			FlyingMountModel:SetDisplayInfo(0);
			FlyingMountModel:SetAlpha(1);
			FlyingMountClear:Hide();
			ClearSelectedFlyingMount(); 				
		end)				

		-- Ground Mount Frame

		groundMountFrame = CreateFrame("Frame", "GroundMountFrame", MogMountFrame)
		groundMountFrame:SetFrameStrata("MEDIUM");
		groundMountFrame:SetSize(44, 44);

		local point, relativeTo, relativePoint, xOfs, yOfs = MogMountFrame:GetPoint();
		groundMountFrame:SetPoint("TOPLEFT", MogMountFrame, "TOPLEFT", 0, -64);
		groundMountFrame:Show();

		groundMountTexture = groundMountFrame:CreateTexture(nil,"BACKGROUND");

		-- Ground Mount Border

		groundMountBorder = CreateFrame("Frame", "GroundMountBorder", groundMountFrame);
		groundMountBorder:SetFrameStrata("HIGH");
		groundMountBorder:SetSize(borderSize, borderSize);

		groundMountBorderTexture = groundMountBorder:CreateTexture(nil,"BACKGROUND");
		groundMountBorderTexture:SetAtlas("transmog-gearSlot-default");
		groundMountBorderTexture:SetAllPoints(groundMountBorder);
		groundMountBorder.texture = groundMountBorderTexture;

		local point, relativeTo, relativePoint, xOfs, yOfs = groundMountFrame:GetPoint();
		groundMountBorder:SetPoint("TOPLEFT", groundMountFrame, "TOPLEFT", borderOffset * -1, borderOffset);
		groundMountBorder:Show();

		--

		groundMountBorderHighlight = CreateFrame("Frame", "GroundMountBorderHighlight", groundMountFrame);
		groundMountBorderHighlight:SetFrameStrata("HIGH");
		groundMountBorderHighlight:SetSize(borderSize, borderSize);
		groundMountBorderHighlightTexture = groundMountBorderHighlight:CreateTexture(nil,"BACKGROUND");
		groundMountBorderHighlightTexture:SetAtlas("transmog-gearSlot-default");
		groundMountBorderHighlightTexture:SetAllPoints(groundMountBorderHighlight);
		groundMountBorderHighlightTexture:SetBlendMode("ADD");
		groundMountBorderHighlight.texture = groundMountBorderHighlightTexture;
		
		local point, relativeTo, relativePoint, xOfs, yOfs = groundMountFrame:GetPoint();
		groundMountBorderHighlight:SetPoint("TOPLEFT", groundMountFrame, "TOPLEFT", borderOffset * -1, borderOffset);
		groundMountBorderHighlight:Hide();

		GroundMountClear = CreateFrame("Button", "GroundMountClearButton", groundMountBorder, "UIResetButtonTemplate");
		GroundMountClear:SetPoint("CENTER", groundMountBorder, "TOPRIGHT", -8, -8);

		GroundMountClear:SetScript("OnEnter", function()
			GameTooltip:SetOwner(GroundMountClear, "ANCHOR_RIGHT");
			GameTooltip:SetText(L["Item Slot Ground Mount Clear Tooltip"]);
			GameTooltip:Show();
			GroundMountClear:Show();
		end)

		GroundMountClear:SetScript("OnLeave", function()
			GroundMountClear:Hide();
			GameTooltip:Hide();
		end)

		GroundMountClear:SetScript("OnClick", function()
			SetSelectedGroundMount(1);
			GroundMountModel:SetDisplayInfo(0);
			GroundMountModel:SetAlpha(0);
			GroundMountClear:Hide();
			ClearSelectedGroundMount();			
		end)	

	end

	name, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected, mountID, isSteadyFlight = C_MountJournal.GetMountInfoByID(MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Flying);
	creatureDisplayInfoID, description, source, isSelfMount, mountTypeID, uiModelSceneID, animID, spellVisualKitID, disablePlayerMountPreview = C_MountJournal.GetMountInfoExtraByID(MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Flying);

	MogMount:UpdateSelectMountDetails("Flying", MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Flying);

	if MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Flying == 1 then
		flyingIcon, _ = getEmptyMountIcon();
		flyingMountTexture:SetTexture(flyingIcon);
		flyingMountTexture:SetDesaturated(true);
		flyingMountTexture:SetVertexColor(0.63,0.63,0.63);
		flyingMountBorderTexture:SetAtlas("transmog-gearSlot-default");
		flyingMountBorderHighlightTexture:SetAtlas("transmog-gearSlot-default");
	else
		flyingMountTexture:SetTexture(icon);
		flyingMountTexture:SetDesaturated(false);
		flyingMountTexture:SetVertexColor(1,1,1);
		flyingMountBorderTexture:SetAtlas("transmog-gearSlot-transmogrified");
		flyingMountBorderHighlightTexture:SetAtlas("transmog-gearSlot-transmogrified");
	end
	
	flyingMountTexture:SetAllPoints(flyingMountFrame);
	flyingMountFrame.texture = flyingMountTexture;

	--

	name, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected, mountID, isSteadyFlight = C_MountJournal.GetMountInfoByID(MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Ground);
	creatureDisplayInfoID, description, source, isSelfMount, mountTypeID, uiModelSceneID, animID, spellVisualKitID, disablePlayerMountPreview = C_MountJournal.GetMountInfoExtraByID(MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Ground);

	MogMount:UpdateSelectMountDetails("Ground", MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Ground);

	groundMountName = name;

	if MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Ground == 1 then
		_, groundIcon = getEmptyMountIcon();
		groundMountTexture:SetTexture(groundIcon);
		groundMountTexture:SetDesaturated(true);
		groundMountTexture:SetVertexColor(0.63,0.63,0.63);
		groundMountBorderTexture:SetAtlas("transmog-gearSlot-default");
		groundMountBorderHighlightTexture:SetAtlas("transmog-gearSlot-default");
	else
		groundMountTexture:SetTexture(icon);
		groundMountTexture:SetDesaturated(false);
		groundMountTexture:SetVertexColor(1,1,1);
		groundMountBorderTexture:SetAtlas("transmog-gearSlot-transmogrified");
		groundMountBorderHighlightTexture:SetAtlas("transmog-gearSlot-transmogrified");
	end

	groundMountTexture:SetAllPoints(groundMountFrame);
	groundMountFrame.texture = groundMountTexture;

	if reset then

		flyingMountBorder:HookScript("OnEnter", function()
			GameTooltip:SetOwner(flyingMountBorder, "ANCHOR_RIGHT");
			if MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Flying > 1 then
				GameTooltip:AddLine(MogMountSelectedMount.Flying.name);
				GameTooltip:AddLine("|cFFFFFFFF"..L["Item Slot Flying Mount Title"].."|r");
				FlyingMountClear:Show();				
			else
				GameTooltip:SetText(L["Item Slot Flying Mount Title"]);
			end
			GameTooltip:Show();
			flyingMountBorderHighlight:Show();
		end)

		flyingMountBorder:HookScript("OnLeave", function()
			GameTooltip:Hide();
			flyingMountBorderHighlight:Hide();
			FlyingMountClear:Hide();
		end)

		flyingMountBorder:SetScript("OnMouseDown", function (self, button)
			TransmogFrame.WardrobeCollection:SetTab(TransmogFrame.WardrobeCollection.mountsTabID);
		 	PlaySound(SOUNDKIT.UI_TRANSMOG_GEAR_SLOT_CLICK);
		end)

		groundMountBorder:HookScript("OnEnter", function()
			GameTooltip:SetOwner(groundMountBorder, "ANCHOR_RIGHT")
			if MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Ground > 1 then
				GameTooltip:AddLine(MogMountSelectedMount.Ground.name);
				GameTooltip:AddLine("|cFFFFFFFF"..L["Item Slot Ground Mount Title"].."|r");
				GroundMountClear:Show();
			else
				GameTooltip:AddLine(L["Item Slot Ground Mount Title"]);
			end
			GameTooltip:Show();
			groundMountBorderHighlight:Show();
		end)

		groundMountBorder:HookScript("OnLeave", function()
			GameTooltip:Hide();
			groundMountBorderHighlight:Hide();
			GroundMountClear:Hide();
		end)

		groundMountBorder:SetScript("OnMouseDown", function (self, button)
			TransmogFrame.WardrobeCollection:SetTab(TransmogFrame.WardrobeCollection.mountsTabID);
			PlaySound(SOUNDKIT.UI_TRANSMOG_GEAR_SLOT_CLICK);
		end)

	end

end



local function OnFlyingMountSelectionChanged(self, data, selected)

	local button = FlyingMountListScrollBox:FindFrame(data);
	local children = {FlyingMountListScrollBox.ScrollTarget:GetChildren()};

	for i, child in ipairs(children) do
		child.isSelected = false
		child:UnlockHighlight();
	end
	if button ~= nil then
		if button.isSelected then
			button.isSelected = false
			button:UnlockHighlight();
		else
			button.isSelected = true
			button:LockHighlight();
		end
	end
end



local function OnGroundMountSelectionChanged(self, data, selected)

	local button = GroundMountListScrollBox:FindFrame(data);
	local children = {GroundMountListScrollBox.ScrollTarget:GetChildren()};

	for i, child in ipairs(children) do
		child.isSelected = false;
		child:UnlockHighlight();
	end

	if button ~= nil then
		if button.isSelected then
			button.isSelected = false;
			button:UnlockHighlight();
		else
			button.isSelected = true;
			button:LockHighlight();
		end
	end

end



function MissingKeybindOrMacro()

	local key1, key2 = '', '';
	key1, key2 = GetBindingKey("Mount/Dismount");

	local missingKeys = false;
	local missingMacro = true;

	if (not key1 or key1 == '') and (not key2 or key2 == '') then
		missingKeys = true;
	end

	for i = 1, 180 do
		if HasAction(i) then
			local actionType, actionId, macroIndex = GetActionInfo(i);
			if actionType == 'macro' then
				local currentMacroName, _, _ = GetMacroInfo(actionId);
				if currentMacroName == "MogMount" then
					missingMacro = false;
				end
			end
  		end
	end

	return missingMacro and missingKeys;

end

local CheckboxShowFlyingInGroundList;

local function ToggleGroundMountIncludeFlying()

	-- CheckboxShowFlyingInGroundList:IsSelected()

end



local function CreateShortcuts(f)

	local ShortcutSettings = CreateFrame("DropdownButton", "ShortcutSettings", f, "DamageMeterSettingsDropdownButtonTemplate");
	ShortcutSettings:SetPoint("TOPRIGHT", f, "TOPRIGHT", -26, -22);
	ShortcutSettings:SetPoint("CENTER");
	ShortcutSettings:SetupMenu(function(dropdown, rootDescription)
		rootDescription:CreateTitle("MogMount");
		rootDescription:CreateButton(L["Open Settings"], function() OpenSettingsToMogMount() end);
		rootDescription:CreateButton(L["Open Keybinds"], function() OpenKeybindingsToMogMount() end);
		rootDescription:CreateButton(L["Create Macro"], function() CreateMacroButton(ShortcutSettings) end);
	end)
	ShortcutSettings:Hide()

end



local function FilterIsChecked(filter)
	return MogMountSaved.ShowFlyingInGround;
end

local function FilterSetChecked(filter)

	if FilterIsChecked(filter) then
		MogMountSaved.ShowFlyingInGround = false;
	else
		MogMountSaved.ShowFlyingInGround = true;
	end
	mounts = MogMount:getSortedGroundMounts();

	local scrollToCount = 0;
	local scrollToIndex = 0;

	GroundMountDataProvider = CreateDataProvider();

	for i = 1, #mounts do
		local mount = mounts[i];
		scrollToCount = scrollToCount + 1;
		if mount.id == MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetActiveOutfitID()].Ground then
			scrollToIndex = scrollToCount;
		end
		GroundMountDataProvider:Insert(mount);
	end
	
	GroundMountListScrollView:SetDataProvider(GroundMountDataProvider);
	GroundMountListScrollBox:ScrollToElementDataIndex(scrollToIndex);

end



local function InitMountTab()

	if not TransmogFrame.WardrobeCollection.mountsTabID then

		hooksecurefunc(TransmogFrame.WardrobeCollection, "OnLoad", function()
			self.mountsTabID = self:AddNamedTab(L["Mount Tab Title"], self.TabContent.MountsFrame);
			self:UpdateTabs();
		end)

		function TransmogFrame.WardrobeCollection:UpdateTabs()
			self.TabHeaders:SetTabShown(self.itemsTabID, true);
			self.TabHeaders:SetTabShown(self.setsTabID, true);
			self.TabHeaders:SetTabShown(self.custmSetsTabID, true);
			self.TabHeaders:SetTabShown(self.situationsTabID, true);
			self.TabHeaders:SetTabShown(self.mountsTabID, true);
		end

		local s = 0.85714285714;

		local x, y = 360 * s, 360 * s;
		local inset = 12;
		local scale = 1;
		local columns, rows = 3, 4;
		local left, top = 18, 64;
		local spacing = 10;
		local count = 0;

		default = {};
		default.id = 1;
		default.name = "Default";
		default.icon = 1769016;
		default.model = 0;		

		local f = CreateFrame("Frame", "MountsFrame", TransmogFrame.WardrobeCollection.TabContent);
		f:SetAllPoints(true);
		f:SetFrameStrata("HIGH");
		f:Hide();

		--

		FilterDropdown = CreateFrame("DropdownButton", nil, f, "WowStyle1FilterDropdownTemplate");
		FilterDropdown:SetPoint("TOPRIGHT", f, "TOPRIGHT", -60, -24);
		FilterDropdown:SetWidth(104);		
		FilterDropdown.resizeToText = false;
		FilterDropdown:SetupMenu(function(dropdown, rootDescription)
			CheckboxShowFlyingInGroundList = rootDescription:CreateCheckbox(L["Show Flying In Ground Toggle"], FilterIsChecked, FilterSetChecked);
		end)

		---		

		MountListSearchBox = CreateFrame("EditBox", "MountListSearchBox", f, "TransmogSearchBoxTemplate");
		MountListSearchBox:SetPoint("TOPRIGHT", -174, -23); --- -32, -444

		local iconPostion, iconParent, iconParentPostion, iconX, iconY = MountListSearchBox.searchIcon:GetPoint();
		MountListSearchBox.searchIcon:SetPoint(iconPostion, iconParent, iconParentPostion, iconX, iconY + 1);

		---

		CreateSetupReminder(f);
		CreateShortcuts(f);

		ToggleReminder();

		--

		local FlyingSlotTitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge");
		FlyingSlotTitle:SetJustifyH("LEFT");
		FlyingSlotTitle:SetPoint("TOPLEFT", 24, -58);
		FlyingSlotTitle:SetText(L["Mount Tab Flying Section Title"]);

		local FlyingSlotTitleDivider = f:CreateTexture();
		FlyingSlotTitleDivider:SetAtlas("transmog-tabs-header-line", true);
		FlyingSlotTitleDivider:SetAlpha(0.1);
		FlyingSlotTitleDivider:SetPoint("TOPLEFT", FlyingSlotTitle, "BOTTOMLEFT", 0, -2);

		local GroundSlotTitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge");
		GroundSlotTitle:SetJustifyH("LEFT");
		GroundSlotTitle:SetPoint("TOPLEFT", 24, -444);
		GroundSlotTitle:SetText(L["Mount Tab Ground Section Title"]);

		local GroundSlotTitleDivider = f:CreateTexture();
		GroundSlotTitleDivider:SetAtlas("transmog-tabs-header-line", true);
		GroundSlotTitleDivider:SetAlpha(0.1);
		GroundSlotTitleDivider:SetPoint("TOPLEFT", GroundSlotTitle, "BOTTOMLEFT", 0, -2);

		--

		local flyingModelID, _, _, _, _, _, _, _, _ = C_MountJournal.GetMountInfoExtraByID(MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetActiveOutfitID()].Flying);
		local groundModelID, _, _, _, _, _, _, _, _ = C_MountJournal.GetMountInfoExtraByID(MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetActiveOutfitID()].Ground);

		--

		local FlyingMountPreview = CreateFrame("Frame", "MountTabFlyingPreview", f);
		FlyingMountPreview:SetPoint("TOPLEFT", f, "TOPLEFT", 24 * s, -114 * s);
		FlyingMountPreview:SetFrameStrata("HIGH");
		FlyingMountPreview:SetSize(x, y);
		FlyingMountPreview:SetParent(f);

		local FlyingMountPreviewBackground = FlyingMountPreview:CreateTexture(nil, "BACKGROUND");
		FlyingMountPreviewBackground:SetAtlas("professions-recipe-background");
		FlyingMountPreviewBackground:SetPoint("CENTER", FlyingMountPreview, "CENTER", 0, 0);
		FlyingMountPreviewBackground:SetSize(x - inset, y - inset);
		FlyingMountPreviewBackground:SetAlpha(1);
		FlyingMountPreviewBackground:SetVertexColor(0,0,0);

		FlyingMountModel = CreateFrame("PlayerModel", "MountTabFlyingModel", FlyingMountPreview);
		FlyingMountModel:SetPoint("CENTER", FlyingMountPreview, "CENTER", 0, 0);
		FlyingMountModel:SetSize(x - inset, y - inset);		
		FlyingMountModel:SetPortraitZoom(0);
		if flyingModelID ~= nil and flyingModelID > 0 then
			FlyingMountModel:SetDisplayInfo(flyingModelID);
			FlyingMountModel:SetAlpha(1);
		end
		-- FlyingMountModel:SetPosition(-0.2, -0.1, -0.1)
		FlyingMountModel:SetFacing(-5.5);

		local FlyingMountPreviewBorder = FlyingMountPreview:CreateTexture(nil, "OVERLAY");
		FlyingMountPreviewBorder:SetAtlas("transmog-itemCard-default", true);
		FlyingMountPreviewBorder:SetPoint("CENTER", FlyingMountPreview, "CENTER", 0, 0);
		FlyingMountPreviewBorder:SetSize(x, y);

		local _, _, _, xx, yy = FlyingMountPreview:GetPoint();
		local ww, hh = FlyingMountPreview:GetSize();
		local fw, fh = f:GetSize();
		local ii = 5;
		local gap = 16 * s;
		local r = 8;

		local FlyingMountList = CreateFrame("Frame", "FlyingMountList", f);
		FlyingMountList:SetPoint("TOPLEFT", f, "TOPLEFT", xx + gap + x, yy - ii);
		FlyingMountList:SetFrameStrata("HIGH");
		FlyingMountList:SetSize(fw - (xx + ww + gap + xx + r), y - (ii * 2));
		FlyingMountList:SetParent(f);

		--

		FlyingMountListScrollBox = CreateFrame("Frame", "FlyingMountListScrollBox", FlyingMountList, "WowScrollBoxList");
		local z, zz = FlyingMountList:GetSize() ;
		FlyingMountListScrollBox:SetSize(z - 40, zz - 4);
		FlyingMountListScrollBox:SetPoint("TOPLEFT", FlyingMountList, "TOPLEFT", 12, -2);

		local FlyingMountListScrollBar = CreateFrame("EventFrame", nil, FlyingMountList, "MinimalScrollBar");
		FlyingMountListScrollBar:SetPoint("TOPLEFT", FlyingMountListScrollBox, "TOPRIGHT", 10, -6);
		FlyingMountListScrollBar:SetPoint("BOTTOMLEFT", FlyingMountListScrollBox, "BOTTOMRIGHT", 10, 6);

		FlyingMountListScrollBar:SetHideIfUnscrollable(true);
		local FlyingMountDataProvider = CreateDataProvider();
		local FlyingMountListScrollView = CreateScrollBoxListLinearView();
		FlyingMountSelectionBehavior = ScrollUtil.AddSelectionBehavior(FlyingMountListScrollBox, SelectionBehaviorFlags.Intrusive);

		FlyingMountSelectionBehavior:RegisterCallback(SelectionBehaviorMixin.Event.OnSelectionChanged, OnFlyingMountSelectionChanged, self);

		function SetSelectedFlyingMount(value)

			selectedValue = value;
			name, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected, mountID, isSteadyFlight = C_MountJournal.GetMountInfoByID(value);
			creatureDisplayInfoID, description, source, isSelfMount, mountTypeID, uiModelSceneID, animID, spellVisualKitID, disablePlayerMountPreview = C_MountJournal.GetMountInfoExtraByID(value);

			MogMount:UpdateSelectMountDetails("Flying", value);

			if value == 1 then
				flyingIcon, _ = getEmptyMountIcon();
				flyingMountTexture:SetTexture(flyingIcon);
				flyingMountTexture:SetDesaturated(true);
				flyingMountTexture:SetVertexColor(0.63,0.63,0.63);
				flyingMountBorderTexture:SetAtlas("transmog-gearSlot-default");
				flyingMountBorderHighlightTexture:SetAtlas("transmog-gearSlot-default");
			else
				flyingMountTexture:SetTexture(icon);
				flyingMountTexture:SetDesaturated(false);
				flyingMountTexture:SetVertexColor(1,1,1);
				flyingMountBorderTexture:SetAtlas("transmog-gearSlot-transmogrified");
				flyingMountBorderHighlightTexture:SetAtlas("transmog-gearSlot-transmogrified");
			end

			flyingMountFrame.texture = flyingMountTexture;

			MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Flying = value;
			PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK);

		end	

		local function FlyingMountListInitializer(button, data)

			local isSelected = FlyingMountSelectionBehavior:IsElementDataSelected(data);

			if data.id == MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetActiveOutfitID()].Flying then
				isSelected = true;
			end

			button.Name:SetText("|T"..data.icon..":18|t "..data.name);
			button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight");
			button.MountID = data.id;

			if isSelected then
				button:LockHighlight();
			else
				button:UnlockHighlight();
			end

			button:SetScript("OnEnter", function()
				if FlyingMountModel:GetDisplayInfo() ~= data.model and data.model ~= nil then
					FlyingMountModel:SetDisplayInfo(data.model);
				end
				FlyingMountModel:SetAlpha(1);
			end)

			button:SetScript("OnLeave", function()
				SavedFlyingMoundID, _, _, _, _, _, _, _, _ = C_MountJournal.GetMountInfoExtraByID(MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Flying);
				if SavedFlyingMoundID ~= nil and SavedFlyingMoundID ~= data.model and SavedFlyingMoundID > 0 then
					FlyingMountModel:SetDisplayInfo(SavedFlyingMoundID);
				end
				if SavedFlyingMoundID == nil then
					FlyingMountModel:SetAlpha(0);
				end
			end)

			button:SetScript("OnClick", function()
				FlyingMountSelectionBehavior:Select(button);
				SetSelectedFlyingMount(data.id);
				SavedFlyingMoundID, _, _, _, _, _, _, _, _ = C_MountJournal.GetMountInfoExtraByID(MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Flying);
				if SavedFlyingMoundID ~= nil and SavedFlyingMoundID ~= data.model and SavedFlyingMoundID > 0 then
					FlyingMountModel:SetDisplayInfo(data.model);
				end	
				FlyingMountModel:SetAlpha(1);	
			end)

		end

		FlyingMountListScrollView:SetElementInitializer("MogMountListButtonTemplate", FlyingMountListInitializer);

		local mounts = MogMount:getSortedFlyingMounts();

		local scrollToCount = 0;
		local scrollToIndex = 0;

		for i = 1, #mounts do
			local mount = mounts[i];
			scrollToCount = scrollToCount + 1;
			if mount.id == MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetActiveOutfitID()].Flying then
				scrollToIndex = scrollToCount;
			end
			FlyingMountDataProvider:Insert(mount);
		end
		
		FlyingMountListScrollView:SetElementExtent(22);
		ScrollUtil.InitScrollBoxListWithScrollBar(FlyingMountListScrollBox, FlyingMountListScrollBar, FlyingMountListScrollView);
		FlyingMountListScrollView:SetDataProvider(FlyingMountDataProvider);

		FlyingMountListScrollBox:ScrollToElementDataIndex(scrollToIndex);

		--

		local FlyingMountListBackground = FlyingMountList:CreateTexture(nil, "OVERLAY");
		FlyingMountListBackground:SetAtlas("transmog-situations-containerbg", true);
		FlyingMountListBackground:SetAllPoints(true);

		local GroundMountPreview = CreateFrame("Frame", "MountTabGroundPreview", f);
		GroundMountPreview:SetPoint("TOPLEFT", f, "TOPLEFT", 24 * s, -564 * s);
		GroundMountPreview:SetFrameStrata("HIGH");
		GroundMountPreview:SetSize(x, y);
		GroundMountPreview:SetParent(f);

		local GroundMountPreviewBackground = GroundMountPreview:CreateTexture(nil, "BACKGROUND");
		GroundMountPreviewBackground:SetAtlas("professions-recipe-background");
		GroundMountPreviewBackground:SetPoint("CENTER", GroundMountPreview, "CENTER", 0, 0);
		GroundMountPreviewBackground:SetSize(x - inset, y - inset);
		GroundMountPreviewBackground:SetAlpha(1);
		GroundMountPreviewBackground:SetVertexColor(0,0,0);

		GroundMountModel = CreateFrame("PlayerModel", "MountTabGroundModel", GroundMountPreview);
		GroundMountModel:SetPoint("CENTER", GroundMountPreview, "CENTER", 0, 0);
		GroundMountModel:SetSize(x - inset, y - inset);
		GroundMountModel:SetPortraitZoom(0);
		if groundModelID ~= nil and groundModelID > 0 then
	   		GroundMountModel:SetDisplayInfo(groundModelID);
	   		GroundMountModel:SetAlpha(1);
	   	end
		GroundMountModel:SetPosition(-0.2, -0.1, -0.1);
		GroundMountModel:SetFacing(-5.5);

		local GroundMountPreviewBorder = GroundMountPreview:CreateTexture(nil, "OVERLAY");
		GroundMountPreviewBorder:SetAtlas("transmog-itemCard-default", true);
		GroundMountPreviewBorder:SetPoint("CENTER", GroundMountPreview, "CENTER", 0, 0);
		GroundMountPreviewBorder:SetSize(x, y);

		local _, _, _, xx, yy = GroundMountPreview:GetPoint();
		local ww, hh = GroundMountPreview:GetSize();

		local GroundMountList = CreateFrame("Frame", "MountTabGroundPreview", f);
		GroundMountList:SetPoint("TOPLEFT", f, "TOPLEFT", xx + gap + x, yy - ii);
		GroundMountList:SetFrameStrata("HIGH");
		GroundMountList:SetSize(fw - (xx + ww + gap + xx + r), y - (ii * 2));
		GroundMountList:SetParent(f);

		local GroundMountListBackground = GroundMountList:CreateTexture(nil, "BACKGROUND");
		GroundMountListBackground:SetAtlas("transmog-situations-containerbg", true);
		GroundMountListBackground:SetAllPoints(true);

		--

		GroundMountListScrollBox = CreateFrame("Frame", "GroundMountListScrollBox", GroundMountList, "WowScrollBoxList");
		local z, zz = GroundMountList:GetSize();
		GroundMountListScrollBox:SetSize(z - 40, zz - 4);
		GroundMountListScrollBox:SetPoint("TOPLEFT", GroundMountList, "TOPLEFT", 12, -2);

		local GroundMountListScrollBar = CreateFrame("EventFrame", nil, GroundMountList, "MinimalScrollBar");
		GroundMountListScrollBar:SetPoint("TOPLEFT", GroundMountListScrollBox, "TOPRIGHT", 10, -6);
		GroundMountListScrollBar:SetPoint("BOTTOMLEFT", GroundMountListScrollBox, "BOTTOMRIGHT", 10, 6);

		GroundMountListScrollBar:SetHideIfUnscrollable(true);
		local GroundMountDataProvider = CreateDataProvider();
		GroundMountListScrollView = CreateScrollBoxListLinearView();
		GroundMountSelectionBehavior = ScrollUtil.AddSelectionBehavior(GroundMountListScrollBox, SelectionBehaviorFlags.Intrusive);

		GroundMountSelectionBehavior:RegisterCallback(SelectionBehaviorMixin.Event.OnSelectionChanged, OnGroundMountSelectionChanged, self);

		function SetSelectedGroundMount(value)

			selectedValue = value;
			name, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected, mountID, isSteadyFlight = C_MountJournal.GetMountInfoByID(value);
			creatureDisplayInfoID, description, source, isSelfMount, mountTypeID, uiModelSceneID, animID, spellVisualKitID, disablePlayerMountPreview = C_MountJournal.GetMountInfoExtraByID(value);

			MogMount:UpdateSelectMountDetails("Ground", value);

			if value == 1 then
				_, groundIcon = getEmptyMountIcon();
				groundMountTexture:SetTexture(groundIcon);
				groundMountTexture:SetDesaturated(true);
				groundMountTexture:SetVertexColor(0.63,0.63,0.63);
				groundMountBorderTexture:SetAtlas("transmog-gearSlot-default");
				groundMountBorderHighlightTexture:SetAtlas("transmog-gearSlot-default");
			else
				groundMountTexture:SetTexture(icon);
				groundMountTexture:SetDesaturated(false);
				groundMountTexture:SetVertexColor(1,1,1);
				groundMountBorderTexture:SetAtlas("transmog-gearSlot-transmogrified");
				groundMountBorderHighlightTexture:SetAtlas("transmog-gearSlot-transmogrified");
			end

			groundMountFrame.texture = groundMountTexture;

			MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Ground = value;
			PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK);

		end	

		local function GroundMountListInitializer(button, data)

			local isSelected = GroundMountSelectionBehavior:IsElementDataSelected(data);

			if data.id == MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetActiveOutfitID()].Ground then
				isSelected = true;
			end

			button.Name:SetText("|T"..data.icon..":18|t "..data.name);
			button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight");
			button.MountID = data.id;

			if isSelected then
				button:LockHighlight();
			else
				button:UnlockHighlight();
			end

			button:SetScript("OnEnter", function()
				if GroundMountModel:GetDisplayInfo() ~= data.model and data.model ~= nil then
					GroundMountModel:SetDisplayInfo(data.model);
				end
				GroundMountModel:SetAlpha(1);
			end)

			button:SetScript("OnLeave", function()
				SavedGroundMoundID, _, _, _, _, _, _, _, _ = C_MountJournal.GetMountInfoExtraByID(MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Ground);
				if SavedGroundMoundID ~= nil and SavedGroundMoundID ~= data.model and SavedGroundMoundID > 0 then
					GroundMountModel:SetDisplayInfo(SavedGroundMoundID);
					GroundMountModel:SetAlpha(1);
				end
				if SavedGroundMoundID == nil then
					GroundMountModel:SetAlpha(0);
				end
			end)

			button:SetScript("OnClick", function()
				GroundMountSelectionBehavior:Select(button);
				SetSelectedGroundMount(data.id);
				SavedGroundMoundID, _, _, _, _, _, _, _, _ = C_MountJournal.GetMountInfoExtraByID(MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Ground);
				if SavedGroundMoundID ~= nil and SavedGroundMoundID ~= data.model and SavedGroundMoundID > 0 then
					GroundMountModel:SetDisplayInfo(data.model);
				end
				GroundMountModel:SetAlpha(1);				
			end)

		end

		GroundMountListScrollView:SetElementInitializer("MogMountListButtonTemplate", GroundMountListInitializer);

		mounts = MogMount:getSortedGroundMounts();

		local scrollToCount = 0;
		local scrollToIndex = 0;

		for i = 1, #mounts do
			local mount = mounts[i];
			if mount.mountTypeID == 230 then
				scrollToCount = scrollToCount + 1;
				if mount.id == MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetActiveOutfitID()].Ground then
					scrollToIndex = scrollToCount;
				end
				GroundMountDataProvider:Insert(mount);
			end
		end
		
		GroundMountListScrollView:SetElementExtent(22);
		ScrollUtil.InitScrollBoxListWithScrollBar(GroundMountListScrollBox, GroundMountListScrollBar, GroundMountListScrollView);
		GroundMountListScrollView:SetDataProvider(GroundMountDataProvider);

		GroundMountListScrollBox:ScrollToElementDataIndex(scrollToIndex);

		---

		MountListSearchBox:SetScript("OnTextChanged", function()

			MogMount.MountSearchString = MountListSearchBox:GetText();

			if string.len(MogMount.MountSearchString) > 0 then
				MountListSearchBox.Instructions:Hide();
			else
				MountListSearchBox.Instructions:Show();
			end

			local mounts = MogMount:getSortedFlyingMounts();

			local scrollToCount = 0;
			local scrollToIndex = 0;

			FlyingMountDataProvider = CreateDataProvider();

			for i = 1, #mounts do
				local mount = mounts[i];
				scrollToCount = scrollToCount + 1;
				if mount.id == MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetActiveOutfitID()].Flying then
					scrollToIndex = scrollToCount;
				end	
				FlyingMountDataProvider:Insert(mount);
			end
			
			FlyingMountListScrollView:SetElementExtent(22);
			ScrollUtil.InitScrollBoxListWithScrollBar(FlyingMountListScrollBox, FlyingMountListScrollBar, FlyingMountListScrollView);
			FlyingMountListScrollView:SetDataProvider(FlyingMountDataProvider);

			FlyingMountListScrollBox:ScrollToElementDataIndex(scrollToIndex);

			--

			mounts = MogMount:getSortedGroundMounts();

			local scrollToCount = 0;
			local scrollToIndex = 0;

			GroundMountDataProvider = CreateDataProvider();

			for i = 1, #mounts do
				local mount = mounts[i];
				scrollToCount = scrollToCount + 1;
				if mount.id == MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetActiveOutfitID()].Ground then
					scrollToIndex = scrollToCount;
				end
				GroundMountDataProvider:Insert(mount);
			end
			
			GroundMountListScrollView:SetElementExtent(22);
			ScrollUtil.InitScrollBoxListWithScrollBar(GroundMountListScrollBox, GroundMountListScrollBar, GroundMountListScrollView);
			GroundMountListScrollView:SetDataProvider(GroundMountDataProvider);

			GroundMountListScrollBox:ScrollToElementDataIndex(scrollToIndex);

		end)

		--		
	
		TransmogFrame.WardrobeCollection.mountsTabID = TransmogFrame.WardrobeCollection:AddNamedTab(L["Mount Tab Title"], MountsFrame);
		TransmogFrame.WardrobeCollection:UpdateTabs();
	
	end

	ToggleReminder();

end



function CreateSetupReminder(f)

	SetupReminderFrame = CreateFrame("Frame", SetupReminderFrame, f);
	SetupReminderFrame:SetAllPoints(f);
	SetupReminderFrame:SetParent(f);

	local SetupReminderIcon = SetupReminderFrame:CreateTexture(nil,"BACKGROUND");
	SetupReminderIcon:SetAtlas("transmog-icon-warning");
	SetupReminderIcon:SetSize(20,20);
	SetupReminderIcon:SetPoint("TOPLEFT", 24, -24);	

	local SetupReminderText = SetupReminderFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	SetupReminderText:SetJustifyH("LEFT");
	SetupReminderText:SetPoint("TOPLEFT", 48, -28);
	SetupReminderText:SetText("|cFFE36F1B"..L["Setup Reminder"].."|r");

	characterWidth = 8;
	buttonPadding = 12;

	local CreateMacroButtonFrame = CreateFrame("Button", "CreateMacroButtonFrame", SetupReminderFrame, "UIPanelButtonTemplate");
	CreateMacroButtonFrame:SetPoint("TOPRIGHT", SetupReminderFrame, "TOPRIGHT", -26, -22);
	length = string.len(L["Create Macro"]);
	CreateMacroButtonFrame:SetSize(length * characterWidth + buttonPadding, 22);
	CreateMacroButtonFrame:SetText(L["Create Macro"]);

	local OpenKeybindingsButton = CreateFrame("Button", "CreateMacroButtonFrame", SetupReminderFrame, "UIPanelButtonTemplate");
	OpenKeybindingsButton:SetPoint("TOPRIGHT", SetupReminderFrame, "TOPRIGHT", (-1 * length * characterWidth) - buttonPadding - 26 - 8, -22);
	length = string.len(L["Open Keybinds"]);
	OpenKeybindingsButton:SetSize(length * characterWidth + buttonPadding, 22);
	OpenKeybindingsButton:SetText(L["Open Keybinds"]);

	OpenKeybindingsButton:SetScript("OnClick", function()
		OpenKeybindingsToMogMount();
	end)	

	CreateMacroButtonFrame:SetScript("OnMouseDown", function()
		CreateMacroButton(CreateMacroButtonFrame);
	end)

end



function ClearSelectedFlyingMount()

	FlyingMountModel:SetAlpha(0);

	children = {FlyingMountListScrollBox.ScrollTarget:GetChildren()};

	for i, child in ipairs(children) do
		child.isSelected = false;
		child:UnlockHighlight();						
	end   

	FlyingMountListScrollBox:ScrollToElementDataIndex(1);

end



function ClearSelectedGroundMount()

	GroundMountModel:SetAlpha(0);

	children = {GroundMountListScrollBox.ScrollTarget:GetChildren()};

	for i, child in ipairs(children) do
		child.isSelected = false;
		child:UnlockHighlight();						
	end   

	GroundMountListScrollBox:ScrollToElementDataIndex(1);

end



function UpdateSelectedMountRow()

	if FlyingMountListScrollBox then

		ClearSelectedFlyingMount();

		mounts = MogMount:getSortedFlyingMounts();

		for i = 1, #mounts do
			local mount = mounts[i];
			if mount.id == MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Flying then
				FlyingMountListScrollBox:ScrollToElementDataIndex(i);
				children = {FlyingMountListScrollBox.ScrollTarget:GetChildren()};
				for j, child in ipairs(children) do
					if child.MountID == mount.id then
						FlyingMountSelectionBehavior:Select(child);
						if mount.model ~= nil then
							FlyingMountModel:SetDisplayInfo(mount.model);
							FlyingMountModel:SetAlpha(1);
						end
					else
						child.isSelected = false;
						child:UnlockHighlight();
			   		end
				end				
			end
		end

	end

	if GroundMountListScrollBox then

		ClearSelectedGroundMount();

		mounts = MogMount:getSortedGroundMounts();

		for i = 1, #mounts do
			local mount = mounts[i];
			if mount.id == MogMountCharacterSaved["Outfit"..C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()].Ground then
				GroundMountListScrollBox:ScrollToElementDataIndex(i);
				children = {GroundMountListScrollBox.ScrollTarget:GetChildren()};
				for j, child in ipairs(children) do
					if child.MountID == mount.id then
						GroundMountSelectionBehavior:Select(child);
						GroundMountModel:SetDisplayInfo(mount.model);
						GroundMountModel:SetAlpha(1);
					else
						child.isSelected = false;
						child:UnlockHighlight();						
			   		end
				end				
			end
		end

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

		InitTransmog(firstLoad);

		InitTitles(firstLoad);

		C_Timer.After(0.1, function()
			UpdateSelectedMountRow();
		end)

		firstLoad = false;

	end		



	if event == "TRANSMOGRIFY_OPEN" then

		C_Timer.After(0.1, function()
			InitMountTab();
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
