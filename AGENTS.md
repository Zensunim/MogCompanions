# MogCompanions Addon Instructions

## Project type
MogCompanions is a World of Warcraft addon written for WoW's restricted Lua 5.1 environment.
It is event-driven and runs inside the WoW client.
There is no standalone runtime or automated test suite in this repository.

This is a maintained fork of MogCompanions with compatibility updates and new functionality. Preserve the fork attribution and license notices.

## Hard constraints
- Use WoW Lua 5.1 compatible syntax only.
- Do not use Lua 5.2+ features.
- Do not add external libraries, file I/O, sockets, OS calls, or non-WoW runtime assumptions.
- Do not invent WoW API functions. If unsure, follow existing repo patterns or leave a note.
- Do not claim runtime testing was performed unless the change was actually tested in-game.
- Prefer minimal, high-confidence changes. Avoid broad refactors and formatting churn unless explicitly requested.
- This repository currently targets Retail with a single `MogCompanions.toc`. Do not add Classic-era compatibility layers or extra TOC variants unless explicitly requested.
- Respect modern Retail addon restrictions, including combat lockdown and protected UI behavior.

## Repository map
- `Initialization.lua`
  - Initializes `MogCompanionsLocales` before localization and addon code load.
- `MogCompanions.toc`
  - Addon metadata, saved variable declarations, and file load order.
- `Core.lua`
  - Main addon frame, event handling, summon logic, transmog UI integration, title handling, mount slot UI, mount list tab, macro setup, keybind reminder, and selected mount updates.
- `Shared.lua`
  - Shared helpers for collected mounts, mount sorting, mount filtering, mount category lists, random mount selection, title sorting, selected mount data, and empty outfit saved-variable creation.
- `Settings.lua`
  - Retail Settings API registration for default mounts, per-outfit mounts, per-outfit title settings, and addon category setup.
- `Core.xml`
  - XML UI template for mount list buttons.
- `Settings.xml`
  - Settings XML shell. Currently empty but loaded by the TOC.
- `Bindings.xml`
  - MogCompanions keybinding definition that calls `MogCompanionsBindingClicked()`.
- `Locales/Localization.xml`
  - Loads localization files.
- `Locales/enUS.lua`
  - Default user-facing strings.
- `README.md`
  - Project description, attribution, and version history.
- `LICENSE.md`
  - Creative Commons Attribution 4.0 license text.
- `.github/workflows/build.yml`
  - Tag-triggered release zip workflow.

## Working rules
- Follow the surrounding file's style and formatting.
- Keep changes localized. Do not rewrite `Core.lua` or `Settings.lua` broadly unless explicitly requested.
- Do not mix behavior changes with unrelated cleanup.
- Prefer using existing helpers in `Shared.lua` instead of duplicating mount, title, or outfit logic.
- Preserve existing public entry points used by bindings, macros, XML, or saved variables.
- Avoid renaming global functions or saved-variable keys unless the repo owner explicitly requests a migration.
- Do not change attribution, license text, README attribution, or the original project link unless explicitly requested.
- Do not add debug output unless explicitly requested or gated behind a clear debug flag.

## Lua style and namespacing rules
- Prefer `local` variables and functions unless a global is required by XML, bindings, slash commands, macros, or saved-variable compatibility.
- Existing required globals include `MogCompanionsLocales`, `MogCompanionsSelectedMount`, `MogCompanionsBindingClicked`, `MogCompanionsSummon`, `MogCompanionsSummonFlying`, `MogCompanionsSummonGround`, `MogCompanionsSummonAquatic`, `MogCompanionsSummonRepair`, `MogCompanionsSummonRandom`, `MissingKeybindOrMacro`, `CreateSetupReminder`, `ClearSelectedFlyingMount`, `ClearSelectedGroundMount`, and `UpdateSelectedMountRow`.
- Prefer methods on `MogCompanions` for shared addon behavior, for example `function MogCompanions:CreateEmptyOutfit(id)`.
- Keep the existing namespace pattern:
  - `local addonName, addon = ...`
  - `local ns = select(2, ...)`
  - `ns.MogCompanions = MogCompanions`
- Do not introduce new top-level globals accidentally. Many existing variables are global by legacy style, but new code should avoid adding to that problem.
- Use Lua tables and simple control flow compatible with WoW Lua 5.1.

## Saved variable rules
- Account-wide saved variables live in `MogCompanionsSaved`.
- Per-character saved variables live in `MogCompanionsCharacterSaved`.
- Add saved-variable migrations defensively during addon initialization.
- Never wipe or rebuild user saved variables as a shortcut.
- Handle missing, deleted, or newly created transmog outfits without nil errors.
- Treat `0` and `1` carefully. This addon currently uses both as sentinel values in different dropdown contexts.

## Mount behavior rules
- Preserve current summon priority unless explicitly changed:
  - exit vehicle first
  - dismount if already mounted
  - [Ground modifier] while swimming summons aquatic mount
  - [Repair modifier] summons repair/vendor mount (saved-variable key is `MountMods.Repair`)
  - [Random modifier] summons a random flying or ground mount (saved-variable key is `MountMods.Random`)
  - flyable area without [Ground modifier] summons flying
  - otherwise summons ground
- Do not change modifier-key behavior without updating settings text, tooltips, keybind reminders, README notes, and validation notes.
- Do not assume a mount list has at least one result. Random selection must handle empty lists safely when adding or changing logic.
- Use `C_MountJournal` APIs consistently with existing code.
- Keep mount category decisions centralized in `Shared.lua` where possible.
- Before adding hardcoded mount IDs or mount type IDs, search for existing lists and comments first.

## Transmog and title rules
- This addon is tightly coupled to the Retail transmog UI.
- Use existing `C_TransmogOutfitInfo` patterns for current, active, and viewed outfit IDs.
- Be careful about the difference between:
  - `GetActiveOutfitID()`
  - `GetCurrentlyViewedOutfitID()`
  - outfit IDs returned by `GetOutfitsInfo()`
- Avoid touching Blizzard transmog frames before they exist.
- Use delayed initialization patterns like `C_Timer.After(...)` only when needed for Blizzard UI timing.
- Do not assume `TransmogFrame`, `WardrobeCollection`, `CharacterPreview`, or model frames are available outside transmog-related events.
- Preserve title behavior unless explicitly requested. Title changes currently apply when mounting and when title selections change.

## UI and combat lockdown rules
- Respect combat lockdown. Do not create, destroy, reparent, or reconfigure protected UI in combat unless the operation is known to be safe.
- Do not create or modify macros during combat.
- Do not modify keybindings during combat.
- Be careful with `SecureActionButtonTemplate` and protected frames. Avoid changing secure attributes after combat begins.
- Keep UI frame creation close to the existing initialization flow unless a specific bug requires restructuring.
- Do not assume hidden Blizzard UI internals are stable across Retail patches. If using internal frame paths, guard nils and keep the change minimal.

## Settings rules
- `Settings.lua` uses the Retail Settings API. Keep settings registration in `Settings.lua` unless the change directly belongs to the transmog UI.
- Register new user options through `Settings.RegisterAddOnSetting` and `Settings.CreateDropdown` or the appropriate existing Settings API pattern.
- Keep default settings and saved-variable migrations in sync.
- Add or update tooltips when changing behavior users need to understand.
- Do not hardcode user-facing strings in `Settings.lua`; add them to `Locales/enUS.lua`.

## Localization rules
- `Locales/enUS.lua` is the default localization file.
- Add new user-facing strings to `Locales/enUS.lua` and reference them through `MogCompanionsLocales` / `L[...]`.
- Do not rename existing localization keys unless the feature requires it.
- Do not add machine-generated translations for other locales. Add other locale files only when translations are provided or explicitly requested.
- Internal-only debug strings may be hardcoded if debugging is explicitly requested, but remove or gate them before release.

## TOC and load order rules
- Update `MogCompanions.toc` only when needed, for example:
  - adding a new file
  - renaming a file
  - removing a file
  - bumping version metadata
  - changing saved-variable declarations
- Preserve load order unless there is a clear reason to change it.
- `Initialization.lua` must load before localization files and addon code that uses `MogCompanionsLocales`.
- `Core.lua` must load before files that rely on `ns.MogCompanions`.
- XML files should be listed where their templates or scripts are needed.

## Packaging rules
- Release zips are built by `.github/workflows/build.yml` when a tag is pushed.
- The package root should remain `MogCompanions`.
- Do not package `.git/` or `.github/` or `docs/`.
- Do not package AI instruction sets like `AGENTS.md`.
- Do not include generated zip files in the repository.
- Keep the artifact naming pattern `MogCompanions-<tag>.zip` unless explicitly requested.

## Transmog Outfit Events

Use `VIEWED_TRANSMOG_OUTFIT_CHANGED` only for transmog UI refresh logic.

This event means the player is viewing or selecting a different saved outfit in the transmog UI. It does not necessarily mean the character actually changed outfits.

Good uses:
- Refreshing displayed mount, pet, hearthstone, or title slots
- Updating selected rows or checkmarks
- Updating previews
- Reading `C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()`

Do not use `VIEWED_TRANSMOG_OUTFIT_CHANGED` for gameplay behavior.

Use `TRANSMOG_DISPLAYED_OUTFIT_CHANGED` for actual applied outfit changes.

This event means the character's displayed outfit changed. Use it for behavior that should follow the active outfit, including:
- Auto-summoning assigned pets
- Updating active outfit hearthstone behavior
- Applying active outfit side effects

For active outfit behavior, use the active outfit ID, not the viewed outfit ID.

Rule:
- Viewed outfit = UI selection
- Displayed outfit = actual character outfit

## Release, versioning, and documentation rules
- This fork currently uses a visible `1.0` style version in `MogCompanions.toc` and `README.md`.
- Unless explicitly instructed otherwise, use simple semantic-style versioning:
  - patch version for small bug fixes, compatibility fixes, text fixes, or packaging-only fixes, for example `1.0.1`
  - minor version for user-visible feature additions or behavior changes, for example `1.1`
  - major version only for major architecture changes, saved-variable-breaking changes, or when explicitly requested, for example `2.0`
- Every release must update `## Version` in `MogCompanions.toc`.
- Every release must append notes to `README.md` under `## Version History`.
- Release notes should be short, factual, and end-user readable.
- Do not rewrite old changelog entries.
- Do not invent release notes that are not supported by actual changes.
- Tag names should match the visible addon version unless explicitly instructed otherwise.

## GitHub Actions rules
- Keep the release workflow simple.
- Do not add build steps that require nonstandard external tools unless explicitly requested.
- If changing package contents, review the `rsync` excludes and the final zip root.
- If changing release permissions, keep `permissions: contents: write` unless a specific workflow change requires otherwise.
- Do not change release behavior and addon behavior in the same PR unless explicitly requested.

## Validation checklist
Before finishing, verify by static review:
- Lua syntax is compatible with WoW Lua 5.1.
- No WoW APIs were invented.
- No obvious nil-access was introduced around transmog frames, mount data, saved variables, dropdowns, or model frames.
- Saved-variable migrations are backward compatible.
- Modifier-key summon behavior still matches tooltips and reminders.
- User-facing strings are localized through `Locales/enUS.lua`.
- `MogCompanions.toc` load order is still correct.
- README version notes were updated for release-related changes.
- Packaging changes do not include `.git/`, `.github/`, `AGENTS.md`, or generated zip files.
- No unrelated files were changed.

## When unsure
- Search the repo for a similar pattern first.
- Match existing MogCompanions behavior and file organization rather than introducing a new architecture.
- Choose the smallest safe change.
- Leave a clear note when a WoW API behavior or Retail patch behavior cannot be verified statically.
