-- Hearthstones.lua
-- Manages the Hearthstone toy slot and the Hearthstones tab inside the Transmog wardrobe.
--
-- Key responsibilities:
--   • HearthstoneSecureButton — a hidden SecureActionButtonTemplate that fires the toy;
--     must be configured outside combat because of protected frame rules.
--   • Hearthstone slot icon (alongside the mount slots in CharacterPreview.RightSlots).
--   • Hearthstones tab in WardrobeCollection (scrollable toy list, search box, gear menu).
--
-- Events handled: PLAYER_ENTERING_WORLD, TOYS_UPDATED, TRANSMOG_COLLECTION_UPDATED,
-- PLAYER_REGEN_ENABLED (retries pending item set after combat), GET_ITEM_INFO_RECEIVED,
-- VIEWED_TRANSMOG_OUTFIT_CHANGED, TRANSMOG_DISPLAYED_OUTFIT_CHANGED.
local _, addon = ...;
local ns = select(2,...);
local MogCompanions = ns.MogCompanions;
local L = MogCompanionsLocales;

local HearthstoneFrame;
local HearthstoneTexture;
local HearthstoneBorder;
local HearthstoneBorderTexture;
local HearthstoneBorderHighlight;
local HearthstoneBorderHighlightTexture;
local HearthstoneClear;
local HearthstonesPage;
local HearthstoneSlotTitle;
local HearthstonesSearchBox;
local HearthstoneListScrollView;
local HearthstoneListScrollBox;
local HearthstoneDataProvider;
local RefreshHearthstoneList;
local HearthstoneShowSelectedButton;
local HearthstoneNoResultsText;
local HearthstonesInitialized = false;
local HearthstoneSecureButton;
local HearthstonePendingItemID;
local HearthstoneShortcuts;
local ShowOnlySelectedHearthstones = false;

MogCompanions.HearthstoneSearchString = "";
MogCompanionsSelectedHearthstone = {};

-- ── Outfit Accessors ────────────────────────────────────────────────────────────
-- Nil-safe wrappers around C_TransmogOutfitInfo. Returns nil if the API is unavailable.
local function GetViewedOutfitID()
	if C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID then
		return C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID();
	end

	return nil;
end

local function GetActiveOutfitID()
	if C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetActiveOutfitID then
		return C_TransmogOutfitInfo.GetActiveOutfitID();
	end

	return nil;
end

-- Returns the saved-variable table for the given outfitID,
-- creating an empty entry via CreateEmptyOutfit if it doesn't exist yet.
local function GetOutfitTable(outfitID)
	if outfitID == nil or MogCompanionsCharacterSaved == nil then
		return nil;
	end

	MogCompanions:CreateEmptyOutfit(outfitID);

	return MogCompanionsCharacterSaved["Outfit"..outfitID];
end

local function IsValidHearthstoneSelection(itemID)
	return type(itemID) == "number" and itemID > 1 and MogCompanions:IsHearthstoneToyCollected(itemID);
end

local function GetValidHearthstoneSelectionValues(outfit)
	return MogCompanions:GetValidSelectionPoolValues(outfit, "Hearthstones", MogCompanions.IsHearthstoneToyCollected);
end

local function GetValidHearthstoneSelection(outfit, preferLast, preferredItemID)
	if outfit == nil then
		return 1;
	end

	if IsValidHearthstoneSelection(preferredItemID) then
		return preferredItemID;
	end

	local validSelections = GetValidHearthstoneSelectionValues(outfit);
	if #validSelections == 0 then
		return 1;
	end

	if preferLast then
		return validSelections[#validSelections];
	end

	return validSelections[1];
end

local function SyncLegacyHearthstoneSelection(outfit)
	if outfit == nil then
		return 1;
	end

	local itemID = GetValidHearthstoneSelection(outfit, false);
	outfit.Hearthstone = itemID;
	return itemID;
end

local function GetValidHearthstoneToyInfos(outfit)
	local validSelections = GetValidHearthstoneSelectionValues(outfit);
	local toys = {};

	for i = 1, #validSelections do
		local toy = MogCompanions:GetHearthstoneToyInfo(validSelections[i]);
		if toy ~= nil then
			table.insert(toys, toy);
		end
	end

	return toys;
end

local function GetFilteredSelectedHearthstones(outfit)
	local toys = MogCompanions:getSortedHearthstoneToys(false);
	return MogCompanions:FilterSelectedOnly(toys, outfit, "Hearthstones");
end

local function SetHearthstoneSectionTitle(count)
	if HearthstoneSlotTitle == nil then
		return;
	end

	if count > 0 then
		HearthstoneSlotTitle:SetText(L["Hearthstone Tab Title"].." "..string.format(L["Selected Count Format"], count));
	else
		HearthstoneSlotTitle:SetText(L["Hearthstone Tab Title"]);
	end
end

local function GetHearthstoneTooltipLines(outfit)
	local toys = GetValidHearthstoneToyInfos(outfit);
	local tooltipLines = {};

	if #toys > 0 then
		table.insert(tooltipLines, string.format(L["Random From Selected Hearthstones"], #toys));

		for i = 1, math.min(3, #toys) do
			table.insert(tooltipLines, "|T"..toys[i].icon..":18|t "..toys[i].name);
		end

		if #toys > 3 then
			table.insert(tooltipLines, string.format(L["More Selected Hearthstones"], #toys - 3));
		end
	end

	return tooltipLines, #toys;
end

local function RefreshVisibleHearthstoneRows()
	if HearthstoneListScrollBox == nil or HearthstoneListScrollBox.ScrollTarget == nil then
		return;
	end

	local outfit = GetOutfitTable(GetViewedOutfitID());
	local children = { HearthstoneListScrollBox.ScrollTarget:GetChildren() };

	for i = 1, #children do
		local child = children[i];
		local itemID = child.HearthstoneID;
		if itemID ~= nil then
			local isSelected = outfit ~= nil and MogCompanions:IsInSelectionPool(outfit, "Hearthstones", itemID);

			if child.CheckboxCheck ~= nil then
				child.CheckboxCheck:SetShown(isSelected);
			end

			if isSelected then
				child:LockHighlight();
			else
				child:UnlockHighlight();
			end
		end
	end
end

-- Returns a toy info table for the first valid selected hearthstone for the given outfit,
-- or nil if none is selected or the toy is no longer collected.
local function GetSelectedHearthstoneToy(outfitID)
	local outfit = GetOutfitTable(outfitID);
	local itemID = GetValidHearthstoneSelection(outfit, false);

	if itemID > 1 then
		return MogCompanions:GetHearthstoneToyInfo(itemID);
	end

	return nil;
end

-- ── Secure Button Management ────────────────────────────────────────────────
-- Creates the invisible SecureActionButtonTemplate button used to fire hearthstone toys.
-- Must be created once and reused; do NOT recreate in combat (combat lockdown).
local function EnsureHearthstoneSecureButton()
	if HearthstoneSecureButton ~= nil then
		return;
	end

	if InCombatLockdown and InCombatLockdown() then
		return;
	end

	HearthstoneSecureButton = CreateFrame("Button", "MCHearthButton", UIParent, "SecureActionButtonTemplate");
	HearthstoneSecureButton:SetParent(UIParent);
	HearthstoneSecureButton:SetSize(1, 1);
	HearthstoneSecureButton:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
	HearthstoneSecureButton:SetAlpha(0);
	HearthstoneSecureButton:EnableMouse(false);
	HearthstoneSecureButton:RegisterForClicks("AnyDown");
	HearthstoneSecureButton:SetAttribute("pressAndHoldAction", true);
	HearthstoneSecureButton:SetAttribute("type", "toy");
	HearthstoneSecureButton:SetAttribute("typerelease", "toy");
	HearthstoneSecureButton:SetAttribute("toy", nil);
	HearthstoneSecureButton:Show();
end

-- Returns the item ID to use for the secure button for the given outfit.
-- Uses a random valid selected toy when the outfit pool is non-empty.
-- Falls back to a random collected toy when the pool is empty.
-- Returns nil if no hearthstone toys are collected at all.
local function GetHearthstoneItemIDForOutfit(outfitID)
	local outfit = GetOutfitTable(outfitID);
	local validSelections = GetValidHearthstoneSelectionValues(outfit);

	if #validSelections > 0 then
		return validSelections[math.random(1, #validSelections)];
	end

	local randomToy = MogCompanions:getRandomHearthstoneToy();

	if randomToy ~= nil then
		return randomToy.id;
	end

	return nil;
end

-- Sets the secure button's toy attribute to the toy matching itemID.
-- If in combat, stores itemID in HearthstonePendingItemID and retries on PLAYER_REGEN_ENABLED.
-- Returns false if deferred due to combat, true on success.
local function SetHearthstoneSecureButtonItem(itemID)
	EnsureHearthstoneSecureButton();

	if InCombatLockdown and InCombatLockdown() then
		HearthstonePendingItemID = itemID;
		return false;
	end

	if itemID ~= nil then
		local toy = MogCompanions:GetHearthstoneToyInfo(itemID);
		if toy ~= nil and toy.name ~= nil then
			HearthstoneSecureButton:SetAttribute("type", "toy");
			HearthstoneSecureButton:SetAttribute("toy", toy.name);
		else
			-- Item data not yet loaded; will retry via GET_ITEM_INFO_RECEIVED
			HearthstoneSecureButton:SetAttribute("toy", nil);
		end
	else
		HearthstoneSecureButton:SetAttribute("toy", nil);
	end

	HearthstonePendingItemID = nil;

	return true;
end

-- Refreshes the secure button with the correct toy for the currently active outfit.
local function RefreshHearthstoneSecureButton()
	local itemID = GetHearthstoneItemIDForOutfit(GetActiveOutfitID());
	SetHearthstoneSecureButtonItem(itemID);
end

local hearthstonePostClickRegistered = false;
local hearthstonePreClickRegistered = false;

-- Registers a PostClick handler on the secure button that re-randomizes the toy
-- after each press (only when no specific toy is pinned to the current outfit).
local function EnsureHearthstonePostClick()
	if hearthstonePostClickRegistered then
		return;
	end
	if HearthstoneSecureButton == nil then
		return;
	end
	hearthstonePostClickRegistered = true;
	HearthstoneSecureButton:SetScript("PostClick", function(self)
		if InCombatLockdown and InCombatLockdown() then
			return;
		end
		-- Re-arm for the next press when the active outfit resolves to a random choice.
		local outfit = GetOutfitTable(GetActiveOutfitID());
		if outfit == nil or #GetValidHearthstoneSelectionValues(outfit) ~= 1 then
			SetHearthstoneSecureButtonItem(GetHearthstoneItemIDForOutfit(GetActiveOutfitID()));
		end
	end);
end

-- Registers a PreClick handler that arms the secure button before it fires.
-- Reads HearthstoneMods at click-time and routes to the appropriate action:
--   Garrison modifier held     → Garrison Hearthstone (110560) if collected
--   Dalaran modifier held      → Dalaran Hearthstone (140192) if collected
--   Otherwise                  → selected outfit toy or random (MogCompanionsPrepareHearthstone)
-- Only arms outside combat; in combat the button retains the last armed state.
local function EnsureHearthstonePreClick()
	if hearthstonePreClickRegistered then
		return;
	end
	if HearthstoneSecureButton == nil then
		return;
	end
	hearthstonePreClickRegistered = true;
	HearthstoneSecureButton:SetScript("PreClick", function(self)
		if InCombatLockdown and InCombatLockdown() then
			return;
		end
		local mods = MogCompanionsSaved and MogCompanionsSaved.HearthstoneMods;
		if mods then
			local modKeys = { IsControlKeyDown(), IsShiftKeyDown(), IsAltKeyDown() };
			if mods.Garrison and modKeys[mods.Garrison] and PlayerHasToy(110560) then
				SetHearthstoneSecureButtonItem(110560);
				return;
			end
			if mods.Dalaran and modKeys[mods.Dalaran] and PlayerHasToy(140192) then
				SetHearthstoneSecureButtonItem(140192);
				return;
			end
		end
		MogCompanionsPrepareHearthstone();
	end);
end

-- Public entry point called from macros / external code.
-- Resolves the correct toy for the active outfit and arms the secure button.
-- Prints a localized error if no toys are collected.
function MogCompanionsPrepareHearthstone()
	local itemID = GetHearthstoneItemIDForOutfit(GetActiveOutfitID());

	if itemID == nil then
		SetHearthstoneSecureButtonItem(nil);
		print(L["No Hearthstone Toys"]);
		return;
	end

	SetHearthstoneSecureButtonItem(itemID);
end

-- Updates MogCompanionsSelectedHearthstone with the name/icon/id of the given toy.
-- Set to nil fields when itemID is invalid or the toy info is unavailable.
local function UpdateSelectedHearthstoneDetails(itemID)
	if itemID == nil or itemID <= 1 then
		MogCompanionsSelectedHearthstone.name = nil;
		MogCompanionsSelectedHearthstone.icon = nil;
		MogCompanionsSelectedHearthstone.id = nil;
		return;
	end

	local toy = MogCompanions:GetHearthstoneToyInfo(itemID);

	if toy == nil then
		MogCompanionsSelectedHearthstone.name = nil;
		MogCompanionsSelectedHearthstone.icon = nil;
		MogCompanionsSelectedHearthstone.id = nil;
		return;
	end

	MogCompanionsSelectedHearthstone.name = toy.name;
	MogCompanionsSelectedHearthstone.icon = toy.icon;
	MogCompanionsSelectedHearthstone.id = toy.id;
end

-- Refreshes the hearthstone slot icon in the transmog panel based on the viewed outfit.
-- Shows the pinned toy icon (blue border) or the desaturated fallback icon.
local function UpdateHearthstoneSlot()
	if HearthstoneFrame == nil or HearthstoneTexture == nil then
		return;
	end

	local outfitID = GetViewedOutfitID();
	local outfit = GetOutfitTable(outfitID);
	local selectedItemID = SyncLegacyHearthstoneSelection(outfit);

	local toy = nil;

	if selectedItemID > 1 then
		toy = MogCompanions:GetHearthstoneToyInfo(selectedItemID);
	end

	if toy ~= nil then
		UpdateSelectedHearthstoneDetails(toy.id);
		HearthstoneTexture:SetTexture(toy.icon);
		HearthstoneTexture:SetDesaturated(false);
		HearthstoneTexture:SetVertexColor(1, 1, 1);
		HearthstoneBorderTexture:SetAtlas("transmog-gearSlot-transmogrified");
		HearthstoneBorderHighlightTexture:SetAtlas("transmog-gearSlot-transmogrified");
	else
		UpdateSelectedHearthstoneDetails(nil);
		HearthstoneTexture:SetTexture(MogCompanions.EmptyHearthstoneIcon);
		HearthstoneTexture:SetDesaturated(true);
		HearthstoneTexture:SetVertexColor(0.63, 0.63, 0.63);
		HearthstoneBorderTexture:SetAtlas("transmog-gearSlot-default");
		HearthstoneBorderHighlightTexture:SetAtlas("transmog-gearSlot-default");
	end

	HearthstoneTexture:SetAllPoints(HearthstoneFrame);
	HearthstoneFrame.texture = HearthstoneTexture;
	SetHearthstoneSectionTitle(select(2, GetHearthstoneTooltipLines(outfit)));
end

-- Toggles a hearthstone toy in the current outfit pool and refreshes the UI.
-- itemID = 1 clears the pool and falls back to random collected toys.
local function SetSelectedHearthstone(itemID)
	local outfitID = GetViewedOutfitID();
	local outfit = GetOutfitTable(outfitID);

	if outfit == nil then
		return;
	end

	if itemID == nil or itemID <= 1 then
		MogCompanions:ClearSelectionPool(outfit, "Hearthstones");
	else
		MogCompanions:ToggleSelectionPoolValue(outfit, "Hearthstones", itemID);
	end

	SyncLegacyHearthstoneSelection(outfit);
	UpdateHearthstoneSlot();
	RefreshHearthstoneList(false);
	RefreshHearthstoneSecureButton();

	if PlaySound ~= nil and SOUNDKIT ~= nil and SOUNDKIT.UI_TRANSMOG_ITEM_CLICK ~= nil then
		PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK);
	end
end

function ClearSelectedHearthstone()
	ShowOnlySelectedHearthstones = false;
	SetSelectedHearthstone(1);
end

-- Flushes and repopulates the HearthstoneDataProvider with the current toy list.
-- Called after search text changes, outfit changes, or toy collection changes.
RefreshHearthstoneList = function(scrollToSelection)
	if HearthstoneListScrollView == nil then
		return;
	end

	local outfit = GetOutfitTable(GetViewedOutfitID());
	if outfit ~= nil then
		MogCompanions:PruneInvalidSelectionPool(outfit, "Hearthstones", MogCompanions.IsHearthstoneToyCollected);
		SyncLegacyHearthstoneSelection(outfit);
	end

	local selectedCount = #GetValidHearthstoneSelectionValues(outfit);
	if selectedCount <= 0 then
		ShowOnlySelectedHearthstones = false;
	end

	local toys;
	if ShowOnlySelectedHearthstones then
		toys = GetFilteredSelectedHearthstones(outfit);
	else
		toys = MogCompanions:getSortedHearthstoneToys(false);
	end

	local selectedItemID = GetValidHearthstoneSelection(outfit, false);

	HearthstoneDataProvider = CreateDataProvider(toys);
	HearthstoneListScrollView:SetDataProvider(HearthstoneDataProvider);

	if scrollToSelection and HearthstonesPage ~= nil then
		if HearthstoneListScrollBox ~= nil and selectedItemID > 1 then
			for i = 1, #toys do
				if toys[i].id == selectedItemID then
					HearthstoneListScrollBox:ScrollToElementDataIndex(i);
					break;
				end
			end
		end
	end

	SetHearthstoneSectionTitle(selectedCount);
	MogCompanions:UpdateShowSelectedButton(HearthstoneShowSelectedButton, ShowOnlySelectedHearthstones, selectedCount);
	MogCompanions:UpdateNoResultsText(HearthstoneNoResultsText, HearthstonesSearchBox, #toys);
end

-- Creates a "MogComp Hearth" macro (or edits the existing one) and puts it on the cursor
-- so the player can drag it to an action bar.
-- The macro body is always "/click MCHearthButton"; modifier routing is handled in PreClick.
-- Cannot be created during combat (combat lockdown).
function MogCompanions:CreateHearthstoneMacro(parent)
	if InCombatLockdown and InCombatLockdown() then
		print(L["Macro Combat Error"]);
		return;
	end

	local macroId = false;

	for i = 1, 120 do
		if C_Macro.GetMacroName(i) == "MogComp Hearth" then
			macroId = i;
		end
	end

	EnsureHearthstoneSecureButton();
	MogCompanionsPrepareHearthstone();

	local macroBody = "#showtooltip Hearthstone\n/click MCHearthButton";

	if not macroId then
		macroId = CreateMacro("MogComp Hearth", MogCompanions.EmptyHearthstoneIcon, macroBody, nil);
	else
		EditMacro(macroId, "MogComp Hearth", MogCompanions.EmptyHearthstoneIcon, macroBody, nil);
	end

	PickupMacro(macroId);

	GameTooltip:SetOwner(parent, "ANCHOR_CURSOR_RIGHT");
	GameTooltip:AddLine(L["Drop Hearthstone Macro Tooltip"], 1, 1, 1);
	GameTooltip:Show();
end

-- ── Hearthstones Tab UI ─────────────────────────────────────────────────────────
-- Creates the full Hearthstones tab frame inside WardrobeCollection.TabContent.
-- Idempotent: returns early if HearthstonesPage already exists (or reparents it if the
-- parent has changed). Creates the Hearthstones page parented directly to the given frame.
-- Contains: search box, gear dropdown, section title, scrollable toy list + scrollbar.
function MogCompanions:CreateHearthstonesFrame(parent)
	if parent == nil then
		return nil;
	end

	if HearthstonesPage ~= nil then
		if HearthstonesPage:GetParent() ~= parent then
			HearthstonesPage:SetParent(parent);
			HearthstonesPage:ClearAllPoints();
			HearthstonesPage:SetAllPoints(parent);
		end
		return HearthstonesPage;
	end

	HearthstonesPage = CreateFrame("Frame", "MogCompanionsHearthstonesPage", parent);
	HearthstonesPage:SetAllPoints(parent);
	HearthstonesPage:Hide();

	local topOffset = 26;
	local listRightInset = 28;

	-- Gear dropdown (matching Mounts tab ShortcutSettings)
	HearthstoneShortcuts = MogCompanions:CreateCompanionsShortcutMenu(HearthstonesPage, "MogCompanionsHearthstoneShortcuts");
	HearthstoneShortcuts:SetPoint("TOPRIGHT", HearthstonesPage, "TOPRIGHT", -26, -50 + topOffset);

	-- Search box aligned directly beside the gear shortcut button.
	HearthstonesSearchBox = CreateFrame("EditBox", "MogCompanionsHearthstoneSearchBox", HearthstonesPage, "TransmogSearchBoxTemplate");
	HearthstonesSearchBox:SetPoint("TOPRIGHT", HearthstoneShortcuts, "TOPLEFT", -8, 0);
	local iconPos, iconParent, iconParentPos, iconX, iconY = HearthstonesSearchBox.searchIcon:GetPoint();
	HearthstonesSearchBox.searchIcon:SetPoint(iconPos, iconParent, iconParentPos, iconX, iconY + 1);
	HearthstonesSearchBox:SetScript("OnTextChanged", function(self)
		if SearchBoxTemplate_OnTextChanged ~= nil then
			SearchBoxTemplate_OnTextChanged(self);
		end
		MogCompanions.HearthstoneSearchString = self:GetText() or "";
		RefreshHearthstoneList(true);
	end)

	-- Section title (matching Mounts FlyingSlotTitle style)
	HearthstoneSlotTitle = HearthstonesPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge");
	HearthstoneSlotTitle:SetJustifyH("LEFT");
	HearthstoneSlotTitle:SetPoint("TOPLEFT", HearthstonesPage, "TOPLEFT", 24, -76 + topOffset);
	HearthstoneSlotTitle:SetText(L["Hearthstone Tab Title"]);

	local HearthstoneSlotTitleDivider = HearthstonesPage:CreateTexture();
	HearthstoneSlotTitleDivider:SetAtlas("transmog-tabs-header-line", true);
	HearthstoneSlotTitleDivider:SetAlpha(0.1);
	HearthstoneSlotTitleDivider:SetPoint("TOPLEFT", HearthstoneSlotTitle, "BOTTOMLEFT", 0, -2);

	-- List container (full-width, no preview panel)
	local HearthstoneList = CreateFrame("Frame", "MogCompanionsHearthstoneListFrame", HearthstonesPage);
	HearthstoneList:SetPoint("TOPLEFT", HearthstonesPage, "TOPLEFT", 24, -113 + topOffset);
	HearthstoneList:SetPoint("BOTTOMRIGHT", HearthstonesPage, "BOTTOMRIGHT", -listRightInset, 42);
	HearthstoneList:SetFrameStrata("HIGH");

	HearthstoneShowSelectedButton = CreateFrame("Button", nil, HearthstonesPage, "UIPanelButtonTemplate");
	HearthstoneShowSelectedButton:SetSize(110, 22);
	HearthstoneShowSelectedButton:SetPoint("BOTTOMRIGHT", HearthstoneList, "TOPRIGHT", -40, 4);
	HearthstoneShowSelectedButton:SetText(L["Show Selected"]);
	HearthstoneShowSelectedButton:Hide();
	HearthstoneShowSelectedButton:SetScript("OnClick", function()
		ShowOnlySelectedHearthstones = not ShowOnlySelectedHearthstones;
		RefreshHearthstoneList(false);
	end);

	local HearthstoneListBackground = HearthstoneList:CreateTexture(nil, "OVERLAY");
	HearthstoneListBackground:SetAtlas("transmog-situations-containerbg", true);
	HearthstoneListBackground:SetAllPoints(true);

	HearthstoneNoResultsText = HearthstoneList:CreateFontString(nil, "OVERLAY", "GameFontDisable");
	HearthstoneNoResultsText:SetPoint("CENTER", HearthstoneList, "CENTER", 0, 0);
	HearthstoneNoResultsText:SetText(L["No Items Match Search"]);
	HearthstoneNoResultsText:Hide();

	-- ScrollBox
	HearthstoneListScrollBox = CreateFrame("Frame", "MogCompanionsHearthstoneScrollBox", HearthstoneList, "WowScrollBoxList");
	HearthstoneListScrollBox:SetPoint("TOPLEFT", HearthstoneList, "TOPLEFT", 12, -2);
	HearthstoneListScrollBox:SetPoint("BOTTOMRIGHT", HearthstoneList, "BOTTOMRIGHT", -40, 4);

	-- ScrollBar
	local HearthstoneScrollBar = CreateFrame("EventFrame", nil, HearthstoneList, "MinimalScrollBar");
	HearthstoneScrollBar:SetPoint("TOPLEFT", HearthstoneListScrollBox, "TOPRIGHT", 10, -6);
	HearthstoneScrollBar:SetPoint("BOTTOMLEFT", HearthstoneListScrollBox, "BOTTOMRIGHT", 10, 6);
	HearthstoneScrollBar:SetHideIfUnscrollable(true);

	-- Data provider and scroll view
	HearthstoneDataProvider = CreateDataProvider();
	local scrollView = CreateScrollBoxListLinearView();

	local function HearthstoneListInitializer(button, data)
		local outfit = GetOutfitTable(GetViewedOutfitID());
		local isSelected = outfit ~= nil and MogCompanions:IsInSelectionPool(outfit, "Hearthstones", data.id);

		button.HearthstoneID = data.id;
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

		button:SetScript("OnClick", function(self)
			SetSelectedHearthstone(data.id);
		end)
		button:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
			GameTooltip:SetToyByItemID(data.id);
			GameTooltip:Show();
		end)
		button:SetScript("OnLeave", function()
			GameTooltip:Hide();
		end)
	end

	scrollView:SetElementInitializer("MogCompanionsMultiSelectListButtonTemplate", HearthstoneListInitializer);
	scrollView:SetElementExtent(22);
	ScrollUtil.InitScrollBoxListWithScrollBar(HearthstoneListScrollBox, HearthstoneScrollBar, scrollView);
	scrollView:SetDataProvider(HearthstoneDataProvider);

	HearthstoneListScrollView = scrollView;

	local toys = MogCompanions:getSortedHearthstoneToys(false);
	for i = 1, #toys do
		HearthstoneDataProvider:Insert(toys[i]);
	end
	SetHearthstoneSectionTitle(select(2, GetHearthstoneTooltipLines(GetOutfitTable(GetViewedOutfitID()))));

	return HearthstonesPage;
end

-- ── Hearthstone Slot Icon (Outfit Panel) ──────────────────────────────────────
-- Creates the clickable hearthstone slot icon that sits beside the mount slots
-- in the transmog CharacterPreview panel. Only created once (guarded by HearthstoneFrame nil check).
local function CreateHearthstoneSlot()
	if HearthstoneFrame ~= nil or _G.MogCompanionsFrame == nil then
		return;
	end

	local borderSize = 59;
	local borderOffset = 7;

	HearthstoneFrame = CreateFrame("Frame", "HearthstoneFrame", _G.MogCompanionsFrame);
	HearthstoneFrame:SetFrameStrata("MEDIUM");
	HearthstoneFrame:SetSize(44, 44);
	HearthstoneFrame:SetPoint("TOPLEFT", _G.MogCompanionsFrame, "TOPLEFT", 0, MogCompanions.TransmogSlotOffsets.Hearthstone);
	HearthstoneFrame:Show();

	HearthstoneTexture = HearthstoneFrame:CreateTexture(nil, "BACKGROUND");

	HearthstoneBorder = CreateFrame("Frame", "HearthstoneBorder", HearthstoneFrame);
	HearthstoneBorder:SetFrameStrata("HIGH");
	HearthstoneBorder:SetSize(borderSize, borderSize);
	HearthstoneBorder:SetPoint("TOPLEFT", HearthstoneFrame, "TOPLEFT", borderOffset * -1, borderOffset);
	HearthstoneBorder:Show();

	HearthstoneBorderTexture = HearthstoneBorder:CreateTexture(nil, "BACKGROUND");
	HearthstoneBorderTexture:SetAtlas("transmog-gearSlot-default");
	HearthstoneBorderTexture:SetAllPoints(HearthstoneBorder);
	HearthstoneBorder.texture = HearthstoneBorderTexture;

	HearthstoneBorderHighlight = CreateFrame("Frame", "HearthstoneBorderHighlight", HearthstoneFrame);
	HearthstoneBorderHighlight:SetFrameStrata("HIGH");
	HearthstoneBorderHighlight:SetSize(borderSize, borderSize);
	HearthstoneBorderHighlight:SetPoint("TOPLEFT", HearthstoneFrame, "TOPLEFT", borderOffset * -1, borderOffset);
	HearthstoneBorderHighlight:Hide();

	HearthstoneBorderHighlightTexture = HearthstoneBorderHighlight:CreateTexture(nil, "BACKGROUND");
	HearthstoneBorderHighlightTexture:SetAtlas("transmog-gearSlot-default");
	HearthstoneBorderHighlightTexture:SetAllPoints(HearthstoneBorderHighlight);
	HearthstoneBorderHighlightTexture:SetBlendMode("ADD");
	HearthstoneBorderHighlight.texture = HearthstoneBorderHighlightTexture;

	HearthstoneClear = CreateFrame("Button", "HearthstoneClearButton", HearthstoneBorder, "UIResetButtonTemplate");
	HearthstoneClear:SetPoint("CENTER", HearthstoneBorder, "TOPRIGHT", -8, -8);
	HearthstoneClear:Hide();
	HearthstoneClear:SetScript("OnEnter", function()
		GameTooltip:SetOwner(HearthstoneClear, "ANCHOR_RIGHT");
		GameTooltip:SetText(L["Item Slot Hearthstone Clear Tooltip"]);
		GameTooltip:Show();
		HearthstoneClear:Show();
	end)
	HearthstoneClear:SetScript("OnLeave", function()
		HearthstoneClear:Hide();
		GameTooltip:Hide();
	end)
	HearthstoneClear:SetScript("OnClick", function()
		ClearSelectedHearthstone();
		HearthstoneClear:Hide();
	end)

	HearthstoneBorder:HookScript("OnEnter", function()
		GameTooltip:SetOwner(HearthstoneBorder, "ANCHOR_RIGHT");

		local outfit = GetOutfitTable(GetViewedOutfitID());
		local tooltipLines, count = GetHearthstoneTooltipLines(outfit);

		if count > 0 then
			GameTooltip:AddLine(L["Item Slot Hearthstone Title"]);
			for i = 1, #tooltipLines do
				GameTooltip:AddLine(tooltipLines[i], 1, 1, 1);
			end
			HearthstoneClear:Show();
		else
			GameTooltip:SetText(L["Item Slot Hearthstone Title"]);
		end

		GameTooltip:Show();
		HearthstoneBorderHighlight:Show();
	end)

	HearthstoneBorder:HookScript("OnLeave", function()
		GameTooltip:Hide();
		HearthstoneBorderHighlight:Hide();
		HearthstoneClear:Hide();
	end)

	HearthstoneBorder:SetScript("OnMouseDown", function()
		MogCompanions:OpenHearthstonesTab();
		PlaySound(SOUNDKIT.UI_TRANSMOG_GEAR_SLOT_CLICK);
	end)

	UpdateHearthstoneSlot();
end

-- ── Initialization ────────────────────────────────────────────────────────────
-- Ensures saved-variable entries exist for all known outfits.
-- Defensive guard run before UI creation to avoid nil-access on outfit tables.
local function EnsureOutfitHearthstoneSaved()
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
	local activeOutfitID = GetActiveOutfitID();

	if viewedOutfitID ~= nil then
		MogCompanions:CreateEmptyOutfit(viewedOutfitID);
	end

	if activeOutfitID ~= nil then
		MogCompanions:CreateEmptyOutfit(activeOutfitID);
	end
end

-- Runs the full hearthstone initialization sequence:
-- slot icon, tab frame, secure button, post-click handler, data refresh.
-- Called with C_Timer delays to let Blizzard's WardrobeCollection load first.
local function InitializeHearthstones()
	if TransmogFrame == nil or TransmogFrame.WardrobeCollection == nil then
		return;
	end

	EnsureOutfitHearthstoneSaved();
	CreateHearthstoneSlot();
	if _G.MogCompanionsCompanionsFrame ~= nil then
		MogCompanions:CreateHearthstonesFrame(_G.MogCompanionsCompanionsFrame);
	end
	EnsureHearthstoneSecureButton();
	EnsureHearthstonePreClick();
	EnsureHearthstonePostClick();
	RefreshHearthstoneSecureButton();
	UpdateHearthstoneSlot();
	RefreshHearthstoneList();

	HearthstonesInitialized = true;
end

-- Schedules two initialization attempts (0.25 s and 0.75 s) to handle the race
-- between addon load and Blizzard's deferred UI construction.
local function ScheduleInitializeHearthstones()
	C_Timer.After(0.25, InitializeHearthstones);
	C_Timer.After(0.75, InitializeHearthstones);
end

local HearthstoneEventFrame = CreateFrame("Frame");
HearthstoneEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
HearthstoneEventFrame:RegisterEvent("TOYS_UPDATED");
HearthstoneEventFrame:RegisterEvent("TRANSMOG_COLLECTION_UPDATED");
HearthstoneEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED");
HearthstoneEventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED");
HearthstoneEventFrame:RegisterEvent("VIEWED_TRANSMOG_OUTFIT_CHANGED");
HearthstoneEventFrame:RegisterEvent("TRANSMOG_DISPLAYED_OUTFIT_CHANGED");
HearthstoneEventFrame:SetScript("OnEvent", function(self, event, ...)
	if event == "PLAYER_REGEN_ENABLED" then
		EnsureHearthstoneSecureButton();
		EnsureHearthstonePreClick();
		EnsureHearthstonePostClick();
		if HearthstonePendingItemID ~= nil then
			-- Honor a specific toy selection that was deferred because combat started mid-update.
			SetHearthstoneSecureButtonItem(HearthstonePendingItemID);
		else
			-- Re-arm the button after combat so the next press gets a fresh random selection
			-- when no specific toy is pinned to the active outfit.
			RefreshHearthstoneSecureButton();
		end
		return;
	end

	if event == "GET_ITEM_INFO_RECEIVED" then
		local itemID = ...;
		if itemID == nil or not MogCompanions:hasValue(MogCompanions.HearthstoneToyItemIDs, itemID) then
			return;
		end
	end

	if event == "VIEWED_TRANSMOG_OUTFIT_CHANGED" or event == "TRANSMOG_DISPLAYED_OUTFIT_CHANGED" then
		ShowOnlySelectedHearthstones = false;
	end

	EnsureOutfitHearthstoneSaved();
	ScheduleInitializeHearthstones();
	UpdateHearthstoneSlot();
	EnsureHearthstoneSecureButton();
	EnsureHearthstonePreClick();
	EnsureHearthstonePostClick();
	RefreshHearthstoneSecureButton();
	RefreshHearthstoneList();
end)

local function HookTransmogFrame()
	if TransmogFrame ~= nil then
		TransmogFrame:HookScript("OnShow", function()
			ScheduleInitializeHearthstones();
		end)
		ScheduleInitializeHearthstones();
	else
		C_Timer.After(1, HookTransmogFrame);
	end
end

HookTransmogFrame();

-- Shows the Hearthstones tab page and refreshes the list.
function MogCompanions:ShowHearthstonesPage()
	if HearthstonesPage == nil then
		if _G.MogCompanionsCompanionsFrame ~= nil then
			MogCompanions:CreateHearthstonesFrame(_G.MogCompanionsCompanionsFrame);
		end
	end

	if HearthstonesPage ~= nil then
		HearthstonesPage:Show();
	end

	RefreshHearthstoneList();
end

function MogCompanions:HideHearthstonesPage()
	if HearthstonesPage ~= nil then
		HearthstonesPage:Hide();
	end
end

function MogCompanions:OpenHearthstonesTab()
	MogCompanions:OpenCompanionsTab("Hearthstones");
end
