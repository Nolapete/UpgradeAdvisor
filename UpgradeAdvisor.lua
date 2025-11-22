local UpgradeAdvisor = {}
pcall(function() DEFAULT_CHAT_FRAME:AddMessage("UA> Lua file executed") end)
-- Saved samples (compact) so user can /reload and retrieve them from SavedVariables on disk.
-- This is intentionally small and concise to work around inability to copy from in-game chat.
UpgradeAdvisor_Samples = UpgradeAdvisor_Samples or { meta = {}, pfq = { items = {}, vendors = {} }, al = { modules = {} } }

-- forward-declare helpers so functions defined earlier can call them regardless of file order
local getPfQuestData, getAtlasLootData, normalizeCandidate

-- Save compact AtlasLoot/pfQuest samples into SavedVariables for external copy/paste.
function UpgradeAdvisor:SaveSamples()
    local s = UpgradeAdvisor_Samples or {}
    s.meta = { player = UnitName("player") or "?", realm = GetRealmName() or "?", time = date("%Y-%m-%d %H:%M:%S") }

    -- pfQuest compact sample
    local pfItems, pfVendors = nil, nil
    if type(getPfQuestData) == "function" then
        pfItems, pfVendors = getPfQuestData()
    else
        pcall(function() DEFAULT_CHAT_FRAME:AddMessage("UA> warning: getPfQuestData not available yet") end)
    end
    s.pfq = { items = {}, vendors = {} }
    if type(pfItems) == "table" then
        local c = 0
        for k,v in pairs(pfItems) do
            c = c + 1
            if c > 10 then break end
            local sample = nil
            if type(v) == "table" then
                sample = v.id or v.itemID or v[1] or nil
            else
                sample = tostring(v)
            end
            table.insert(s.pfq.items, { key = k, sample = sample })
        end
    end
    if type(pfVendors) == "table" then
        local c = 0
        for k,v in pairs(pfVendors) do
            c = c + 1
            if c > 10 then break end
            local coords = nil
            if type(v) == "table" and (v.x or v.coords or v.zone) then
                coords = { x = v.x or (v.coords and v.coords.x) or nil, y = v.y or (v.coords and v.coords.y) or nil, zone = v.zone or (v.coords and v.coords.zone) }
            end
            table.insert(s.pfq.vendors, { key = k, coords = coords })
        end
    end

    -- AtlasLoot compact sample
    local al = nil
    if type(getAtlasLootData) == "function" then
        al = getAtlasLootData()
    else
        pcall(function() DEFAULT_CHAT_FRAME:AddMessage("UA> warning: getAtlasLootData not available yet") end)
    end
    s.al = { modules = {} }
    if type(al) == "table" then
        local mc = 0
        for modk, modv in pairs(al) do
            mc = mc + 1
            if mc > 10 then break end
            local mod = { key = tostring(modk), sample = {} }
            if type(modv) == "table" then
                local gi = 0
                for gidx, group in pairs(modv) do
                    gi = gi + 1
                    if gi > 2 then break end
                    local entries = {}
                    if type(group) == "table" then
                        local ei = 0
                        for _, e in pairs(group) do
                            ei = ei + 1
                            if ei > 3 then break end
                            if type(e) == "table" and e[1] then
                                table.insert(entries, tostring(e[1]))
                            else
                                table.insert(entries, tostring(e))
                            end
                        end
                    end
                    table.insert(mod.sample, entries)
                end
            end
            table.insert(s.al.modules, mod)
        end
    end

    UpgradeAdvisor_Samples = s
    pcall(function() DEFAULT_CHAT_FRAME:AddMessage("UA> Saved compact samples to SavedVariables 'UpgradeAdvisor_Samples'. Use /reload or log out to write to disk, then open your SavedVariables/UpgradeAdvisor.lua to copy the data.") end)
end

    -- safe table length (some server Lua builds don't support the # operator)
    local function tcount(t)
        if type(t) ~= "table" then return 0 end
        local c = 0
        for _ in pairs(t) do c = c + 1 end
        return c
    end

-- Slash command to save compact samples into SavedVariables for external retrieval
SLASH_UASAVE1 = "/uasave"
SlashCmdList["UASAVE"] = function()
    UpgradeAdvisor:SaveSamples()
end
UpgradeAdvisor.frame = CreateFrame("Frame", "UpgradeAdvisorFrame", UIParent)
if UpgradeAdvisor.frame.SetSize then
    UpgradeAdvisor.frame:SetSize(320, 200)
else
    -- older clients may not have :SetSize
    UpgradeAdvisor.frame:SetWidth(320)
    UpgradeAdvisor.frame:SetHeight(200)
end
UpgradeAdvisor.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
UpgradeAdvisor.frame:Hide()

-- UpgradeAdvisor core (drop into UpgradeAdvisor.lua)
-- core initialization continued

do
    local bg = UpgradeAdvisor.frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(true)
    -- protect the color/texture calls; some server clients lack SetColorTexture or have different APIs
    local ok, err = pcall(function()
        if bg.SetColorTexture then
            bg:SetColorTexture(0, 0, 0, 0.6)
        else
            bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
            if bg.SetVertexColor then bg:SetVertexColor(0, 0, 0, 0.6) end
        end
    end)
    if not ok then pcall(function() DEFAULT_CHAT_FRAME:AddMessage("UA> warning: background texture setup failed: "..tostring(err)) end) end
    UpgradeAdvisor.frame.bg = bg
end

UpgradeAdvisor.frame.title = UpgradeAdvisor.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
UpgradeAdvisor.frame.title:SetPoint("TOP", 0, -8)
UpgradeAdvisor.frame.title:SetText("UpgradeAdvisor")

-- simple lines area (up to 12 clickable lines)
UpgradeAdvisor.lines = {}
for i = 1, 12 do
    local b = CreateFrame("Button", "UpgradeAdvisorLine"..i, UpgradeAdvisor.frame)
    if b.SetSize then
        b:SetSize(300, 16)
    else
        b:SetWidth(300)
        b:SetHeight(16)
    end
    b:SetPoint("TOPLEFT", UpgradeAdvisor.frame, "TOPLEFT", 10, -30 - (i-1)*16)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.text:SetAllPoints(b)
    b:SetScript("OnEnter", function(self)
        if self.itemLink then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.itemLink)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self)
        if self.itemLink then
            -- show item link in chat edit box (shift-click behavior)
            if IsShiftKeyDown() then
                ChatEdit_InsertLink(self.itemLink)
            else
                -- if location info present and is a table, try to add a pfQuest map marker if possible
                if type(self.coord) == "table" and self.coord.zone then
                    -- safe call into pfQuest if present
                    if pfQuest and pfQuest.map and type(pfQuest.map.Add) == "function" then
                        pcall(function()
                            pfQuest.map:Add(self.coord.zone, self.coord.x, self.coord.y, {text = self.itemName or "Drop loc"})
                        end)
                    else
                        -- fallback: print location to chat
                        local cx = tonumber(self.coord.x) or 0
                        local cy = tonumber(self.coord.y) or 0
                        DEFAULT_CHAT_FRAME:AddMessage(("Location: %s (%.2f, %.2f)"):format(self.coord.zone, cx*100, cy*100))
                    end
                end
            end
        end
    end)
    UpgradeAdvisor.lines[i] = b
end

-- Ensure slash commands are registered after the client has finished loading.
-- Some addons defer registration until PLAYER_LOGIN; replicate that to be robust.
do
    local regFrame = CreateFrame("Frame")
    regFrame:RegisterEvent("PLAYER_LOGIN")
    regFrame:SetScript("OnEvent", function()
        -- primary scan command
        SLASH_UPGRADEADVISOR1 = "/upgradeadvisor"
        SLASH_UPGRADEADVISOR2 = "/ua"
        SlashCmdList["UPGRADEADVISOR"] = function()
            UpgradeAdvisor:ScanUpgrades()
        end

        -- hide UI
        SLASH_UPGRADEADVISORHIDE1 = "/uahide"
        SlashCmdList["UPGRADEADVISORHIDE"] = function()
            UpgradeAdvisor.frame:Hide()
        end

        -- debug
        SLASH_UPGRADEADVISORDBG1 = "/uadb"
        SLASH_UPGRADEADVISORDBG2 = "/uadebug"
        SlashCmdList["UPGRADEADVISORDBG"] = SlashCmdList["UPGRADEADVISORDBG"] or function()
            -- if debug func already exists (defined earlier) call it, otherwise call our debug writer
            if SlashCmdList["UPGRADEADVISORDBG"] then
                -- already set earlier in file; no-op to avoid recursion
            end
        end

        -- short helper commands
        SLASH_UAHELP1 = "/uahelp"
        SlashCmdList["UAHELP"] = SlashCmdList["UAHELP"] or function() end

        SLASH_UAINFO1 = "/uainfo"
        SlashCmdList["UAINFO"] = SlashCmdList["UAINFO"] or function() end

        SLASH_UAPFQ1 = "/uapfq"
        SlashCmdList["UAPFQ"] = SlashCmdList["UAPFQ"] or function() end

        SLASH_UAAL1 = "/uaal"
        SlashCmdList["UAAL"] = SlashCmdList["UAAL"] or function() end

        regFrame:UnregisterAllEvents()
    end)
end

    -- Extra defensive registration: listen to multiple lifecycle events and register commands + announce when loaded.
    do
        local ef = CreateFrame("Frame")
        ef:RegisterEvent("ADDON_LOADED")
        ef:RegisterEvent("VARIABLES_LOADED")
        ef:RegisterEvent("PLAYER_LOGIN")
        ef:SetScript("OnEvent", function(self, event, arg1, ...)
            if event == "ADDON_LOADED" then
                -- nothing special, but keep for compatibility
                if arg1 == "UpgradeAdvisor" then
                    -- pass
                end
            elseif event == "VARIABLES_LOADED" or event == "PLAYER_LOGIN" then
                -- ensure commands are available early; some loaders register later
                SLASH_UPGRADEADVISOR1 = "/upgradeadvisor"
                SLASH_UPGRADEADVISOR2 = "/ua"
                SlashCmdList["UPGRADEADVISOR"] = function() UpgradeAdvisor:ScanUpgrades() end

                SLASH_UPGRADEADVISORHIDE1 = "/uahide"
                SlashCmdList["UPGRADEADVISORHIDE"] = function() UpgradeAdvisor.frame:Hide() end

                SLASH_UPGRADEADVISORDBG1 = "/uadb"
                SLASH_UPGRADEADVISORDBG2 = "/uadebug"
                -- If the debug implementation exists earlier in file, keep it; otherwise fallback to a simple reporter
                if not SlashCmdList["UPGRADEADVISORDBG"] then
                    SlashCmdList["UPGRADEADVISORDBG"] = function()
                        DEFAULT_CHAT_FRAME:AddMessage("|cffffff00UpgradeAdvisor Debug:|r debug function not available")
                    end
                end

                -- announce loaded so user can confirm registration
                DEFAULT_CHAT_FRAME:AddMessage("|cffffff00UpgradeAdvisor:|r loaded - try /uahelp")

                ef:UnregisterAllEvents()
            end
        end)
    end

-- utility: safe access to external data
getPfQuestData = function()
    -- Try a few common names/shapes used by pfQuest across forks/versions.
    local candidates = {"pfQuest", "pfQuestDB", "pfQuest_data", "pfQuestDB", "pfQuest_data_db"}
    for _, name in ipairs(candidates) do
        local ok, obj = pcall(function() return _G[name] end)
        if ok and type(obj) == "table" then
            -- common shape: obj.db.items + obj.db.vendors
            if type(obj.db) == "table" then
                if obj.db.items or obj.db.vendors then
                    return obj.db.items, obj.db.vendors
                end
            end
            -- alternate shape: top-level items/vendors tables
            if type(obj.items) == "table" or type(obj.vendors) == "table" then
                return obj.items, obj.vendors
            end
        end
    end
    -- last-resort: try pfQuest global directly in a safe way
    if type(pfQuest) == "table" then
        if type(pfQuest.db) == "table" then
            return pfQuest.db.items, pfQuest.db.vendors
        elseif type(pfQuest.items) == "table" then
            return pfQuest.items, pfQuest.vendors
        end
    end
    return nil, nil
end

getAtlasLootData = function()
    -- AtlasLoot historically exposes AtlasLoot_Data or AtlasLoot_Items; handle common names
    if type(AtlasLoot_Data) == "table" then
        return AtlasLoot_Data
    end
    if type(AtlasLoot) == "table" and type(AtlasLoot.Modules) == "table" then
        return AtlasLoot.Modules
    end
    return nil
end

-- Robust extractor for AtlasLoot entry shapes.
-- Common shapes:
--  - number (itemID)
--  - string item link containing "item:ID"
--  - table where element[1] is an itemID or item-link, or nested tables
local function extractItemIDsFromAtlasEntry(entry, out)
    out = out or {}
    local t = type(entry)
    if t == "number" then
        table.insert(out, entry)
        -- Prefer IDs that resolve via GetItemInfo (valid items). If none resolve, fall back to raw extracted IDs.
        local verified = {}
        for _, iid in ipairs(out) do
            local ok, name = pcall(GetItemInfo, iid)
            if ok and name then
                table.insert(verified, iid)
            end
        end
        if tcount(verified) > 0 then return verified end
        return out
    elseif t == "string" then
        -- AtlasLoot entries can be full item-links, plain numeric strings, or prefixed codes
        -- Try item:ID first, then plain numeric, then any embedded number. Skip "0" placeholders.
        local id = string.match(entry, "item:(%d+)") or string.match(entry, "^(%d+)$") or string.match(entry, "(%d+)")
        if id then
            local nid = tonumber(id)
            if nid and nid ~= 0 then table.insert(out, nid) end
        end
        return out
    elseif t == "table" then
        -- If first element is a number or link, prefer that
        if entry[1] then
            if type(entry[1]) == "number" then
                table.insert(out, entry[1]); return out
            elseif type(entry[1]) == "string" then
                local id = string.match(entry[1], "item:(%d+)") or string.match(entry[1], "^(%d+)$") or string.match(entry[1], "(%d+)")
                if id then local nid = tonumber(id); if nid and nid ~= 0 then table.insert(out, nid); return out end end
            end
        end
        -- Otherwise, scan table fields shallowly for numbers or link-like strings
        for _, v in pairs(entry) do
            local vt = type(v)
            if vt == "number" then
                table.insert(out, v)
            elseif vt == "string" then
                local id = string.match(v, "item:(%d+)") or string.match(v, "^(%d+)$") or string.match(v, "(%d+)")
                if id then local nid = tonumber(id); if nid and nid ~= 0 then table.insert(out, nid) end end
            elseif vt == "table" then
                -- nested small table, try its first element
                if v[1] then
                    if type(v[1]) == "number" then
                        table.insert(out, v[1])
                    elseif type(v[1]) == "string" then
                        local id = string.match(v[1], "item:(%d+)") or string.match(v[1], "^(%d+)$") or string.match(v[1], "(%d+)")
                        if id then local nid = tonumber(id); if nid and nid ~= 0 then table.insert(out, nid) end end
                    end
                end
            end
            -- keep scanning but avoid deep recursion
            if out[8] then break end
        end
        return out
    end
    return out
end

-- mapping simple textual slot to inventory slot constant via GetInventorySlotInfo
local slotNameMap = {
    ["Head"] = "HeadSlot",
    ["Neck"] = "NeckSlot",
    ["Shoulder"] = "ShoulderSlot",
    ["Back"] = "BackSlot",
    ["Chest"] = "ChestSlot",
    ["Shirt"] = "ShirtSlot",
    ["Tabard"] = "TabardSlot",
    ["Wrist"] = "WristSlot",
    ["Hands"] = "HandsSlot",
    ["Waist"] = "WaistSlot",
    ["Legs"] = "LegsSlot",
    ["Feet"] = "FeetSlot",
    ["Finger"] = "Finger0Slot", -- use Finger0Slot then Finger1Slot fallback
    ["Trinket"] = "Trinket0Slot",
    ["MainHand"] = "MainHandSlot",
    ["OffHand"] = "SecondaryHandSlot",
    ["Ranged"] = "RangedSlot",
}

-- Helper to get equipped item link/id in a slot; handles common slot name or inventory slot ID
local function getEquippedItemForSlot(slotKey)
    if type(slotKey) == "number" then
        local id = GetInventoryItemID("player", slotKey)
        if id then
            return id, select(7, GetItemInfo(id)) -- link is returned by GetItemInfo (deprecated returns), safer to request GetItemInfo(id) again
        end
        return nil, nil
    end
    local invName = slotNameMap[slotKey]
    if invName then
        --@diagnostic disable-next-line: Cannot assign 'string' to parameter
        local slotId = GetInventorySlotInfo(invName)
        if slotId then
            local id = GetInventoryItemID("player", slotId)
            if id then
                local name, link = GetItemInfo(id)
                return id, link
            end
        end
    end
    return nil, nil
end

-- scoring: prefer item.ilvl if present, else compute weighted stat sum
local defaultWeights = {
    -- example weights: each class/spec should adjust these; user can override later
    PRIEST = {int = 2.0, spirit = 0.5, stamina = 0.7, mp5 = 0.8},
    WARRIOR = {str = 2.0, stam = 0.9, agi = 0.4},
    ROGUE = {agi = 2.0, stam = 0.6, str = 1.0},
    MAGE = {int = 2.0, spirit = 0.6, stam = 0.6},
    -- fallback weights
    DEFAULT = {str = 1.0, agi = 1.0, int = 1.0, stam = 0.7, spirit = 0.5},
}

local function getPlayerClassWeight()
    local _, class = UnitClass("player")
    if class and defaultWeights[class] then return defaultWeights[class] end
    return defaultWeights.DEFAULT
end

local function computeStatScoreFromTable(stats, weights)
    if not stats then return 0 end
    local s = 0
    for k,v in pairs(stats) do
        local key = string.lower(k)
        local w = weights[key] or weights[string.upper(key)] or 1.0
        s = s + (v * (type(w)=="number" and w or 1.0))
    end
    return s
end

local function itemScore(candidate)
    -- candidate may be number (itemID), or table with fields .id, .ilvl, .stats
    if not candidate then return 0 end
    if type(candidate) == "string" then candidate = normalizeCandidate(candidate) end
    local weights = getPlayerClassWeight()
    if type(candidate) == "number" then
        -- try to use GetItemInfo to find item level via tooltip scanning is complex; fallback to basic item link fallback 0
        return 0
    end
    if type(candidate.ilvl) == "number" and candidate.ilvl > 0 then
        return candidate.ilvl
    end
    if candidate.stats then
        return computeStatScoreFromTable(candidate.stats, weights)
    end
    -- fallback: if itemID present, try to use a heuristic from itemLink name (best-effort)
    if candidate.id then
        -- calling GetItemInfo can return itemLink/name; user should populate ilvl or stats for best results
        local name, link = GetItemInfo(candidate.id)
        if link then
            -- we can't reliably derive ilvl without parsing tooltips here; return small non-zero base
            return 1
        end
    end
    return 0
end

-- comparing: consider candidate an upgrade if its score is a threshold higher than equipped item.
local UPGRADE_THRESHOLD = 0.05 -- 5% better to count as upgrade

local function isUpgrade(candidate, equipped)
    local candScore = itemScore(candidate)
    local eqScore = itemScore(equipped)
    if eqScore == 0 and candScore > 0 then
        return true
    end
    if candScore > eqScore * (1 + UPGRADE_THRESHOLD) then
        return true
    end
    return false
end

-- helper to normalize candidate item shape (try to extract id, slot, ilvl, stats, coord)
local function normalizeCandidate(raw)
    -- raw may be number (itemID), string (itemLink), or table
    local out = {}
    if type(raw) == "number" then
        out.id = raw
    elseif type(raw) == "string" then
        -- attempt to parse item link for id
        local id = string.match(raw, "item:(%d+)")
        if id then out.id = tonumber(id) end
        out.link = raw
    elseif type(raw) == "table" then
        -- copy common fields if present
        out.id = raw.id or raw.itemId or raw.itemID or raw[1]
        out.ilvl = raw.ilvl or raw.itemLevel
        out.stats = raw.stats or raw.bonus or raw.stat
        out.slot = raw.slot or raw.equipSlot or raw.slotName
    if type(raw.coord) == "table" then out.coord = raw.coord end
    if type(raw.location) == "table" then out.coord = raw.location end
        out.source = raw.source
        out.raw = raw
    end
    if out.id then
        local name, link = GetItemInfo(out.id)
        out.itemLink = link
        out.itemName = name
    end
    return out
end

-- iterate pfQuest items, vendors and AtlasLoot data and collect upgrades
function UpgradeAdvisor:ScanUpgrades()
    local playerLevel = UnitLevel("player")
    local pfItems, pfVendors = getPfQuestData()
    local atlasLoot = getAtlasLootData()

    local candidates = {}

    -- 1) pfQuest items collection (if the data shape is a map of itemID -> data)
    if pfItems and type(pfItems) == "table" then
        for key, data in pairs(pfItems) do
            -- pfQuest store shapes vary; we normalize per normalizeCandidate
            local norm = normalizeCandidate(data or key)
            -- Accept only items with requiredLevel <= playerLevel (if present)
            local req = 0
            if type(data) == "table" then
                req = data.req or data.reqLevel or data.reqlevel or 0
            end
            if not req or req <= playerLevel then
                table.insert(candidates, norm)
            end
        end
    end

    -- 2) pfQuest vendors: they often list vendor items with coords
    if pfVendors and type(pfVendors) == "table" then
        for vid, vdata in pairs(pfVendors) do
            if type(vdata) == "table" and vdata.items then
                for _, it in ipairs(vdata.items) do
                    local norm = normalizeCandidate(it)
                    -- attach vendor coords if available
                    if type(vdata) == "table" and vdata.zone and vdata.x and vdata.y then
                        norm.coord = { zone = vdata.zone, x = vdata.x, y = vdata.y }
                    elseif type(vdata) == "table" and vdata.coords then
                        norm.coord = vdata.coords
                    end
                    table.insert(candidates, norm)
                end
            end
        end
    end

    -- 3) AtlasLoot: scan common container AtlasLoot_Data (handle known top-level sections)
    if atlasLoot and type(atlasLoot) == "table" then
        -- prefer scanning common top-level categories if present
        local topKeys = { "Items", "SetItems", "Crafting", "BGItems", "GeneralPVPItems", "WorldEvents", "Sources", "Fallback" }
        local seen = {}
        for _, k in ipairs(topKeys) do
            if atlasLoot[k] then seen[k] = atlasLoot[k] end
        end
        -- include any other module tables too
        for k,v in pairs(atlasLoot) do
            if type(k) == "string" and not seen[k] and type(v) == "table" then seen[k] = v end
        end

        for key, module in pairs(seen) do
            -- module is typically a list of groups; each group is a table of entries
            if type(module) == "table" then
                for _, group in pairs(module) do
                    if type(group) == "table" then
                        for _, entry in pairs(group) do
                            local ids = extractItemIDsFromAtlasEntry(entry)
                            for _, id in ipairs(ids) do
                                table.insert(candidates, normalizeCandidate(id))
                            end
                        end
                    end
                end
            end
        end
    end

    -- now filter candidates by slot and compare with equipped
    -- normalize candidates and deduplicate by item id/link to avoid massive duplicate lists
    local normalized = {}
    local seen = {}
    for i, c in ipairs(candidates) do
        local n = (type(c) == "table") and c or normalizeCandidate(c)
        local key = nil
        if type(n) == "table" and n.id then key = tostring(n.id) end
        if not key and type(n) == "table" and n.itemLink then key = tostring(n.itemLink) end
        if not key then key = tostring(n) end
        if not seen[key] then
            table.insert(normalized, n)
            seen[key] = true
        end
    end
    candidates = normalized
    local upgrades = {}
    for idx, cand in ipairs(candidates) do
        -- ensure candidate is a table before processing (some extracts may still be raw strings/numbers)
        if type(cand) ~= "table" then cand = normalizeCandidate(cand) end
        if type(cand) ~= "table" then
            -- couldn't normalize; skip safely and report short message
            pcall(function() DEFAULT_CHAT_FRAME:AddMessage("UA> scan: skipping candidate #"..tostring(idx).." (bad candidate type)") end)
        else
            local ok, err = pcall(function()
                -- we need a slot; try to infer from raw or from GetItemInfo
                local slot = (type(cand) == "table") and cand.slot or nil
                if not slot and cand.id then
                    local info = nil
                    if GetItemInfoInstant then
                        info = { GetItemInfoInstant(cand.id) }
                    else
                        info = { GetItemInfo(cand.id) }
                    end
                    local equipSlot = info[9]
                    -- equipSlot may be returned as a string like "INVTYPE_HEAD"
                    if equipSlot and type(equipSlot) == "string" then
                        slot = string.gsub(equipSlot, "INVTYPE_", "")
                    end
                end
                if slot and type(slot) == "string" then
                    -- map a few common forms
                    slot = string.gsub(slot, "INVTYPE_", "") -- ensure consistent
                    local equippedId, equippedLink = getEquippedItemForSlot(slot)
                    local equippedNorm = nil
                    if equippedId then
                        equippedNorm = { id = equippedId }
                    end
                    if isUpgrade(cand, equippedNorm) then
                        local it = (type(cand) == "table") and cand or normalizeCandidate(cand)
                        table.insert(upgrades, { item = it, slot = slot, equipped = equippedNorm })
                    end
                end
            end)
            if not ok then
                -- report the candidate that caused a crash and continue (use safe chat print)
                local idprint = (type(cand) == "table" and cand.id) or tostring(cand)
                pcall(function() DEFAULT_CHAT_FRAME:AddMessage("UA> scan: candidate #"..tostring(idx).." ("..tostring(idprint)..") error: "..tostring(err)) end)
            end
        end
    end

    -- show results in UI
    if tcount(upgrades) == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffff00UpgradeAdvisor:|r No upgrades found.")
        UpgradeAdvisor.frame:Hide()
        return upgradest
    end

    -- populate UI lines & also print to chat
    DEFAULT_CHAT_FRAME:AddMessage("|cffffff00UpgradeAdvisor:|r Found "..tcount(upgrades).." potential upgrades:")
    for i = 1, 12 do
        local line = UpgradeAdvisor.lines[i]
        local u = upgrades[i]
        if not line then
            -- defensive: if UI line missing, skip
        elseif not u or type(u) ~= "table" then
            -- nothing for this slot; hide line to be safe
            pcall(function()
                line:Hide()
                line.itemLink = nil
                line.itemName = nil
                line.coord = nil
            end)
        else
            -- ensure item is normalized
            local item = u.item
            if type(item) ~= "table" then item = normalizeCandidate(item); u.item = item end
            local name, link = nil, nil
            if item and item.id then
                local ok, n, l = pcall(function() return GetItemInfo(item.id) end)
                if ok then name, link = n, l end
            end
            local text = link or (item and item.itemName) or (item and item.id and ("item:"..tostring(item.id))) or tostring(item)
            -- safely set UI text and fields
            local ok, err = pcall(function()
                if line.text and type(line.text.SetText) == "function" then
                    line.text:SetText(("[%s] %s"):format(tostring(u.slot), text))
                end
                line.itemLink = link
                line.itemName = name
                line.coord = (item and item.coord) or nil
                line:Show()
            end)
            if not ok then
                pcall(function() DEFAULT_CHAT_FRAME:AddMessage("UA> UI line set failed for upgrade #"..tostring(i)..": "..tostring(err)) end)
                pcall(function() line:Hide() end)
            else
                -- print chat line safely
                pcall(function() DEFAULT_CHAT_FRAME:AddMessage((" - %s: %s"):format(tostring(u.slot), text)) end)
                if type(item) == "table" and type(item.coord) == "table" and item.coord.zone then
                    local cx = tonumber(item.coord.x) or 0
                    local cy = tonumber(item.coord.y) or 0
                    pcall(function() DEFAULT_CHAT_FRAME:AddMessage(("   Location: %s (%.2f, %.2f)"):format(item.coord.zone, cx*100, cy*100)) end)
                end
            end
        end
    end
    UpgradeAdvisor.frame:Show()
    return upgrades
end

-- expose slash command
SLASH_UPGRADEADVISOR1 = "/upgradeadvisor"
SLASH_UPGRADEADVISOR2 = "/ua"
SlashCmdList["UPGRADEADVISOR"] = function()
    -- run scan inside pcall so we can capture and report runtime errors instead of crashing
    local ok, err = pcall(function() UpgradeAdvisor:ScanUpgrades() end)
    if not ok then
        DEFAULT_CHAT_FRAME:AddMessage("UA> Scan failed: "..tostring(err))
        -- suggest running debug to collect shapes
        DEFAULT_CHAT_FRAME:AddMessage("UA> Try /uadb to inspect pfQuest/AtlasLoot globals")
    end
end

-- Optional: small command to hide UI
SLASH_UPGRADEADVISORHIDE1 = "/uahide"
SlashCmdList["UPGRADEADVISORHIDE"] = function()
    UpgradeAdvisor.frame:Hide()
end

-- Example: automatically scan at PLAYER_ENTERING_WORLD (optional)
UpgradeAdvisor.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
UpgradeAdvisor.frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        -- do a gentle scan but don't spam
        -- UpgradeAdvisor:ScanUpgrades()
    end
end)

-- Debug slash command: prints detected globals and small AtlasLoot sample
SLASH_UPGRADEADVISORDBG1 = "/uadb"
SLASH_UPGRADEADVISORDBG2 = "/uadebug"
SlashCmdList["UPGRADEADVISORDBG"] = function()
    DEFAULT_CHAT_FRAME:AddMessage("|cffffff00UpgradeAdvisor Debug:|r scanning globals...")
    local function safeGet(name)
        local ok, v = pcall(function() return _G[name] end)
        if not ok then return nil end
        return v
    end
    local function tname(v)
        if v == nil then return "nil" end
        return type(v)
    end

    local pf = safeGet("pfQuest")
    local pfAlt = safeGet("pfQuestDB") or safeGet("pfQuest_data") or safeGet("pfQuest_data_db")
    DEFAULT_CHAT_FRAME:AddMessage("pfQuest -> "..tname(pf) .. ", pfQuestDB/alt -> "..tname(pfAlt))
    if type(pf) == "table" and type(pf.db) == "table" then
        DEFAULT_CHAT_FRAME:AddMessage(" pfQuest.db.items -> "..tname(pf.db.items) .. ", pfQuest.db.vendors -> "..tname(pf.db.vendors))
    end

    local al = safeGet("AtlasLoot")
    local alData = safeGet("AtlasLoot_Data")
    DEFAULT_CHAT_FRAME:AddMessage("AtlasLoot -> "..tname(al) .. ", AtlasLoot_Data -> "..tname(alData))
    if type(alData) == "table" then
        local c = 0
        for k,v in pairs(alData) do
            c = c + 1
            if c <= 6 then
                DEFAULT_CHAT_FRAME:AddMessage(" AL key: "..tostring(k).." -> "..tname(v))
            end
        end
        DEFAULT_CHAT_FRAME:AddMessage("AtlasLoot_Data entries: "..c)
    end

    -- search for pfQuest-like globals
    local found = false
    for k,v in pairs(_G) do
        if type(k) == "string" then
            local lk = string.lower(k)
            if string.find(lk, "pfquest") or string.find(lk, "pf_quest") or string.find(lk, "pfq") or (string.find(lk, "pf") and string.find(lk, "quest")) then
                DEFAULT_CHAT_FRAME:AddMessage("Global match: "..k.." -> "..tname(v))
                found = true
            end
        end
    end
    if not found then DEFAULT_CHAT_FRAME:AddMessage("No pfQuest-like globals found in _G.") end
    DEFAULT_CHAT_FRAME:AddMessage("Type /uadb to run this debug check again.")
end

-- Short, user-friendly slash commands to run checks without long /run lines
local function uaPrint(msg)
    DEFAULT_CHAT_FRAME:AddMessage("UA> "..tostring(msg))
end

SLASH_UAHELP1 = "/uahelp"
SlashCmdList["UAHELP"] = function()
    uaPrint("Commands:")
    uaPrint("/ua - scan")
    uaPrint("/uahide")
    uaPrint("/uadb")
    uaPrint("/uainfo")
    uaPrint("/uapfq")
    uaPrint("/uaal")
end

SLASH_UAINFO1 = "/uainfo"
SlashCmdList["UAINFO"] = function()
    uaPrint("Addon loaded: "..tostring(IsAddOnLoaded("UpgradeAdvisor")))
    local ok, build = pcall(function() return select(4, GetBuildInfo()) end)
    uaPrint("Client TOC (select(4, GetBuildInfo())) -> "..tostring(build))
    uaPrint("Player level: "..tostring(UnitLevel("player")).."  Class: "..tostring(select(2,UnitClass("player"))))
    local pfItems, pfVendors = getPfQuestData()
    uaPrint("pfQuest items: "..tostring((type(pfItems)=="table" and (tcount(pfItems) or "table") ) or tostring(type(pfItems))))
    uaPrint("pfQuest vendors: "..tostring((type(pfVendors)=="table" and (tcount(pfVendors) or "table") ) or tostring(type(pfVendors))))
    local al = getAtlasLootData()
    if type(al) == "table" then
        local count = 0 for _ in pairs(al) do count = count + 1 end
        uaPrint("AtlasLoot modules: "..tostring(count))
    else
        uaPrint("AtlasLoot: "..tostring(type(al)))
    end
end

SLASH_UAPFQ1 = "/uapfq"
SlashCmdList["UAPFQ"] = function()
    local pfItems, pfVendors = getPfQuestData()
    if type(pfItems) ~= "table" and type(pfVendors) ~= "table" then
        uaPrint("pfQuest data not found (under expected names). Try /uadb for debug scan.")
        return
    end
    if type(pfItems) == "table" then
        local c = 0 for k,v in pairs(pfItems) do c = c + 1; if c<=5 then uaPrint(" item sample key: "..tostring(k)) end end
        uaPrint("pfQuest items count (approx): "..tostring(c))
    else uaPrint("pfQuest items: "..tostring(type(pfItems))) end
    if type(pfVendors) == "table" then
        local c = 0
        for k,v in pairs(pfVendors) do
            c = c + 1
            if c <= 5 then
                local s = "vendor: "..tostring(k)
                if type(v) == "table" and (v.x or v.coords or v.zone) then
                    s = s .. " (has coords)"
                end
                uaPrint(s)
            end
        end
        uaPrint("pfQuest vendors count (approx): "..tostring(c))
    else uaPrint("pfQuest vendors: "..tostring(type(pfVendors))) end
end

SLASH_UAAL1 = "/uaal"
SlashCmdList["UAAL"] = function()
    local al = getAtlasLootData()
    if type(al) ~= "table" then
        uaPrint("AtlasLoot data not found. Try /uadb for debug scan.")
        return
    end
    local c = 0
    for k,v in pairs(al) do
        c = c + 1
        if c <= 12 then
        uaPrint("AL key: "..tostring(k).." -> "..tostring(type(v)))
        end
    end
    uaPrint("(printed up to 12 AtlasLoot keys; total: "..tostring(c)..")")
    -- show a tiny sample from the first key
    local first = next(al)
    if first then
    uaPrint("Sample key: "..tostring(first))
        local groups = al[first]
        if type(groups) == "table" then
            local gi = 0
            for gidx, group in pairs(groups) do
                gi = gi + 1
                if gi > 2 then break end
                uaPrint(" group "..tostring(gidx).." type="..tostring(type(group)))
                if type(group) == "table" then
                    local ei = 0
                    for _, e in pairs(group) do
                        ei = ei + 1
                        if ei > 3 then break end
                        if type(e) == "table" and e[1] then
                        uaPrint("  entry "..tostring(ei).." -> "..tostring(e[1]))
                        else
                            uaPrint("  entry "..tostring(ei).." -> "..tostring(e))
                        end
                    end
                end
            end
        end
    end
end