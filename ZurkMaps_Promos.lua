-- Battleground- and feature-specific promotional messages and hidden CTRL+SHIFT+Click /4 sender.
ZurkMapsPromos = ZurkMapsPromos or {}

ZurkMapsPromos.header = {
    WSG = "Zurk Maps: fast WSG flag-carrier callouts, live teammate blips, and FC tracking. curseforge.com/wow/addons/zurk-maps",
    AB = "Zurk Maps: fast AB base-control callouts, live base states, timers, and teammate rotations. curseforge.com/wow/addons/zurk-maps",
    AV = "Zurk Maps: live Alterac Valley objectives, honor NPC tracking, teammate blips, and ranking progress. curseforge.com/wow/addons/zurk-maps",
}

ZurkMapsPromos.wsgMessages = {
    "That guy is way too geared to go unnoticed. Mark standout players as Raid Bosses or Elites on Zurk Maps—and fight alongside the Horde’s heavy hitters. curseforge.com/wow/addons/zurk-maps",
    "Where's the flag carrier? Zurk Maps turns WSG into a live command board with friendly and enemy FC tracking, carrier health, teammate blips, and one-click EFC location calls. curseforge.com/wow/addons/zurk-maps",
    "Stop typing flag calls in WSG. Zurk Maps lets you click EFC locations, watch FC health, see your team's movement, and fire PICK/CAP, Focus, Turtle, and EYES calls without losing the fight.",
    "See the flag fight at a glance. Zurk Maps shows your FC, the EFC, and teammate positions so you know when to escort, collapse, return, or cap. curseforge.com/wow/addons/zurk-maps",
}

ZurkMapsPromos.abMessages = {
    "That guy is way too geared to go unnoticed. Mark standout players as Raid Bosses or Elites on Zurk Maps—and fight alongside the Horde’s heavy hitters. curseforge.com/wow/addons/zurk-maps",
    "See who actually owns the map in Arathi Basin. Zurk Maps shows live base control, contested timers, teammate rotations, and one-click calls for every base. curseforge.com/wow/addons/zurk-maps",
    "Get off the roads and fight for the flags. Zurk Maps shows every AB base, contested timer, teammate rotation, and incoming call so you know where you should actually be fighting. curseforge.com/wow/addons/zurk-maps",
    "Turn Arathi Basin into a live control board with Zurk Maps: see which flags are safe, contested, or lost, watch friendly rotations, and make fast base-specific calls before the cap lands. curseforge.com/wow/addons/zurk-maps",
}

ZurkMapsPromos.avMessages = {
    "That guy is way too geared to go unnoticed. Mark standout players as Raid Bosses or Elites on Zurk Maps—and fight alongside the Horde’s heavy hitters. curseforge.com/wow/addons/zurk-maps",
    "Zurk Maps turns Alterac Valley into a live objective board: track honor-yielding NPCs, towers, bunkers, graveyards, mines, and your team's movement in one place. curseforge.com/wow/addons/zurk-maps",
    "See when AV honor NPCs are actually getting burned. Zurk Maps shows live shared health bars for honor-yielding NPCs, so you can track the kill even from across the map. curseforge.com/wow/addons/zurk-maps",
}

-- CTRL+SHIFT-clicking the Honor Bar uses its own promo pool regardless of battleground.
ZurkMapsPromos.honorMessages = {
    "Stop tabbing out to check your honor. Zurk Maps shows your weekly progress and exactly how much honor remains to your next PvP breakpoint. curseforge.com/wow/addons/zurk-maps",
    "Know when you're done for the week. Zurk Maps tracks your current honor and shows how much more you need for your next PvP breakpoint. curseforge.com/wow/addons/zurk-maps",
    "Ranking this week? Zurk Maps puts your honor progress right next to the battleground so you can see exactly how much more you need. curseforge.com/wow/addons/zurk-maps",
    "Grinding honor? Zurk Maps keeps your weekly progress visible and shows how much honor is left before your next breakpoint. curseforge.com/wow/addons/zurk-maps",
    "Know your number before you queue again. Zurk Maps shows your current weekly honor and how much remains to the next breakpoint. curseforge.com/wow/addons/zurk-maps",
    "Keep your honor grind visible between queues. Detach the Zurk Maps Honor Bar and leave it on-screen in town, at the bank, or wherever you are between BGs. curseforge.com/wow/addons/zurk-maps",
    "The Honor Bar doesn't have to stay attached to a battleground map. Detach it, resize it, and keep your next breakpoint visible while you queue or do anything else between games. curseforge.com/wow/addons/zurk-maps",
}

function ZurkMapsPromos.GetHeaderPromo(which)
    return ZurkMapsPromos.header[which] or ZurkMapsPromos.header.WSG
end

local function GetPromoPool(which)
    if which == "HONOR" then return ZurkMapsPromos.honorMessages end
    if which == "AB" then return ZurkMapsPromos.abMessages end
    if which == "AV" then return ZurkMapsPromos.avMessages end
    return ZurkMapsPromos.wsgMessages
end

function ZurkMapsPromos.SendRandomPromo(which)
    local list = GetPromoPool(which) or {}
    if #list == 0 then return end

    local index = math.random(1, #list)
    if #list > 1 and ZurkMapsPromos.lastMessage == list[index] then
        index = (index % #list) + 1
    end

    local message = list[index]
    ZurkMapsPromos.lastMessage = message
    SendChatMessage(message, "CHANNEL", nil, 4)
end
