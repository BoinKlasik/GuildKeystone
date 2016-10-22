local keystoneID = 138019;
local PREFIX = "GUILDKEYSTONE"
local SYNC_MESSAGE = "SYNCHRONIZE"
local GREEN = {r=.25, g=.25, b=.75}
local YELLOW = {r=1, g=0, b=.82}
local RED = {r=1, g=.1, b=.1}
local PlayerName
RegisterAddonMessagePrefix(PREFIX)
local KeystoneTooltip = CreateFrame("GameTooltip", "GuildKeystone-Tooltip", UIParent, "GameTooltipTemplate")
local hiddenTip
local currentTip = nil

local LOOT_SELF_REGEX = gsub(LOOT_ITEM_SELF, "%%s", "(.+)")
local LOOT_REGEX = gsub(LOOT_ITEM, "%%s", "(.+)")
local ITEM_SELF_REGEX = gsub(LOOT_ITEM_PUSHED_SELF, "%%s", "(.+)")
local ITEM_REGEX = gsub(LOOT_ITEM_PUSHED, "%%s", "(.+)")

local function Synchronize()
    SendAddonMessage(PREFIX, SYNC_MESSAGE, 'GUILD')
end

local function SendPlayerKeystoneMessage(level, instance, player)
    if player == nil then
        player = UnitName("player")
    end
    SendAddonMessage(PREFIX, 'KEYSTONE '..instance..'#'..level..'#'..player, 'GUILD')
end

local function SyncAll()
    local stones = GuildKeystone_Datastore.keystones
    for level, _ in pairs(stones) do
        for instance, _ in pairs(stones[level]) do
            for idx, player in pairs(stones[level][instance]) do
                SendPlayerKeystoneMessage(level, instance, player)
            end
        end
    end
end

local function CleanDatastore()
    local stones = GuildKeystone_Datastore.keystones
    for level, _ in pairs(stones) do
        local instances = stones[level]
        if next(instances) == nil then
            stones[level] = nil
        else
            for instance, _ in pairs(instances) do
                local playersArray = instances[instance]
                if next(playersArray) == nil then
                    instances[instance] = nil
                end
            end
        end
    end
end

-- Recusion is kind of silly here but it should be super rare (like development only) rare to find more than one person ever anyway.
local function RemovePlayerFromDatastore(player)
    local stones = GuildKeystone_Datastore.keystones
    for k, _ in pairs(stones) do
        for k2, _ in pairs(stones[k]) do
            for idx, v in pairs(stones[k][k2]) do
                if v == player then
                    table.remove(stones[k][k2], idx)
                    RemovePlayerFromDatastore(player)
                end
            end
        end
    end
    CleanDatastore()
end

local function create()
    local tip, left, right = CreateFrame("GameTooltip"), {}, {}
    for i = 1, 2 do
        local L,R = tip:CreateFontString(), tip:CreateFontString()
        L:SetFontObject(GameFontNormal)
        R:SetFontObject(GameFontNormal)
        tip:AddFontStrings(L,R)
        left[i] = L
        right[i] = R
    end
    tip.left = left
    tip.right = right
    return tip
end

local function getKeystoneValues(item)
    hiddenTip = hiddenTip or create()
    hiddenTip:SetOwner(UIParent, ANCHOR_NONE)
    hiddenTip:ClearLines()
    hiddenTip:SetHyperlink(item)
    local t = hiddenTip.left[2]:GetText()
    local one = hiddenTip.left[1]:GetText()
    local zone = string.match(one, 'Keystone: (.*)')
    local level = string.match(t, 'Level ([0-9]+)')
    hiddenTip:Hide()
    return zone, level
end

local function ResetDatastore()
    GuildKeystone_Datastore.keystones = {}
end

local function SetAnchorPoint(loc)
    GuildKeystone_Datastore.Options.AnchorPoint = loc
end

SLASH_GUILDKEYSTONE_TEST1 = '/gk';
local function CommandLine(msg, editbox)
    if msg == 'reset' then ResetDatastore(); return end
    if msg == 'right' then SetAnchorPoint("ANCHOR_RIGHT"); return end
    if msg == 'left' then SetAnchorPoint("ANCHOR_LEFT"); return end
    if msg == 'all' then SyncAll(); return end
    Synchronize()
end
SlashCmdList["GUILDKEYSTONE_TEST"] = CommandLine;


local function InitDatastore()
    GuildKeystone_Datastore = {
        LastUpdate = date(),
        LastReset = date(),
        Options = {
            AnchorPoint = "ANCHOR_LEFT"
        },
        keystones = {}
    }
end

local OnTooltip = function(tip)
    currentTip = tip
    KeystoneTooltip:Hide()
    if not tip then return end

    --be sure we have an actual item
    local _, link = tip:GetItem()
    if not link then return end
    printable = gsub(link, "\124", "\124\124")
    local itemid = string.match(link, 'item:([0-9]*):')
    itemid = tonumber(itemid) or 0
    if itemid ~= keystoneID then return end
    KeystoneTooltip:ClearLines()
    KeystoneTooltip:SetOwner(tip, ANCHOR_NONE)
    KeystoneTooltip:SetText("Guild Keystones:")
    local stones = GuildKeystone_Datastore.keystones
    local toSort = {}
    for n in pairs(stones) do table.insert(toSort, n) end
    table.sort(toSort, function(a,b)
        return a > b
    end)
    for other, level in ipairs(toSort) do
        local levelNum = tonumber(level)
        for zone, _ in pairs(stones[level]) do
            for idx, char in pairs(stones[level][zone]) do
                if levelNum < 4 then
                    color = GREEN
                elseif levelNum < 8 then
                    color = YELLOW
                else
                    color = RED
                end
                KeystoneTooltip:AddLine(level..' '..zone..' '..char, color.r, color.b, color.g)
            end
        end
    end

    KeystoneTooltip:Show()
    KeystoneTooltip:SetAnchorType(GuildKeystone_Datastore.Options.AnchorPoint, 0, -KeystoneTooltip:GetHeight())
end

local OnHide = function(tip)
    if currentTip ~= tip and currentTip and currentTip:IsShown() then
        return
    end
    currentTip = nil
    KeystoneTooltip:Hide()
end

local OnFade = function(tip)

end

local OnMove = function(tip)

end

local function SendKeystone()
    local zone,level
    for bag = 0,4 do
        for slot = 1,GetContainerNumSlots(bag) do
            local _, _, _, _, _, _, link, _, _, itemid = GetContainerItemInfo(bag, slot);
            if itemid == keystoneID then
                zone, level = getKeystoneValues(link);
                break
            end
        end
    end
    if zone and level then
        SendPlayerKeystoneMessage(level, zone, PlayerName)
    end
end


KeystoneTooltip:SetScript("OnEvent", function(self, event, ...)
        if event == 'CHAT_MSG_ADDON' then
            local prefix, message, channel, sender = ...
            if prefix == PREFIX then
                -- print(prefix..' '..message..' '..channel..' '..sender)
                if message == SYNC_MESSAGE then 
                    print("gk: syncrhonize")
                    SendKeystone()
                    return
                end
                keystone, instance, level, player = string.match(message, '(KEYSTONE) (.*)#(.*)#(.*)')
                local noServerName = string.match(sender, '(.+)-.+')
                if noServerName ~= nil then
                    player = noServerName
                end
                if keystone then
                    RemovePlayerFromDatastore(player)
                    local stones = GuildKeystone_Datastore.keystones
                    if stones[level] == nil then
                        stones[level] = {}
                    end
                    if stones[level][instance] == nil then
                        stones[level][instance] = {}
                    end
                    table.insert(stones[level][instance], player)
                    GuildKeystone_Datastore.LastUpdate = date()
                    print(level, instance, player)
                end
            end
        elseif event == 'ADDON_LOADED' then
            local addonName = ...
            KeystoneTooltip:UnregisterEvent("ADDON_LOADED")
            if GuildKeystone_Datastore.Options == nil then
                GuildKeystone_Datastore.Options = {
                    AnchorPoint = "ANCHOR_LEFT"
                }
            end

            for _, tooltip in pairs({ GameTooltip, ItemRefTooltip }) do
                tooltip:HookScript("OnTooltipSetItem", OnTooltip)
                hooksecurefunc(tooltip, "SetHyperlink", OnTooltip)
                tooltip:HookScript("OnHide", OnHide)
                hooksecurefunc(tooltip, "FadeOut", OnFade)
                tooltip:HookScript("OnDragStop", OnMove)
            end
            if addonName == 'GuildKeystone' then
                print("GuildKeystone loaded")
                if GuildKeystone_Datastore == nil then
                    InitDatastore()
                end
            end
        elseif event == 'PLAYER_LOGIN' then
            PlayerName, _ = UnitName("player")
            Synchronize()
        elseif event == 'CHAT_MSG_LOOT' then
            message, sender, language, channelString, target, flags, unknown, channelNumber, channelName, unknown, counter = ...
            local sPlayer, itemlink = string.match(message, LOOT_REGEX)
            if not sPlayer then sPlayer, itemlink = string.match(message, ITEM_REGEX) end 
            if not sPlayer then itemlink = string.match(message, LOOT_SELF_REGEX) end
            if not itemlink then itemlink = string.match(message, ITEM_SELF_REGEX) end
            if not itemlink then print("No item link") return end
            local itemId = string.match(itemlink, "item:(%d+):")
            itemId = tonumber(itemId) or 0
            if itemId == keystoneID then
                --do something
                print("PLAYER LOOTED A KEYSTONE!", sPlayer, itemlink)

                if not sPlayer then
                    SendKeystone()
                end
            end
        elseif event == "GET_ITEM_INFO_RECEIVED" then
            itemid = ...
            if itemid == keystoneID then
                SendKeystone()
                print("Got item info about a Keystone!")
            end
        end

    end)

KeystoneTooltip:RegisterEvent("CHAT_MSG_ADDON")
KeystoneTooltip:RegisterEvent("ADDON_LOADED")
KeystoneTooltip:RegisterEvent("CHAT_MSG_LOOT")
KeystoneTooltip:RegisterEvent("GET_ITEM_INFO_RECEIVED")
KeystoneTooltip:RegisterEvent("PLAYER_LOGIN")