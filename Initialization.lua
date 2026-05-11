-- Initialization.lua
-- Must load first — before all locale files and all other addon Lua files.
-- Creates the global MogMountLocales table that locale files write into
-- using the pattern: L["key"] = "value" (where L = MogMountLocales).
MogMountLocales = {};
