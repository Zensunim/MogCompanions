-- Pets.lua
-- Companion pet slot + pets tab UI for the wardrobe Companions panel.
-- This module only handles selection and preview UI; summoning behavior remains separate.
local _, addon = ...;
local ns = select(2, ...);
local MogCompanions = ns.MogCompanions;
local L = MogCompanionsLocales;

local PET_EMPTY_ICON = 656575;

local PetsFrame;
local PetFrame;
local PetTexture;
local PetBorder;
local PetBorderTexture;
local PetBorderHighlight;
local PetBorderHighlightTexture;
local PetClear;

local PetPreview;
local PetModel;
local PetPreviewControls;

local PetsSearchBox;
local PetsDataProvider;
local PetsScrollView;
local PetsListScrollBox;
local PetsSlotTitle;
local PetShowSelectedButton;
local PetNoResultsText;
local PetsInitScheduled = false;
local RefreshPetList;
local PetDetailsCache = {};
local LastClickedPetID;
local ShowOnlySelectedPets = false;

MogCompanions.PetSearchString = "";

local function GetViewedOutfitID()
	if C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID then
		return C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID();
	end

	return nil;
end

local function GetOutfitTable(outfitID)
	if outfitID == nil or MogCompanionsCharacterSaved == nil then
		return nil;
	end

	MogCompanions:CreateEmptyOutfit(outfitID);

	return MogCompanionsCharacterSaved["Outfit"..outfitID];
end

local function GetPetJournalInfo(petID)
	if petID == nil or petID == "" or C_PetJournal == nil or C_PetJournal.GetPetInfoByPetID == nil then
		return nil;
	end

	if C_PetJournal.GetPetInfoTableByPetID ~= nil then
		return C_PetJournal.GetPetInfoTableByPetID(petID);
	end

	local speciesID, customName, level, xp, maxXp, displayID, favorite, name, icon = C_PetJournal.GetPetInfoByPetID(petID);
	if name == nil or icon == nil then
		return nil;
	end

	return {
		speciesID = speciesID,
		customName = customName,
		displayID = displayID,
		name = name,
		icon = icon,
	};
end

local function GetPetDataByGUID(petID)
	if petID == nil or petID == "" then
		return nil;
	end

	if PetDetailsCache[petID] ~= nil then
		return PetDetailsCache[petID];
	end

	local info = GetPetJournalInfo(petID);
	if info == nil or info.name == nil or info.icon == nil then
		return nil;
	end

	if info.isRevoked == true or info.canBattle == false then
		return nil;
	end

	local displayName;
	if info.customName ~= nil and info.customName ~= "" then
		displayName = info.customName .. " (" .. info.name .. ")";
	else
		displayName = info.name;
	end

	PetDetailsCache[petID] = {
		id = petID,
		name = displayName,
		customName = info.customName,
		speciesName = info.name,
		icon = info.icon,
		displayID = info.displayID,
		speciesID = info.speciesID,
	};

	return PetDetailsCache[petID];
end

local function IsValidPetSelection(petID)
	return type(petID) == "string" and petID ~= "" and GetPetDataByGUID(petID) ~= nil;
end

local function ValidatePetSelection(_, petID)
	return IsValidPetSelection(petID);
end

local function GetValidPetSelectionValues(outfit)
	return MogCompanions:GetValidSelectionPoolValues(outfit, "Pets", ValidatePetSelection);
end

local function GetValidPetSelection(outfit, preferLast, preferredPetID)
	if outfit == nil then
		return "";
	end

	if IsValidPetSelection(preferredPetID) then
		return preferredPetID;
	end

	local validSelections = GetValidPetSelectionValues(outfit);
	if #validSelections == 0 then
		return "";
	end

	if preferLast then
		return validSelections[#validSelections];
	end

	return validSelections[1];
end

local function SyncLegacyPetSelection(outfit)
	if outfit == nil then
		return "";
	end

	local petID = GetValidPetSelection(outfit, false);
	outfit.Pet = petID;
	return petID;
end

local function GetValidPetDataSelections(outfit)
	local validSelections = GetValidPetSelectionValues(outfit);
	local pets = {};

	for i = 1, #validSelections do
		local pet = GetPetDataByGUID(validSelections[i]);
		if pet ~= nil then
			table.insert(pets, pet);
		end
	end

	table.sort(pets, MogCompanionsSortAlphabetical);

	return pets;
end

local function PetMatchesSearch(pet)
	local searchString = MogCompanions.PetSearchString;
	if searchString == nil or searchString == "" then
		return true;
	end

	local lowered = searchString:lower();
	local displayName = pet ~= nil and pet.name or "";
	local speciesName = pet ~= nil and pet.speciesName or "";

	return string.find(displayName:lower(), lowered, 1, true) ~= nil
		or string.find(speciesName:lower(), lowered, 1, true) ~= nil;
end

local function GetFilteredNormalPets()
	local pets = MogCompanions:GetSortedPets();
	local filtered = {};

	for i = 1, #pets do
		if IsValidPetSelection(pets[i].id) then
			table.insert(filtered, pets[i]);
		end
	end

	return filtered;
end

local function GetFilteredSelectedPets(outfit)
	local pets = GetValidPetDataSelections(outfit);
	local filtered = {};

	for i = 1, #pets do
		if PetMatchesSearch(pets[i]) then
			table.insert(filtered, pets[i]);
		end
	end

	return filtered;
end

local function SetPetsSectionTitle(count)
	if PetsSlotTitle == nil then
		return;
	end

	if count > 0 then
		PetsSlotTitle:SetText(L["Pets Tab Section Title"].." "..string.format(L["Selected Count Format"], count));
	else
		PetsSlotTitle:SetText(L["Pets Tab Section Title"]);
	end
end

local function GetPetTooltipLines(outfit)
	local pets = GetValidPetDataSelections(outfit);
	local tooltipLines = {};

	if #pets > 0 then
		table.insert(tooltipLines, string.format(L["Random From Selected Pets"], #pets));

		for i = 1, math.min(3, #pets) do
			table.insert(tooltipLines, "|T"..pets[i].icon..":18|t "..pets[i].name);
		end

		if #pets > 3 then
			table.insert(tooltipLines, string.format(L["More Selected Pets"], #pets - 3));
		end
	end

	return tooltipLines, #pets;
end

local function GetSelectedPet(outfitID)
	local outfit = GetOutfitTable(outfitID);
	local petID = GetValidPetSelection(outfit, false);

	if petID == nil or petID == "" then
		return nil;
	end

	return GetPetDataByGUID(petID);
end

local function EnsurePetModel()
	if PetPreview == nil then
		return nil;
	end

	if PetModel == nil then
		PetModel = CreateFrame("PlayerModel", "MogCompanionsPetModel", PetPreview);
		PetModel:SetPoint("TOPLEFT", PetPreview, "TOPLEFT", 12, -12);
		PetModel:SetPoint("BOTTOMRIGHT", PetPreview, "BOTTOMRIGHT", -12, 12);
		PetModel:SetPortraitZoom(0);
		PetModel:SetFacing(0.35);
		PetModel:SetAlpha(0);
		PetPreviewControls = MogCompanions:AttachPreviewModelControls(PetPreview, PetModel, {
			zoom = 1,
			minZoom = 0.4,
			maxZoom = 3.0,
			facing = 0.35,
			x = 0,
			y = 0,
			z = 0,
			buttonOffsetY = -8,
			controlNamePrefix = "MogCompanionsPetPreview",
		});
	end

	return PetModel;
end

local function UpdatePetPreview(pet)
	if type(pet) ~= "table" then
		pet = GetPetDataByGUID(pet);
	elseif pet.displayID == nil and pet.id ~= nil then
		pet = GetPetDataByGUID(pet.id);
	end

	if pet ~= nil and pet.displayID ~= nil and pet.displayID > 0 then
		local petModel = EnsurePetModel();
		if petModel == nil then
			return;
		end

		petModel:SetDisplayInfo(pet.displayID);
		if PetPreviewControls ~= nil then
			PetPreviewControls.reset();
		end
		petModel:SetAlpha(1);
	elseif PetModel ~= nil then
		PetModel:SetDisplayInfo(0);
		if PetPreviewControls ~= nil then
			PetPreviewControls.reset();
		end
		PetModel:SetAlpha(0);
	end
end

local function UpdatePetSlot()
	if PetFrame == nil or PetTexture == nil then
		return;
	end

	local outfit = GetOutfitTable(GetViewedOutfitID());
	local petID = SyncLegacyPetSelection(outfit);
	local pet = GetPetDataByGUID(petID);

	if pet ~= nil then
		PetTexture:SetTexture(pet.icon);
		PetTexture:SetDesaturated(false);
		PetTexture:SetVertexColor(1, 1, 1);
		PetBorderTexture:SetAtlas("transmog-gearSlot-transmogrified");
		PetBorderHighlightTexture:SetAtlas("transmog-gearSlot-transmogrified");
	else
		PetTexture:SetTexture(PET_EMPTY_ICON);
		PetTexture:SetDesaturated(true);
		PetTexture:SetVertexColor(0.63, 0.63, 0.63);
		PetBorderTexture:SetAtlas("transmog-gearSlot-default");
		PetBorderHighlightTexture:SetAtlas("transmog-gearSlot-default");
	end

	PetTexture:SetAllPoints(PetFrame);
	PetFrame.texture = PetTexture;
	SetPetsSectionTitle(select(2, GetPetTooltipLines(outfit)));
	UpdatePetPreview(GetValidPetSelection(outfit, false, LastClickedPetID));
end

RefreshPetList = function(scrollToSelection)
	if PetsScrollView == nil then
		return;
	end

	local outfit = GetOutfitTable(GetViewedOutfitID());
	if outfit ~= nil then
		MogCompanions:PruneInvalidSelectionPool(outfit, "Pets", ValidatePetSelection);
		SyncLegacyPetSelection(outfit);
	end

	local selectedCount = #GetValidPetSelectionValues(outfit);
	if selectedCount <= 0 then
		ShowOnlySelectedPets = false;
	end

	local pets;
	if ShowOnlySelectedPets then
		pets = GetFilteredSelectedPets(outfit);
	else
		pets = GetFilteredNormalPets();
	end

	local selectedPetID = GetValidPetSelection(outfit, false);

	PetsDataProvider = CreateDataProvider(pets);
	PetsScrollView:SetDataProvider(PetsDataProvider);

	if scrollToSelection and PetsListScrollBox ~= nil and selectedPetID ~= nil and selectedPetID ~= "" then
		for i = 1, #pets do
			if pets[i].id == selectedPetID then
				PetsListScrollBox:ScrollToElementDataIndex(i);
				break;
			end
		end
	end

	SetPetsSectionTitle(selectedCount);
	MogCompanions:UpdateShowSelectedButton(PetShowSelectedButton, ShowOnlySelectedPets, selectedCount);
	MogCompanions:UpdateNoResultsText(PetNoResultsText, PetsSearchBox, #pets);
end

local function SetSelectedPet(petID)
	local outfit = GetOutfitTable(GetViewedOutfitID());

	if outfit == nil then
		return;
	end

	if petID == nil then
		petID = "";
	end

	if petID ~= "" and not IsValidPetSelection(petID) then
		return;
	end

	LastClickedPetID = petID;

	if petID == "" then
		MogCompanions:ClearSelectionPool(outfit, "Pets");
	else
		MogCompanions:ToggleSelectionPoolValue(outfit, "Pets", petID);
	end

	SyncLegacyPetSelection(outfit);

	UpdatePetSlot();
	UpdatePetPreview(GetValidPetSelection(outfit, false, LastClickedPetID));
	RefreshPetList(false);

	if PlaySound ~= nil and SOUNDKIT ~= nil and SOUNDKIT.UI_TRANSMOG_ITEM_CLICK ~= nil then
		PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK);
	end
	end

local function ClearSelectedPet()
	ShowOnlySelectedPets = false;
	LastClickedPetID = nil;
	SetSelectedPet("");
	if PetClear ~= nil then
		PetClear:Hide();
	end
end

local function EnsureOutfitPetSaved()
	if MogCompanionsCharacterSaved == nil or C_TransmogOutfitInfo == nil or C_TransmogOutfitInfo.GetOutfitsInfo == nil then
		return;
	end

	local outfits = C_TransmogOutfitInfo.GetOutfitsInfo();

	if outfits == nil then
		return;
	end

	for i = 1, #outfits do
		MogCompanions:CreateEmptyOutfit(outfits[i].outfitID);
	end

	local viewedOutfitID = GetViewedOutfitID();
	if viewedOutfitID ~= nil then
		MogCompanions:CreateEmptyOutfit(viewedOutfitID);
	end
	end

local function CreatePetSlot()
	if PetFrame ~= nil or _G.MogCompanionsFrame == nil then
		return;
	end

	local borderSize = 59;
	local borderOffset = 7;

	PetFrame = CreateFrame("Frame", "MogCompanionsPetFrame", _G.MogCompanionsFrame);
	PetFrame:SetFrameStrata("MEDIUM");
	PetFrame:SetSize(44, 44);
	PetFrame:SetPoint("TOPLEFT", _G.MogCompanionsFrame, "TOPLEFT", 0, MogCompanions.TransmogSlotOffsets.Pet);
	PetFrame:Show();

	PetTexture = PetFrame:CreateTexture(nil, "BACKGROUND");

	PetBorder = CreateFrame("Frame", "MogCompanionsPetBorder", PetFrame);
	PetBorder:SetFrameStrata("HIGH");
	PetBorder:SetSize(borderSize, borderSize);
	PetBorder:SetPoint("TOPLEFT", PetFrame, "TOPLEFT", borderOffset * -1, borderOffset);
	PetBorder:Show();

	PetBorderTexture = PetBorder:CreateTexture(nil, "BACKGROUND");
	PetBorderTexture:SetAtlas("transmog-gearSlot-default");
	PetBorderTexture:SetAllPoints(PetBorder);
	PetBorder.texture = PetBorderTexture;

	PetBorderHighlight = CreateFrame("Frame", "MogCompanionsPetBorderHighlight", PetFrame);
	PetBorderHighlight:SetFrameStrata("HIGH");
	PetBorderHighlight:SetSize(borderSize, borderSize);
	PetBorderHighlight:SetPoint("TOPLEFT", PetFrame, "TOPLEFT", borderOffset * -1, borderOffset);
	PetBorderHighlight:Hide();

	PetBorderHighlightTexture = PetBorderHighlight:CreateTexture(nil, "BACKGROUND");
	PetBorderHighlightTexture:SetAtlas("transmog-gearSlot-default");
	PetBorderHighlightTexture:SetAllPoints(PetBorderHighlight);
	PetBorderHighlightTexture:SetBlendMode("ADD");
	PetBorderHighlight.texture = PetBorderHighlightTexture;

	PetClear = CreateFrame("Button", "MogCompanionsPetClearButton", PetBorder, "UIResetButtonTemplate");
	PetClear:SetPoint("CENTER", PetBorder, "TOPRIGHT", -8, -8);
	PetClear:Hide();
	PetClear:SetScript("OnEnter", function()
		GameTooltip:SetOwner(PetClear, "ANCHOR_RIGHT");
		GameTooltip:SetText(L["Item Slot Pet Clear Tooltip"]);
		GameTooltip:Show();
		PetClear:Show();
	end)
	PetClear:SetScript("OnLeave", function()
		PetClear:Hide();
		GameTooltip:Hide();
	end)
	PetClear:SetScript("OnClick", function()
		ClearSelectedPet();
	end)

	PetBorder:HookScript("OnEnter", function()
		GameTooltip:SetOwner(PetBorder, "ANCHOR_RIGHT");

		local outfit = GetOutfitTable(GetViewedOutfitID());
		local tooltipLines, count = GetPetTooltipLines(outfit);

		if count > 0 then
			GameTooltip:AddLine(L["Item Slot Pet Title"]);
			for i = 1, #tooltipLines do
				GameTooltip:AddLine(tooltipLines[i], 1, 1, 1);
			end
			PetClear:Show();
		else
			GameTooltip:SetText(L["Item Slot Pet Title"]);
		end
		GameTooltip:Show();
		PetBorderHighlight:Show();
	end)

	PetBorder:HookScript("OnLeave", function()
		GameTooltip:Hide();
		PetBorderHighlight:Hide();
		PetClear:Hide();
	end)

	PetBorder:SetScript("OnMouseDown", function()
		MogCompanions:OpenCompanionsTab("Pets");
		PlaySound(SOUNDKIT.UI_TRANSMOG_GEAR_SLOT_CLICK);
	end)

	UpdatePetSlot();
	end

function MogCompanions:CreatePetMacro(parent)
	if InCombatLockdown and InCombatLockdown() then
		print(L["Macro Combat Error"]);
		return nil;
	end

	local macroId = false;
	for i = 1, 120 do
		if C_Macro.GetMacroName(i) == "MComp Pets" then
			macroId = i;
		end
	end

	local macroIcon = 656575;
	local showTooltipLine = "#showtooltip";
	local outfitData = MogCompanions:GetActiveOutfitTable();
	local selectedPet = outfitData and GetPetDataByGUID(SyncLegacyPetSelection(outfitData));
	if selectedPet ~= nil then
		macroIcon = selectedPet.icon or macroIcon;
		showTooltipLine = showTooltipLine .. " " .. selectedPet.name;
	end

	local macroBody = showTooltipLine.."\n/mcomp pet";
	if not macroId then
		macroId = CreateMacro("MComp Pets", macroIcon, macroBody, nil);
	else
		EditMacro(macroId, "MComp Pets", macroIcon, macroBody, nil);
	end

	if parent ~= nil then
		PickupMacro(macroId);
		GameTooltip:SetOwner(parent, "ANCHOR_CURSOR_RIGHT");
		GameTooltip:AddLine(L["Drop Pet Macro Tooltip"], 1, 1, 1);
		GameTooltip:Show();
	end

	return macroId;
end

-- Creates the pets tab page: preview model on the left and scrollable pet list on the right.
-- Idempotent: reparents the existing frame if needed and refreshes the list contents.
function MogCompanions:CreatePetsFrame(parent)
	if parent == nil then
		return nil;
	end

	if PetsFrame ~= nil then
		if PetsFrame:GetParent() ~= parent then
			PetsFrame:SetParent(parent);
			PetsFrame:ClearAllPoints();
			PetsFrame:SetAllPoints(parent);
		end

		return PetsFrame;
	end

	PetsFrame = CreateFrame("Frame", "MogCompanionsPetsFrame", parent);
	PetsFrame:SetAllPoints(parent);
	PetsFrame:Hide();

	local topOffset = 26;
	local listRightInset = 28;
	local previewWidth = 308;
	local previewInset = 12;

	local PetsShortcuts = MogCompanions:CreateCompanionsShortcutMenu(PetsFrame, "MogCompanionsPetsShortcuts");
	PetsShortcuts:SetPoint("TOPRIGHT", PetsFrame, "TOPRIGHT", -26, -50 + topOffset);

	-- Search box aligned directly beside the gear shortcut button.
	PetsSearchBox = CreateFrame("EditBox", "MogCompanionsPetsSearchBox", PetsFrame, "TransmogSearchBoxTemplate");
	PetsSearchBox:SetPoint("TOPRIGHT", PetsShortcuts, "TOPLEFT", -8, 0);
	if PetsSearchBox.searchIcon ~= nil then
		local iconPos, iconParent, iconParentPos, iconX, iconY = PetsSearchBox.searchIcon:GetPoint();
		PetsSearchBox.searchIcon:SetPoint(iconPos, iconParent, iconParentPos, iconX, iconY + 1);
	end
	PetsSearchBox:SetScript("OnTextChanged", function(self)
		if SearchBoxTemplate_OnTextChanged ~= nil then
			SearchBoxTemplate_OnTextChanged(self);
		end

		MogCompanions.PetSearchString = self:GetText() or "";
		RefreshPetList(true);
	end)

	-- Section title (matching the Mounts tab layout style)
	PetsSlotTitle = PetsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge");
	PetsSlotTitle:SetJustifyH("LEFT");
	PetsSlotTitle:SetPoint("TOPLEFT", PetsFrame, "TOPLEFT", 24, -76 + topOffset);
	PetsSlotTitle:SetText(L["Pets Tab Section Title"]);

	local PetsSlotTitleDivider = PetsFrame:CreateTexture();
	PetsSlotTitleDivider:SetAtlas("transmog-tabs-header-line", true);
	PetsSlotTitleDivider:SetAlpha(0.1);
	PetsSlotTitleDivider:SetPoint("TOPLEFT", PetsSlotTitle, "BOTTOMLEFT", 0, -2);

	PetPreview = CreateFrame("Frame", "MogCompanionsPetPreview", PetsFrame);
	PetPreview:SetPoint("TOPLEFT", PetsFrame, "TOPLEFT", 24, -113 + topOffset);
	PetPreview:SetPoint("BOTTOMLEFT", PetsFrame, "BOTTOMLEFT", 24, 42);
	PetPreview:SetWidth(previewWidth);
	PetPreview:SetFrameStrata("HIGH");

	local PetsPreviewBackground = PetPreview:CreateTexture(nil, "BACKGROUND");
	PetsPreviewBackground:SetAtlas("professions-recipe-background");
	PetsPreviewBackground:SetPoint("TOPLEFT", PetPreview, "TOPLEFT", 6, -6);
	PetsPreviewBackground:SetPoint("BOTTOMRIGHT", PetPreview, "BOTTOMRIGHT", -6, 6);
	PetsPreviewBackground:SetAlpha(1);
	PetsPreviewBackground:SetVertexColor(0, 0, 0);

	local PetsPreviewBorder = PetPreview:CreateTexture(nil, "OVERLAY");
	PetsPreviewBorder:SetAtlas("transmog-itemCard-default", true);
	PetsPreviewBorder:SetAllPoints(PetPreview);

	-- List container (right side; 42 px bottom margin for the sub-tab bar)
	local PetsList = CreateFrame("Frame", "MogCompanionsPetsListFrame", PetsFrame);
	PetsList:SetPoint("TOPLEFT", PetPreview, "TOPRIGHT", 16, 0);
	PetsList:SetPoint("BOTTOMRIGHT", PetsFrame, "BOTTOMRIGHT", -listRightInset, 42);
	PetsList:SetFrameStrata("HIGH");

	PetShowSelectedButton = CreateFrame("Button", nil, PetsFrame, "UIPanelButtonTemplate");
	PetShowSelectedButton:SetSize(110, 22);
	PetShowSelectedButton:SetPoint("BOTTOMRIGHT", PetsList, "TOPRIGHT", 0, 4);
	PetShowSelectedButton:SetText(L["Show Selected"]);
	PetShowSelectedButton:Hide();
	PetShowSelectedButton:SetScript("OnClick", function()
		ShowOnlySelectedPets = not ShowOnlySelectedPets;
		RefreshPetList(false);
	end);

	local PetsListBackground = PetsList:CreateTexture(nil, "OVERLAY");
	PetsListBackground:SetAtlas("transmog-situations-containerbg", true);
	PetsListBackground:SetAllPoints(true);

	PetNoResultsText = PetsList:CreateFontString(nil, "OVERLAY", "GameFontDisable");
	PetNoResultsText:SetPoint("CENTER", PetsList, "CENTER", 0, 0);
	PetNoResultsText:SetText(L["No Items Match Search"]);
	PetNoResultsText:Hide();

	-- ScrollBox
	PetsListScrollBox = CreateFrame("Frame", "MogCompanionsPetsScrollBox", PetsList, "WowScrollBoxList");
	PetsListScrollBox:SetPoint("TOPLEFT", PetsList, "TOPLEFT", 12, -2);
	PetsListScrollBox:SetPoint("BOTTOMRIGHT", PetsList, "BOTTOMRIGHT", -40, 4);

	-- ScrollBar
	local PetsScrollBar = CreateFrame("EventFrame", nil, PetsList, "MinimalScrollBar");
	PetsScrollBar:SetPoint("TOPLEFT", PetsListScrollBox, "TOPRIGHT", 10, -6);
	PetsScrollBar:SetPoint("BOTTOMLEFT", PetsListScrollBox, "BOTTOMRIGHT", 10, 6);
	PetsScrollBar:SetHideIfUnscrollable(true);

	PetsDataProvider = CreateDataProvider();
	PetsScrollView = CreateScrollBoxListLinearView();
	PetsScrollView:SetElementInitializer("MogCompanionsMultiSelectListButtonTemplate", function(button, data)
		local outfit = GetOutfitTable(GetViewedOutfitID());
		local isSelected = outfit ~= nil and MogCompanions:IsInSelectionPool(outfit, "Pets", data.id);

		button.Name:SetText("|T"..data.icon..":18|t "..data.name);
		button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight");
		if button.CheckboxCheck ~= nil then
			button.CheckboxCheck:SetShown(isSelected);
		end

		if isSelected then
			button:LockHighlight();
		else
			button:UnlockHighlight();
		end

		button:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
			GameTooltip:AddLine(data.name);
			GameTooltip:AddLine("|cFFFFFFFF"..L["Item Slot Pet Title"].."|r");
			GameTooltip:Show();
			UpdatePetPreview(data);
		end)
		button:SetScript("OnLeave", function()
			GameTooltip:Hide();
			local viewedOutfit = GetOutfitTable(GetViewedOutfitID());
			UpdatePetPreview(GetValidPetSelection(viewedOutfit, false, LastClickedPetID));
		end)
		button:SetScript("OnClick", function()
			SetSelectedPet(data.id);
		end)
	end);
	PetsScrollView:SetElementExtent(22);
	ScrollUtil.InitScrollBoxListWithScrollBar(PetsListScrollBox, PetsScrollBar, PetsScrollView);
	PetsScrollView:SetDataProvider(PetsDataProvider);

	return PetsFrame;
end

local function InitializePets()
	if TransmogFrame == nil or TransmogFrame.WardrobeCollection == nil then
		return;
	end

	EnsureOutfitPetSaved();
	CreatePetSlot();

	UpdatePetSlot();

	if PetsFrame ~= nil and PetsFrame:IsShown() then
		UpdatePetPreview(GetSelectedPet(GetViewedOutfitID()));
		RefreshPetList(true);
	end
end

local function ScheduleInitializePets()
	if PetsInitScheduled then
		return;
	end

	PetsInitScheduled = true;

	C_Timer.After(0.25, InitializePets);
	C_Timer.After(0.75, function()
		InitializePets();
		PetsInitScheduled = false;
	end);
end

local PetEventFrame = CreateFrame("Frame");
PetEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
PetEventFrame:RegisterEvent("PET_JOURNAL_LIST_UPDATE");
PetEventFrame:RegisterEvent("VIEWED_TRANSMOG_OUTFIT_CHANGED");
PetEventFrame:RegisterEvent("TRANSMOG_DISPLAYED_OUTFIT_CHANGED");

local function IsTransmogShown()
	return TransmogFrame ~= nil and TransmogFrame:IsShown();
end

PetEventFrame:SetScript("OnEvent", function(self, event)
	EnsureOutfitPetSaved();

	if event == "PLAYER_ENTERING_WORLD" then
		return;
	end

	if event == "PET_JOURNAL_LIST_UPDATE" then
		PetDetailsCache = {};
		MogCompanions:InvalidateSortedPetsCache();

		if not IsTransmogShown() then
			return;
		end

		UpdatePetSlot();

		if PetsFrame ~= nil and PetsFrame:IsShown() then
			UpdatePetPreview(GetSelectedPet(GetViewedOutfitID()));
			RefreshPetList(false);
		end

		return;
	end

	if event == "VIEWED_TRANSMOG_OUTFIT_CHANGED" or event == "TRANSMOG_DISPLAYED_OUTFIT_CHANGED" then
		ShowOnlySelectedPets = false;
	end

	if not IsTransmogShown() then
		return;
	end

	ScheduleInitializePets();
	UpdatePetSlot();

	if PetsFrame ~= nil and PetsFrame:IsShown() then
		UpdatePetPreview(GetSelectedPet(GetViewedOutfitID()));
		RefreshPetList(false);
	end
end)

local function HookTransmogFrame()
	if TransmogFrame ~= nil then
		TransmogFrame:HookScript("OnShow", function()
			ScheduleInitializePets();
		end)
		ScheduleInitializePets();
	else
		C_Timer.After(1, HookTransmogFrame);
	end
end

HookTransmogFrame();

function MogCompanions:ShowPetsPage()
	if PetsFrame == nil then
		if _G.MogCompanionsCompanionsFrame ~= nil then
			MogCompanions:CreatePetsFrame(_G.MogCompanionsCompanionsFrame);
		end
	end

	if PetsFrame ~= nil then
		PetsFrame:Show();
	end

	UpdatePetPreview(GetSelectedPet(GetViewedOutfitID()));
	RefreshPetList(true);
end

function MogCompanions:HidePetsPage()
	if PetsFrame ~= nil then
		PetsFrame:Hide();
	end
end