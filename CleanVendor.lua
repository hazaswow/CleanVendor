-- CleanVendor
-- Search + filters for merchant windows, with a red-gray tint on
-- unequippable items. Standalone. Compatible with 3.3.5 (Ascension / CoA).

CleanVendorDB = CleanVendorDB or {}

-------------------------------------------------
-- Localization
-------------------------------------------------
local LOCALES = {
    enUS = {
        SEARCH_HINT   = "Search (name or tooltip)...",
        FILTER_ALL    = "Everything",
        FILTER_ALLWEAPONS = "All weapons",
        FILTER_ONEHAND = "One-handed",
        FILTER_TWOHAND = "Two-handed",
        FILTER_RANGED  = "Ranged",
        BUY_HINT      = "Right-click: buy 1  |  Alt+right-click: choose amount",
        BUY_PROMPT    = "Buy how many?",
        NO_RESULTS    = "No matching items",
        OPT_HEADER    = "Options",
        OPT_RED       = "Red tint on unusable gear",
        OPT_RED_NATIVE = "Also tint the merchant grid",
        MSG_RED_ON    = "red tint on unusable items: enabled.",
        MSG_RED_OFF   = "red tint on unusable items: disabled.",
        HELP_HEADER   = "available commands:",
        HELP_RED      = "  /cvd red - toggle the red tint on unusable items",
    },
    frFR = {
        SEARCH_HINT   = "Recherche (nom ou tooltip)...",
        FILTER_ALL    = "Tout",
        FILTER_ALLWEAPONS = "Toutes les armes",
        FILTER_ONEHAND = "Une main",
        FILTER_TWOHAND = "Deux mains",
        FILTER_RANGED  = "A distance",
        BUY_HINT      = "Clic droit : acheter 1  |  Alt+clic droit : choisir la quantite",
        BUY_PROMPT    = "Acheter combien ?",
        NO_RESULTS    = "Aucun objet correspondant",
        OPT_HEADER    = "Options",
        OPT_RED       = "Teinte rouge sur le stuff inutilisable",
        OPT_RED_NATIVE = "Teinter aussi la grille du marchand",
        MSG_RED_ON    = "teinte rouge sur les objets inutilisables : activee.",
        MSG_RED_OFF   = "teinte rouge sur les objets inutilisables : desactivee.",
        HELP_HEADER   = "commandes disponibles:",
        HELP_RED      = "  /cvd red - active/desactive la teinte rouge des objets inutilisables",
    },
}

local L = setmetatable(LOCALES[GetLocale()] or {}, { __index = LOCALES.enUS })
local MSG = "|cff33ff99CleanVendor|r: "

-------------------------------------------------
-- Backdrop compatibility (same approach as CleanLoot)
-------------------------------------------------
local TEST_BACKDROP = { bgFile = "Interface\\ChatFrame\\ChatFrameBackground" }

local function InstallBackdropShim(frame)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    local edges = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local tex = frame:CreateTexture(nil, "BORDER")
        if side == "TOP" then
            tex:SetPoint("TOPLEFT") tex:SetPoint("TOPRIGHT") tex:SetHeight(1)
        elseif side == "BOTTOM" then
            tex:SetPoint("BOTTOMLEFT") tex:SetPoint("BOTTOMRIGHT") tex:SetHeight(1)
        elseif side == "LEFT" then
            tex:SetPoint("TOPLEFT") tex:SetPoint("BOTTOMLEFT") tex:SetWidth(1)
        else
            tex:SetPoint("TOPRIGHT") tex:SetPoint("BOTTOMRIGHT") tex:SetWidth(1)
        end
        table.insert(edges, tex)
    end
    frame.__shimBg, frame.__shimEdges = bg, edges
    frame.SetBackdrop = function(self, def)
        if def then self.__shimBg:Show() for _, e in ipairs(self.__shimEdges) do e:Show() end
        else self.__shimBg:Hide() for _, e in ipairs(self.__shimEdges) do e:Hide() end end
    end
    frame.SetBackdropColor = function(self, r, g, b, a) self.__shimBg:SetTexture(r or 0, g or 0, b or 0, a or 1) end
    frame.SetBackdropBorderColor = function(self, r, g, b, a)
        for _, e in ipairs(self.__shimEdges) do e:SetTexture(r or 0, g or 0, b or 0, a or 1) end
    end
end

local function EnsureBackdropSupport(frame)
    if not frame or frame.__backdropReady then return end
    frame.__backdropReady = true
    if frame.SetBackdrop then
        local ok = pcall(frame.SetBackdrop, frame, TEST_BACKDROP)
        if ok and frame.GetBackdrop and frame:GetBackdrop() then
            pcall(frame.SetBackdrop, frame, nil)
            return
        end
    end
    InstallBackdropShim(frame)
end

-------------------------------------------------
-- Item classification
-------------------------------------------------
-- Localized item class/subclass names through the auction house API:
-- already translated by the client, and directly comparable to the
-- itemType/itemSubType returned by GetItemInfo. Free localization.
local CLASS_NAMES = { GetAuctionItemClasses() }
local WEAPON_CLASS = CLASS_NAMES[1]
local ARMOR_CLASS = CLASS_NAMES[2]
local WEAPON_SUBCLASSES = { GetAuctionItemSubClasses(1) }
local ARMOR_SUBCLASSES = { GetAuctionItemSubClasses(2) }

local ONE_HAND_SLOTS = {
    INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true,
}
local TWO_HAND_SLOTS = { INVTYPE_2HWEAPON = true }
local RANGED_SLOTS = {
    INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true,
}

-- Current filter: { kind = "all" } | { kind = "class", class = X }
-- | { kind = "subclass", class = X, sub = Y } | { kind = "hands", which = W }
local currentFilter = { kind = "all" }
local searchText = ""

-------------------------------------------------
-- Tooltip scanning (for searching in the description)
-------------------------------------------------
local scanTT = CreateFrame("GameTooltip", "CleanVendorScanTT", nil, "GameTooltipTemplate")
local tooltipCache = {}

local function GetMerchantItemScan(index)
    local link = GetMerchantItemLink(index)
    local key = link or ("idx"..index)
    if tooltipCache[key] then return tooltipCache[key] end

    local result = { text = "", unusable = false }
    scanTT:SetOwner(UIParent, "ANCHOR_NONE")
    local ok = pcall(scanTT.SetMerchantItem, scanTT, index)
    if not ok then
        tooltipCache[key] = result
        return result
    end

    local parts = {}
    for i = 1, scanTT:NumLines() do
        for _, side in ipairs({ "Left", "Right" }) do
            local fs = _G["CleanVendorScanTTText"..side..i]
            local text = fs and fs:GetText()
            if text then
                table.insert(parts, text)
                -- Red line = unmet requirement (missing weapon or armor
                -- proficiency, required level, already-known recipe...).
                -- This is the same visual signal the game itself uses, and it
                -- works even when the server's isUsable flag reports nothing
                -- (the case on classless servers like CoA).
                local r, g, b = fs:GetTextColor()
                if r and r >= 0.98 and g <= 0.15 and b <= 0.15 then
                    result.unusable = true
                end
            end
        end
    end
    scanTT:Hide()

    result.text = table.concat(parts, "\n"):lower()
    tooltipCache[key] = result
    return result
end

-- The tint only applies to COMBAT-equippable gear: an equip slot must
-- exist, excluding shirt and tabard (cosmetics). Chests, consumables,
-- recipes, cosmetic items, etc. are never tinted, even if their tooltip
-- contains red lines for other reasons (custom server
-- mechanics).
local COMBAT_EQUIP_EXCLUDE = { INVTYPE_TABARD = true, INVTYPE_BODY = true }

local function IsCombatEquipment(index)
    local link = GetMerchantItemLink(index)
    if not link then return false end
    local _, _, _, _, _, _, _, _, equipSlot = GetItemInfo(link)
    if not equipSlot or equipSlot == "" then return false end
    return not COMBAT_EQUIP_EXCLUDE[equipSlot]
end

-- Tint criterion: the native isUsable flag when it reports something,
-- otherwise the tooltip red-line detection.
local function IsMerchantItemUnusable(index)
    if not IsCombatEquipment(index) then return false end
    local _, _, _, _, _, isUsable = GetMerchantItemInfo(index)
    if isUsable == false then return true end
    return GetMerchantItemScan(index).unusable
end

-------------------------------------------------
-- Filtering
-------------------------------------------------
local function ItemMatchesFilter(index)
    local name = GetMerchantItemInfo(index)
    if not name then return false end

    -- Category filter
    if currentFilter.kind ~= "all" then
        local link = GetMerchantItemLink(index)
        local itemType, itemSubType, equipSlot
        if link then
            local _, _, _, _, _, iType, iSubType, _, iEquipSlot = GetItemInfo(link)
            itemType, itemSubType, equipSlot = iType, iSubType, iEquipSlot
        end

        if currentFilter.kind == "class" then
            if itemType ~= currentFilter.class then return false end
        elseif currentFilter.kind == "subclass" then
            if itemType ~= currentFilter.class or itemSubType ~= currentFilter.sub then return false end
        elseif currentFilter.kind == "hands" then
            if not equipSlot then return false end
            if currentFilter.which == "one" and not ONE_HAND_SLOTS[equipSlot] then return false end
            if currentFilter.which == "two" and not TWO_HAND_SLOTS[equipSlot] then return false end
            if currentFilter.which == "ranged" and not RANGED_SLOTS[equipSlot] then return false end
        end
    end

    -- Text search: name OR tooltip content
    if searchText ~= "" then
        local q = searchText:lower()
        if not name:lower():find(q, 1, true) then
            local tip = GetMerchantItemScan(index).text
            if not tip:find(q, 1, true) then return false end
        end
    end

    return true
end

local filteredIndices = {}

local function RebuildFilteredList()
    wipe(filteredIndices)
    local total = GetMerchantNumItems() or 0
    for i = 1, total do
        if ItemMatchesFilter(i) then
            table.insert(filteredIndices, i)
        end
    end
end

-------------------------------------------------
-- Buy by amount
-------------------------------------------------
-- BuyMerchantItem is capped at ONE stack per call: to go beyond the stack
-- max, we automatically chain several purchases in stack-sized batches.
-- Items sold in lots (e.g. 5 per purchase) are bought lot by lot.
-- Safety cap of 1000 units per order.
local MAX_BUY = 1000

local function BuyAmount(index, total)
    total = math.floor(tonumber(total) or 0)
    if total <= 0 then return end
    if total > MAX_BUY then total = MAX_BUY end

    local link = GetMerchantItemLink(index)
    local _, _, _, batch = GetMerchantItemInfo(index)
    batch = batch or 1
    local stackSize = (link and select(8, GetItemInfo(link))) or 1
    if stackSize < 1 then stackSize = 1 end

    if batch > 1 then
        local lots = math.ceil(total / batch)
        for _ = 1, lots do
            BuyMerchantItem(index)
        end
    else
        local remaining = total
        while remaining > 0 do
            local step = math.min(remaining, stackSize)
            BuyMerchantItem(index, step)
            remaining = remaining - step
        end
    end
end

-- Homemade amount prompt: on this client the native Shift+click appears to
-- trigger its own "buy a stack" behavior through the active merchant
-- tooltip, bypassing any StaticPopup we could show. So the amount prompt
-- (1) lives on Alt+right-click instead, and (2) uses our own small input
-- frame rather than the native StaticPopup system.
local amountFrame

local function CreateAmountFrame()
    if amountFrame then return amountFrame end

    local f = CreateFrame("Frame", "CleanVendorAmountFrame", UIParent)
    f:SetSize(220, 90)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    EnsureBackdropSupport(f)
    f:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(0.06, 0.06, 0.06, 0.98)
    f:SetBackdropBorderColor(0, 0, 0, 1)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOP", 0, -8)
    title:SetPoint("LEFT", 8, 0)
    title:SetPoint("RIGHT", -8, 0)
    title:SetJustifyH("CENTER")
    f.__title = title

    local eb = CreateFrame("EditBox", "CleanVendorAmountEditBox", f)
    eb:SetSize(80, 18)
    eb:SetPoint("TOP", 0, -34)
    eb:SetAutoFocus(true)
    eb:SetNumeric(true)
    eb:SetMaxLetters(4)
    eb:SetFontObject(ChatFontNormal)
    eb:SetJustifyH("CENTER")
    EnsureBackdropSupport(eb)
    eb:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, edgeSize = 1,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    eb:SetBackdropColor(0.02, 0.02, 0.02, 1)
    eb:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    eb:SetTextInsets(4, 4, 0, 0)
    f.__editBox = eb

    local function DoAccept()
        if f.__index then
            BuyAmount(f.__index, eb:GetNumber())
        end
        f:Hide()
    end

    eb:SetScript("OnEnterPressed", DoAccept)
    eb:SetScript("OnEscapePressed", function() f:Hide() end)

    local okBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    okBtn:SetSize(80, 20)
    okBtn:SetPoint("BOTTOMLEFT", 12, 10)
    okBtn:SetText(ACCEPT or "Accept")
    okBtn:SetScript("OnClick", DoAccept)

    local cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancelBtn:SetSize(80, 20)
    cancelBtn:SetPoint("BOTTOMRIGHT", -12, 10)
    cancelBtn:SetText(CANCEL or "Cancel")
    cancelBtn:SetScript("OnClick", function() f:Hide() end)

    f:Hide()
    amountFrame = f
    return f
end

local function PromptBuyAmount(index)
    local name = GetMerchantItemInfo(index)
    local f = CreateAmountFrame()
    f.__index = index
    f.__title:SetText(L.BUY_PROMPT.."\n"..(name or ""))
    f.__editBox:SetText("")
    f:Show()
    f.__editBox:SetFocus()
end

-------------------------------------------------
-- Side panel
-------------------------------------------------
local NUM_LINES = 13
local LINE_HEIGHT = 20

local panel
local RefreshList
local ScheduleNativeTint

local function CreateLine(parent, i)
    local line = CreateFrame("Button", nil, parent)
    line:SetHeight(LINE_HEIGHT)
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -58 - (i - 1) * LINE_HEIGHT)
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -30, -58 - (i - 1) * LINE_HEIGHT)
    line:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local icon = line:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", 0, 0)
    line.__icon = icon

    -- Red tint via overlay: on some clients, shader desaturation
    -- neutralizes SetVertexColor on the same texture (icon gray but
    -- never reddened). A semi-transparent red layer placed ON TOP does
    -- not depend on the texture's rendering and works everywhere.
    local redOverlay = line:CreateTexture(nil, "OVERLAY")
    redOverlay:SetAllPoints(icon)
    redOverlay:SetTexture(0.45, 0.06, 0.06, 0.6)
    redOverlay:Hide()
    line.__redOverlay = redOverlay

    local name = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    name:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    name:SetPoint("RIGHT", line, "RIGHT", -2, 0)
    name:SetJustifyH("LEFT")
    name:SetHeight(LINE_HEIGHT)
    line.__name = name

    local hl = line:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(line)
    hl:SetTexture(0.3, 0.5, 0.8, 0.2)

    line:SetScript("OnEnter", function(self)
        if self.__index then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local ok = pcall(GameTooltip.SetMerchantItem, GameTooltip, self.__index)
            if ok then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(L.BUY_HINT, 0.5, 0.8, 0.5)
                GameTooltip:Show()
            else
                GameTooltip:Hide()
            end
        end
    end)
    line:SetScript("OnLeave", function() GameTooltip:Hide() end)

    line:SetScript("OnClick", function(self, button)
        if not self.__index then return end
        if button == "RightButton" then
            if IsAltKeyDown() then
                PromptBuyAmount(self.__index)
            elseif IsShiftKeyDown() then
                -- Deliberately do nothing: on this client, Shift+click seems
                -- to trigger a native "buy a stack" shortcut through the
                -- active merchant tooltip. Adding our own action on top
                -- would stack purchases unpredictably.
                return
            else
                BuyMerchantItem(self.__index)
            end
        elseif button == "LeftButton" and IsShiftKeyDown() then
            local link = GetMerchantItemLink(self.__index)
            if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
        end
    end)

    return line
end

local function CreatePanel()
    if panel then return panel end

    local f = CreateFrame("Frame", "CleanVendorPanel", MerchantFrame)
    f:SetSize(230, 58 + NUM_LINES * LINE_HEIGHT + 66)
    f:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", -30, -12)
    -- LOW strata: stays above the world but below standard interface
    -- windows (item appearance preview, etc.), so the panel never covers
    -- them. User-confirmed: the small overlap with the merchant window is
    -- not an issue on CoA's merchant UI. Tooltips and dropdown lists render
    -- on higher strata regardless.
    f:SetFrameStrata("LOW")
    EnsureBackdropSupport(f)
    f:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
    f:SetBackdropBorderColor(0, 0, 0, 1)

    -- Search bar
    local search = CreateFrame("EditBox", "CleanVendorSearchBox", f)
    search:SetHeight(18)
    search:SetPoint("TOPLEFT", 10, -8)
    search:SetPoint("TOPRIGHT", -10, -8)
    search:SetAutoFocus(false)
    search:SetFontObject(ChatFontNormal)
    EnsureBackdropSupport(search)
    search:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, edgeSize = 1,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    search:SetBackdropColor(0.02, 0.02, 0.02, 1)
    search:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    search:SetTextInsets(4, 4, 0, 0)

    local hint = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", 5, 0)
    hint:SetText(L.SEARCH_HINT)
    search.__hint = hint

    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    search:SetScript("OnTextChanged", function(self)
        searchText = self:GetText() or ""
        if searchText == "" then self.__hint:Show() else self.__hint:Hide() end
        RefreshList(true)
    end)

    -- Filter dropdown
    local dd = CreateFrame("Frame", "CleanVendorFilterDropdown", f, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", -6, -28)
    UIDropDownMenu_SetWidth(dd, 190)
    f.__dd = dd

    local function SetFilter(filter, label)
        currentFilter = filter
        UIDropDownMenu_SetText(dd, label)
        CloseDropDownMenus()
        RefreshList(true)
    end

    UIDropDownMenu_Initialize(dd, function(self, level)
        level = level or 1
        local info

        if level == 1 then
            info = UIDropDownMenu_CreateInfo()
            info.text = L.FILTER_ALL
            info.checked = (currentFilter.kind == "all")
            info.func = function() SetFilter({ kind = "all" }, L.FILTER_ALL) end
            UIDropDownMenu_AddButton(info, level)

            if WEAPON_CLASS then
                info = UIDropDownMenu_CreateInfo()
                info.text = WEAPON_CLASS
                info.hasArrow = true
                info.notCheckable = true
                info.value = "WEAPONS"
                UIDropDownMenu_AddButton(info, level)
            end

            if ARMOR_CLASS then
                info = UIDropDownMenu_CreateInfo()
                info.text = ARMOR_CLASS
                info.hasArrow = true
                info.notCheckable = true
                info.value = "ARMOR"
                UIDropDownMenu_AddButton(info, level)
            end

            -- Other main classes, as direct filters
            for i = 3, #CLASS_NAMES do
                local className = CLASS_NAMES[i]
                info = UIDropDownMenu_CreateInfo()
                info.text = className
                info.checked = (currentFilter.kind == "class" and currentFilter.class == className)
                info.func = function() SetFilter({ kind = "class", class = className }, className) end
                UIDropDownMenu_AddButton(info, level)
            end

        elseif level == 2 then
            if UIDROPDOWNMENU_MENU_VALUE == "WEAPONS" then
                info = UIDropDownMenu_CreateInfo()
                info.text = L.FILTER_ALLWEAPONS
                info.checked = (currentFilter.kind == "class" and currentFilter.class == WEAPON_CLASS)
                info.func = function() SetFilter({ kind = "class", class = WEAPON_CLASS }, L.FILTER_ALLWEAPONS) end
                UIDropDownMenu_AddButton(info, level)

                local handFilters = {
                    { which = "one",    label = L.FILTER_ONEHAND },
                    { which = "two",    label = L.FILTER_TWOHAND },
                    { which = "ranged", label = L.FILTER_RANGED },
                }
                for _, def in ipairs(handFilters) do
                    info = UIDropDownMenu_CreateInfo()
                    info.text = def.label
                    info.checked = (currentFilter.kind == "hands" and currentFilter.which == def.which)
                    info.func = function() SetFilter({ kind = "hands", which = def.which }, def.label) end
                    UIDropDownMenu_AddButton(info, level)
                end

                for _, sub in ipairs(WEAPON_SUBCLASSES) do
                    info = UIDropDownMenu_CreateInfo()
                    info.text = sub
                    info.checked = (currentFilter.kind == "subclass" and currentFilter.sub == sub)
                    info.func = function() SetFilter({ kind = "subclass", class = WEAPON_CLASS, sub = sub }, sub) end
                    UIDropDownMenu_AddButton(info, level)
                end

            elseif UIDROPDOWNMENU_MENU_VALUE == "ARMOR" then
                info = UIDropDownMenu_CreateInfo()
                info.text = ARMOR_CLASS
                info.checked = (currentFilter.kind == "class" and currentFilter.class == ARMOR_CLASS)
                info.func = function() SetFilter({ kind = "class", class = ARMOR_CLASS }, ARMOR_CLASS) end
                UIDropDownMenu_AddButton(info, level)

                for _, sub in ipairs(ARMOR_SUBCLASSES) do
                    info = UIDropDownMenu_CreateInfo()
                    info.text = sub
                    info.checked = (currentFilter.kind == "subclass" and currentFilter.sub == sub)
                    info.func = function() SetFilter({ kind = "subclass", class = ARMOR_CLASS, sub = sub }, sub) end
                    UIDropDownMenu_AddButton(info, level)
                end
            end
        end
    end)
    UIDropDownMenu_SetText(dd, L.FILTER_ALL)

    -- Scrollable list
    local scroll = CreateFrame("ScrollFrame", "CleanVendorScroll", f, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -58)
    scroll:SetPoint("BOTTOMRIGHT", -28, 64)
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, LINE_HEIGHT, function() RefreshList(false) end)
    end)
    f.__scroll = scroll

    f.__lines = {}
    for i = 1, NUM_LINES do
        table.insert(f.__lines, CreateLine(f, i))
    end

    local empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    empty:SetPoint("TOP", 0, -80)
    empty:SetText(L.NO_RESULTS)
    empty:Hide()
    f.__empty = empty

    -- Options area at the bottom (fills the height gap between the panel
    -- and the taller native merchant window).
    local optTop = 58 + NUM_LINES * LINE_HEIGHT + 4

    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", 8, -optTop)
    sep:SetPoint("TOPRIGHT", -8, -optTop)
    sep:SetHeight(1)
    sep:SetTexture(0.25, 0.25, 0.25, 1)

    local function MakeOption(name, label, offsetY, getter, onToggle)
        local cb = CreateFrame("CheckButton", name, f, "UICheckButtonTemplate")
        cb:SetSize(22, 22)
        cb:SetPoint("TOPLEFT", 6, -(optTop + offsetY))
        local text = _G[name.."Text"]
        if text then
            text:SetText(label)
            local fnt = text:GetFont()
            if fnt then text:SetFont(fnt, 10, "") end
        end
        cb.__getter = getter
        cb:SetScript("OnClick", function(self)
            onToggle(self:GetChecked() and true or false)
            RefreshList(false)
            ScheduleNativeTint()
        end)
        table.insert(f.__optionButtons, cb)
        return cb
    end

    f.__optionButtons = {}
    MakeOption("CleanVendorOptRed", L.OPT_RED, 4,
        function() return CleanVendorDB.redTint end,
        function(v) CleanVendorDB.redTint = v end)
    MakeOption("CleanVendorOptRedNative", L.OPT_RED_NATIVE, 26,
        function() return CleanVendorDB.redTintNative end,
        function(v) CleanVendorDB.redTintNative = v end)

    f.__RefreshOptions = function()
        for _, cb in ipairs(f.__optionButtons) do
            cb:SetChecked(cb.__getter() and true or false)
        end
    end
    f.__RefreshOptions()

    panel = f
    return f
end

RefreshList = function(rebuild)
    if not panel then return end

    -- The panel only applies to the buy tab (not the buyback)
    if MerchantFrame.selectedTab and MerchantFrame.selectedTab ~= 1 then
        panel:Hide()
        return
    end
    panel:Show()

    if rebuild then
        RebuildFilteredList()
        FauxScrollFrame_SetOffset(panel.__scroll, 0)
    end

    local total = #filteredIndices
    FauxScrollFrame_Update(panel.__scroll, total, NUM_LINES, LINE_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(panel.__scroll)

    for i = 1, NUM_LINES do
        local line = panel.__lines[i]
        local index = filteredIndices[offset + i]
        if index then
            local name, texture, price, quantity, numAvailable, isUsable, extendedCost = GetMerchantItemInfo(index)
            line.__index = index
            line.__icon:SetTexture(texture)

            local link = GetMerchantItemLink(index)
            local quality = link and select(3, GetItemInfo(link))
            local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]

            local displayName = name or "?"
            if quantity and quantity > 1 then
                displayName = displayName .. " x" .. quantity
            end
            line.__name:SetText(displayName)

            if CleanVendorDB.redTint and IsMerchantItemUnusable(index) then
                line.__icon:SetDesaturated(true)
                line.__icon:SetVertexColor(0.9, 0.3, 0.3)
                line.__redOverlay:Show()
                line.__name:SetTextColor(0.85, 0.25, 0.25)
            else
                line.__icon:SetDesaturated(false)
                line.__icon:SetVertexColor(1, 1, 1)
                line.__redOverlay:Hide()
                if color then
                    line.__name:SetTextColor(color.r, color.g, color.b)
                else
                    line.__name:SetTextColor(1, 1, 1)
                end
            end

            line:Show()
        else
            line.__index = nil
            line:Hide()
        end
    end

    if total == 0 then
        panel.__empty:Show()
    else
        panel.__empty:Hide()
    end
end

-------------------------------------------------
-- Red tint on the NATIVE merchant grid
-------------------------------------------------
local PER_PAGE = MERCHANT_ITEMS_PER_PAGE or 10

-- Red overlays for native slots, created once per slot then reused.
local nativeOverlays = {}

local function GetNativeOverlay(i)
    if nativeOverlays[i] then return nativeOverlays[i] end
    local btn = _G["MerchantItem"..i.."ItemButton"]
    if not btn then return nil end
    local icon = _G["MerchantItem"..i.."ItemButtonIconTexture"]
    local ov = btn:CreateTexture(nil, "OVERLAY")
    if icon then ov:SetAllPoints(icon) else ov:SetAllPoints(btn) end
    ov:SetTexture(0.45, 0.06, 0.06, 0.6)
    ov:Hide()
    nativeOverlays[i] = ov
    return ov
end

local function TintNativeSlots()
    if MerchantFrame.selectedTab and MerchantFrame.selectedTab ~= 1 then return end

    local page = MerchantFrame.page or 1
    local total = GetMerchantNumItems() or 0
    for i = 1, PER_PAGE do
        local index = (page - 1) * PER_PAGE + i
        local icon = _G["MerchantItem"..i.."ItemButtonIconTexture"]
        local ov = GetNativeOverlay(i)
        if icon then
            if CleanVendorDB.redTint and CleanVendorDB.redTintNative and index <= total and IsMerchantItemUnusable(index) then
                icon:SetDesaturated(true)
                icon:SetVertexColor(0.9, 0.3, 0.3)
                if ov then ov:Show() end
            else
                icon:SetDesaturated(false)
                icon:SetVertexColor(1, 1, 1)
                if ov then ov:Hide() end
            end
        end
    end
end

-- Apply the tint on the NEXT frame: if a third-party skin (ElvUI-like)
-- recolors the merchant grid after us within the same hook pass, our
-- tint would be overwritten. Deferring by one frame puts us last
-- every time.
local tintDelayer = CreateFrame("Frame")
tintDelayer:Hide()
tintDelayer:SetScript("OnUpdate", function(self)
    self:Hide()
    pcall(TintNativeSlots)
end)

ScheduleNativeTint = function()
    tintDelayer:Show()
end

if type(MerchantFrame_UpdateMerchantInfo) == "function" and hooksecurefunc then
    hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function()
        ScheduleNativeTint()
        -- The native update also signals a potential page/stock change
        if panel and panel:IsShown() then
            RefreshList(false)
        end
    end)
end

-------------------------------------------------
-- Slash commands
-------------------------------------------------
SLASH_CLEANVENDOR1 = "/cleanvendor"
SLASH_CLEANVENDOR2 = "/cvd"
SlashCmdList["CLEANVENDOR"] = function(msg)
    msg = strtrim(msg or ""):lower()
    if msg == "red" then
        CleanVendorDB.redTint = not CleanVendorDB.redTint
        print(MSG .. (CleanVendorDB.redTint and L.MSG_RED_ON or L.MSG_RED_OFF))
        if panel and panel:IsShown() then RefreshList(false) end
        if panel and panel.__RefreshOptions then panel.__RefreshOptions() end
        ScheduleNativeTint()
    else
        print(MSG .. L.HELP_HEADER)
        print(L.HELP_RED)
    end
end

-------------------------------------------------
-- Init / merchant events
-------------------------------------------------
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:RegisterEvent("MERCHANT_SHOW")
watcher:RegisterEvent("MERCHANT_UPDATE")
watcher:RegisterEvent("MERCHANT_CLOSED")

watcher:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "CleanVendor" then
        if CleanVendorDB.redTint == nil then CleanVendorDB.redTint = true end
        if CleanVendorDB.redTintNative == nil then CleanVendorDB.redTintNative = true end
    elseif event == "MERCHANT_SHOW" then
        wipe(tooltipCache)
        searchText = ""
        currentFilter = { kind = "all" }
        local ok, err = pcall(CreatePanel)
        if not ok then
            print(MSG .. tostring(err))
            return
        end
        if panel.__dd then UIDropDownMenu_SetText(panel.__dd, L.FILTER_ALL) end
        if panel.__RefreshOptions then panel.__RefreshOptions() end
        local sb = _G["CleanVendorSearchBox"]
        if sb then sb:SetText("") end
        RefreshList(true)
    elseif event == "MERCHANT_UPDATE" then
        if panel and panel:IsShown() then
            RefreshList(true)
        end
    elseif event == "MERCHANT_CLOSED" then
        if panel then panel:Hide() end
        CloseDropDownMenus()
    end
end)
