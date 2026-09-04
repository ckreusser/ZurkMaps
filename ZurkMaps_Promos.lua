-- Battleground- and feature-specific promotional messages and hidden CTRL+SHIFT+Click /4 sender.
ZurkMapsPromos = ZurkMapsPromos or {}

ZurkMapsPromos.header = {
    WSG = "Zurk Maps: fast WSG flag-carrier callouts, live teammate blips, and FC tracking. curseforge.com/wow/addons/zurk-maps",
    AB = "Zurk Maps: fast AB base-control callouts, live base states, timers, and teammate rotations. curseforge.com/wow/addons/zurk-maps",
    AV = "Zurk Maps: live Alterac Valley objectives, honor NPC tracking, teammate blips, and ranking progress. curseforge.com/wow/addons/zurk-maps",
}

ZurkMapsPromos.wsgMessages = {
    "Know both flag carriers at a glance. Zurk Maps shows FC and EFC names, class colors, live health when visible, secure click-to-target frames, and Shift-click health reports. curseforge.com/wow/addons/zurk-maps",
    "Call the EFC without typing. Click detailed WSG regions for flag-room, roof, second-floor, tunnel, ramp, graveyard, hut, midfield, and route-specific reports. curseforge.com/wow/addons/zurk-maps",
    "Turn teammate callouts into map intel. Zurk Maps reads friendly /bg reports like 'EFC tun' or 'roof or gy' and animates every possible WSG area for 12 seconds. curseforge.com/wow/addons/zurk-maps",
    "Run the WSG fight from the map: Cap and Pick buttons, class-selectable Focus calls, five Turtle options, an Eyes-on-EFC request, and your editable Battlecry. curseforge.com/wow/addons/zurk-maps",
    "Know when the EFC is about to drop. When the visible EFC crosses 40%, 20%, or 10% health, Zurk Maps reports it; meaningful heals re-arm thresholds with anti-spam timing. curseforge.com/wow/addons/zurk-maps",
    "Make the team readable. WSG teammate blips switch between Gold and Class Colors, R12-R14 players get class-colored helmets, and any standout can be marked Elite or Raid Boss. curseforge.com/wow/addons/zurk-maps",
    "Keep the grind beside the flag fight. WSG's Honor Bar tracks weekly honor, exact breakpoint progress, and estimated games remaining from your recent WSG honor history. curseforge.com/wow/addons/zurk-maps",
    "Fit WSG to your UI: drag and resize the map, lock its position, tune opacity, choose /bg or /RW calls, and detach or reorient the shared Honor Bar. curseforge.com/wow/addons/zurk-maps",
}

ZurkMapsPromos.abMessages = {
    "See the five-base race live. Zurk Maps displays every AB flag as neutral, controlled, or contested, with faction-colored capture clocks and completion pulses. curseforge.com/wow/addons/zurk-maps",
    "Call more than bases. Click AB's bridges, graveyard water, intersections, and major roads for numbered incoming reports or a fast GET OUT warning. curseforge.com/wow/addons/zurk-maps",
    "Make the right base call instantly: mark a flag Safe or 1+ through 7+, Shift-click it as weak, right-click for help, or call SPIN while it is contested. curseforge.com/wow/addons/zurk-maps",
    "Never guess a cap timer. Zurk Maps counts down contested AB flags, lets you click the clock to report exact seconds remaining, and animates the faction that finishes the claim. curseforge.com/wow/addons/zurk-maps",
    "Read rotations before they arrive. Live friendly blips show who is holding, crossing water, or moving between ST, GM, LM, BS, and Farm on a purpose-built AB map. curseforge.com/wow/addons/zurk-maps",
    "Identify your AB team quickly with Gold or Class Colors, class-colored R12-R14 helmets, persistent rank detection, and right-click Elite or Raid Boss assignments. curseforge.com/wow/addons/zurk-maps",
    "Plan the honor session from AB. The shared bar shows weekly honor and breakpoint distance, then uses up to 50 recorded AB games to estimate your remaining queues. curseforge.com/wow/addons/zurk-maps",
    "Shape Zurk Maps around your AB setup: move, resize, lock, and fade the map; route calls through /bg or /RW; and save a custom faction-aware Battlecry. curseforge.com/wow/addons/zurk-maps",
}

ZurkMapsPromos.avMessages = {
    "See the whole AV war state on one map: every tower, bunker, graveyard, and mine, including neutral Snowfall and both faction bases, updates from live objective data. curseforge.com/wow/addons/zurk-maps",
    "Track every five-minute assault. Zurk Maps gives AV towers and graveyards fixed M:SS clocks; left-click reports time, while right-click calls reinforcements or marks the objective weak. curseforge.com/wow/addons/zurk-maps",
    "Hunt AV honor targets without guessing. Lieutenants, commanders, captains, and the enemy general have faction blips, status tooltips, secure targeting, and mapped patrol routes. curseforge.com/wow/addons/zurk-maps",
    "Watch distant honor NPC fights unfold. Shared health observations add health bars and combat pulses; confirmed deaths trigger a skull, honor-gain float, and synced status for other Zurk Maps users. curseforge.com/wow/addons/zurk-maps",
    "Lead the AV push with five saved message buttons plus an editable Battlecry. Quick messages support multiple /bg lines and raid-marker tags, and edited or blank slots stay yours. curseforge.com/wow/addons/zurk-maps",
    "Turn a 40-player AV raid into readable roles: live class-colored blips, special R12-R14 helmets, and persistent Elite or Raid Boss markers help priority players stand out. curseforge.com/wow/addons/zurk-maps",
    "Measure AV's payoff while you play. Zurk Maps records honor from up to 50 AV runs, shows the recent honor/game average, and estimates queues to your next PvP breakpoint. curseforge.com/wow/addons/zurk-maps",
    "Control the AV board your way: drag, resize, lock, and adjust opacity; choose /bg or /RW callouts; then detach the Honor Bar to keep progress visible after the map closes. curseforge.com/wow/addons/zurk-maps",
}

-- CTRL+SHIFT-clicking the Honor Bar uses its own promo pool regardless of battleground.
ZurkMapsPromos.honorMessages = {
    "Know the exact target. The Zurk Maps Honor Bar shows current weekly honor, the precise amount above or below each PvP breakpoint, and which milestone comes next. curseforge.com/wow/addons/zurk-maps",
    "See what each breakpoint earns. Hover a marker for required honor, current rank and progress, predicted rank and progress at that point, and whether you have already reached it. curseforge.com/wow/addons/zurk-maps",
    "Replace guesswork with your own history. Zurk Maps averages up to 50 completed games for WSG, AB, or AV and estimates how many more of that battleground you need. curseforge.com/wow/addons/zurk-maps",
    "Share the grind in one click. Shift-click any Honor Bar milestone to report the honor remaining, estimated games left, and the rank or breakpoint you are chasing. curseforge.com/wow/addons/zurk-maps",
    "Keep progress visible between queues. Detach the Honor Bar from the active map and leave it on-screen in town; it follows the most recently played battleground's history. curseforge.com/wow/addons/zurk-maps",
    "Build the bar around your UI. Unlock it to move and resize, switch between vertical and horizontal layouts, detach or reattach it, then lock the finished placement. curseforge.com/wow/addons/zurk-maps",
    "Read earned and unrealized honor instantly. Solid faction-colored metal marks completed progress, animated stripes mark the next segment, and new honor visibly fills the bar. curseforge.com/wow/addons/zurk-maps",
    "Cross a rank-up breakpoint and Zurk Maps celebrates after you leave the BG with your name, new title and badge, animated progress, faction rally text, and weekly-reset reminder. curseforge.com/wow/addons/zurk-maps",
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

local function GetPromoPoolKey(which)
    if which == "HONOR" or which == "AB" or which == "AV" then return which end
    return "WSG"
end

local function BuildShuffledPromoBag(poolKey, list)
    local order = {}
    for index = 1, #list do
        order[index] = index
    end

    for index = #order, 2, -1 do
        local swapIndex = math.random(1, index)
        order[index], order[swapIndex] = order[swapIndex], order[index]
    end

    -- Do not let the boundary between two complete rotations repeat the same
    -- message, while still showing every message exactly once per rotation.
    local previous = ZurkMapsPromos.lastMessageByPool and ZurkMapsPromos.lastMessageByPool[poolKey]
    if #order > 1 and previous == list[order[1]] then
        order[1], order[2] = order[2], order[1]
    end

    return { order = order, nextPosition = 1, size = #list }
end

function ZurkMapsPromos.SendRandomPromo(which)
    local poolKey = GetPromoPoolKey(which)
    local list = GetPromoPool(which) or {}
    if #list == 0 then return end

    ZurkMapsPromos.promoBags = ZurkMapsPromos.promoBags or {}
    ZurkMapsPromos.lastMessageByPool = ZurkMapsPromos.lastMessageByPool or {}

    local bag = ZurkMapsPromos.promoBags[poolKey]
    if not bag or bag.size ~= #list or bag.nextPosition > #bag.order then
        bag = BuildShuffledPromoBag(poolKey, list)
        ZurkMapsPromos.promoBags[poolKey] = bag
    end

    local index = bag.order[bag.nextPosition]
    bag.nextPosition = bag.nextPosition + 1
    local message = list[index]
    ZurkMapsPromos.lastMessageByPool[poolKey] = message
    SendChatMessage(message, "CHANNEL", nil, 4)
end
