-- Shared.lua
-- Shared helpers consumed by Core.lua, Mounts.lua, Hearthstones.lua, and Settings.lua.
-- Contains: mount collection queries, sorting/filtering, random selection,
-- hearthstone toy helpers, title helpers, and saved-variable outfit initialization.
-- Mount category logic (flying/ground/aquatic/special/alternative) is centralized here.
local _, addon = ...;
local ns = select(2,...);
local MogCompanions = ns.MogCompanions;

local playerName = UnitName("player");

-- Sorts a table of objects with a .name field alphabetically (case-insensitive).
-- Used as the comparator for table.sort throughout the addon.
function MogCompanionsSortAlphabetical(a, b)
	return a.name:lower() < b.name:lower();
end

-- Returns true if 'value' exists anywhere in the given array table.
function MogCompanions:hasValue(table, value)
	for i, v in ipairs(table) do
		if v == value then
			return true;
		end
	end

	return false;
end

-- Returns an array of all collected, visible mount IDs for this character.
-- Excludes mounts hidden on this character (shouldHideOnChar).
function MogCompanions:GetCollectedMounts()
	local collectedMounts = {};
	local mountIDs = C_MountJournal.GetMountIDs();

	for _, mountID in ipairs(mountIDs) do
		local name, _, _, _, isUsable, _, _, _, _, shouldHideOnChar, isCollected, mountID_, _ = C_MountJournal.GetMountInfoByID(mountID);
		if isCollected and not shouldHideOnChar then
			table.insert(collectedMounts, mountID_);
		end
	end

	return collectedMounts;
end

-- Converts a raw array of mount IDs into a sorted array of mount info tables.
-- Each entry: { name, icon, nameAndIcon, id, model (creatureDisplayInfoID), mountTypeID }.
-- Filters to only collected + usable mounts, then sorts alphabetically.
function MogCompanions:sortMounts(mountsRaw)
	local mounts = {};

	for i = 1, #mountsRaw do

		local name, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected, mountID, isSteadyFlight = C_MountJournal.GetMountInfoByID(mountsRaw[i]);
		local creatureDisplayInfoID, description, source, isSelfMount, mountTypeID, uiModelSceneID, animID, spellVisualKitID, disablePlayerMountPreview = C_MountJournal.GetMountInfoExtraByID(mountsRaw[i]);
		
		local temp = {};
		temp["name"] = name;
		temp["icon"] = icon;
		temp["nameAndIcon"] = "|T"..icon..":18|t "..name;
		temp["id"] = mountID;
		temp["model"] = creatureDisplayInfoID;
		temp["mountTypeID"] = mountTypeID;
		
		if isCollected and not shouldHideOnChar and isUsable then
			table.insert(mounts, temp);
		end

	end

	table.sort(mounts, MogCompanionsSortAlphabetical);

	return mounts;
end

-- Returns true if the mount name contains MogCompanions.MountSearchString (case-insensitive),
-- or if the search filter is empty or nil. Used to filter the visible mount list rows.
function MogCompanions:listSearchString(name)
	if MogCompanions.MountSearchString == "" or MogCompanions.MountSearchString == nil or string.len(MogCompanions.MountSearchString) < 1 then
		return true;
	elseif string.len(MogCompanions.MountSearchString) >= 1 and string.find(name:lower(), MogCompanions.MountSearchString:lower()) then
		return true;
	else
		return false;
	end
end

-- Returns a filtered, alphabetically sorted list of collected Dragonriding/flying mounts
-- that match the current MountSearchString filter.
function MogCompanions:getSortedFlyingMounts()
	local mountsRaw = MogCompanions:sortMounts(C_MountJournal.GetCollectedDragonridingMounts());
	local mounts = {};

	for i = 1, #mountsRaw do
		local mount = mountsRaw[i];
		if MogCompanions:listSearchString(mount.name) then
			table.insert(mounts, mount);
		end
	end 

	return mounts;
end

-- Returns a filtered, alphabetically sorted list of collected ground mounts (mountTypeID 230).
-- If MogCompanionsSaved.ShowFlyingInGround is true, flying mounts are also included.
function MogCompanions:getSortedGroundMounts()
	local mountsRaw = MogCompanions:sortMounts(MogCompanions:GetCollectedMounts());
	local mounts = {};

	for i = 1, #mountsRaw do
		local mount = mountsRaw[i];
		if (mount.mountTypeID == 230 or MogCompanionsSaved.ShowFlyingInGround) and MogCompanions:listSearchString(mount.name) then
			table.insert(mounts, mount);
		end
	end

	return mounts;
end

-- Returns collected aquatic mounts matched by mountTypeID.
-- Aquatic type IDs: 231, 232, 254, 407, 436. No search filter applied.
function MogCompanions:getSortedAquaticMounts()
	local mountsRaw = MogCompanions:sortMounts(MogCompanions:GetCollectedMounts());
	local mounts = {};
	local aquaticTypeIDs = {231, 232, 254, 407, 436};

	for i = 1, #mountsRaw do
		local mount = mountsRaw[i];
		if MogCompanions:hasValue(aquaticTypeIDs, mount.mountTypeID) then
			table.insert(mounts, mount);
		end
	end

	return mounts;
end

-- Returns collected repair/vendor/utility mounts matched by hardcoded mount ID.
-- IDs: 460 (Grand Expedition Yak), 280 (Traveler's Tundra Mammoth), 284, 273, 274, 1039, 2237.
-- Update this list when Blizzard adds new vendor mounts.
function MogCompanions:getSortedSpecialMounts()
	local mountsRaw = MogCompanions:sortMounts(MogCompanions:GetCollectedMounts());
	local mounts = {};
	local specialMountIDs = {460, 280, 284, 273, 274, 1039, 2237};

	for i = 1, #mountsRaw do
		local mount = mountsRaw[i];
		if MogCompanions:hasValue(specialMountIDs, mount.id) then
			table.insert(mounts, mount);
		end
	end

	return mounts;
end

-- Returns all collected mounts (no category filter, no search filter).
-- Used for the Alt-key alternative mount slot — the player can assign anything here.
function MogCompanions:getSortedAlternativeMounts()
	local mountsRaw = MogCompanions:sortMounts(MogCompanions:GetCollectedMounts());
	local mounts = {};

	for i = 1, #mountsRaw do
		local mount = mountsRaw[i];
		table.insert(mounts, mount);
	end

	return mounts;
end

-- Returns a random mount table from the specified category string.
-- type: "flying" | "ground" | "aquatic" | "special" | "alternative"
-- Returns nil if the category list is empty (safe to call with no mounts collected).
-- The UI search filter (MountSearchString) is bypassed here so that the random pool
-- is always the full category, not whatever the player last typed in the search box.
function MogCompanions:getRandomMount(type)
	local mounts = {}

	local savedSearch = MogCompanions.MountSearchString;
	MogCompanions.MountSearchString = "";

	if type == "flying" then
		mounts = MogCompanions:getSortedFlyingMounts();
	elseif type == "ground" then
		mounts = MogCompanions:getSortedGroundMounts();
	elseif type == "aquatic" then
		mounts = MogCompanions:getSortedAquaticMounts();
	elseif type == "special" then
		mounts = MogCompanions:getSortedSpecialMounts();
	elseif type == "alternative" then
		mounts = MogCompanions:getSortedAlternativeMounts();		
	else
		mounts = MogCompanions:getSortedFlyingMounts();
	end

	MogCompanions.MountSearchString = savedSearch;

	if #mounts == 0 then
		return nil;
	end

	local rand = math.random(1, #mounts);

	return mounts[rand];
end

-- ── Hearthstone Toy Helpers ──────────────────────────────────────────────────
-- Fallback icon (plain Hearthstone) shown when no toy info is available yet.
MogCompanions.EmptyHearthstoneIcon = 134414;
MogCompanions.HearthstoneToyItemIDs = {
    64488,  -- The Innkeeper's Daughter
    93672,  -- Dark Portal
    142542, -- Tome of Town Portal
    162973, -- Greatfather Winter's Hearthstone
    163045, -- Headless Horseman's Hearthstone
    165669, -- Lunar Elder's Hearthstone
    165670, -- Peddlefeet's Lovely Hearthstone
    165802, -- Noble Gardener's Hearthstone
    166746, -- Fire Eater's Hearthstone
    166747, -- Brewfest Reveler's Hearthstone
    168907, -- Holographic Digitalization Hearthstone
    172179, -- Eternal Traveler's Hearthstone
    180290, -- Night Fae Hearthstone
    182773, -- Necrolord Hearthstone
    183716, -- Venthyr Sinstone
    184353, -- Kyrian Hearthstone
    188952, -- Dominated Hearthstone
    190196, -- Enlightened Hearthstone
    190237, -- Broker Translocation Matrix
    193588, -- Timewalker's Hearthstone
    200630, -- Ohn'ir Windsage's Hearthstone
    206195, -- Path of the Naaru
    208704, -- Deepdweller's Earthen Hearthstone
    209035, -- Hearthstone of the Flame
    210455, -- Draenic Hologem
    212337, -- Stone of the Hearth
    228940, -- Notorious Thread's Hearthstone
    235016, -- Redeployment Module
    236687, -- Explosive Hearthstone
    245970, -- P.O.S.T. Master's Express Hearthstone
    246565, -- Cosmic Hearthstone
    257736, -- Lightcalled Hearthstone
    263489, -- Naaru's Enfold
    263933, -- Preyseeker's Hearthstone
    265100, -- Corewarden's Hearthstone
};

-- Returns true if the toy name contains HearthstoneSearchString (case-insensitive),
-- or if the filter is empty. Used to filter the Hearthstones tab list.
function MogCompanions:listHearthstoneSearchString(name)
	if MogCompanions.HearthstoneSearchString == "" or MogCompanions.HearthstoneSearchString == nil or string.len(MogCompanions.HearthstoneSearchString) < 1 then
		return true;
	elseif string.len(MogCompanions.HearthstoneSearchString) >= 1 and string.find(name:lower(), MogCompanions.HearthstoneSearchString:lower()) then
		return true;
	else
		return false;
	end
end

-- Returns true if the player owns the given hearthstone toy itemID.
function MogCompanions:IsHearthstoneToyCollected(itemID)
	if itemID == nil or itemID <= 1 then
		return false;
	end

	if PlayerHasToy then
		return PlayerHasToy(itemID);
	end

	return false;
end

-- Returns a toy info table { name, icon, nameAndIcon, id } for a hearthstone toy itemID.
-- Falls back from C_ToyBox to C_Item/GetItemInfo for compatibility.
-- Returns nil if item data is not yet loaded; async load is requested automatically.
function MogCompanions:GetHearthstoneToyInfo(itemID)
	if itemID == nil or itemID <= 1 then
		return nil;
	end

	local toyName;
	local icon;

	if C_ToyBox and C_ToyBox.GetToyInfo then
		local _, name, toyIcon = C_ToyBox.GetToyInfo(itemID);
		toyName = name;
		icon = toyIcon;
	end

	if toyName == nil then
		local itemName, _, _, _, _, _, _, _, _, itemIcon;

		if C_Item and C_Item.GetItemInfo then
			itemName, _, _, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(itemID);
		else
			itemName, _, _, _, _, _, _, _, _, itemIcon = GetItemInfo(itemID);
		end

		toyName = itemName;
		icon = itemIcon;
	end

	if toyName == nil then
		if C_Item and C_Item.RequestLoadItemDataByID then
			C_Item.RequestLoadItemDataByID(itemID);
		end
		return nil;
	end

	local toy = {};
	toy.name = toyName;
	toy.icon = icon or MogCompanions.EmptyHearthstoneIcon;
	toy.nameAndIcon = "|T"..toy.icon..":18|t "..toyName;
	toy.id = itemID;

	return toy;
end
 
-- Returns collected hearthstone toys, sorted alphabetically.
-- If ignoreSearch is true, the HearthstoneSearchString filter is bypassed
-- (used when picking a random toy so all collected toys are eligible).
function MogCompanions:getSortedHearthstoneToys(ignoreSearch)
	local toys = {};

	for i = 1, #MogCompanions.HearthstoneToyItemIDs do
		local itemID = MogCompanions.HearthstoneToyItemIDs[i];

		if MogCompanions:IsHearthstoneToyCollected(itemID) then
			local toy = MogCompanions:GetHearthstoneToyInfo(itemID);

			if toy ~= nil and (ignoreSearch or MogCompanions:listHearthstoneSearchString(toy.name)) then
				table.insert(toys, toy);
			end
		end
	end

	table.sort(toys, MogCompanionsSortAlphabetical);

	return toys;
end

-- Returns a random collected hearthstone toy, ignoring the search filter.
-- Returns nil if no hearthstone toys are collected.
function MogCompanions:getRandomHearthstoneToy()
	local toys = MogCompanions:getSortedHearthstoneToys(true);

	if #toys == 0 then
		return nil;
	end

	local rand = math.random(1, #toys);

	return toys[rand];
end

-- ── Title Helpers ────────────────────────────────────────────────────────────
-- Formats a title ID into a displayable string: "Title PlayerName" or "PlayerName Title".
-- titleID 0 returns the bare player name (represents the "no title" selection).
local function CreateDisplayTitle(titleID)
	if titleID == 0 then
		return playerName;
	end

	local title, _ = GetTitleName(titleID);
	if title == nil then
		return playerName;
	end
	local displayTitle = "";

	if title:sub(-1) == " " then
		displayTitle = title..playerName;
	else
		displayTitle = playerName.." "..title;
	end

	return displayTitle;
end

-- Returns all known player titles as an alphabetically sorted array of { id, name } tables.
-- Used to populate title dropdowns in the transmog UI and Settings panel.
function MogCompanions:getSortedTitles()
	local titlesRaw = {}
	local count = 1;

	for i = 1, GetNumTitles() do
		if IsTitleKnown(i) then
			titlesRaw[count] = {};
			titlesRaw[count].id = i;
			titlesRaw[count].name = CreateDisplayTitle(i);
			count = count + 1;				
		end
	end

	table.sort(titlesRaw, MogCompanionsSortAlphabetical)

	return titlesRaw;
end

-- Populates MogCompanionsSelectedMount[type] with full info for the given mount ID.
-- type: "Flying" | "Ground". Called when the player picks a mount in the list UI.
function MogCompanions:UpdateSelectMountDetails(type, id)
	local name, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected, mountID, isSteadyFlight = C_MountJournal.GetMountInfoByID(id);
	local creatureDisplayInfoID, description, source, isSelfMount, mountTypeID, uiModelSceneID, animID, spellVisualKitID, disablePlayerMountPreview = C_MountJournal.GetMountInfoExtraByID(id);
			
	MogCompanionsSelectedMount[type].name = name;
	MogCompanionsSelectedMount[type].spellID = spellID;
	MogCompanionsSelectedMount[type].icon = icon;
	MogCompanionsSelectedMount[type].id = mountID;
	MogCompanionsSelectedMount[type].display = creatureDisplayInfoID;
	MogCompanionsSelectedMount[type].type = mountTypeID;
end

-- Ensures a saved-variable entry exists for outfit 'id' in MogCompanionsCharacterSaved.
-- Called defensively any time an outfit ID is encountered that may be new.
-- Sentinel values:
--   Flying = 1: no per-outfit selection; summon a random flying mount.
--   Ground = 1: no per-outfit selection; summon a random ground mount.
--   Hearthstone = 1: no per-outfit selection; use a random hearthstone toy.
--   Title = 0: do not change the title on mount.
--   Title = -1: clear the title (bare player name).
-- Safe to call multiple times; only writes fields that are missing.
function MogCompanions:CreateEmptyOutfit(id)
	if id == nil then
		return;
	end

	if MogCompanionsCharacterSaved == nil then
		MogCompanionsCharacterSaved = {};
	end

	if MogCompanionsCharacterSaved["Outfit"..id] == nil then
		MogCompanionsCharacterSaved["Outfit"..id] = {};
	end

	local outfit = MogCompanionsCharacterSaved["Outfit"..id];

	if outfit.Flying == nil then
		outfit.Flying = 1;
	end

	if outfit.Ground == nil then
		outfit.Ground = 1;
	end

	if outfit.Hearthstone == nil then
		outfit.Hearthstone = 1;
	end

	if outfit.Title == nil then
		outfit.Title = 0;
	end
end
