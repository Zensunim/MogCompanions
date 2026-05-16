-- Mounts.lua
-- Contains all mount summon logic and the full mount UI inside the Transmog wardrobe.
--
-- Summon priority (MogCompanionsSummon):
--   1. Exit vehicle (CanExitVehicle)
--   2. Dismount if already mounted
--   3. [Ground modifier] + swimming → aquatic mount
--   4. [Repair modifier] → repair/vendor mount
--   5. [Random modifier] → random mount
--   6. Flyable area, no [Ground modifier] → flying mount
--   7. Fallback → ground mount
--
-- UI sections:
--   • Flying/ground mount slot icons in CharacterPreview.RightSlots (InitMountSlots)
--   • Mounts tab in WardrobeCollection with model previews + scrollable lists (InitMountTab)
--
-- SetSelectedFlyingMount / SetSelectedGroundMount are defined inside InitMountTab
-- (they close over local scroll-box references) and are forward-declared at file scope.
local _, addon = ...;
local ns = select(2, ...);
local MogCompanions = ns.MogCompanions;
local L = MogCompanionsLocales;

local MogCompanionsFrame;
local flyingMountFrame, flyingMountTexture, flyingMountBorder, flyingMountBorderTexture, flyingMountBorderHighlightTexture;
local groundMountFrame, groundMountTexture, groundMountBorder, groundMountBorderTexture, groundMountBorderHighlightTexture;

local FlyingMountPreview, GroundMountPreview;
local FlyingMountModel, GroundMountModel;
local FlyingMountPreviewControls, GroundMountPreviewControls;

local FlyingMountListScrollView, FlyingMountListScrollBox, FlyingMountListScrollBar, FlyingMountDataProvider;

local GroundMountListScrollView, GroundMountListScrollBox, GroundMountListScrollBar, GroundMountDataProvider;

local FlyingMountClear, GroundMountClear;
local FlyingMountShowSelectedButton, GroundMountShowSelectedButton;
local FlyingMountNoResultsText, GroundMountNoResultsText;
local SetSelectedFlyingMount, SetSelectedGroundMount;
local RefreshFlyingMountList, RefreshGroundMountList, RefreshMountSlots;
local FlyingSlotTitle, GroundSlotTitle;
local LastClickedFlyingMountID, LastClickedGroundMountID;
local ShowOnlySelectedFlyingMounts = false;
local ShowOnlySelectedGroundMounts = false;

local FlyingMountModeButtons = {};
local GroundMountModeButtons = {};
local MOUNT_RANDOM_FAVORITE_ICON = 6013777;
local MOUNT_PASSENGER_ICON = 134149;

local MountListSearchBox, FilterDropdown, MountShortcuts;

MogCompanions.MountSearchString = "";

MogCompanionsSelectedMount = {}
MogCompanionsSelectedMount.Flying = {}
MogCompanionsSelectedMount.Ground = {}

-- Returns race-appropriate placeholder icons for the flying and ground mount slots.
-- Used when no mount has been selected (slot shows a desaturated icon).
local function getEmptyMountIcon()
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

-- Nil-safe accessor for the currently viewed outfit ID in the transmog UI.
-- Guards against the frame not existing yet (e.g. before TRANSMOGRIFY_OPEN fires).
local function GetViewedOutfitID()
	if C_TransmogOutfitInfo == nil or C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID == nil then
		return nil;
	end

	return C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID();
end

-- Returns the saved-variable table for the viewed outfit, creating an empty entry
-- if it doesn't exist yet. Centralizing CreateEmptyOutfit here avoids every caller
-- needing to guard against a missing outfit table.
local function GetViewedOutfitData()
	local outfitID = GetViewedOutfitID();
	if outfitID == nil then
		return nil;
	end

	MogCompanions:CreateEmptyOutfit(outfitID);

	if MogCompanionsCharacterSaved == nil then
		return nil;
	end

	return MogCompanionsCharacterSaved["Outfit"..outfitID];
end

-- Normalizes a FlyingMountMode or GroundMountMode field to "Selected", "Favorite", or "Passenger".
-- modeKey is "FlyingMountMode" or "GroundMountMode". Missing or unknown values
-- default to "Selected" so existing outfits without the field behave as before.
local function GetNormalizedMountMode(outfit, modeKey)
	if type(outfit) ~= "table" then
		return "Selected";
	end

	local mode = outfit[modeKey];
	if mode == "Favorite" then
		return "Favorite";
	end
	if mode == "Passenger" then
		return "Passenger";
	end

	return "Selected";
end

-- Highlights only the button matching the active mode for the given mount slot.
-- modeKey distinguishes "FlyingMountMode" from "GroundMountMode" so both slots
-- share a single highlight function rather than duplicating the loop.
local function UpdateMountModeButtonHighlights(outfit, modeKey, buttons)
	local mode = GetNormalizedMountMode(outfit, modeKey);

	for key, button in pairs(buttons) do
		local selected = mode == key;
		if button.selectedBorder ~= nil then
			button.selectedBorder:SetShown(selected);
		end

		if selected then
			button:SetAlpha(1);
			button:LockHighlight();
		else
			button:SetAlpha(0.9);
			button:UnlockHighlight();
		end
	end
end

-- Resets all MogCompanionsSelectedMount[type] fields to nil.
-- All fields must be cleared together so tooltip / preview code never reads
-- stale icon or spellID data from a mount that is no longer selected.
local function ClearSelectedMountDetails(type)
	MogCompanionsSelectedMount[type].name = nil;
	MogCompanionsSelectedMount[type].spellID = nil;
	MogCompanionsSelectedMount[type].icon = nil;
	MogCompanionsSelectedMount[type].id = nil;
	MogCompanionsSelectedMount[type].display = nil;
	MogCompanionsSelectedMount[type].type = nil;
end

-- Returns the best mount ID to display in the preview model.
-- preferredMountID lets the last-clicked mount stay in the preview even when the
-- pool has multiple entries, giving the user immediate visual feedback on click.
-- preferLast=true is used on UI refresh to keep the most recently added mount visible.
-- Returns 1 when the pool is empty or no valid mount is found (sentinel for "none").
local function GetValidPoolMountSelection(outfit, poolKey, category, preferLast, preferredMountID)
	if outfit == nil then
		return 1;
	end

	if type(preferredMountID) == "number" and preferredMountID > 1 then
		if MogCompanions:IsMountUsableForCategory(preferredMountID, category) then
			return preferredMountID;
		end
	end

	local pool = MogCompanions:GetOutfitSelectionPool(outfit, poolKey);
	if pool == nil then
		return 1;
	end

	if preferLast then
		for i = #pool, 1, -1 do
			local mountID = pool[i];
			if type(mountID) == "number" and MogCompanions:IsMountUsableForCategory(mountID, category) then
				return mountID;
			end
		end
	else
		for i = 1, #pool do
			local mountID = pool[i];
			if type(mountID) == "number" and MogCompanions:IsMountUsableForCategory(mountID, category) then
				return mountID;
			end
		end
	end

	return 1;
end

-- Writes the first valid pool mount back into the legacy scalar key (outfit.Flying /
-- outfit.Ground). This keeps the legacy key in sync so old macros and saved-variable
-- readers that predate the pool feature continue to work correctly.
local function SyncLegacyMountSelection(outfit, legacyKey, poolKey, category)
	if outfit == nil then
		return 1;
	end

	local mountID = GetValidPoolMountSelection(outfit, poolKey, category, false);
	if mountID > 1 then
		outfit[legacyKey] = mountID;
		return mountID;
	end

	outfit[legacyKey] = 1;
	return 1;
end

-- Returns the number of currently valid (collected + usable) mounts in the pool.
-- Used to decide the section title text: "Flying Mounts (3)" vs. "Flying Mounts".
local function GetValidMountSelectionCount(outfit, poolKey, category)
	return #MogCompanions:GetValidMountPoolInfos(outfit, poolKey, category);
end

-- Updates the section header to show the selection count when count > 0.
-- When count is 0 the header shows the plain label to avoid confusing "(0)" clutter.
local function SetMountSectionTitle(titleFontString, baseText, count)
	if titleFontString == nil then
		return;
	end

	if count > 0 then
		titleFontString:SetText(baseText.." "..string.format(L["Selected Count Format"], count));
	else
		titleFontString:SetText(baseText);
	end
end

-- Adapter functions that match the isValidFunc(self, mountID) callback signature
-- expected by GetValidSelectionPoolValues. Delegates to IsMountUsableForCategory
-- so validation logic stays centralized in Shared.lua.
local function ValidateFlyingMountSelection(_, mountID)
	return MogCompanions:IsMountUsableForCategory(mountID, "flying");
end

local function ValidateGroundMountSelection(_, mountID)
	return MogCompanions:IsMountUsableForCategory(mountID, "ground");
end

-- Returns valid mounts from the pool that also match the current search string.
-- Applied only in the "Show Selected" view; the normal list is filtered by the
-- scroll view's own search path so this avoids double-filtering in that case.
local function GetFilteredSelectedMountInfos(outfit, poolKey, category)
	local mounts = MogCompanions:GetValidMountPoolInfos(outfit, poolKey, category);
	if MogCompanions.MountSearchString == nil or MogCompanions.MountSearchString == "" then
		return mounts;
	end

	local filtered = {};
	for i = 1, #mounts do
		if MogCompanions:listSearchString(mounts[i].name) then
			table.insert(filtered, mounts[i]);
		end
	end

	return filtered;
end

-- Updates the 3D model preview for a mount slot.
-- Sets alpha=0 rather than hiding the frame when there is no valid mount, so the
-- frame still occupies space and the layout does not shift around.
local function UpdateMountPreviewModel(modelFrame, previewControls, mountID)
	if modelFrame == nil then
		return;
	end

	local displayID = nil;
	if mountID ~= nil and mountID > 1 then
		displayID = C_MountJournal.GetMountInfoExtraByID(mountID);
	end

	if displayID ~= nil and displayID > 0 then
		modelFrame:SetDisplayInfo(displayID);
		if previewControls ~= nil then
			previewControls.reset();
		end
		modelFrame:SetAlpha(1);
	else
		modelFrame:SetDisplayInfo(0);
		if previewControls ~= nil then
			previewControls.reset();
		end
		modelFrame:SetAlpha(0);
	end
end

-- Builds tooltip lines for the mount slot hover, capped at 3 previewed names
-- plus an overflow line. Callers use the returned count to decide whether to show
-- the tooltip at all (empty pool = no tooltip).
local function GetMountTooltipLines(outfit, poolKey, category)
	local mounts = MogCompanions:GetValidMountPoolInfos(outfit, poolKey, category);
	local tooltipLines = {};

	if #mounts > 0 then
		table.insert(tooltipLines, string.format(L["Random From Selected Mounts"], #mounts));

		for i = 1, math.min(3, #mounts) do
			table.insert(tooltipLines, mounts[i].nameAndIcon or mounts[i].name);
		end

		if #mounts > 3 then
			table.insert(tooltipLines, string.format(L["More Selected Mounts"], #mounts - 3));
		end
	end

	return tooltipLines, #mounts;
end

-- Refreshes one mount slot icon and its preview model for the currently viewed outfit.
-- Parameterized so flying and ground slots share a single implementation; all
-- slot-specific state (textures, frame refs, pool keys) is passed by the caller.
-- When FlyingMountMode or GroundMountMode is "Favorite", a star icon is shown
-- instead of a specific mount to indicate the per-outfit Favorite mode is active.
local function UpdateMountSlot(type, legacyKey, poolKey, category, texture, frame, borderTexture, borderHighlightTexture, previewModel, previewControls, emptyIcon)
	if texture == nil or frame == nil or borderTexture == nil or borderHighlightTexture == nil then
		return;
	end

	local outfit = GetViewedOutfitData();
	if outfit == nil then
		return;
	end

	-- Favorite mode: show star icon and skip pool/preview logic.
	if GetNormalizedMountMode(outfit, type.."MountMode") == "Favorite" then
		texture:SetTexture(MOUNT_RANDOM_FAVORITE_ICON);
		texture:SetDesaturated(false);
		texture:SetVertexColor(1, 1, 1);
		borderTexture:SetAtlas("transmog-gearSlot-default");
		borderHighlightTexture:SetAtlas("transmog-gearSlot-default");
		ClearSelectedMountDetails(type);
		texture:SetAllPoints(frame);
		frame.texture = texture;
		UpdateMountPreviewModel(previewModel, previewControls, nil);
		return;
	end

	-- Passenger mode: show group/passenger icon and skip pool/preview logic.
	if GetNormalizedMountMode(outfit, type.."MountMode") == "Passenger" then
		texture:SetTexture(MOUNT_PASSENGER_ICON);
		texture:SetDesaturated(false);
		texture:SetVertexColor(1, 1, 1);
		borderTexture:SetAtlas("transmog-gearSlot-default");
		borderHighlightTexture:SetAtlas("transmog-gearSlot-default");
		ClearSelectedMountDetails(type);
		texture:SetAllPoints(frame);
		frame.texture = texture;
		UpdateMountPreviewModel(previewModel, previewControls, nil);
		return;
	end

	local mountID = SyncLegacyMountSelection(outfit, legacyKey, poolKey, category);
	if mountID > 1 then
		local name, spellID, icon = C_MountJournal.GetMountInfoByID(mountID);
		if icon ~= nil then
			texture:SetTexture(icon);
			texture:SetDesaturated(false);
			texture:SetVertexColor(1, 1, 1);
			borderTexture:SetAtlas("transmog-gearSlot-transmogrified");
			borderHighlightTexture:SetAtlas("transmog-gearSlot-transmogrified");
			MogCompanions:UpdateSelectMountDetails(type, mountID);
		else
			mountID = 1;
		end
	end

	if mountID <= 1 then
		texture:SetTexture(emptyIcon);
		texture:SetDesaturated(true);
		texture:SetVertexColor(0.63, 0.63, 0.63);
		borderTexture:SetAtlas("transmog-gearSlot-default");
		borderHighlightTexture:SetAtlas("transmog-gearSlot-default");
		ClearSelectedMountDetails(type);
	end

	texture:SetAllPoints(frame);
	frame.texture = texture;
	if type == "Flying" then
		UpdateMountPreviewModel(previewModel, previewControls, GetValidPoolMountSelection(outfit, poolKey, category, false, LastClickedFlyingMountID));
	else
		UpdateMountPreviewModel(previewModel, previewControls, GetValidPoolMountSelection(outfit, poolKey, category, false, LastClickedGroundMountID));
	end
end

-- Refreshes both mount slots and their section title counts for the viewed outfit.
-- Called after any selection change and on VIEWED_TRANSMOG_OUTFIT_CHANGED so the
-- panel always reflects the current outfit's pool state.
RefreshMountSlots = function()
	local outfit = GetViewedOutfitData();
	if outfit == nil then
		return;
	end

	local flyingIcon, groundIcon = getEmptyMountIcon();
	UpdateMountSlot("Flying", "Flying", "FlyingMounts", "flying", flyingMountTexture, flyingMountFrame, flyingMountBorderTexture, flyingMountBorderHighlightTexture, FlyingMountModel, FlyingMountPreviewControls, flyingIcon);
	UpdateMountSlot("Ground", "Ground", "GroundMounts", "ground", groundMountTexture, groundMountFrame, groundMountBorderTexture, groundMountBorderHighlightTexture, GroundMountModel, GroundMountPreviewControls, groundIcon);

	SetMountSectionTitle(FlyingSlotTitle, L["Mount Tab Flying Section Title"], GetValidMountSelectionCount(outfit, "FlyingMounts", "flying"));
	SetMountSectionTitle(GroundSlotTitle, L["Mount Tab Ground Section Title"], GetValidMountSelectionCount(outfit, "GroundMounts", "ground"));

	UpdateMountModeButtonHighlights(outfit, "FlyingMountMode", FlyingMountModeButtons);
	UpdateMountModeButtonHighlights(outfit, "GroundMountMode", GroundMountModeButtons);
end

-- ── Mount Summon Functions ──────────────────────────────────────────────────────
-- Flying/Ground: use a random valid per-outfit pool selection when available,
-- otherwise fall back to the existing random category behavior.
-- Aquatic/Repair: use global default if set (> 1), otherwise random from category.
-- Random: always random from all collected usable mounts.
function MogCompanionsSummonFlying()
	local outfitData = MogCompanions:GetActiveOutfitTable();
	if outfitData ~= nil and GetNormalizedMountMode(outfitData, "FlyingMountMode") == "Favorite" then
		-- SummonByID(0) is the WoW-native "summon random favorite" API. It respects
		-- the player's Mount Journal favorites without any manual filtering needed.
		C_MountJournal.SummonByID(0);
		return;
	end
	if outfitData ~= nil and GetNormalizedMountMode(outfitData, "FlyingMountMode") == "Passenger" then
		-- Passenger mode delegates to MogCompanionsSummonPassenger which prefers a
		-- flying passenger mount in flyable areas and falls back to ground passengers.
		MogCompanionsSummonPassenger();
		return;
	end
	local validMounts = MogCompanions:GetValidMountPoolInfos(outfitData, "FlyingMounts", "flying");
	if #validMounts > 0 then
		local selectedMount = validMounts[math.random(1, #validMounts)];
		C_MountJournal.SummonByID(selectedMount.id);
	else
		local randomMount = MogCompanions:getRandomMount("flying");
		if randomMount then C_MountJournal.SummonByID(randomMount.id); end
	end
end

function MogCompanionsSummonGround()
	local outfitData = MogCompanions:GetActiveOutfitTable();
	if outfitData ~= nil and GetNormalizedMountMode(outfitData, "GroundMountMode") == "Favorite" then
		-- SummonByID(0) is the WoW-native "summon random favorite" API. It respects
		-- the player's Mount Journal favorites without any manual filtering needed.
		C_MountJournal.SummonByID(0);
		return;
	end
	if outfitData ~= nil and GetNormalizedMountMode(outfitData, "GroundMountMode") == "Passenger" then
		-- Passenger mode on the ground slot always picks a ground-capable passenger
		-- mount. MogCompanionsSummonPassenger handles the area check internally.
		local mount = MogCompanions:getRandomMount("passenger_ground");
		if mount then C_MountJournal.SummonByID(mount.id); end
		return;
	end
	local validMounts = MogCompanions:GetValidMountPoolInfos(outfitData, "GroundMounts", "ground");
	if #validMounts > 0 then
		local selectedMount = validMounts[math.random(1, #validMounts)];
		C_MountJournal.SummonByID(selectedMount.id);
	else
		local randomMount = MogCompanions:getRandomMount("ground");
		if randomMount then C_MountJournal.SummonByID(randomMount.id); end
	end
end

-- Summons the aquatic mount for this character.
-- Falls back to a random aquatic mount when no default is saved (value <= 1).
-- Aquatic mounts are matched by mountTypeID (231, 232, 254, 407, 436) in Shared.lua.
function MogCompanionsSummonAquatic()
	if MogCompanionsCharacterSaved.Default.Aquatic <= 1 then
		local randomMount = MogCompanions:getRandomMount("aquatic");
		if randomMount then C_MountJournal.SummonByID(randomMount.id); end
	else
		C_MountJournal.SummonByID(MogCompanionsCharacterSaved.Default.Aquatic);
	end
end

-- Summons the repair/vendor mount for this character.
-- Falls back to a random repair mount when no default is saved (value <= 1).
-- Repair mounts are matched by hardcoded mount IDs in Shared.lua (repairMountIDs).
function MogCompanionsSummonRepair()
	if MogCompanionsCharacterSaved.Default.Repair <= 1 then
		local randomMount = MogCompanions:getRandomMount("repair");
		if randomMount then C_MountJournal.SummonByID(randomMount.id); end
	else
		C_MountJournal.SummonByID(MogCompanionsCharacterSaved.Default.Repair);
	end
end

-- Summons a random mount. Picks flying when in a flyable area, ground otherwise.
-- Ignores per-outfit pool assignments entirely — the Random modifier is meant to
-- break out of the outfit's curated selection and pull from the full collection.
function MogCompanionsSummonRandom()
	local randomMount;
	if IsFlyableArea() then
		randomMount = MogCompanions:getRandomMount("flying");
	else
		randomMount = MogCompanions:getRandomMount("ground");
	end
	if randomMount then C_MountJournal.SummonByID(randomMount.id); end
end

-- Summons a random mount from the player's favorited mounts in the Mount Journal.
-- SummonByID(0) is the WoW-native "summon random favorite" call — no manual
-- filtering needed. WoW handles area/flyability rules internally.
function MogCompanionsSummonFavoriteMount()
	C_MountJournal.SummonByID(0);
end

-- Summons a random passenger-capable mount appropriate for the current zone.
-- In flyable areas, prefers flying passenger mounts (e.g. Sandstone Drake, Obsidian
-- Nightwing, Skychaser) so both players can fly together. Falls back to ground
-- passenger mounts when no flying passenger mount is available or collected.
-- In non-flyable areas, only ground passenger mounts are candidates.
function MogCompanionsSummonPassenger()
	local mount;
	if IsFlyableArea() then
		mount = MogCompanions:getRandomMount("passenger_flying");
		if not mount then
			mount = MogCompanions:getRandomMount("passenger_ground");
		end
		if not mount then
			mount = MogCompanions:getRandomMount("flying");
		end
	else
		mount = MogCompanions:getRandomMount("passenger_ground");
		if not mount then
			mount = MogCompanions:getRandomMount("ground");
		end
	end
	if mount then
		C_MountJournal.SummonByID(mount.id);
	end
end

-- Cache: spellID → mountID for all collected, usable mounts owned by this character.
-- nil means the cache has not been built yet (or was invalidated).
-- Rebuilt lazily on the next tryCloneTargetedMount call.
local mountCloneCache = nil;

local function buildMountCloneCache()
	mountCloneCache = {};
	local mountIDs = C_MountJournal.GetMountIDs();
	for _, mountID in ipairs(mountIDs) do
		local name, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected = C_MountJournal.GetMountInfoByID(mountID);
		if isCollected and isUsable and not shouldHideOnChar and spellID then
			mountCloneCache[spellID] = mountID;
		end
	end
end

-- Invalidate the cache when mount collection or usability changes.
local MountCloneCacheFrame = CreateFrame("Frame");
MountCloneCacheFrame:RegisterEvent("NEW_MOUNT_ADDED");
MountCloneCacheFrame:RegisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED");
MountCloneCacheFrame:SetScript("OnEvent", function() mountCloneCache = nil; end);

-- Returns the mount ID of the mount the target player is riding, if the local
-- player also has that mount collected and usable. Returns nil otherwise.
-- Used by MogCompanionsSummon when CloneTargetedMount is enabled.
local function tryCloneTargetedMount()
	if not MogCompanionsSaved.CloneTargetedMount then return nil; end
	if not UnitExists("target") then return nil; end
	if not UnitIsPlayer("target") then return nil; end

	if not mountCloneCache then
		buildMountCloneCache();
	end

	-- Scan the target's buffs (typically < 40) and do an O(1) cache lookup per entry.
	local i = 1;
	while true do
		local aura = C_UnitAuras.GetAuraDataByIndex("target", i, "HELPFUL");
		if not aura then break; end
		if aura.spellId and mountCloneCache[aura.spellId] then
			return mountCloneCache[aura.spellId];
		end
		i = i + 1;
	end

	return nil;
end

-- Returns true if the modifier key configured for modType is currently held.
-- modType: "Ground" | "Repair" | "Random"
-- Reads MogCompanionsSaved.MountMods: 1=CTRL, 2=SHIFT, 3=ALT.
-- Falls back to legacy hardcoded keys if MountMods is not yet initialised.
local function GetMountModKey(modType)
	local mods = {};
	mods[1] = IsControlKeyDown();
	mods[2] = IsShiftKeyDown();
	mods[3] = IsAltKeyDown();

	if MogCompanionsSaved and MogCompanionsSaved.MountMods then
		if modType == "Repair" then
			return mods[MogCompanionsSaved.MountMods.Repair] or false;
		elseif modType == "Ground" then
			return mods[MogCompanionsSaved.MountMods.Ground] or false;
		elseif modType == "Random" then
			return mods[MogCompanionsSaved.MountMods.Random] or false;
		end
	else
		-- Fallback: legacy hardcoded behaviour (CTRL=Ground, SHIFT=Repair, ALT=Random)
		if modType == "Repair" then return IsShiftKeyDown(); end
		if modType == "Ground" then return IsControlKeyDown(); end
		if modType == "Random" then return IsAltKeyDown(); end
	end

	return false;
end

-- Main mount/dismount entry point. Evaluates current state and modifier keys
-- to determine which category to summon, then calls the appropriate helper.
-- Also applies the per-outfit title after summoning via MogCompanions:UpdateTitle().
function MogCompanionsSummon()
	if CanExitVehicle() then
		VehicleExit();
	elseif IsMounted() then
		Dismount();
	elseif IsSwimming() and GetMountModKey("Ground") then
		-- Aquatic mount: Ground modifier + swimming
		MogCompanionsSummonAquatic();
	elseif GetMountModKey("Repair") then
		-- Repair bear, yak, or long boi
		MogCompanionsSummonRepair();
	elseif GetMountModKey("Random") then
		-- Random mount from all collected usable mounts
		MogCompanionsSummonRandom();
	else
		-- Flyable or ground. Try cloning the targeted player's mount first;
		-- a successful clone ignores the "allow flying in ground" setting entirely.
		local cloneID = tryCloneTargetedMount();
		if cloneID then
			C_MountJournal.SummonByID(cloneID);
		elseif IsFlyableArea() and not GetMountModKey("Ground") then
			-- Flyable
			MogCompanionsSummonFlying();
		else
			-- Ground or when Ground modifier is pressed
			MogCompanionsSummonGround();
		end
	end

	MogCompanions:UpdateTitle();
	MogCompanions:HandleAutoPetSummon("PetSummonOnMount");
end

-- ── Mount Slot UI (CharacterPreview) ─────────────────────────────────────────
-- Creates the flying and ground mount slot icons beside the outfit preview.
-- reset=true builds the frames (first call only); subsequent calls just refresh icons.
-- Hooks OnEnter/OnLeave/OnMouseDown on the slot borders each time (reset=true only).
-- Do NOT call during combat — creates and reparents frames.
function MogCompanions:InitMountSlots(reset)
	if reset then

		local point, relativeTo, relativePoint, xOfs, yOfs = TransmogFrame.CharacterPreview.RightSlots:GetPoint();
		TransmogFrame.CharacterPreview.RightSlots:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs + 80);

		MogCompanionsFrame = CreateFrame("Frame", "MogCompanionsFrame", TransmogFrame.CharacterPreview.RightSlots);
		MogCompanionsFrame:SetFrameStrata("MEDIUM");
		MogCompanionsFrame:SetSize(44, 120);

		local point, relativeTo, relativePoint, xOfs, yOfs = TransmogFrame.CharacterPreview.RightSlots:GetPoint();
		MogCompanionsFrame:SetPoint("TOPLEFT", TransmogFrame.CharacterPreview.RightSlots, "BOTTOMLEFT", xOfs + 35, yOfs + MogCompanions.TransmogSlotOffsets.FirstMount);
		
		-- Flying Mount Frame

		flyingMountFrame = CreateFrame("Frame", "FlyingMountFrame", MogCompanionsFrame);
		flyingMountFrame:SetFrameStrata("MEDIUM");
		flyingMountFrame:SetSize(44, 44);

		local point, relativeTo, relativePoint, xOfs, yOfs = MogCompanionsFrame:GetPoint();
		flyingMountFrame:SetPoint("TOPLEFT", MogCompanionsFrame, "TOPLEFT", 0, 0);
		flyingMountFrame:Show();

		flyingMountTexture = flyingMountFrame:CreateTexture(nil,"BACKGROUND");

		-- Flying Mount Border

		local borderSize = 59;
		local borderOffset = 7;

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

		-- Flying Mount Border Highlight

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
			local outfit = GetViewedOutfitData();
			if outfit ~= nil then
				ShowOnlySelectedFlyingMounts = false;
				outfit.FlyingMountMode = "Selected";
				MogCompanions:ClearSelectionPool(outfit, "FlyingMounts");
				SyncLegacyMountSelection(outfit, "Flying", "FlyingMounts", "flying");
				RefreshMountSlots();
				if RefreshFlyingMountList ~= nil then
					RefreshFlyingMountList(false);
				end
				PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK);
			end
			FlyingMountClear:Hide();
		end)				

		-- Ground Mount Frame

		groundMountFrame = CreateFrame("Frame", "GroundMountFrame", MogCompanionsFrame)
		groundMountFrame:SetFrameStrata("MEDIUM");
		groundMountFrame:SetSize(44, 44);

		local point, relativeTo, relativePoint, xOfs, yOfs = MogCompanionsFrame:GetPoint();
		groundMountFrame:SetPoint("TOPLEFT", MogCompanionsFrame, "TOPLEFT", 0, MogCompanions.TransmogSlotOffsets.GroundMount);
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

		-- Ground Mount Border Highlight

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
			local outfit = GetViewedOutfitData();
			if outfit ~= nil then
				ShowOnlySelectedGroundMounts = false;
				outfit.GroundMountMode = "Selected";
				MogCompanions:ClearSelectionPool(outfit, "GroundMounts");
				SyncLegacyMountSelection(outfit, "Ground", "GroundMounts", "ground");
				RefreshMountSlots();
				if RefreshGroundMountList ~= nil then
					RefreshGroundMountList(false);
				end
				PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK);
			end
			GroundMountClear:Hide();
		end)	

	end

	RefreshMountSlots();

	if reset then

		flyingMountBorder:HookScript("OnEnter", function()
			GameTooltip:SetOwner(flyingMountBorder, "ANCHOR_RIGHT");
			GameTooltip:SetText(L["Item Slot Flying Mount Title"]);

			local outfit = GetViewedOutfitData();
			if outfit ~= nil and GetNormalizedMountMode(outfit, "FlyingMountMode") == "Favorite" then
				GameTooltip:AddLine(L["Random Favorite Mount"], 1, 1, 1);
				FlyingMountClear:Show();
			elseif outfit ~= nil and GetNormalizedMountMode(outfit, "FlyingMountMode") == "Passenger" then
				GameTooltip:AddLine(L["Random Passenger Mount"], 1, 1, 1);
				FlyingMountClear:Show();
			else
				local tooltipLines, count = GetMountTooltipLines(outfit, "FlyingMounts", "flying");
				for i = 1, #tooltipLines do
					GameTooltip:AddLine(tooltipLines[i], 1, 1, 1);
				end

				if count > 0 then
					FlyingMountClear:Show();
				end
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
			MogCompanions:OpenCompanionsTab("Mounts");
		 	PlaySound(SOUNDKIT.UI_TRANSMOG_GEAR_SLOT_CLICK);
		end)

		groundMountBorder:HookScript("OnEnter", function()
			GameTooltip:SetOwner(groundMountBorder, "ANCHOR_RIGHT")
			GameTooltip:SetText(L["Item Slot Ground Mount Title"]);

			local outfit = GetViewedOutfitData();
			if outfit ~= nil and GetNormalizedMountMode(outfit, "GroundMountMode") == "Favorite" then
				GameTooltip:AddLine(L["Random Favorite Mount"], 1, 1, 1);
				GroundMountClear:Show();
			elseif outfit ~= nil and GetNormalizedMountMode(outfit, "GroundMountMode") == "Passenger" then
				GameTooltip:AddLine(L["Random Passenger Mount"], 1, 1, 1);
				GroundMountClear:Show();
			else
				local tooltipLines, count = GetMountTooltipLines(outfit, "GroundMounts", "ground");
				for i = 1, #tooltipLines do
					GameTooltip:AddLine(tooltipLines[i], 1, 1, 1);
				end

				if count > 0 then
					GroundMountClear:Show();
				end
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
			MogCompanions:OpenCompanionsTab("Mounts");
			PlaySound(SOUNDKIT.UI_TRANSMOG_GEAR_SLOT_CLICK);
		end)

	end
end

-- Selection-changed callback for the flying mount ScrollBox.
-- Toggles highlight lock on list rows to show/hide the selection state.
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

-- Selection-changed callback for the ground mount ScrollBox.
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

-- Returns true if the player has neither a MogCompanions keybind nor a MogCompanions macro
-- on any action bar slot. Retained as a compatibility helper for setup state checks.
function MissingKeybindOrMacro()
	local key1, key2 = '', '';
	key1, key2 = GetBindingKey("MOGCOMPANIONS_MOUNT_DISMOUNT");

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
				if currentMacroName == "MogComp Mount" then
					missingMacro = false;
				end
			end
  		end
	end

	return missingMacro and missingKeys;
end

-- ── Mount Tab UI Helpers ────────────────────────────────────────────────────────
local function FilterIsChecked(filter)
	return MogCompanionsSaved.ShowFlyingInGround;
end

local function FilterSetChecked(filter)
	if FilterIsChecked(filter) then
		MogCompanionsSaved.ShowFlyingInGround = false;
	else
		MogCompanionsSaved.ShowFlyingInGround = true;
	end

	if RefreshGroundMountList ~= nil then
		RefreshGroundMountList(true);
	end
end

local function CreateShortcuts(f, topOffset)
	MountShortcuts = MogCompanions:CreateCompanionsShortcutMenu(f, "MogCompanionsMountShortcuts");
	MountShortcuts:SetPoint("TOPRIGHT", f, "TOPRIGHT", -26, -50 + (topOffset or 0));
end

local function GetConfiguredMountMacroConditionLabel(mountID)
	if mountID == nil or mountID <= 1 then
		return nil;
	end

	local mountName = C_MountJournal.GetMountInfoByID(mountID);
	if mountName ~= nil and mountName ~= "" then
		return mountName;
	end

	return nil;
end

function MogCompanions:CreateMountMacro(parent, options)
	if InCombatLockdown and InCombatLockdown() then
		print(L["Macro Combat Error"]);
		return nil;
	end

	local updateExistingOnly = options == true or (type(options) == "table" and options.updateExistingOnly == true);
	local macroId = MogCompanions:FindMacroByExactName("MogComp Mount");
	if updateExistingOnly and macroId == nil then
		return nil;
	end

	local macroIcon = 6841475;
	local outfitData = MogCompanions:GetActiveOutfitTable();
	local mountMods = MogCompanionsSaved and MogCompanionsSaved.MountMods or {};
	local modTokens = { "ctrl", "shift", "alt" };
	local groundToken = modTokens[mountMods.Ground or 1] or "ctrl";
	local repairToken = modTokens[mountMods.Repair or 2] or "shift";
	local tooltipParts = {};

	local aquaticName = GetConfiguredMountMacroConditionLabel(MogCompanionsCharacterSaved and MogCompanionsCharacterSaved.Default and MogCompanionsCharacterSaved.Default.Aquatic);
	if aquaticName ~= nil then
		table.insert(tooltipParts, "[swimming,mod:"..groundToken.."]"..aquaticName);
	end

	local repairName = GetConfiguredMountMacroConditionLabel(MogCompanionsCharacterSaved and MogCompanionsCharacterSaved.Default and MogCompanionsCharacterSaved.Default.Repair);
	if repairName ~= nil then
		table.insert(tooltipParts, "[mod:"..repairToken.."]"..repairName);
	end

	local flyingName = nil;
	local groundName = nil;
	if outfitData ~= nil then
		flyingName = GetConfiguredMountMacroConditionLabel(outfitData.Flying);
		groundName = GetConfiguredMountMacroConditionLabel(outfitData.Ground);
	end

	if flyingName ~= nil then
		table.insert(tooltipParts, "[flyable,nomod:"..groundToken.."]"..flyingName);
	end
	if groundName ~= nil then
		table.insert(tooltipParts, groundName);
	end

	local macroBody = "#showtooltip";
	if #tooltipParts > 0 then
		macroBody = macroBody.." "..table.concat(tooltipParts, ";")..";";
	end
	macroBody = macroBody.."\n/mcomp mount";

	if MogCompanionsSaved ~= nil and MogCompanionsSaved.DynamicMountMacroIcon == true and #tooltipParts > 0 then
		macroIcon = 134400;
	end

	if macroId == nil then
		macroId = CreateMacro("MogComp Mount", macroIcon, macroBody, nil);
	else
		EditMacro(macroId, "MogComp Mount", macroIcon, macroBody, nil);
	end

	if MogCompanionsSaved ~= nil then
		MogCompanionsSaved.MacroID = macroId;
	end

	if parent ~= nil then
		PickupMacro(macroId);
		GameTooltip:SetOwner(parent, "ANCHOR_CURSOR_RIGHT");
		GameTooltip:AddLine(L["Drop Macro Tooltip"], 1, 1, 1);
		GameTooltip:Show();
	end

	return macroId;
end

-- ── Mounts Tab UI (WardrobeCollection) ────────────────────────────────────────
-- Creates the full Mounts tab inside WardrobeCollection on first call (idempotent).
-- Contains: flying/ground model preview frames, scrollable mount lists, search box,
-- and filter dropdown (show flying in ground list).
-- SetSelectedFlyingMount and SetSelectedGroundMount are defined here as closures
-- over the local scroll-box and data-provider references.
function MogCompanions:InitMountTab()
	local collection = TransmogFrame and TransmogFrame.WardrobeCollection;
	if collection == nil or collection.TabContent == nil or collection.AddNamedTab == nil then
		return;
	end

	if not collection.companionsTabID then

		function TransmogFrame.WardrobeCollection:UpdateTabs()
			if self.TabHeaders then
				if self.itemsTabID then self.TabHeaders:SetTabShown(self.itemsTabID, true); end
				if self.setsTabID then self.TabHeaders:SetTabShown(self.setsTabID, true); end
				if self.custmSetsTabID then self.TabHeaders:SetTabShown(self.custmSetsTabID, true); end
				if self.situationsTabID then self.TabHeaders:SetTabShown(self.situationsTabID, true); end
				if self.companionsTabID then self.TabHeaders:SetTabShown(self.companionsTabID, true); end
			end
		end

		-- Layout scale factor (6/7 ≈ 0.857) that maps the 360-unit preview design coords to the wardrobe tab's actual rendered dimensions.
		local s = 0.85714285714;
		local topOffset = 26;

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

		local CompanionsFrame = CreateFrame("Frame", "MogCompanionsCompanionsFrame", collection.TabContent);
		CompanionsFrame:SetAllPoints(true);
		CompanionsFrame:SetFrameStrata("HIGH");
		CompanionsFrame:Hide();

		local f = CreateFrame("Frame", "MountsFrame", CompanionsFrame);
		f:SetAllPoints(true);
		f:SetFrameStrata("HIGH");
		f:Hide();

		-- Mount tab controls: gear dropdown, filter dropdown, and search box

		CreateShortcuts(f, topOffset);

		FilterDropdown = CreateFrame("DropdownButton", nil, f, "WowStyle1FilterDropdownTemplate");
		FilterDropdown:SetPoint("TOPRIGHT", f, "TOPRIGHT", -60, -50 + topOffset);
		FilterDropdown:SetWidth(104);		
		FilterDropdown.resizeToText = false;
		FilterDropdown:SetupMenu(function(dropdown, rootDescription)
				rootDescription:CreateCheckbox(L["Show Flying In Ground Toggle"], FilterIsChecked, FilterSetChecked);
		end)

		---		

		MountListSearchBox = CreateFrame("EditBox", "MountListSearchBox", f, "TransmogSearchBoxTemplate");
		MountListSearchBox:SetPoint("TOPRIGHT", -174, -50 + topOffset); --- -32, -444

		local iconPostion, iconParent, iconParentPostion, iconX, iconY = MountListSearchBox.searchIcon:GetPoint();
		MountListSearchBox.searchIcon:SetPoint(iconPostion, iconParent, iconParentPostion, iconX, iconY + 1);

		-- Flying and ground section title labels

		FlyingSlotTitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge");
		FlyingSlotTitle:SetJustifyH("LEFT");
		FlyingSlotTitle:SetPoint("TOPLEFT", 24, -76 + topOffset);
		FlyingSlotTitle:SetText(L["Mount Tab Flying Section Title"]);

		local FlyingSlotTitleDivider = f:CreateTexture();
		FlyingSlotTitleDivider:SetAtlas("transmog-tabs-header-line", true);
		FlyingSlotTitleDivider:SetAlpha(0.1);
		FlyingSlotTitleDivider:SetPoint("TOPLEFT", FlyingSlotTitle, "BOTTOMLEFT", 0, -2);

		GroundSlotTitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge");
		GroundSlotTitle:SetJustifyH("LEFT");
		GroundSlotTitle:SetPoint("TOPLEFT", 24, -444 + topOffset);
		GroundSlotTitle:SetText(L["Mount Tab Ground Section Title"]);

		local GroundSlotTitleDivider = f:CreateTexture();
		GroundSlotTitleDivider:SetAtlas("transmog-tabs-header-line", true);
		GroundSlotTitleDivider:SetAlpha(0.1);
		GroundSlotTitleDivider:SetPoint("TOPLEFT", GroundSlotTitle, "BOTTOMLEFT", 0, -2);

		-- Load display info for the flying and ground model previews

		local outfit = GetViewedOutfitData();
		local flyingModelID = nil;
		local groundModelID = nil;

		if outfit ~= nil then
			local flyingMountID = SyncLegacyMountSelection(outfit, "Flying", "FlyingMounts", "flying");
			local groundMountID = SyncLegacyMountSelection(outfit, "Ground", "GroundMounts", "ground");
			flyingModelID = C_MountJournal.GetMountInfoExtraByID(GetValidPoolMountSelection(outfit, "FlyingMounts", "flying", true));
			groundModelID = C_MountJournal.GetMountInfoExtraByID(GetValidPoolMountSelection(outfit, "GroundMounts", "ground", true));
		end

		-- Flying mount model preview frame and list

		FlyingMountPreview = CreateFrame("Frame", "MountTabFlyingPreview", f);
		FlyingMountPreview:SetPoint("TOPLEFT", f, "TOPLEFT", 24 * s, (-114 + topOffset) * s);
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
		FlyingMountPreviewControls = MogCompanions:AttachPreviewModelControls(FlyingMountPreview, FlyingMountModel, {
			zoom = 1,
			minZoom = 0.4,
			maxZoom = 3.0,
			facing = -5.5,
			x = 0,
			y = 0,
			z = 0,
			buttonOffsetY = -8,
			controlNamePrefix = "MogCompanionsFlyingMountPreview",
		});

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

		FlyingMountShowSelectedButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate");
		FlyingMountShowSelectedButton:SetSize(110, 22);
		FlyingMountShowSelectedButton:SetPoint("BOTTOMRIGHT", FlyingMountList, "TOPRIGHT", 0, 4);
		FlyingMountShowSelectedButton:SetText(L["Show Selected"]);
		FlyingMountShowSelectedButton:Hide();
		FlyingMountShowSelectedButton:SetScript("OnClick", function()
			ShowOnlySelectedFlyingMounts = not ShowOnlySelectedFlyingMounts;
			RefreshFlyingMountList(false);
		end);

		-- Flying mount Favorite mode button. Sits above the top-left of the list so it
		-- does not obscure the ShowSelected button (which anchors to the top-right).
		-- Clicking it clears the flying pool and enters Favorite mode; clicking any mount
		-- in the list exits Favorite mode by setting FlyingMountMode back to "Selected".
		local flyingFavoriteBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate");
		flyingFavoriteBtn:SetSize(30, 30);
		flyingFavoriteBtn:SetPoint("BOTTOMLEFT", FlyingMountList, "TOPLEFT", 12, 6);
		flyingFavoriteBtn:SetFrameStrata("HIGH");
		flyingFavoriteBtn:SetFrameLevel(FlyingMountList:GetFrameLevel() + 5);
		flyingFavoriteBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD");
		flyingFavoriteBtn.icon = flyingFavoriteBtn:CreateTexture(nil, "ARTWORK");
		flyingFavoriteBtn.icon:SetPoint("TOPLEFT", flyingFavoriteBtn, "TOPLEFT", -2, 2);
		flyingFavoriteBtn.icon:SetPoint("BOTTOMRIGHT", flyingFavoriteBtn, "BOTTOMRIGHT", 2, -2);
		flyingFavoriteBtn.icon:SetTexture(MOUNT_RANDOM_FAVORITE_ICON);
		flyingFavoriteBtn.selectedBorder = flyingFavoriteBtn:CreateTexture(nil, "OVERLAY");
		flyingFavoriteBtn.selectedBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border");
		flyingFavoriteBtn.selectedBorder:SetBlendMode("ADD");
		flyingFavoriteBtn.selectedBorder:SetAlpha(0.9);
		flyingFavoriteBtn.selectedBorder:SetSize(48, 48);
		flyingFavoriteBtn.selectedBorder:SetPoint("CENTER", flyingFavoriteBtn, "CENTER", 0, 0);
		flyingFavoriteBtn.selectedBorder:Hide();
		flyingFavoriteBtn:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
			GameTooltip:SetText(L["Random Favorite Mount"]);
			GameTooltip:AddLine(L["Random Favorite Flying Mount Tooltip"], 1, 1, 1, true);
			GameTooltip:Show();
		end)
		flyingFavoriteBtn:SetScript("OnLeave", function()
			GameTooltip:Hide();
		end)
		flyingFavoriteBtn:SetScript("OnClick", function()
			local outfit = GetViewedOutfitData();
			if outfit then
				outfit.FlyingMountMode = "Favorite";
				MogCompanions:ClearSelectionPool(outfit, "FlyingMounts");
				LastClickedFlyingMountID = nil;
				RefreshMountSlots();
				if RefreshFlyingMountList ~= nil then
					RefreshFlyingMountList(false);
				end
				PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK);
			end
		end)
		FlyingMountModeButtons["Favorite"] = flyingFavoriteBtn;
		UpdateMountModeButtonHighlights(GetViewedOutfitData(), "FlyingMountMode", FlyingMountModeButtons);

		-- Flying mount Passenger mode button. Sits to the right of the Favorite button.
		-- Clicking it clears the flying pool and enters Passenger mode; clicking any mount
		-- in the list exits Passenger mode by setting FlyingMountMode back to "Selected".
		local flyingPassengerBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate");
		flyingPassengerBtn:SetSize(30, 30);
		flyingPassengerBtn:SetPoint("BOTTOMLEFT", FlyingMountList, "TOPLEFT", 46, 6);
		flyingPassengerBtn:SetFrameStrata("HIGH");
		flyingPassengerBtn:SetFrameLevel(FlyingMountList:GetFrameLevel() + 5);
		flyingPassengerBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD");
		flyingPassengerBtn.icon = flyingPassengerBtn:CreateTexture(nil, "ARTWORK");
		flyingPassengerBtn.icon:SetAllPoints(flyingPassengerBtn);
		flyingPassengerBtn.icon:SetTexture(MOUNT_PASSENGER_ICON);
		flyingPassengerBtn.selectedBorder = flyingPassengerBtn:CreateTexture(nil, "OVERLAY");
		flyingPassengerBtn.selectedBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border");
		flyingPassengerBtn.selectedBorder:SetBlendMode("ADD");
		flyingPassengerBtn.selectedBorder:SetAlpha(0.9);
		flyingPassengerBtn.selectedBorder:SetSize(48, 48);
		flyingPassengerBtn.selectedBorder:SetPoint("CENTER", flyingPassengerBtn, "CENTER", 0, 0);
		flyingPassengerBtn.selectedBorder:Hide();
		flyingPassengerBtn:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
			GameTooltip:SetText(L["Random Passenger Mount"]);
			GameTooltip:AddLine(L["Random Passenger Flying Mount Tooltip"], 1, 1, 1, true);
			GameTooltip:Show();
		end)
		flyingPassengerBtn:SetScript("OnLeave", function()
			GameTooltip:Hide();
		end)
		flyingPassengerBtn:SetScript("OnClick", function()
			local outfit = GetViewedOutfitData();
			if outfit then
				outfit.FlyingMountMode = "Passenger";
				MogCompanions:ClearSelectionPool(outfit, "FlyingMounts");
				LastClickedFlyingMountID = nil;
				RefreshMountSlots();
				if RefreshFlyingMountList ~= nil then
					RefreshFlyingMountList(false);
				end
				PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK);
			end
		end)
		FlyingMountModeButtons["Passenger"] = flyingPassengerBtn;
		UpdateMountModeButtonHighlights(GetViewedOutfitData(), "FlyingMountMode", FlyingMountModeButtons);

		-- Flying mount scroll box and list controls

		FlyingMountListScrollBox = CreateFrame("Frame", "FlyingMountListScrollBox", FlyingMountList, "WowScrollBoxList");
		local z, zz = FlyingMountList:GetSize() ;
		FlyingMountListScrollBox:SetSize(z - 40, zz - 4);
		FlyingMountListScrollBox:SetPoint("TOPLEFT", FlyingMountList, "TOPLEFT", 12, -2);

		FlyingMountListScrollBar = CreateFrame("EventFrame", nil, FlyingMountList, "MinimalScrollBar");
		FlyingMountListScrollBar:SetPoint("TOPLEFT", FlyingMountListScrollBox, "TOPRIGHT", 10, -6);
		FlyingMountListScrollBar:SetPoint("BOTTOMLEFT", FlyingMountListScrollBox, "BOTTOMRIGHT", 10, 6);

		FlyingMountListScrollBar:SetHideIfUnscrollable(true);
		FlyingMountDataProvider = CreateDataProvider();
		FlyingMountListScrollView = CreateScrollBoxListLinearView();

		function SetSelectedFlyingMount(value)
			local outfit = GetViewedOutfitData();
			if outfit == nil then
				return;
			end

			LastClickedFlyingMountID = value;

			if value == nil or value <= 1 then
				MogCompanions:ClearSelectionPool(outfit, "FlyingMounts");
			else
				-- Selecting a specific mount always switches back to Selected mode so
				-- Favorite or Passenger mode does not silently override the user's explicit choice.
				outfit.FlyingMountMode = "Selected";
				MogCompanions:ToggleSelectionPoolValue(outfit, "FlyingMounts", value);
			end

			SyncLegacyMountSelection(outfit, "Flying", "FlyingMounts", "flying");
			RefreshMountSlots();
			if RefreshFlyingMountList ~= nil then
				RefreshFlyingMountList(false);
			end
			PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK);
		end	

		local function FlyingMountListInitializer(button, data)
			local outfit = GetViewedOutfitData();
			local isSelected = outfit ~= nil and MogCompanions:IsInSelectionPool(outfit, "FlyingMounts", data.id);

			button.Name:SetText("|T"..data.icon..":18|t "..data.name);
			button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight");
			button.MountID = data.id;
			if button.CheckboxCheck ~= nil then
				button.CheckboxCheck:SetShown(isSelected);
			end

			if isSelected then
				button:LockHighlight();
			else
				button:UnlockHighlight();
			end

			button:SetScript("OnEnter", function()
				if data.model ~= nil then
					FlyingMountModel:SetDisplayInfo(data.model);
					if FlyingMountPreviewControls ~= nil then
						FlyingMountPreviewControls.reset();
					end
				end
				FlyingMountModel:SetAlpha(1);
			end)

			button:SetScript("OnLeave", function()
				local viewedOutfit = GetViewedOutfitData();
				local mountID = GetValidPoolMountSelection(viewedOutfit, "FlyingMounts", "flying", false, LastClickedFlyingMountID);
				UpdateMountPreviewModel(FlyingMountModel, FlyingMountPreviewControls, mountID);
			end)
			button:SetScript("OnClick", function()
				SetSelectedFlyingMount(data.id);
			end)

		end

		FlyingMountListScrollView:SetElementInitializer("MogCompanionsMultiSelectListButtonTemplate", FlyingMountListInitializer);
		FlyingMountListScrollView:SetElementExtent(22);
		ScrollUtil.InitScrollBoxListWithScrollBar(FlyingMountListScrollBox, FlyingMountListScrollBar, FlyingMountListScrollView);

		RefreshFlyingMountList = function(scrollToSelection)
			if FlyingMountListScrollView == nil then
				return;
			end

			local viewedOutfit = GetViewedOutfitData();
			if viewedOutfit ~= nil then
				MogCompanions:PruneInvalidSelectionPool(viewedOutfit, "FlyingMounts", ValidateFlyingMountSelection);
				SyncLegacyMountSelection(viewedOutfit, "Flying", "FlyingMounts", "flying");
			end

			local selectedCount = GetValidMountSelectionCount(viewedOutfit, "FlyingMounts", "flying");
			if selectedCount <= 0 then
				ShowOnlySelectedFlyingMounts = false;
			end

			local mounts;
			if ShowOnlySelectedFlyingMounts then
				mounts = GetFilteredSelectedMountInfos(viewedOutfit, "FlyingMounts", "flying");
			else
				mounts = MogCompanions:getSortedFlyingMounts();
			end

			FlyingMountDataProvider = CreateDataProvider(mounts);
			FlyingMountListScrollView:SetDataProvider(FlyingMountDataProvider);

			if scrollToSelection and viewedOutfit ~= nil and FlyingMountListScrollBox ~= nil then
				local scrollMountID = GetValidPoolMountSelection(viewedOutfit, "FlyingMounts", "flying", false);
				for i = 1, #mounts do
					if mounts[i].id == scrollMountID then
						FlyingMountListScrollBox:ScrollToElementDataIndex(i);
						break;
					end
				end
			end

			SetMountSectionTitle(FlyingSlotTitle, L["Mount Tab Flying Section Title"], selectedCount);
			MogCompanions:UpdateShowSelectedButton(FlyingMountShowSelectedButton, ShowOnlySelectedFlyingMounts, selectedCount);
			MogCompanions:UpdateNoResultsText(FlyingMountNoResultsText, MountListSearchBox, #mounts);
		end

		RefreshFlyingMountList(true);

		-- Flying mount list background overlay; ground mount section follows

		local FlyingMountListBackground = FlyingMountList:CreateTexture(nil, "OVERLAY");
		FlyingMountListBackground:SetAtlas("transmog-situations-containerbg", true);
		FlyingMountListBackground:SetAllPoints(true);

		FlyingMountNoResultsText = FlyingMountList:CreateFontString(nil, "OVERLAY", "GameFontDisable");
		FlyingMountNoResultsText:SetPoint("CENTER", FlyingMountList, "CENTER", 0, 0);
		FlyingMountNoResultsText:SetText(L["No Items Match Search"]);
		FlyingMountNoResultsText:Hide();

		GroundMountPreview = CreateFrame("Frame", "MountTabGroundPreview", f);
		GroundMountPreview:SetPoint("TOPLEFT", f, "TOPLEFT", 24 * s, (-564 + topOffset) * s);
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
		GroundMountPreviewControls = MogCompanions:AttachPreviewModelControls(GroundMountPreview, GroundMountModel, {
			zoom = 1,
			minZoom = 0.4,
			maxZoom = 3.0,
			facing = -5.5,
			x = -0.2,
			y = -0.1,
			z = -0.1,
			buttonOffsetY = -8,
			controlNamePrefix = "MogCompanionsGroundMountPreview",
		});

		local GroundMountPreviewBorder = GroundMountPreview:CreateTexture(nil, "OVERLAY");
		GroundMountPreviewBorder:SetAtlas("transmog-itemCard-default", true);
		GroundMountPreviewBorder:SetPoint("CENTER", GroundMountPreview, "CENTER", 0, 0);
		GroundMountPreviewBorder:SetSize(x, y);

		local _, _, _, xx, yy = GroundMountPreview:GetPoint();
		local ww, hh = GroundMountPreview:GetSize();

		local GroundMountList = CreateFrame("Frame", "MountTabGroundList", f);
		GroundMountList:SetPoint("TOPLEFT", f, "TOPLEFT", xx + gap + x, yy - ii);
		GroundMountList:SetFrameStrata("HIGH");
		GroundMountList:SetSize(fw - (xx + ww + gap + xx + r), y - (ii * 2));
		GroundMountList:SetParent(f);

		GroundMountShowSelectedButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate");
		GroundMountShowSelectedButton:SetSize(110, 22);
		GroundMountShowSelectedButton:SetPoint("BOTTOMRIGHT", GroundMountList, "TOPRIGHT", 0, 4);
		GroundMountShowSelectedButton:SetText(L["Show Selected"]);
		GroundMountShowSelectedButton:Hide();
		GroundMountShowSelectedButton:SetScript("OnClick", function()
			ShowOnlySelectedGroundMounts = not ShowOnlySelectedGroundMounts;
			RefreshGroundMountList(false);
		end);

		-- Ground mount Favorite mode button. Mirrors the flying mount Favorite button above.
		local groundFavoriteBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate");
		groundFavoriteBtn:SetSize(30, 30);
		groundFavoriteBtn:SetPoint("BOTTOMLEFT", GroundMountList, "TOPLEFT", 12, 6);
		groundFavoriteBtn:SetFrameStrata("HIGH");
		groundFavoriteBtn:SetFrameLevel(GroundMountList:GetFrameLevel() + 5);
		groundFavoriteBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD");
		groundFavoriteBtn.icon = groundFavoriteBtn:CreateTexture(nil, "ARTWORK");
		groundFavoriteBtn.icon:SetPoint("TOPLEFT", groundFavoriteBtn, "TOPLEFT", -2, 2);
		groundFavoriteBtn.icon:SetPoint("BOTTOMRIGHT", groundFavoriteBtn, "BOTTOMRIGHT", 2, -2);
		groundFavoriteBtn.icon:SetTexture(MOUNT_RANDOM_FAVORITE_ICON);
		groundFavoriteBtn.selectedBorder = groundFavoriteBtn:CreateTexture(nil, "OVERLAY");
		groundFavoriteBtn.selectedBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border");
		groundFavoriteBtn.selectedBorder:SetBlendMode("ADD");
		groundFavoriteBtn.selectedBorder:SetAlpha(0.9);
		groundFavoriteBtn.selectedBorder:SetSize(48, 48);
		groundFavoriteBtn.selectedBorder:SetPoint("CENTER", groundFavoriteBtn, "CENTER", 0, 0);
		groundFavoriteBtn.selectedBorder:Hide();
		groundFavoriteBtn:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
			GameTooltip:SetText(L["Random Favorite Mount"]);
			GameTooltip:AddLine(L["Random Favorite Ground Mount Tooltip"], 1, 1, 1, true);
			GameTooltip:Show();
		end)
		groundFavoriteBtn:SetScript("OnLeave", function()
			GameTooltip:Hide();
		end)
		groundFavoriteBtn:SetScript("OnClick", function()
			local outfit = GetViewedOutfitData();
			if outfit then
				outfit.GroundMountMode = "Favorite";
				MogCompanions:ClearSelectionPool(outfit, "GroundMounts");
				LastClickedGroundMountID = nil;
				RefreshMountSlots();
				if RefreshGroundMountList ~= nil then
					RefreshGroundMountList(false);
				end
				PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK);
			end
		end)
		GroundMountModeButtons["Favorite"] = groundFavoriteBtn;
		UpdateMountModeButtonHighlights(GetViewedOutfitData(), "GroundMountMode", GroundMountModeButtons);

		-- Ground mount Passenger mode button. Mirrors the flying mount Passenger button above.
		local groundPassengerBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate");
		groundPassengerBtn:SetSize(30, 30);
		groundPassengerBtn:SetPoint("BOTTOMLEFT", GroundMountList, "TOPLEFT", 46, 6);
		groundPassengerBtn:SetFrameStrata("HIGH");
		groundPassengerBtn:SetFrameLevel(GroundMountList:GetFrameLevel() + 5);
		groundPassengerBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD");
		groundPassengerBtn.icon = groundPassengerBtn:CreateTexture(nil, "ARTWORK");
		groundPassengerBtn.icon:SetAllPoints(groundPassengerBtn);
		groundPassengerBtn.icon:SetTexture(MOUNT_PASSENGER_ICON);
		groundPassengerBtn.selectedBorder = groundPassengerBtn:CreateTexture(nil, "OVERLAY");
		groundPassengerBtn.selectedBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border");
		groundPassengerBtn.selectedBorder:SetBlendMode("ADD");
		groundPassengerBtn.selectedBorder:SetAlpha(0.9);
		groundPassengerBtn.selectedBorder:SetSize(48, 48);
		groundPassengerBtn.selectedBorder:SetPoint("CENTER", groundPassengerBtn, "CENTER", 0, 0);
		groundPassengerBtn.selectedBorder:Hide();
		groundPassengerBtn:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
			GameTooltip:SetText(L["Random Passenger Mount"]);
			GameTooltip:AddLine(L["Random Passenger Ground Mount Tooltip"], 1, 1, 1, true);
			GameTooltip:Show();
		end)
		groundPassengerBtn:SetScript("OnLeave", function()
			GameTooltip:Hide();
		end)
		groundPassengerBtn:SetScript("OnClick", function()
			local outfit = GetViewedOutfitData();
			if outfit then
				outfit.GroundMountMode = "Passenger";
				MogCompanions:ClearSelectionPool(outfit, "GroundMounts");
				LastClickedGroundMountID = nil;
				RefreshMountSlots();
				if RefreshGroundMountList ~= nil then
					RefreshGroundMountList(false);
				end
				PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK);
			end
		end)
		GroundMountModeButtons["Passenger"] = groundPassengerBtn;
		UpdateMountModeButtonHighlights(GetViewedOutfitData(), "GroundMountMode", GroundMountModeButtons);

		local GroundMountListBackground = GroundMountList:CreateTexture(nil, "BACKGROUND");
		GroundMountListBackground:SetAtlas("transmog-situations-containerbg", true);
		GroundMountListBackground:SetAllPoints(true);

		GroundMountNoResultsText = GroundMountList:CreateFontString(nil, "OVERLAY", "GameFontDisable");
		GroundMountNoResultsText:SetPoint("CENTER", GroundMountList, "CENTER", 0, 0);
		GroundMountNoResultsText:SetText(L["No Items Match Search"]);
		GroundMountNoResultsText:Hide();

		-- Ground mount scroll box and list controls

		GroundMountListScrollBox = CreateFrame("Frame", "GroundMountListScrollBox", GroundMountList, "WowScrollBoxList");
		local z, zz = GroundMountList:GetSize();
		GroundMountListScrollBox:SetSize(z - 40, zz - 4);
		GroundMountListScrollBox:SetPoint("TOPLEFT", GroundMountList, "TOPLEFT", 12, -2);

		GroundMountListScrollBar = CreateFrame("EventFrame", nil, GroundMountList, "MinimalScrollBar");
		GroundMountListScrollBar:SetPoint("TOPLEFT", GroundMountListScrollBox, "TOPRIGHT", 10, -6);
		GroundMountListScrollBar:SetPoint("BOTTOMLEFT", GroundMountListScrollBox, "BOTTOMRIGHT", 10, 6);

		GroundMountListScrollBar:SetHideIfUnscrollable(true);
		GroundMountDataProvider = CreateDataProvider();
		GroundMountListScrollView = CreateScrollBoxListLinearView();

		function SetSelectedGroundMount(value)
			local outfit = GetViewedOutfitData();
			if outfit == nil then
				return;
			end

			LastClickedGroundMountID = value;

			if value == nil or value <= 1 then
				MogCompanions:ClearSelectionPool(outfit, "GroundMounts");
			else
				-- Selecting a specific mount always switches back to Selected mode so
				-- Favorite or Passenger mode does not silently override the user's explicit choice.
				outfit.GroundMountMode = "Selected";
				MogCompanions:ToggleSelectionPoolValue(outfit, "GroundMounts", value);
			end

			SyncLegacyMountSelection(outfit, "Ground", "GroundMounts", "ground");
			RefreshMountSlots();
			if RefreshGroundMountList ~= nil then
				RefreshGroundMountList(false);
			end
			PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK);
		end	

		local function GroundMountListInitializer(button, data)
			local outfit = GetViewedOutfitData();
			local isSelected = outfit ~= nil and MogCompanions:IsInSelectionPool(outfit, "GroundMounts", data.id);

			button.Name:SetText("|T"..data.icon..":18|t "..data.name);
			button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight");
			button.MountID = data.id;
			if button.CheckboxCheck ~= nil then
				button.CheckboxCheck:SetShown(isSelected);
			end

			if isSelected then
				button:LockHighlight();
			else
				button:UnlockHighlight();
			end

			button:SetScript("OnEnter", function()
				if data.model ~= nil then
					GroundMountModel:SetDisplayInfo(data.model);
					if GroundMountPreviewControls ~= nil then
						GroundMountPreviewControls.reset();
					end
				end
				GroundMountModel:SetAlpha(1);
			end)

			button:SetScript("OnLeave", function()
				local viewedOutfit = GetViewedOutfitData();
				local mountID = GetValidPoolMountSelection(viewedOutfit, "GroundMounts", "ground", false, LastClickedGroundMountID);
				UpdateMountPreviewModel(GroundMountModel, GroundMountPreviewControls, mountID);
			end)
			button:SetScript("OnClick", function()
				SetSelectedGroundMount(data.id);
			end)

		end

		GroundMountListScrollView:SetElementInitializer("MogCompanionsMultiSelectListButtonTemplate", GroundMountListInitializer);
		GroundMountListScrollView:SetElementExtent(22);
		ScrollUtil.InitScrollBoxListWithScrollBar(GroundMountListScrollBox, GroundMountListScrollBar, GroundMountListScrollView);

		RefreshGroundMountList = function(scrollToSelection)
			if GroundMountListScrollView == nil then
				return;
			end

			local viewedOutfit = GetViewedOutfitData();
			if viewedOutfit ~= nil then
				MogCompanions:PruneInvalidSelectionPool(viewedOutfit, "GroundMounts", ValidateGroundMountSelection);
				SyncLegacyMountSelection(viewedOutfit, "Ground", "GroundMounts", "ground");
			end

			local selectedCount = GetValidMountSelectionCount(viewedOutfit, "GroundMounts", "ground");
			if selectedCount <= 0 then
				ShowOnlySelectedGroundMounts = false;
			end

			local mounts;
			if ShowOnlySelectedGroundMounts then
				mounts = GetFilteredSelectedMountInfos(viewedOutfit, "GroundMounts", "ground");
			else
				mounts = MogCompanions:getSortedGroundMounts();
			end

			GroundMountDataProvider = CreateDataProvider(mounts);
			GroundMountListScrollView:SetDataProvider(GroundMountDataProvider);

			if scrollToSelection and viewedOutfit ~= nil and GroundMountListScrollBox ~= nil then
				local scrollMountID = GetValidPoolMountSelection(viewedOutfit, "GroundMounts", "ground", false);
				for i = 1, #mounts do
					if mounts[i].id == scrollMountID then
						GroundMountListScrollBox:ScrollToElementDataIndex(i);
						break;
					end
				end
			end

			SetMountSectionTitle(GroundSlotTitle, L["Mount Tab Ground Section Title"], selectedCount);
			MogCompanions:UpdateShowSelectedButton(GroundMountShowSelectedButton, ShowOnlySelectedGroundMounts, selectedCount);
			MogCompanions:UpdateNoResultsText(GroundMountNoResultsText, MountListSearchBox, #mounts);
		end

		RefreshGroundMountList(true);

		-- Search box OnTextChanged: re-filter both flying and ground mount lists

		MountListSearchBox:SetScript("OnTextChanged", function(self)
			if SearchBoxTemplate_OnTextChanged ~= nil then
				SearchBoxTemplate_OnTextChanged(self);
			end

			MogCompanions.MountSearchString = MountListSearchBox:GetText();

			if RefreshFlyingMountList ~= nil then
				RefreshFlyingMountList(true);
			end

			if RefreshGroundMountList ~= nil then
				RefreshGroundMountList(true);
			end

		end)

		RefreshMountSlots();

		--		

		if MogCompanions.CreateHearthstonesFrame ~= nil then
			MogCompanions:CreateHearthstonesFrame(CompanionsFrame);
		end

		-- Companions sub-tab buttons (Mounts, Hearthstones, Pets) at bottom of container.
		-- numTabs and Tabs are assigned manually; PanelTemplates_SetNumTabs is NOT used
		-- because it calls AnchorTabs internally, which would fight our manual anchors.

		local mountsTab = CreateFrame("Button", "MogCompanionsCompanionsTab1", CompanionsFrame, "PanelTabButtonTemplate", 1);
		mountsTab:SetID(1);
		mountsTab:SetText(L["Mount Tab Title"]);
		PanelTemplates_TabResize(mountsTab, 0);
		mountsTab:SetPoint("BOTTOMLEFT", CompanionsFrame, "BOTTOMLEFT", 16, 2);
		mountsTab:SetScript("OnClick", function(self)
			MogCompanions:OpenCompanionsSubTab(self:GetID());
		end);

		local hearthstonesTab = CreateFrame("Button", "MogCompanionsCompanionsTab2", CompanionsFrame, "PanelTabButtonTemplate", 2);
		hearthstonesTab:SetID(2);
		hearthstonesTab:SetText(L["Hearthstone Tab Title"]);
		PanelTemplates_TabResize(hearthstonesTab, 0);
		hearthstonesTab:SetPoint("LEFT", mountsTab, "RIGHT", 3, 0);
		hearthstonesTab:SetScript("OnClick", function(self)
			MogCompanions:OpenCompanionsSubTab(self:GetID());
		end);

		local petsTab = CreateFrame("Button", "MogCompanionsCompanionsTab3", CompanionsFrame, "PanelTabButtonTemplate", 3);
		petsTab:SetID(3);
		petsTab:SetText(L["Pets Tab Title"]);
		PanelTemplates_TabResize(petsTab, 0);
		petsTab:SetPoint("LEFT", hearthstonesTab, "RIGHT", 3, 0);
		petsTab:SetScript("OnClick", function(self)
			MogCompanions:OpenCompanionsSubTab(self:GetID());
		end);

		CompanionsFrame.numTabs = 3;
		CompanionsFrame.Tabs = { mountsTab, hearthstonesTab, petsTab };

		collection.companionsTabID = collection:AddNamedTab(L["Companions Tab Title"], CompanionsFrame);
		collection:UpdateTabs();

		MogCompanions:OpenCompanionsSubTab(1);
	end

end

-- Shows a specific Companions sub-tab (1=Mounts, 2=Hearthstones, 3=Pets) and updates
-- the PanelTab selection state. PanelTemplates_SetTab calls PanelTemplates_UpdateTabs
-- internally; do not call it again here.
function MogCompanions:OpenCompanionsSubTab(tabIndex)
	local companionsFrame = _G.MogCompanionsCompanionsFrame;
	if companionsFrame == nil then return; end

	if tabIndex ~= 1 and tabIndex ~= 2 and tabIndex ~= 3 then
		tabIndex = 1;
	end

	if _G.MountsFrame then
		_G.MountsFrame:SetShown(tabIndex == 1);
	end
	if _G.MogCompanionsHearthstonesPage then
		_G.MogCompanionsHearthstonesPage:SetShown(tabIndex == 2);
	end
	if tabIndex == 3 then
		if MogCompanions.ShowPetsPage ~= nil then
			MogCompanions:ShowPetsPage();
		elseif _G.MogCompanionsPetsFrame then
			_G.MogCompanionsPetsFrame:Show();
		end
	elseif MogCompanions.HidePetsPage ~= nil then
		MogCompanions:HidePetsPage();
	elseif _G.MogCompanionsPetsFrame then
		_G.MogCompanionsPetsFrame:Hide();
	end

	PanelTemplates_SetTab(companionsFrame, tabIndex);
end

-- Opens the Companions top-level tab and navigates to the given sub-tab by name
-- ("Mounts", "Hearthstones", or "Pets"). Builds the tab UI via InitMountTab if it
-- has not been built yet. Safe to call before the wardrobe has been opened.
function MogCompanions:OpenCompanionsTab(subTabName)
	if TransmogFrame == nil or TransmogFrame.WardrobeCollection == nil then return; end
	local collection = TransmogFrame.WardrobeCollection;

	if collection.companionsTabID == nil then
		MogCompanions:InitMountTab();
	end

	if collection.companionsTabID == nil then return; end

	if collection.SetTab then
		collection:SetTab(collection.companionsTabID);
	end

	local subTabIndex = 1;
	if subTabName == "Hearthstones" then
		subTabIndex = 2;
	elseif subTabName == "Pets" then
		subTabIndex = 3;
	end

	MogCompanions:OpenCompanionsSubTab(subTabIndex);
end

-- Resets the flying mount list selection and scrolls back to the top.
-- Called after the player clears the flying mount slot.
function ClearSelectedFlyingMount()
	local outfit = GetViewedOutfitData();
	if outfit == nil then
		return;
	end

	ShowOnlySelectedFlyingMounts = false;
	MogCompanions:ClearSelectionPool(outfit, "FlyingMounts");
	SyncLegacyMountSelection(outfit, "Flying", "FlyingMounts", "flying");
	RefreshMountSlots();

	if RefreshFlyingMountList ~= nil then
		RefreshFlyingMountList(false);
	end
end

-- Resets the ground mount list selection and scrolls back to the top.
-- Called after the player clears the ground mount slot.
function ClearSelectedGroundMount()
	local outfit = GetViewedOutfitData();
	if outfit == nil then
		return;
	end

	ShowOnlySelectedGroundMounts = false;
	MogCompanions:ClearSelectionPool(outfit, "GroundMounts");
	SyncLegacyMountSelection(outfit, "Ground", "GroundMounts", "ground");
	RefreshMountSlots();

	if RefreshGroundMountList ~= nil then
		RefreshGroundMountList(false);
	end
end

-- Re-selects and scrolls to the currently saved flying and ground mounts in both lists.
-- Called from Core.lua after VIEWED_TRANSMOG_OUTFIT_CHANGED to sync the UI
-- with the newly viewed outfit's saved mount selections.
function UpdateSelectedMountRow()
    if TransmogFrame == nil
        or TransmogFrame.WardrobeCollection == nil
        or not TransmogFrame:IsShown()
        or FlyingMountListScrollBox == nil
        or GroundMountListScrollBox == nil
        or RefreshFlyingMountList == nil
        or RefreshGroundMountList == nil then
        return;
    end

	LastClickedFlyingMountID = nil;
	LastClickedGroundMountID = nil;
	ShowOnlySelectedFlyingMounts = false;
	ShowOnlySelectedGroundMounts = false;

	RefreshMountSlots();
	RefreshFlyingMountList(true);
	RefreshGroundMountList(true);
end
