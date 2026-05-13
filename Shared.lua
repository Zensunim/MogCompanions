-- Shared.lua
-- Shared helpers consumed by Core.lua, Mounts.lua, Hearthstones.lua, and Settings.lua.
-- Contains: mount collection queries, sorting/filtering, random selection,
-- hearthstone toy helpers, title helpers, and saved-variable outfit initialization.
-- Mount category logic (flying/ground/aquatic/repair/random) is centralized here.
local _, addon = ...;
local ns = select(2,...);
local MogCompanions = ns.MogCompanions;

MogCompanions.TransmogSlotOffsets = {
	FirstMount = -108,
	GroundMount = -64,
	Hearthstone = -144,
	Pet = -208,
};

local playerName = UnitName("player");

local aquaticMountTypeIDs = {231, 232, 254, 407, 436};
local repairMountIDs = {460, 280, 284, 273, 274, 1039, 2237};

local function addUniquePoolValue(pool, value)
	if value == nil or value == "" then
		return;
	end

	for i = 1, #pool do
		if pool[i] == value then
			return;
		end
	end

	table.insert(pool, value);
end

-- Sorts a table of objects with a .name field alphabetically (case-insensitive).
-- Used as the comparator for table.sort throughout the addon.
function MogCompanionsSortAlphabetical(a, b)
	return a.name:lower() < b.name:lower();
end

local function Clamp(value, minValue, maxValue)
	if value < minValue then
		return minValue;
	elseif value > maxValue then
		return maxValue;
	end

	return value;
end

function MogCompanions:AttachPreviewModelControls(previewFrame, modelFrame, defaults)
	if previewFrame == nil or modelFrame == nil then
		return nil;
	end

	defaults = defaults or {};

	local state = {
		zoom = defaults.zoom or 1,
		minZoom = defaults.minZoom or 0.4,
		maxZoom = defaults.maxZoom or 3.0,
		facing = defaults.facing or 0,
		x = defaults.x or 0,
		y = defaults.y or 0,
		z = defaults.z or 0,
		dragButton = nil,
		lastX = nil,
		lastY = nil,
	};

	state.zoom = Clamp(state.zoom, state.minZoom, state.maxZoom);

	local function ApplyView()
		modelFrame:SetPortraitZoom(0);
		modelFrame:SetCamDistanceScale(state.zoom);
		modelFrame:SetFacing(state.facing);
		modelFrame:SetPosition(state.x, state.y, state.z);
	end

	local function StopDragging(self)
		state.dragButton = nil;
		state.lastX = nil;
		state.lastY = nil;
		self:SetScript("OnUpdate", nil);
	end

	local function ResetView()
		state.zoom = Clamp(defaults.zoom or 1, state.minZoom, state.maxZoom);
		state.facing = defaults.facing or 0;
		state.x = defaults.x or 0;
		state.y = defaults.y or 0;
		state.z = defaults.z or 0;
		ApplyView();

		if defaults.onReset ~= nil then
			defaults.onReset(modelFrame, state);
		end
	end

	modelFrame:EnableMouse(true);
	modelFrame:EnableMouseWheel(true);
	modelFrame:SetScript("OnMouseWheel", function(self, delta)
		state.zoom = Clamp(state.zoom - (delta * 0.12), state.minZoom, state.maxZoom);
		ApplyView();
	end);

	modelFrame:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" and button ~= "RightButton" then
			return;
		end

		state.dragButton = button;
		state.lastX, state.lastY = GetCursorPosition();

		self:SetScript("OnUpdate", function()
			local cursorX, cursorY = GetCursorPosition();

			if state.lastX == nil or state.lastY == nil then
				state.lastX = cursorX;
				state.lastY = cursorY;
				return;
			end

			local scale = UIParent:GetEffectiveScale();
			local deltaX = (cursorX - state.lastX) / scale;
			local deltaY = (cursorY - state.lastY) / scale;

			if state.dragButton == "LeftButton" then
				state.facing = state.facing + (deltaX * 0.01);
			elseif state.dragButton == "RightButton" then
				state.x = state.x + (deltaX * 0.0025);
				state.z = state.z + (deltaY * 0.0025);
			end

			state.lastX = cursorX;
			state.lastY = cursorY;
			ApplyView();
		end);
	end);

	modelFrame:SetScript("OnMouseUp", function(self)
		StopDragging(self);
	end);

	modelFrame:HookScript("OnHide", function(self)
		StopDragging(self);
	end);

	ResetView();

	local attachedControls = {
		controls = nil,
		reset = ResetView,
		apply = ApplyView,
		state = state,
	};

	modelFrame.MogCompanionsPreviewControls = attachedControls;

	return attachedControls;
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

local sortedPetsCache = nil;

function MogCompanions:InvalidateSortedPetsCache()
	sortedPetsCache = nil;
end

-- Returns collected battle pets as sorted display entries for the pets UI.
-- Each entry: { id, name, icon }.
-- Builds the cache synchronously on first call using the fastest available API.
-- Duplicate display names are collapsed to the first owned pet with that name.
function MogCompanions:GetSortedPets()
	if sortedPetsCache == nil then
		if C_PetJournal == nil or C_PetJournal.GetOwnedPetIDs == nil then
			return {};
		end

		sortedPetsCache = {};
		local uniqueNames = {};
		local petsRaw = C_PetJournal.GetOwnedPetIDs();
		local useTableAPI = C_PetJournal.GetPetInfoTableByPetID ~= nil;

		for i = 1, #petsRaw do
			local petID = petsRaw[i];
			local displayName, icon;

			if useTableAPI then
				local info = C_PetJournal.GetPetInfoTableByPetID(petID);
				if info ~= nil then
					if info.customName ~= nil and info.customName ~= "" then
						displayName = info.customName .. " (" .. info.name .. ")";
					else
						displayName = info.name;
					end
					icon = info.icon;
				end
			else
				local _, customName, _, _, _, _, _, name, petIcon = C_PetJournal.GetPetInfoByPetID(petID);
				if customName ~= nil and customName ~= "" then
					displayName = customName .. " (" .. name .. ")";
				else
					displayName = name;
				end
				icon = petIcon;
			end

			if displayName ~= nil and displayName ~= "" and icon ~= nil and not uniqueNames[displayName] then
				uniqueNames[displayName] = true;
				table.insert(sortedPetsCache, { id = petID, name = displayName, icon = icon });
			end
		end

		table.sort(sortedPetsCache, MogCompanionsSortAlphabetical);
	end

	local searchString = MogCompanions.PetSearchString;

	if searchString == nil or searchString == "" then
		return sortedPetsCache;
	end

	local pets = {};
	local lowered = searchString:lower();

	for i = 1, #sortedPetsCache do
		if string.find(sortedPetsCache[i].name:lower(), lowered, 1, true) ~= nil then
			table.insert(pets, sortedPetsCache[i]);
		end
	end

	return pets;
end

-- Returns a random owned pet GUID.
-- excludedPetID is never added to the pool.
-- favoritesOnly limits the pool to favorite pets.
function MogCompanions:getRandomPet(excludedPetID, favoritesOnly)
	if C_PetJournal == nil or C_PetJournal.GetOwnedPetIDs == nil then
		return nil;
	end

	local petsRaw = C_PetJournal.GetOwnedPetIDs();
	local pets = {};
	local useTableAPI = C_PetJournal.GetPetInfoTableByPetID ~= nil;

	for i = 1, #petsRaw do
		local petID = petsRaw[i];
		local isFavorite = false;

		if useTableAPI then
			local info = C_PetJournal.GetPetInfoTableByPetID(petID);
			isFavorite = info ~= nil and info.isFavorite == true;
		else
			local _, _, _, _, _, _, favorite = C_PetJournal.GetPetInfoByPetID(petID);
			isFavorite = favorite == true;
		end

		if petID ~= nil and petID ~= "" and petID ~= excludedPetID and (not favoritesOnly or isFavorite) then
			table.insert(pets, petID);
		end
	end

	if #pets == 0 then
		return nil;
	end

	return pets[math.random(1, #pets)];
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

	for i = 1, #mountsRaw do
		local mount = mountsRaw[i];
		if MogCompanions:hasValue(aquaticMountTypeIDs, mount.mountTypeID) then
			table.insert(mounts, mount);
		end
	end

	return mounts;
end

-- Returns collected repair/vendor/utility mounts matched by hardcoded mount ID.
-- IDs: 460 (Grand Expedition Yak), 280 (Traveler's Tundra Mammoth), 284, 273, 274, 1039, 2237.
-- Update this list when Blizzard adds new vendor mounts.
function MogCompanions:getSortedRepairMounts()
	local mountsRaw = MogCompanions:sortMounts(MogCompanions:GetCollectedMounts());
	local mounts = {};

	for i = 1, #mountsRaw do
		local mount = mountsRaw[i];
		if MogCompanions:hasValue(repairMountIDs, mount.id) then
			table.insert(mounts, mount);
		end
	end

	return mounts;
end

-- Returns all collected mounts (no category filter, no search filter).
-- Used for the random mount slot — the player can assign anything here.
function MogCompanions:getSortedRandomMounts()
	local mountsRaw = MogCompanions:sortMounts(MogCompanions:GetCollectedMounts());
	local mounts = {};

	for i = 1, #mountsRaw do
		local mount = mountsRaw[i];
		table.insert(mounts, mount);
	end

	return mounts;
end

-- Builds the pool of ground mounts used by random ground selection.
-- Ignores the UI search filter and the ShowFlyingInGround display toggle.
-- Includes flying mounts only when MogCompanionsSaved.RandomGroundAllowFlying is true.
local function buildRandomGroundPool()
	local mountsRaw = MogCompanions:sortMounts(MogCompanions:GetCollectedMounts());
	local mounts = {};

	for i = 1, #mountsRaw do
		local mount = mountsRaw[i];
		if mount.mountTypeID == 230 or MogCompanionsSaved.RandomGroundAllowFlying then
			table.insert(mounts, mount);
		end
	end

	return mounts;
end

-- Returns true when the mount is still collected, usable, visible on this character,
-- and valid for the requested summon category.
-- Ground validation follows summon/random rules rather than the ground-list display filter.
function MogCompanions:IsMountUsableForCategory(mountID, category)
	if mountID == nil or mountID <= 1 then
		return false;
	end

	local name, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected = C_MountJournal.GetMountInfoByID(mountID);
	if not isCollected or shouldHideOnChar or not isUsable then
		return false;
	end

	local creatureDisplayInfoID, description, source, isSelfMount, mountTypeID = C_MountJournal.GetMountInfoExtraByID(mountID);

	if category == "flying" then
		return MogCompanions:hasValue(C_MountJournal.GetCollectedDragonridingMounts(), mountID);
	elseif category == "ground" then
		return mountTypeID == 230 or MogCompanionsSaved.RandomGroundAllowFlying;
	elseif category == "aquatic" then
		return MogCompanions:hasValue(aquaticMountTypeIDs, mountTypeID);
	elseif category == "repair" then
		return MogCompanions:hasValue(repairMountIDs, mountID);
	elseif category == "random" then
		return true;
	end

	return false;
end

-- Returns the saved selection pool table for the given outfit/pool key.
-- Missing pools are created lazily so the saved table remains authoritative.
function MogCompanions:GetOutfitSelectionPool(outfit, poolKey)
	if outfit == nil or poolKey == nil then
		return nil;
	end

	if type(outfit[poolKey]) ~= "table" then
		outfit[poolKey] = {};
		return outfit[poolKey];
	end

	local cleanedPool = {};
	for i = 1, #outfit[poolKey] do
		addUniquePoolValue(cleanedPool, outfit[poolKey][i]);
	end

	if #cleanedPool ~= #outfit[poolKey] then
		outfit[poolKey] = cleanedPool;
	end

	return outfit[poolKey];
end

function MogCompanions:IsInSelectionPool(outfit, poolKey, id)
	local pool = MogCompanions:GetOutfitSelectionPool(outfit, poolKey);
	if pool == nil or id == nil then
		return false;
	end

	return MogCompanions:hasValue(pool, id);
end

-- Toggles a single value in the saved selection pool.
-- Returns true when the value is present after the toggle, false when removed/no-op.
function MogCompanions:ToggleSelectionPoolValue(outfit, poolKey, id)
	local pool = MogCompanions:GetOutfitSelectionPool(outfit, poolKey);
	if pool == nil or id == nil or id == "" then
		return false;
	end

	for i = 1, #pool do
		if pool[i] == id then
			table.remove(pool, i);
			return false;
		end
	end

	table.insert(pool, id);
	return true;
end

function MogCompanions:ClearSelectionPool(outfit, poolKey)
	local pool = MogCompanions:GetOutfitSelectionPool(outfit, poolKey);
	if pool == nil then
		return;
	end

	for i = #pool, 1, -1 do
		table.remove(pool, i);
	end
end

function MogCompanions:GetRandomFromSelectionPool(outfit, poolKey)
	local pool = MogCompanions:GetOutfitSelectionPool(outfit, poolKey);
	if pool == nil or #pool == 0 then
		return nil;
	end

	return pool[math.random(1, #pool)];
end

function MogCompanions:GetSelectionPoolCount(outfit, poolKey)
	local pool = MogCompanions:GetOutfitSelectionPool(outfit, poolKey);
	if pool == nil then
		return 0;
	end

	return #pool;
end

function MogCompanions:GetValidSelectionPoolValues(outfit, poolKey, isValidFunc)
	local pool = MogCompanions:GetOutfitSelectionPool(outfit, poolKey);
	if pool == nil or type(isValidFunc) ~= "function" then
		return {};
	end

	local validValues = {};
	for i = 1, #pool do
		local value = pool[i];
		if isValidFunc(self, value) then
			addUniquePoolValue(validValues, value);
		end
	end

	return validValues;
end

function MogCompanions:PruneInvalidSelectionPool(outfit, poolKey, isValidFunc)
	local pool = MogCompanions:GetOutfitSelectionPool(outfit, poolKey);
	if pool == nil or type(isValidFunc) ~= "function" then
		return 0;
	end

	local validValues = {};
	for i = 1, #pool do
		local value = pool[i];
		if isValidFunc(self, value) then
			addUniquePoolValue(validValues, value);
		end
	end

	for i = #pool, 1, -1 do
		table.remove(pool, i);
	end

	for i = 1, #validValues do
		table.insert(pool, validValues[i]);
	end

	return #pool;
end

function MogCompanions:FilterSelectedOnly(items, outfit, poolKey)
	local filtered = {};

	if outfit == nil or items == nil then
		return filtered;
	end

	for i = 1, #items do
		if MogCompanions:IsInSelectionPool(outfit, poolKey, items[i].id) then
			table.insert(filtered, items[i]);
		end
	end

	return filtered;
end

function MogCompanions:UpdateShowSelectedButton(button, showOnlySelected, selectedCount)
	if button == nil then
		return;
	end

	if selectedCount <= 0 then
		button:Hide();
		return;
	end

	if showOnlySelected then
		button:SetText(MogCompanionsLocales["Show All"]);
	else
		button:SetText(MogCompanionsLocales["Show Selected"]);
	end

	button:Show();
end

function MogCompanions:UpdateNoResultsText(textFrame, searchBox, itemCount)
	if textFrame == nil then
		return;
	end

	local searchText = "";
	if searchBox ~= nil and searchBox.GetText ~= nil then
		searchText = searchBox:GetText() or "";
	end

	if itemCount == 0 and searchText ~= "" then
		textFrame:SetText(MogCompanionsLocales["No Items Match Search"]);
		textFrame:Show();
	else
		textFrame:Hide();
	end
end

-- Returns sorted mount info tables for all still-valid selections in the saved pool.
function MogCompanions:GetValidMountPoolInfos(outfit, poolKey, category)
	local pool = MogCompanions:GetOutfitSelectionPool(outfit, poolKey);
	if pool == nil or category == nil then
		return {};
	end

	local validMountIDs = {};
	for i = 1, #pool do
		local mountID = pool[i];
		if type(mountID) == "number" and MogCompanions:IsMountUsableForCategory(mountID, category) then
			addUniquePoolValue(validMountIDs, mountID);
		end
	end

	if #validMountIDs == 0 then
		return {};
	end

	return MogCompanions:sortMounts(validMountIDs);
end

-- Returns a random mount table from the specified category string.
-- type: "flying" | "ground" | "aquatic" | "repair" | "random"
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
		mounts = buildRandomGroundPool();
	elseif type == "aquatic" then
		mounts = MogCompanions:getSortedAquaticMounts();
	elseif type == "repair" then
		mounts = MogCompanions:getSortedRepairMounts();
	elseif type == "random" then
		mounts = MogCompanions:getSortedRandomMounts();
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
-- Formats a title ID into a displayable string for dropdowns and labels.
-- nil or 0: "[Don't Change Title]" — sentinel meaning do not change the title on mount.
-- -1: bare player name — sentinel meaning clear the title.
-- positive: formatted title string, e.g. "PlayerName the Explorer".
function MogCompanions:CreateDisplayTitle(titleID)
	if titleID == nil or titleID == 0 then
		return MogCompanionsLocales["Default Title"];
	end

	if titleID == -1 then
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
			titlesRaw[count].name = MogCompanions:CreateDisplayTitle(i);
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
--   Pet = "": no per-outfit pet selection.
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

	if outfit.FlyingMounts == nil then
		outfit.FlyingMounts = {};
		if outfit.Flying ~= nil and outfit.Flying > 1 then
			addUniquePoolValue(outfit.FlyingMounts, outfit.Flying);
		end
	end

	if outfit.GroundMounts == nil then
		outfit.GroundMounts = {};
		if outfit.Ground ~= nil and outfit.Ground > 1 then
			addUniquePoolValue(outfit.GroundMounts, outfit.Ground);
		end
	end

	if outfit.Hearthstone == nil then
		outfit.Hearthstone = 1;
	end

	if outfit.Hearthstones == nil then
		outfit.Hearthstones = {};
		if outfit.Hearthstone ~= nil and outfit.Hearthstone > 1 then
			addUniquePoolValue(outfit.Hearthstones, outfit.Hearthstone);
		end
	end

	if outfit.Pet == nil then
		outfit.Pet = "";
	end

	if outfit.Pets == nil then
		outfit.Pets = {};
		if outfit.Pet ~= nil and outfit.Pet ~= "" then
			addUniquePoolValue(outfit.Pets, outfit.Pet);
		end
	end

	if outfit.Title == nil then
		outfit.Title = 0;
	end
end

-- ── Active Outfit Accessors ──────────────────────────────────────────────────
-- Nil-safe wrapper for C_TransmogOutfitInfo.GetActiveOutfitID().
-- Returns the active outfit ID, or nil if there is no active outfit or the API
-- is unavailable.
function MogCompanions:GetSafeActiveOutfitID()
	if C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetActiveOutfitID then
		return C_TransmogOutfitInfo.GetActiveOutfitID();
	end
	return nil;
end

-- Returns the saved-variable table for the currently active outfit, or nil if
-- there is no active outfit or no saved data exists for it yet.
-- Does NOT auto-create the outfit entry; use CreateEmptyOutfit if that is needed.
function MogCompanions:GetActiveOutfitTable()
	local outfitID = MogCompanions:GetSafeActiveOutfitID();
	if outfitID == nil or MogCompanionsCharacterSaved == nil then
		return nil;
	end
	return MogCompanionsCharacterSaved["Outfit"..outfitID];
end
