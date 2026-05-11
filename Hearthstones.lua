local _, addon = ...;
local ns = select(2,...);
local MogMount = ns.MogMount;
local L = MogMountLocales;

local HearthstoneFrame;
local HearthstoneTexture;
local HearthstoneBorder;
local HearthstoneBorderTexture;
local HearthstoneBorderHighlight;
local HearthstoneBorderHighlightTexture;
local HearthstoneClear;
local HearthstonesPanel;
local HearthstonesTab;
local HearthstonesSearchBox;
local HearthstonesButtons = {};
local HearthstonesScrollFrame;
local HearthstonesOffset = 0;
local HearthstonesInitialized = false;
local HearthstoneSecureButton;
local HearthstonePendingItemID;

MogMount.HearthstoneSearchString = "";
MogMountSelectedHearthstone = {};

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

local function GetOutfitTable(outfitID)
	if outfitID == nil or MogMountCharacterSaved == nil then
		return nil;
	end

	MogMount:CreateEmptyOutfit(outfitID);

	return MogMountCharacterSaved["Outfit"..outfitID];
end

local function GetSelectedHearthstoneToy(outfitID)
	local outfit = GetOutfitTable(outfitID);

	if outfit ~= nil and outfit.Hearthstone ~= nil and outfit.Hearthstone > 1 and MogMount:IsHearthstoneToyCollected(outfit.Hearthstone) then
		return MogMount:GetHearthstoneToyInfo(outfit.Hearthstone);
	end

	return nil;
end


local function EnsureHearthstoneSecureButton()
	if HearthstoneSecureButton ~= nil then
		return;
	end

	HearthstoneSecureButton = CreateFrame("Button", "MogMountHearthstoneSecureButton", UIParent, "SecureActionButtonTemplate");
	HearthstoneSecureButton:SetParent(UIParent);
	HearthstoneSecureButton:SetSize(1, 1);
	HearthstoneSecureButton:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
	HearthstoneSecureButton:SetAlpha(0);
	HearthstoneSecureButton:EnableMouse(false);
	HearthstoneSecureButton:SetAttribute("type", "macro");
	HearthstoneSecureButton:SetAttribute("macrotext", nil);
	HearthstoneSecureButton:Show();
end

local function GetHearthstoneItemIDForOutfit(outfitID)
	local outfit = GetOutfitTable(outfitID);

	if outfit ~= nil and outfit.Hearthstone ~= nil and outfit.Hearthstone > 1 and MogMount:IsHearthstoneToyCollected(outfit.Hearthstone) then
		return outfit.Hearthstone;
	end

	local randomToy = MogMount:getRandomHearthstoneToy();

	if randomToy ~= nil then
		return randomToy.id;
	end

	return nil;
end

local function SetHearthstoneSecureButtonItem(itemID)
	EnsureHearthstoneSecureButton();

	if InCombatLockdown and InCombatLockdown() then
		HearthstonePendingItemID = itemID;
		return false;
	end

	HearthstoneSecureButton:SetAttribute("type", "macro");

	if itemID ~= nil then
		HearthstoneSecureButton:SetAttribute("macrotext", "/use item:"..itemID);
	else
		HearthstoneSecureButton:SetAttribute("macrotext", nil);
	end

	HearthstonePendingItemID = nil;

	return true;
end

local function RefreshHearthstoneSecureButton()
	local itemID = GetHearthstoneItemIDForOutfit(GetActiveOutfitID());
	SetHearthstoneSecureButtonItem(itemID);
end

function MogMountPrepareHearthstone()
	local itemID = GetHearthstoneItemIDForOutfit(GetActiveOutfitID());

	if itemID == nil then
		SetHearthstoneSecureButtonItem(nil);
		print(L["No Hearthstone Toys"]);
		return;
	end

	SetHearthstoneSecureButtonItem(itemID);
end

local function UpdateSelectedHearthstoneDetails(itemID)
	if itemID == nil or itemID <= 1 then
		MogMountSelectedHearthstone.name = nil;
		MogMountSelectedHearthstone.icon = nil;
		MogMountSelectedHearthstone.id = nil;
		return;
	end

	local toy = MogMount:GetHearthstoneToyInfo(itemID);

	if toy == nil then
		MogMountSelectedHearthstone.name = nil;
		MogMountSelectedHearthstone.icon = nil;
		MogMountSelectedHearthstone.id = nil;
		return;
	end

	MogMountSelectedHearthstone.name = toy.name;
	MogMountSelectedHearthstone.icon = toy.icon;
	MogMountSelectedHearthstone.id = toy.id;
end

local function UpdateHearthstoneSlot()
	if HearthstoneFrame == nil or HearthstoneTexture == nil then
		return;
	end

	local outfitID = GetViewedOutfitID();
	local outfit = GetOutfitTable(outfitID);
	local selectedItemID = 1;

	if outfit ~= nil and outfit.Hearthstone ~= nil then
		selectedItemID = outfit.Hearthstone;
	end

	local toy = nil;

	if selectedItemID > 1 then
		toy = GetSelectedHearthstoneToy(outfitID);
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
		HearthstoneTexture:SetTexture(MogMount.EmptyHearthstoneIcon);
		HearthstoneTexture:SetDesaturated(true);
		HearthstoneTexture:SetVertexColor(0.63, 0.63, 0.63);
		HearthstoneBorderTexture:SetAtlas("transmog-gearSlot-default");
		HearthstoneBorderHighlightTexture:SetAtlas("transmog-gearSlot-default");
	end

	HearthstoneTexture:SetAllPoints(HearthstoneFrame);
	HearthstoneFrame.texture = HearthstoneTexture;
end

local function SetSelectedHearthstone(itemID)
	local outfitID = GetViewedOutfitID();
	local outfit = GetOutfitTable(outfitID);

	if outfit == nil then
		return;
	end

	outfit.Hearthstone = itemID;
	UpdateHearthstoneSlot();
	RefreshHearthstoneSecureButton();
end

function ClearSelectedHearthstone()
	SetSelectedHearthstone(1);
end

local function CreateHearthstoneMacro(parent)
	if InCombatLockdown and InCombatLockdown() then
		print(L["Macro Combat Error"]);
		return;
	end

	local macroId = false;

	for i = 1, 120 do
		if C_Macro.GetMacroName(i) == "MogMount HS" then
			macroId = i;
		end
	end

	EnsureHearthstoneSecureButton();
	MogMountPrepareHearthstone();

	local macroBody = "/run MogMountPrepareHearthstone()\n/click MogMountHearthstoneSecureButton";

	if not macroId then
		macroId = CreateMacro("MogMount HS", MogMount.EmptyHearthstoneIcon, macroBody, nil);
	else
		EditMacro(macroId, "MogMount HS", MogMount.EmptyHearthstoneIcon, macroBody, nil);
	end

	PickupMacro(macroId);

	GameTooltip:SetOwner(parent, "ANCHOR_CURSOR_RIGHT");
	GameTooltip:AddLine(L["Drop Hearthstone Macro Tooltip"], 1, 1, 1);
	GameTooltip:Show();
end

local function SelectHearthstoneTab()
	if HearthstonesPanel == nil then
		return;
	end

	HearthstonesPanel:Show();

	if HearthstonesTab ~= nil then
		HearthstonesTab:LockHighlight();
	end
end

local function HideHearthstoneTab()
	if HearthstonesPanel ~= nil then
		HearthstonesPanel:Hide();
	end

	if HearthstonesTab ~= nil then
		HearthstonesTab:UnlockHighlight();
	end
end

local function RefreshHearthstoneList()
	if HearthstonesPanel == nil then
		return;
	end

	local toys = MogMount:getSortedHearthstoneToys(false);
	local buttonHeight = 24;
	local visibleButtons = #HearthstonesButtons;
	local maxOffset = math.max(#toys - visibleButtons, 0);

	if HearthstonesOffset > maxOffset then
		HearthstonesOffset = maxOffset;
	end

	for i = 1, visibleButtons do
		local toy = toys[HearthstonesOffset + i];
		local button = HearthstonesButtons[i];

		if toy ~= nil then
			button.toy = toy;
			button.Icon:SetTexture(toy.icon);
			button.Text:SetText(toy.name);
			button:Show();

			local outfit = GetOutfitTable(GetViewedOutfitID());

			if outfit ~= nil and outfit.Hearthstone == toy.id then
				button:LockHighlight();
			else
				button:UnlockHighlight();
			end
		else
			button.toy = nil;
			button:Hide();
			button:UnlockHighlight();
		end
	end

	if HearthstonesScrollFrame ~= nil then
		FauxScrollFrame_Update(HearthstonesScrollFrame, #toys, visibleButtons, buttonHeight);
	end
end

local function CreateHearthstonesPanel(collection)
	if HearthstonesPanel ~= nil then
		return;
	end

	HearthstonesPanel = CreateFrame("Frame", "MogMountHearthstonesPanel", collection, "BackdropTemplate");
	HearthstonesPanel:SetPoint("TOPLEFT", collection, "TOPLEFT", 25, -80);
	HearthstonesPanel:SetPoint("BOTTOMRIGHT", collection, "BOTTOMRIGHT", -25, 25);
	HearthstonesPanel:SetFrameStrata("HIGH");
	HearthstonesPanel:SetFrameLevel(collection:GetFrameLevel() + 20);
	HearthstonesPanel:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 }
	});
	HearthstonesPanel:Hide();

	local title = HearthstonesPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
	title:SetPoint("TOPLEFT", HearthstonesPanel, "TOPLEFT", 18, -18);
	title:SetText(L["Hearthstone Tab Title"]);

	HearthstonesSearchBox = CreateFrame("EditBox", "MogMountHearthstoneSearchBox", HearthstonesPanel, "SearchBoxTemplate");
	HearthstonesSearchBox:SetSize(180, 22);
	HearthstonesSearchBox:SetPoint("TOPRIGHT", HearthstonesPanel, "TOPRIGHT", -18, -16);
	HearthstonesSearchBox:SetScript("OnTextChanged", function(self)
		MogMount.HearthstoneSearchString = self:GetText() or "";
		HearthstonesOffset = 0;
		RefreshHearthstoneList();
	end)

	local macroButton = CreateFrame("Button", "MogMountHearthstoneMacroButton", HearthstonesPanel, "UIPanelButtonTemplate");
	macroButton:SetSize(120, 24);
	macroButton:SetPoint("TOPRIGHT", HearthstonesSearchBox, "BOTTOMRIGHT", 0, -8);
	macroButton:SetText(L["Create Macro"]);
	macroButton:SetScript("OnClick", function(self)
		CreateHearthstoneMacro(self);
	end)

	HearthstonesScrollFrame = CreateFrame("ScrollFrame", "MogMountHearthstoneScrollFrame", HearthstonesPanel, "FauxScrollFrameTemplate");
	HearthstonesScrollFrame:SetPoint("TOPLEFT", HearthstonesPanel, "TOPLEFT", 18, -55);
	HearthstonesScrollFrame:SetPoint("BOTTOMRIGHT", HearthstonesPanel, "BOTTOMRIGHT", -32, 18);
	HearthstonesScrollFrame:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, 24, function()
			HearthstonesOffset = FauxScrollFrame_GetOffset(HearthstonesScrollFrame);
			RefreshHearthstoneList();
		end)
	end)

	for i = 1, 14 do
		local button = CreateFrame("Button", "MogMountHearthstoneListButton"..i, HearthstonesPanel, "MogMountListButtonTemplate");
		button:SetSize(330, 24);

		if i == 1 then
			button:SetPoint("TOPLEFT", HearthstonesPanel, "TOPLEFT", 20, -58);
		else
			button:SetPoint("TOPLEFT", HearthstonesButtons[i - 1], "BOTTOMLEFT", 0, 0);
		end

		button.Icon = button:CreateTexture(nil, "ARTWORK");
		button.Icon:SetSize(18, 18);
		button.Icon:SetPoint("LEFT", button, "LEFT", 0, 0);

		button.Text = button.Name;
		button.Text:ClearAllPoints();
		button.Text:SetPoint("LEFT", button.Icon, "RIGHT", 6, -1);
		button.Text:SetPoint("RIGHT", button, "RIGHT", -4, -1);

		button:SetScript("OnClick", function(self)
			if self.toy ~= nil then
				SetSelectedHearthstone(self.toy.id);
				RefreshHearthstoneList();
			end
		end)
		button:SetScript("OnEnter", function(self)
			if self.toy ~= nil then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
				GameTooltip:SetToyByItemID(self.toy.id);
				GameTooltip:Show();
			end
		end)
		button:SetScript("OnLeave", function()
			GameTooltip:Hide();
		end)

		HearthstonesButtons[i] = button;
	end

	RefreshHearthstoneList();
end

local function CreateHearthstonesTab(collection)
	if HearthstonesTab ~= nil then
		return;
	end

	HearthstonesTab = CreateFrame("Button", "MogMountHearthstonesTab", collection, "PanelTopTabButtonTemplate");
	HearthstonesTab:SetText(L["Hearthstone Tab Title"]);
	PanelTemplates_TabResize(HearthstonesTab, 0);

	local anchorTab = nil;
	for i = 1, 8 do
		local tab = _G["WardrobeCollectionFrameTab"..i] or _G["TransmogFrameTab"..i] or _G["WardrobeFrameTab"..i];
		if tab ~= nil and tab:IsShown() then
			anchorTab = tab;
		end
	end

	if anchorTab ~= nil then
		HearthstonesTab:SetPoint("LEFT", anchorTab, "RIGHT", -15, 0);
	else
		HearthstonesTab:SetPoint("TOPLEFT", collection, "TOPLEFT", 470, 28);
	end

	HearthstonesTab:SetScript("OnClick", function()
		SelectHearthstoneTab();
	end)
	HearthstonesTab:Show();
end

local function CreateHearthstoneSlot()
	if HearthstoneFrame ~= nil or _G.MogMountFrame == nil then
		return;
	end

	local borderSize = 59;
	local borderOffset = 7;

	HearthstoneFrame = CreateFrame("Frame", "HearthstoneFrame", _G.MogMountFrame);
	HearthstoneFrame:SetFrameStrata("MEDIUM");
	HearthstoneFrame:SetSize(44, 44);
	HearthstoneFrame:SetPoint("TOPLEFT", _G.MogMountFrame, "TOPLEFT", 0, -128);
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
		RefreshHearthstoneList();
	end)

	HearthstoneBorder:HookScript("OnEnter", function()
		GameTooltip:SetOwner(HearthstoneBorder, "ANCHOR_RIGHT");

		local outfit = GetOutfitTable(GetViewedOutfitID());

		if outfit ~= nil and outfit.Hearthstone ~= nil and outfit.Hearthstone > 1 then
			local toy = GetSelectedHearthstoneToy(GetViewedOutfitID());

			if toy ~= nil then
				GameTooltip:AddLine(toy.name);
				GameTooltip:AddLine("|cFFFFFFFF"..L["Item Slot Hearthstone Title"].."|r");
				HearthstoneClear:Show();
			else
				GameTooltip:SetText(L["Item Slot Hearthstone Title"]);
			end
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
		SelectHearthstoneTab();
		PlaySound(SOUNDKIT.UI_TRANSMOG_GEAR_SLOT_CLICK);
	end)

	UpdateHearthstoneSlot();
end

local function EnsureOutfitHearthstoneSaved()
	if MogMountCharacterSaved == nil or C_TransmogOutfitInfo == nil or C_TransmogOutfitInfo.GetOutfitsInfo == nil then
		return;
	end

	local outfits = C_TransmogOutfitInfo.GetOutfitsInfo();

	if outfits == nil then
		return;
	end

	for i = 1, #outfits do
		MogMount:CreateEmptyOutfit(outfits[i].outfitID);
	end

	local viewedOutfitID = GetViewedOutfitID();
	local activeOutfitID = GetActiveOutfitID();

	if viewedOutfitID ~= nil then
		MogMount:CreateEmptyOutfit(viewedOutfitID);
	end

	if activeOutfitID ~= nil then
		MogMount:CreateEmptyOutfit(activeOutfitID);
	end
end

local function InitializeHearthstones()
	if TransmogFrame == nil or TransmogFrame.WardrobeCollection == nil then
		return;
	end

	EnsureOutfitHearthstoneSaved();
	CreateHearthstoneSlot();
	CreateHearthstonesTab(TransmogFrame.WardrobeCollection);
	CreateHearthstonesPanel(TransmogFrame.WardrobeCollection);
	EnsureHearthstoneSecureButton();
	RefreshHearthstoneSecureButton();
	UpdateHearthstoneSlot();
	RefreshHearthstoneList();

	if not HearthstonesInitialized then
		HearthstonesInitialized = true;

		hooksecurefunc(TransmogFrame.WardrobeCollection, "SetTab", function()
			HideHearthstoneTab();
		end)
	end
end

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
HearthstoneEventFrame:SetScript("OnEvent", function(self, event, ...)
	if event == "PLAYER_REGEN_ENABLED" and HearthstonePendingItemID ~= nil then
		SetHearthstoneSecureButtonItem(HearthstonePendingItemID);
	end

	if event == "GET_ITEM_INFO_RECEIVED" then
		local itemID = ...;
		if itemID == nil or not MogMount:hasValue(MogMount.HearthstoneToyItemIDs, itemID) then
			return;
		end
	end

	EnsureOutfitHearthstoneSaved();
	ScheduleInitializeHearthstones();
	UpdateHearthstoneSlot();
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

