-- Protect Sector - overview menu.
--
-- Standalone top-level menu, registered the way the Ships Trade Analyzer registers
-- its own and opened from the interaction menu of a ship on the order. Left: every
-- fleet on the order by home sector with one counter of choice over the whole
-- period, picked in the column header. Right: the
-- window's counters for the current row, its subordinates and, with coordination off,
-- the targets it tried (each a scrolling table of seven rows) and a graph over the whole history depth,
-- with the window controls under them. A tab row on top switches to Coordination:
-- the same tree with each fleet's state on the coordinator's board, and on the
-- right the board entries of the current row with the targets they involve.
--
-- The menu asks md/protect_sector_history.xml for a snapshot (requestHistory) and
-- reads it back from the player blackboard when HistoryReady arrives: the live
-- fleets with their current counters, plus the 15-min history buckets when the
-- history is on. Every sum over a window is computed here; with the history off the
-- window is everything since the counters started. Every `overviewRefresh` seconds
-- (Options, 0 = off) it asks again; a snapshot with the same game time (paused) is
-- dropped so the frame stays put.

---@diagnostic disable-next-line: unresolved-require
local ffi = require("ffi")
local C   = ffi.C

ffi.cdef [[
  typedef uint64_t UniverseID;
  UniverseID GetPlayerID(void);
  bool       IsComponentOperational(UniverseID componentid);
]]

local PAGE = 1972092401

-- Window widths in seconds; the dropdown lists them in this order.
local WIDTHS = { 900, 1800, 3600, 7200, 14400, 28800, 43200, 86400 }
local DEFAULT_WIDTH_INDEX = 3

-- Bucket counter keys as the sampler writes them.
local COUNTER_KEYS = { "a", "rp", "l", "t", "ks", "kb", "ko", "f", "h", "r", "b", "i", "e", "s", "sc", "se" }
local UNCATCHABLE_BREAKS = 3
local DEFAULT_REFRESH = 30 -- seconds, when the Options key is missing

local menu = {
  name            = "ProtectSectorReportMenu",
  lastRefreshTime = 0.0,
  lastRequestTime = 0.0,
  updateInterval  = 0.1,
}

local config = {
  infoLayer          = 4,
  leftShare          = 0.3,
  leftMinWidth       = 400,
  statColWidth       = 170,
  labelColShare      = 0.45,
  sectionRows        = 7, -- subordinates and targets: rows under the title
  sectionMinRows     = 3,
  graphMinHeight     = 160,
  graphMaxPoints     = 200, -- the widget's limit per data record
  mapSelectRetry     = 0.25, -- seconds between tries to select the ship on the map
  mapSelectTries     = 8,
  tabInputWidth      = 100, -- the tab-scroll input names either side of the tab icons
}

-- The tab row, modelled on Helper.createTopLevelTab.
local TABS = {
  { id = "stats", icon = "pi_statistics",  name = function() return ReadText(1001, 2500) end },
  { id = "board", icon = "mapst_fs_fight", name = function() return ReadText(PAGE, 1360) end },
}

-- Board states other than idle (ReadText(1001, 12908)), and a label per engaged reason.
local BOARD_STATE_TEXT  = { engaged = 1361, away = 1362, holding = 1363, assigned = 1364 }
local BOARD_STATE_COLOR = { engaged = "text_positive", away = "text_inactive", holding = "text_warning" }
local WHY_TEXT = { solo = 1390, join = 1391, help = 1392, resp = 1393, release = 1394, assign = 1395, follow = 1396, sub = 1397, load = 1398 }
-- How a board target was first found; an entry older than the field has none.
local VIA_TEXT = { scan = 1400, attack = 1401 }

-- Graph series in legend order; each sums the listed bucket keys.
local SERIES = {
  { key = "kills",   keys = { "ks", "kb" },         textId = 1350, color = "graph_data_4" },
  { key = "others",  keys = { "ko" },               textId = 1322, color = "graph_data_6" },
  { key = "attacks", keys = { "a" },                textId = 1323, color = "graph_data_2" },
  { key = "broken",  keys = { "f", "h", "r", "b" }, textId = 1351, color = "graph_data_1" },
}
local Y_STEPS = { 1, 2, 5, 10, 20, 50, 100, 200, 500, 1000 }
local X_STEPS = { 0.25, 0.5, 1, 2, 3, 4, 6, 8, 12 }

local ps = {
  playerId        = nil,
  debugLevel      = "none",
  refreshInterval = 0.0,
}

-- *** debug helpers ***

local function debugLog(fmt, ...)
  if ps.debugLevel ~= "none" then
    DebugError("[ProtectSector] " .. (select("#", ...) > 0 and string.format(fmt, ...) or fmt))
  end
end

local function traceLog(fmt, ...)
  if ps.debugLevel == "trace" then
    DebugError("[ProtectSector] " .. (select("#", ...) > 0 and string.format(fmt, ...) or fmt))
  end
end

local function readConfig()
  local cfg = GetNPCBlackboard(ps.playerId, "$ProtectSectorConfig")
  if type(cfg) ~= "table" then
    cfg = {}
  end
  ps.debugLevel = (cfg.debugLevel ~= nil) and tostring(cfg.debugLevel) or "none"
  ps.refreshInterval = tonumber(cfg.overviewRefresh) or DEFAULT_REFRESH
end

-- *** formatting ***

local function toBool(value)
  return value == true or value == 1
end

local function stripDollar(text)
  text = tostring(text or "")
  if string.sub(text, 1, 1) == "$" then
    return string.sub(text, 2)
  end
  return text
end

local function formatDuration(seconds)
  seconds = math.max(0, math.floor(tonumber(seconds) or 0))
  local id
  if seconds < 3600 then
    id = 209
  elseif seconds < 86400 then
    id = 207
  else
    id = 205
  end
  return ConvertTimeString(seconds, ReadText(1001, id))
end

local function widthLabel(width)
  if width < 3600 then
    return string.format("%d %s", width / 60, ReadText(1001, 103))
  end
  return string.format("%d %s", width / 3600, ReadText(1001, 102))
end

-- A page text with %s placeholders filled in.
local function pageText(id, ...)
  return string.format(tostring(ReadText(PAGE, id)), ...)
end

local function shipLabel(name, idcode)
  return name .. " (" .. idcode .. ")"
end

local function fleetLabel(fleet)
  if fleet.assist then
    return pageText(1308, shipLabel(fleet.name, fleet.idcode), shipLabel(fleet.cmdName, fleet.cmdIdcode))
  end
  if fleet.fleetName ~= "" then
    return pageText(1309, fleet.fleetName, shipLabel(fleet.name, fleet.idcode))
  end
  return shipLabel(fleet.name, fleet.idcode)
end

local function stateLabel(fleet)
  if fleet.state == "destroyed" then
    return ReadText(1001, 1502)
  elseif fleet.state == "off" then
    return ReadText(PAGE, 1310)
  end
  return ""
end

-- *** snapshot parsing ***

-- [start, dur, 'k=v;...'] as the sampler stores it.
local function parseBucket(raw)
  if type(raw) ~= "table" then
    return nil
  end
  local bucket = { start = tonumber(raw[1]) or 0, dur = tonumber(raw[2]) or 0, c = {}, by = {} }
  for key, value in string.gmatch(tostring(raw[3] or ""), "(%w+)=([^;]*);") do
    if key == "by" then
      for subKey, count in string.gmatch(value, "%$?([^:,]+):(%d+),") do
        bucket.by[subKey] = (bucket.by[subKey] or 0) + tonumber(count)
      end
    else
      bucket.c[key] = tonumber(value) or 0
    end
  end
  return bucket
end

local function parseKeys(list)
  local keys = {}
  for _, key in ipairs(list or {}) do
    keys[#keys + 1] = stripDollar(key)
  end
  return keys
end

-- The coordinator's board as the history MD exports it; nil when there is none yet.
-- holds[fleet key] lists the targets that fleet is pledged to.
local function parseBoard(raw)
  if type(raw) ~= "table" then
    return nil
  end
  local board = {
    policy = toBool(raw.policy),
    ksolo = tonumber(raw.ksolo) or 0, kmin = tonumber(raw.kmin) or 0, kbreak = tonumber(raw.kbreak) or 0,
    fleets = {}, fleetByKey = {}, targets = {}, targetByKey = {}, holds = {},
  }
  for _, entry in ipairs(raw.fleets or {}) do
    local fleet = {
      key      = stripDollar(entry.key),
      name     = tostring(entry.name or ""),
      idcode   = tostring(entry.idcode or ""),
      state    = tostring(entry.state or "idle"),
      target   = stripDollar(entry.target),
      why      = tostring(entry.why or ""),
      since    = tonumber(entry.since) or 0,
      assigned = stripDollar(entry.assigned),
      share    = toBool(entry.share),
    }
    board.fleets[#board.fleets + 1] = fleet
    board.fleetByKey[fleet.key] = fleet
  end
  for _, entry in ipairs(raw.targets or {}) do
    local target = {
      key        = stripDollar(entry.key),
      name       = tostring(entry.name or ""),
      idcode     = tostring(entry.idcode or ""),
      size       = tostring(entry.size or "-"),
      sectorName = tostring(entry.sectorName or "-"),
      sectorKey  = tostring(entry.sectorKey or "-"),
      ship       = entry.ship,
      ratio      = tonumber(entry.ratio) or -2,
      foes       = tonumber(entry.foes) or 0,
      engaged    = parseKeys(entry.engaged),
      pledged    = parseKeys(entry.pledged),
      assigned   = parseKeys(entry.assigned),
      help       = tonumber(entry.help) or -1,
      via        = tostring(entry.via or ""),
    }
    board.targets[#board.targets + 1] = target
    board.targetByKey[target.key] = target
    for _, key in ipairs(target.pledged) do
      board.holds[key] = board.holds[key] or {}
      table.insert(board.holds[key], target)
    end
  end
  return board
end

local function parseView(raw)
  local view = {
    now    = tonumber(raw.now) or 0,
    lastAt = tonumber(raw.lastAt) or 0,
    depth  = tonumber(raw.depth) or 0,
    fleets = {},
    byKey  = {},
    board  = parseBoard(raw.board),
  }
  for _, entry in ipairs(raw.fleets or {}) do
    local fleet = {
      key        = stripDollar(entry.key),
      name       = tostring(entry.name or ""),
      idcode     = tostring(entry.idcode or ""),
      size       = tostring(entry.size or "-"),
      fleetName  = tostring(entry.fleetName or ""),
      assist     = toBool(entry.assist),
      cmdName    = tostring(entry.cmdName or ""),
      cmdIdcode  = tostring(entry.cmdIdcode or ""),
      cmdKey     = stripDollar(entry.cmdKey),
      sectorName = tostring(entry.sectorName or "-"),
      sectorKey  = tostring(entry.sectorKey or "-"),
      state      = tostring(entry.state or "off"),
      ship       = entry.ship,
      buckets    = {},
      subs       = {},
      targets    = {},
    }
    for _, rawBucket in ipairs(entry.buckets or {}) do
      local bucket = parseBucket(rawBucket)
      if bucket then
        fleet.buckets[#fleet.buckets + 1] = bucket
      end
    end
    local live = parseBucket(entry.live)
    if live then
      live.live = true
      fleet.buckets[#fleet.buckets + 1] = live
    end
    for _, sub in ipairs(entry.subs or {}) do
      fleet.subs[#fleet.subs + 1] = {
        key = stripDollar(sub.key), name = tostring(sub.name or ""),
        idcode = tostring(sub.idcode or ""), alive = toBool(sub.alive),
      }
    end
    for _, target in ipairs(entry.targets or {}) do
      fleet.targets[#fleet.targets + 1] = {
        name = tostring(target.name or ""), idcode = tostring(target.idcode or ""), size = tostring(target.size or "-"),
        attempts = tonumber(target.attempts) or 0, sight = tonumber(target.sight) or 0, outran = tonumber(target.outran) or 0,
        firstAge = tonumber(target.firstAge) or view.now, sectorName = tostring(target.sectorName or "-"),
      }
    end
    view.fleets[#view.fleets + 1] = fleet
    view.byKey[fleet.key] = fleet
  end
  return view
end

-- Sectors by name; in a sector the commanders by name, each followed by its Assist
-- fleets, then Assist fleets whose commander has no record here.
local function buildGroups(view)
  local sectors, order = {}, {}
  for _, fleet in ipairs(view.fleets) do
    local sector = sectors[fleet.sectorKey]
    if sector == nil then
      sector = { key = fleet.sectorKey, name = fleet.sectorName, fleets = {} }
      sectors[fleet.sectorKey] = sector
      order[#order + 1] = sector
    end
    sector.fleets[#sector.fleets + 1] = fleet
  end
  table.sort(order, function(a, b)
    if a.name ~= b.name then return a.name < b.name end
    return a.key < b.key
  end)
  local byName = function(a, b)
    if a.name ~= b.name then return a.name < b.name end
    return a.idcode < b.idcode
  end
  for _, sector in ipairs(order) do
    local commanders, assists = {}, {}
    for _, fleet in ipairs(sector.fleets) do
      if fleet.assist then
        assists[#assists + 1] = fleet
      else
        commanders[#commanders + 1] = fleet
      end
    end
    table.sort(commanders, byName)
    table.sort(assists, byName)
    local ordered, placed = {}, {}
    for _, commander in ipairs(commanders) do
      ordered[#ordered + 1] = commander
      for _, assist in ipairs(assists) do
        if assist.cmdKey == commander.key then
          ordered[#ordered + 1] = assist
          placed[assist.key] = true
        end
      end
    end
    for _, assist in ipairs(assists) do
      if not placed[assist.key] then
        ordered[#ordered + 1] = assist
      end
    end
    sector.fleets = ordered
  end
  return order
end

-- *** window sums ***

local function historyOn()
  return menu.view ~= nil and menu.view.depth > 0
end

local function windowRange()
  local width = WIDTHS[menu.widthIndex]
  if not historyOn() then
    return 0, menu.view.now, width
  end
  local to = menu.view.now - menu.toOffset
  return to - width, to, width
end

local function emptySum()
  local sum = { covered = 0, coveredMax = 0, hullMin = 100.0, by = {}, c = {}, fleets = 0 }
  for _, key in ipairs(COUNTER_KEYS) do
    sum.c[key] = 0
  end
  return sum
end

-- Adds every bucket of the fleet that overlaps [from, to); counts go in whole,
-- the covered time is clipped to the window.
local function addFleet(sum, fleet, from, to)
  local covered = 0.0
  for _, bucket in ipairs(fleet.buckets) do
    local bucketEnd = bucket.start + bucket.dur
    if bucket.start < to and bucketEnd > from then
      for _, key in ipairs(COUNTER_KEYS) do
        sum.c[key] = sum.c[key] + (bucket.c[key] or 0)
      end
      if bucket.c.m ~= nil and bucket.c.m < sum.hullMin then
        ---@diagnostic disable-next-line: assign-type-mismatch
        sum.hullMin = bucket.c.m
      end
      covered = covered + (math.min(bucketEnd, to) - math.max(bucket.start, from))
      for subKey, count in pairs(bucket.by) do
        sum.by[subKey] = (sum.by[subKey] or 0) + count
      end
    end
  end
  if covered > 0 then
    sum.fleets = sum.fleets + 1
    sum.covered = sum.covered + covered
    sum.coveredMax = math.max(sum.coveredMax, covered)
  end
end

local function aggregate(fleets, from, to)
  local sum = emptySum()
  for _, fleet in ipairs(fleets) do
    addFleet(sum, fleet, from, to)
  end
  return sum
end

-- Targets merged over the fleets by idcode, uncatchable ones first.
local function mergedTargets(fleets)
  local byCode, list = {}, {}
  for _, fleet in ipairs(fleets) do
    for _, target in ipairs(fleet.targets) do
      local merged = byCode[target.idcode]
      if merged == nil then
        merged = {
          name = target.name, idcode = target.idcode, size = target.size,
          attempts = 0, sight = 0, outran = 0, firstAge = target.firstAge, sectorName = target.sectorName, tried = {},
        }
        byCode[target.idcode] = merged
        list[#list + 1] = merged
      end
      merged.tried[#merged.tried + 1] = { fleet = fleet, attempts = target.attempts }
      merged.attempts = merged.attempts + target.attempts
      merged.sight    = merged.sight + target.sight
      merged.outran   = merged.outran + target.outran
      merged.firstAge = math.min(merged.firstAge, target.firstAge)
    end
  end
  for _, target in ipairs(list) do
    target.uncatchable = (target.sight + target.outran) >= UNCATCHABLE_BREAKS
  end
  table.sort(list, function(a, b)
    if a.uncatchable ~= b.uncatchable then return a.uncatchable end
    if a.attempts ~= b.attempts then return a.attempts > b.attempts end
    return a.name < b.name
  end)
  return list
end

-- Subordinates of a fleet with their kills in the window: the live and remembered
-- ones from the snapshot, plus any killer the buckets name that neither lists.
local function subordinateRows(fleet, sum)
  local rows, seen = {}, {}
  for _, sub in ipairs(fleet.subs) do
    rows[#rows + 1] = { key = sub.key, name = sub.name, idcode = (sub.idcode ~= "") and sub.idcode or sub.key, alive = sub.alive, kills = sum.by[sub.key] or 0 }
    seen[sub.key] = true
  end
  for subKey, count in pairs(sum.by) do
    if not seen[subKey] then
      rows[#rows + 1] = { key = subKey, name = subKey, idcode = subKey, alive = false, kills = count }
    end
  end
  table.sort(rows, function(a, b)
    if a.kills ~= b.kills then return a.kills > b.kills end
    if a.alive ~= b.alive then return a.alive end
    return a.name < b.name
  end)
  return rows
end

-- *** coordination board ***

-- An Assist fleet is not on the board; its commander's entry stands for it.
local function boardEntryOf(board, fleet)
  if board == nil or fleet == nil then
    return nil
  end
  return board.fleetByKey[fleet.assist and fleet.cmdKey or fleet.key]
end

-- A fleet pledged to a target is idle on the board; it shows as holding.
local function boardState(board, entry)
  if entry.state == "engaged" or entry.state == "away" then
    return entry.state
  end
  if board.holds[entry.key] then
    return "holding"
  end
  if entry.assigned ~= "" then
    return "assigned"
  end
  return "idle"
end

local function boardStateText(state)
  local color = BOARD_STATE_COLOR[state] and Color[BOARD_STATE_COLOR[state]] or nil
  if state == "idle" then
    return ReadText(1001, 12908), color
  end
  return ReadText(PAGE, BOARD_STATE_TEXT[state]), color
end

local function whyText(why)
  return WHY_TEXT[why] and ReadText(PAGE, WHY_TEXT[why]) or why
end

-- -2 never evaluated, -1 no foes near: both "-".
local function ratioText(board, ratio)
  if ratio < 0 then
    return "-", nil
  end
  local colorId
  if ratio >= board.ksolo then
    colorId = "text_positive"
  elseif ratio < board.kbreak then
    colorId = "text_negative"
  elseif ratio < board.kmin then
    colorId = "text_warning"
  end
  return string.format("%.2f", ratio), colorId
end

-- The ratio number alone in its colour, for use inside a longer text.
local function ratioValue(board, ratio)
  local text, colorId = ratioText(board, ratio)
  return colorId and (ColorText[colorId] .. text .. "\27X") or text
end

local function boardTargetLabel(target)
  return target.name .. " (" .. target.idcode .. ", " .. target.size .. ")"
end

local function viaText(via)
  return VIA_TEXT[via] and ReadText(PAGE, VIA_TEXT[via]) or "-"
end

-- The Found by column: its widest text plus the cell's text offsets.
local function viaColumnWidth()
  local fontSize = Helper.scaleFont(Helper.standardFont, Helper.standardFontSize)
  local width = C.GetTextWidth(ReadText(PAGE, 1399), Helper.standardFontBold, fontSize)
  for _, id in pairs(VIA_TEXT) do
    width = math.max(width, C.GetTextWidth(ReadText(PAGE, id), Helper.standardFont, fontSize))
  end
  return math.ceil(width + 2 * Helper.scaleX(Helper.standardTextOffsetx))
end

local function boardFleetNames(board, keys, skip)
  local names = {}
  for _, key in ipairs(keys) do
    if key ~= skip then
      local fleet = menu.view.byKey[key] or board.fleetByKey[key]
      if not fleet then
        names[#names + 1] = key
      elseif (not fleet.assist) and (fleet.fleetName or "") ~= "" then
        names[#names + 1] = fleet.fleetName
      else
        names[#names + 1] = shipLabel(fleet.name, fleet.idcode)
      end
    end
  end
  return (#names > 0) and table.concat(names, ", ") or "-"
end

-- Board entries of the scope's fleets, once per commander.
local function scopeEntries(board, fleets)
  local entries, seen = {}, {}
  for _, fleet in ipairs(fleets) do
    local entry = boardEntryOf(board, fleet)
    if entry and not seen[entry.key] then
      seen[entry.key] = true
      entries[#entries + 1] = entry
    end
  end
  return entries
end

-- Targets in the sector or involving a scope fleet (All: every target); open
-- requests first, then the most fleets on it.
---@return table[]
local function scopeTargets(board, entries, sectorKey)
  local inScope = {}
  for _, entry in ipairs(entries) do
    inScope[entry.key] = true
  end
  local list = {}
  for _, target in ipairs(board.targets) do
    local hit = (sectorKey == nil) or (target.sectorKey == sectorKey)
    for _, keys in ipairs({ target.engaged, target.pledged, target.assigned }) do
      for _, key in ipairs(keys) do
        hit = hit or inScope[key] == true
      end
    end
    if hit then
      list[#list + 1] = target
    end
  end
  table.sort(list, function(a, b)
    if (a.help >= 0) ~= (b.help >= 0) then return a.help >= 0 end
    if #a.engaged ~= #b.engaged then return #a.engaged > #b.engaged end
    return a.name < b.name
  end)
  return list
end

-- *** state ***

local function resetState()
  menu.widthIndex = DEFAULT_WIDTH_INDEX
  menu.toOffset   = 0.0
  menu.selection  = { kind = "all" }
  menu.leftTopRow = nil
  menu.hiddenSeries = {}
  menu.columnStat = "kills"
  menu.targetRow = nil
  menu.crosshairSeries = nil
  menu.tab = "stats"
  menu.boardTargetRow = nil
end

-- The current row's fleets, falling back to all when its row is gone.
local function scopeFleets()
  local selection = menu.selection
  if selection.kind == "fleet" then
    local fleet = menu.view.byKey[selection.key]
    if fleet then
      return { fleet }, fleetLabel(fleet), fleet
    end
  elseif selection.kind == "sector" then
    for _, sector in ipairs(menu.groups or {}) do
      if sector.key == selection.key then
        return sector.fleets, sector.name, nil
      end
    end
  end
  menu.selection = { kind = "all" }
  return menu.view.fleets, ReadText(PAGE, 1301), nil
end

local function requestHistory(auto)
  menu.pending = true
  menu.autoRequest = auto
  menu.lastRequestTime = getElapsedTime()
  traceLog("requesting a snapshot%s.", auto and " (auto-refresh)" or "")
  AddUITriggeredEvent("ProtectSector", "requestHistory")
end

-- *** registration ***

local function init()
  if Helper then
    Helper.registerMenu(menu)
  end
end

function menu.cleanup()
  menu.open = false
  menu.infoFrame = nil
  menu.view = nil
  menu.groups = nil
  menu.refreshQueued = nil
  menu.pending = nil
  menu.autoRequest = nil
end

-- "back" points at the map explicitly; without a back-target Helper.closeMenu
-- falls through to the engine's generic top-level fallback.
local function onOpenMenuEvent(_, componentLuaId)
  ---@diagnostic disable-next-line: param-type-mismatch
  local id64 = ConvertIDTo64Bit(componentLuaId)
  OpenMenu("ProtectSectorReportMenu", { 0, 0, id64 }, { "MapMenu", { 0, 0 }, nil })
end

local function onHistoryReady()
  if not menu.open then
    return
  end
  menu.pending = nil
  local raw = GetNPCBlackboard(ps.playerId, "$ProtectSectorHistoryView")
  if type(raw) ~= "table" then
    debugLog("HistoryReady without a view table.")
    return
  end
  local view = parseView(raw)
  if menu.autoRequest and menu.view ~= nil and view.now == menu.view.now then
    menu.autoRequest = nil
    traceLog("auto-refresh: game time unchanged, frame kept.")
    return
  end
  menu.autoRequest = nil
  menu.view = view
  menu.groups = buildGroups(menu.view)
  if menu.pendingSelectKey ~= nil then
    if menu.view.byKey[menu.pendingSelectKey] then
      menu.selection = { kind = "fleet", key = menu.pendingSelectKey }
    end
    menu.pendingSelectKey = nil
  end
  debugLog("snapshot: %d fleet(s), %d sector(s), depth %d h, now %d.", #menu.view.fleets, #menu.groups, menu.view.depth, menu.view.now)
  -- Rebuilt from onUpdate, like a row change, never from inside an event.
  menu.refreshQueued = true
end

-- *** callbacks ***

-- `state` marks a return from the map; the picks the player left then stay.
function menu.onShowMenu(state)
  menu.open = true
  readConfig()
  if menu.widthIndex == nil then
    resetState()
  end

  local id64 = menu.param[3]
  if (not state) and id64 ~= nil and id64 ~= 0 then
    local luaId = ConvertStringToLuaID(tostring(id64))
    menu.pendingSelectKey = GetComponentData(luaId, "idcode")
    menu.leftTopRow = nil
    traceLog("opened on %s.", tostring(menu.pendingSelectKey))
  end

  menu.view = nil
  menu.groups = nil
  Helper.setTabScrollCallback(menu, menu.onTabScroll)
  requestHistory()
  menu.createFrame()
end

function menu.selectTab(id)
  if menu.tab == id then
    return
  end
  menu.tab = id
  traceLog("tab: %s.", id)
  menu.refreshInfoFrame()
end

-- The tab-scroll inputs step through the tabs, no wrap at either end.
function menu.onTabScroll(direction)
  local current = 1
  for i, tab in ipairs(TABS) do
    if tab.id == menu.tab then
      current = i
    end
  end
  local target = TABS[current + ((direction == "right") and 1 or -1)]
  if target then
    menu.selectTab(target.id)
  end
end

function menu.viewCreated(_layer, ...)
end

function menu.refreshInfoFrame()
  menu.refreshQueued = nil
  menu.createFrame()
end

function menu.buttonRefresh()
  requestHistory()
end

function menu.selectWidth(_, id)
  menu.widthIndex = math.floor(tonumber(id) or DEFAULT_WIDTH_INDEX)
  menu.refreshInfoFrame()
end

function menu.selectColumnStat(_, id)
  menu.columnStat = tostring(id)
  menu.refreshInfoFrame()
end

-- direction 1 = older, -1 = newer; the window end never passes now.
function menu.shiftWindow(direction)
  local width = WIDTHS[menu.widthIndex]
  menu.toOffset = math.max(0, menu.toOffset + direction * width)
  menu.refreshInfoFrame()
end

function menu.goNow()
  menu.toOffset = 0
  menu.refreshInfoFrame()
end

function menu.toggleSeries(key)
  menu.hiddenSeries[key] = not menu.hiddenSeries[key]
  menu.refreshInfoFrame()
end

-- A click on a graph point moves the window to end at that sample and puts the
-- crosshair on that point's series; data = { mouseover, point, record, index }.
function menu.selectGraphPoint(data)
  local index = (type(data) == "table") and tonumber(data[4]) or nil
  local point = menu.graphPoints and index and menu.graphPoints[index]
  if point == nil or menu.view == nil then
    return
  end
  menu.crosshairSeries = (menu.graphRecords and menu.graphRecords[tonumber(data[3])]) or menu.crosshairSeries
  menu.toOffset = math.max(0, menu.view.now - point.at)
  menu.refreshInfoFrame()
end

-- The legend checkbox whose cell is selected (click or keyboard) takes the crosshair,
-- moved in place: a rebuild would put the legend selection back on the first checkbox.
function menu.onColChanged(_row, col, uitable)
  local rowdata = Helper.getCurrentRowData(menu, uitable)
  if type(rowdata) ~= "table" or rowdata[1] ~= "legend" or col == nil then
    return
  end
  local series = SERIES[math.floor((col + 1) / 2)]
  local recordIdx = series and menu.graphRecordOf and menu.graphRecordOf[series.key]
  if recordIdx == nil or series.key == menu.crosshairSeries then
    return
  end
  menu.crosshairSeries = series.key
  if menu.graphCell and menu.crosshairDataIdx then
    menu.graphCell:setSelectedDataPoint(recordIdx, menu.crosshairDataIdx, true)
  end
end

local function canShowShip(ship)
  return ship ~= nil and C.IsComponentOperational(ConvertIDTo64Bit(ship)) and C.IsStoryFeatureUnlocked("x4ep1_map")
end

local function canShowOnMap(fleet)
  return fleet ~= nil and fleet.state == "active" and canShowShip(fleet.ship)
end

-- The board target of the current Targets row on the Coordination tab.
local function currentBoardTarget()
  local board = menu.view and menu.view.board
  return board and menu.boardTargetRow and board.targetByKey[menu.boardTargetRow]
end

-- The map centres on its parameter 4 but its own selection of it does not show;
-- select the ship once the map is shown and its holomap exists.
local function selectOnMap(id64, tries)
  local map = Helper.getMenu("MapMenu")
  if map ~= nil and map.shown and map.holomap ~= nil and map.holomap ~= 0 then
    traceLog("selectOnMap: selecting, %d tries left.", tries)
    map.addSelectedComponent(id64)
  elseif tries > 0 then
    Helper.addDelayedOneTimeCallbackOnUpdate(function() selectOnMap(id64, tries - 1) end, false, getElapsedTime() + config.mapSelectRetry)
  else
    traceLog("selectOnMap: map not up, giving up.")
  end
end

-- A fleet or a board target. No noreturn, so Back returns here.
function menu.buttonShowOnMap(subject)
  ---@diagnostic disable-next-line: param-type-mismatch
  local id64 = ConvertIDTo64Bit(subject.ship)
  traceLog("showOnMap: %s.", subject.idcode)
  Helper.closeMenuAndOpenNewMenu(menu, "MapMenu", { 0, 0, true, id64 })
  menu.cleanup()
  Helper.addDelayedOneTimeCallbackOnUpdate(function() selectOnMap(id64, config.mapSelectTries) end, false, getElapsedTime() + config.mapSelectRetry)
end

function menu.onRowChanged(row, rowdata, uitable, _modified, _input, source)
  if type(rowdata) ~= "table" then
    return
  end
  local kind = rowdata[1]
  if kind == "target" then
    menu.targetRow = rowdata[2]
    return
  end
  if kind == "btarget" then
    menu.boardTargetRow = rowdata[2]
    return
  end
  if kind ~= "all" and kind ~= "sector" and kind ~= "fleet" then
    return
  end
  menu.leftTopRow = GetTopRow(uitable)
  if menu.selection.kind == kind and menu.selection.key == rowdata[2] then
    return
  end
  menu.selection = { kind = kind, key = rowdata[2] }
  traceLog("selection: %s %s, row %d, source %s.", kind, tostring(rowdata[2]), row, tostring(source))
  -- Never rebuilt here: the engine raises this from inside its own frame setup.
  menu.refreshQueued = true
end

-- A double-click (or Enter) on a fleet row or a Coordination target row opens
-- the map on its ship, as the Show on Map buttons do; on a Targets tried row it
-- narrows the left list to where the target was tried: All fleets -> the sector
-- with the most attempts on it, a sector -> the fleet with the most.
function menu.onSelectElement(uitable, _modified, _row, isdblclick, input)
  local rowdata = Helper.getCurrentRowData(menu, uitable)
  if type(rowdata) ~= "table" or not (isdblclick or input ~= "mouse") then
    return
  end
  if rowdata[1] == "fleet" then
    local fleet = menu.view and menu.view.byKey[rowdata[2]]
    if canShowOnMap(fleet) then
      return menu.buttonShowOnMap(fleet)
    end
    return
  end
  if rowdata[1] == "btarget" then
    local target = menu.view and menu.view.board and menu.view.board.targetByKey[rowdata[2]]
    if target and canShowShip(target.ship) then
      return menu.buttonShowOnMap(target)
    end
    return
  end
  if rowdata[1] ~= "target" then
    return
  end
  local target = menu.targetsByCode and menu.targetsByCode[rowdata[2]]
  if target == nil or menu.selection.kind == "fleet" then
    return
  end
  local kind = (menu.selection.kind == "all") and "sector" or "fleet"
  local attempts, key = {}, nil
  for _, tried in ipairs(target.tried) do
    local k = (kind == "sector") and tried.fleet.sectorKey or tried.fleet.key
    attempts[k] = (attempts[k] or 0) + tried.attempts
    if key == nil or attempts[k] > attempts[key] then
      key = k
    end
  end
  if key == nil then
    return
  end
  menu.selection = { kind = kind, key = key }
  menu.scrollToSelection = true
  traceLog("target %s: %s %s.", rowdata[2], kind, tostring(key))
  menu.refreshQueued = true
end

-- *** frame ***

local function panelHeight(y)
  return Helper.viewHeight - Helper.frameBorder - y
end

function menu.createFrame()
  Helper.clearDataForRefresh(menu, config.infoLayer)

  menu.infoFrame = Helper.createFrameHandle(menu, {
    layer           = config.infoLayer,
    standardButtons = { back = true, close = true, help = false },
    width           = Helper.viewWidth,
    height          = Helper.viewHeight,
    x               = 0,
    y               = 0,
  })
  menu.infoFrame:setBackground("solid", { color = Color["frame_background_semitransparent"] })

  local usableWidth = Helper.viewWidth - 2 * Helper.frameBorder
  local leftWidth   = math.max(Helper.scaleX(config.leftMinWidth), Helper.round(usableWidth * config.leftShare))
  local rightX      = Helper.frameBorder + leftWidth + Helper.borderSize
  local rightWidth  = usableWidth - leftWidth - Helper.borderSize

  menu.panelTop = menu.createTabRow() + Helper.borderSize
  menu.createLeftPanel(Helper.frameBorder, leftWidth)
  if menu.tab == "board" then
    menu.createBoardPanel(rightX, rightWidth)
  else
    menu.createRightPanel(rightX, rightWidth)
  end

  menu.infoFrame:display()
  menu.lastRefreshTime = getElapsedTime()
end

-- Centred tab icons with the tab-scroll input names either side (off on a mouse
-- cursor) and the current tab's name under them; returns the y under the bar.
function menu.createTabRow()
  local iconSize  = Helper.scaleX(Helper.sidebarWidth)
  local inputSize = Helper.scaleX(config.tabInputWidth)
  local cols      = #TABS + 2
  local width     = #TABS * iconSize + 2 * inputSize + (#TABS + 1) * Helper.borderSize
  local bgColor   = Color["toplevel_background_default"]

  local ftable = menu.infoFrame:addTable(cols, {
    tabOrder = 20, x = Helper.viewWidth / 2 - width / 2, y = Helper.frameBorder,
    scaling = false, reserveScrollBar = false, skipTabChange = true,
  })
  ftable:setColWidth(1, inputSize)
  for i = 1, #TABS do
    ftable:setColWidth(i + 1, iconSize)
  end
  ftable:setColWidth(cols, inputSize)
  ftable:setDefaultBackgroundColSpan(1, cols)

  local showInputs = GetControllerInfo() ~= "mouseCursor"
  local inputY = (Helper.sidebarWidth - Helper.titleHeight) / 2
  local row = ftable:addRow(true, { fixed = true, borderBelow = false, bgColor = bgColor })
  if showInputs then
    row[1]:createText(ffi.string(C.GetMappedInputName("INPUT_ACTION_WIDGET_TABSCROLL_LEFT")), { scaling = true, fontsize = Helper.titleFontSize, y = inputY, halign = "right" })
  end
  local currentName = ""
  for i, tab in ipairs(TABS) do
    local current = (tab.id == menu.tab)
    row[i + 1]:createButton({ height = iconSize, bgColor = Color["toplevel_button_background"], borderColor = Color["button_border_hidden"], mouseOverText = tab.name() })
        :setIcon(tab.icon, { color = current and Color["icon_normal"] or Color["icon_inactive"] })
    if current then
      currentName = tostring(tab.name())
    else
      row[i + 1].handlers.onClick = function() return menu.selectTab(tab.id) end
    end
  end
  if showInputs then
    row[cols]:createText(ffi.string(C.GetMappedInputName("INPUT_ACTION_WIDGET_TABSCROLL_RIGHT")), { scaling = true, fontsize = Helper.titleFontSize, y = inputY })
  end

  row = ftable:addRow(false, { fixed = true, borderBelow = false, bgColor = bgColor, scaling = true })
  row[1]:setColSpan(cols):createText(currentName, { halign = "center", x = 0, font = Helper.standardFontOutlined })

  return ftable.properties.y + ftable:getFullHeight()
end

local function noticeRow(ftable, cols, textId)
  local row = ftable:addRow(false, {})
  row[1]:setColSpan(cols):createText(ReadText(PAGE, textId), { halign = "center", wordwrap = true, color = Color["text_inactive"] })
end

local function idleShare(sum)
  return (sum.covered > 0) and math.min(100, math.floor(100 * sum.c.i / sum.covered + 0.5)) or 0
end

-- Counters the left column can show; the header dropdown lists them in this order.
local COLUMN_STATS = {
  { id = "kills",     textId = 1312, value = function(sum) return sum.c.ks + sum.c.kb end },
  { id = "killsSelf", textId = 1320, value = function(sum) return sum.c.ks end },
  { id = "killsSubs", textId = 1321, value = function(sum) return sum.c.kb end },
  { id = "others",    textId = 1322, value = function(sum) return sum.c.ko end },
  { id = "attacks",   textId = 1323, value = function(sum) return sum.c.a end },
  { id = "responses", textId = 1333, value = function(sum) return sum.c.rp end },
  { id = "combat",    textId = 1324, value = function(sum) return formatDuration(sum.c.t) end },
  { id = "sight",     textId = 1325, value = function(sum) return sum.c.f + sum.c.h end },
  { id = "range",     textId = 1326, value = function(sum) return sum.c.r end },
  { id = "fast",      textId = 1327, value = function(sum) return sum.c.b end },
  { id = "idle",      textId = 1328, value = function(sum) return idleShare(sum) .. " %" end },
  { id = "ends",      textId = 1329, value = function(sum) return sum.c.e end },
  { id = "handoff",   textId = 1330, value = function(sum) return sum.c.s end },
  { id = "hull",      textId = 1331, value = function(sum) return math.floor(sum.hullMin) .. " %" end },
  { id = "lost",      textId = 1334, value = function(sum) return sum.c.l end },
  { id = "scans",     textId = 1332, value = function(sum) return sum.c.sc .. " (" .. sum.c.se .. ")" end },
  { id = "covered",   textId = 1314, value = function(sum) return formatDuration(sum.coveredMax) end },
}

local function columnValue(sum)
  if sum.fleets == 0 then
    return "-"
  end
  for _, stat in ipairs(COLUMN_STATS) do
    if stat.id == menu.columnStat then
      return tostring(stat.value(sum))
    end
  end
  return tostring(COLUMN_STATS[1].value(sum))
end

-- The Coordination column: a sector or All counts its commanders on the board.
local function boardCountText(board, fleets)
  local entries = scopeEntries(board, fleets)
  if #entries == 0 then
    return "-"
  end
  local engaged = 0
  for _, entry in ipairs(entries) do
    if entry.state == "engaged" then
      engaged = engaged + 1
    end
  end
  return pageText(1365, engaged, #entries)
end

-- Blank for an Assist fleet and a fleet not on the board.
local function boardFleetText(board, fleet)
  local entry = (not fleet.assist) and boardEntryOf(board, fleet) or nil
  if entry == nil then
    return "", nil
  end
  return boardStateText(boardState(board, entry))
end

function menu.createLeftPanel(x, width)
  local onBoard = (menu.tab == "board")
  local leftTable = menu.infoFrame:addTable(2, {
    tabOrder = 1, width = width, x = x, y = menu.panelTop, borderEnabled = true,
    maxVisibleHeight = panelHeight(menu.panelTop),
    backgroundID = "solid", backgroundColor = Color["frame_background_semitransparent"],
    -- The selection highlight is drawn only on the focused table: take the focus
    -- after a jump from Targets tried.
    defaultInteractiveObject = (menu.scrollToSelection == true),
  })
  leftTable:setColWidth(2, Helper.scaleX(config.statColWidth), false)

  -- The header picks the counter the column shows; its row data is ignored by
  -- onRowChanged, the widget only needs a selectable row.
  local row = leftTable:addRow(not onBoard, { fixed = true, bgColor = Color["row_title_background"] })
  row[1]:createText(ReadText(PAGE, 1300), Helper.titleTextProperties)
  if onBoard then
    row[2]:createText(ReadText(1001, 12), Helper.titleTextProperties)
  else
    local options = {}
    for i, stat in ipairs(COLUMN_STATS) do
      options[i] = { id = stat.id, icon = "", text = ReadText(PAGE, stat.textId), displayremoveoption = false }
    end
    row[2]:createDropDown(options, { startOption = menu.columnStat, height = Helper.standardButtonHeight })
    row[2].handlers.onDropDownConfirmed = menu.selectColumnStat
  end

  if menu.view == nil then
    return noticeRow(leftTable, 2, 1302)
  end
  if #menu.view.fleets == 0 then
    return noticeRow(leftTable, 2, 1303)
  end

  -- The list covers the whole period held, not the window.
  local from, to = 0, menu.view.now + 1
  local selection = menu.selection
  local selectedRow, scrollRow
  local board = menu.view.board
  local function groupValue(fleets)
    if onBoard then
      return (board ~= nil) and boardCountText(board, fleets) or "-"
    end
    return columnValue(aggregate(fleets, from, to))
  end

  -- The rows carry their identity as row data; the current row is the selection.
  row = leftTable:addRow({ "all" }, {})
  row[1]:createText(ReadText(PAGE, 1301), { halign = "left", font = Helper.standardFontBold })
  row[2]:createText(groupValue(menu.view.fleets), { halign = "right" })
  if selection.kind == "all" then
    selectedRow = row.index
  end

  for _, sector in ipairs(menu.groups or {}) do
    row = leftTable:addRow({ "sector", sector.key }, { bgColor = Color["row_title_background"] })
    row[1]:createText(sector.name, { halign = "left", font = Helper.standardFontBold })
    row[2]:createText(groupValue(sector.fleets), { halign = "right" })
    local sectorRow = row.index
    if selection.kind == "sector" and selection.key == sector.key then
      selectedRow, scrollRow = sectorRow, sectorRow
    end
    for _, fleet in ipairs(sector.fleets) do
      local color = (fleet.state ~= "active") and Color["text_inactive"] or nil
      local value, valueColor
      if not onBoard then
        value = columnValue(aggregate({ fleet }, from, to))
      elseif board ~= nil then
        value, valueColor = boardFleetText(board, fleet)
      else
        value = ""
      end
      row = leftTable:addRow({ "fleet", fleet.key }, {})
      row[1]:createText("  " .. fleetLabel(fleet), { halign = "left", color = color })
      row[2]:createText(value, { halign = "right", color = color or valueColor })
      if selection.kind == "fleet" and selection.key == fleet.key then
        selectedRow, scrollRow = row.index, sectorRow
      end
    end
  end

  if selectedRow ~= nil then
    leftTable:setSelectedRow(selectedRow)
  end
  -- After a jump from the Targets tried table the list scrolls to the sector row.
  if menu.scrollToSelection then
    menu.scrollToSelection = nil
    menu.leftTopRow = scrollRow
  end
  if menu.leftTopRow ~= nil then
    leftTable:setTopRow(menu.leftTopRow)
  end
end

local function statRow(ftable, label, value, color, rowdata)
  local row = ftable:addRow(rowdata or true, {})
  row[1]:createText(label, { halign = "left", color = color })
  row[2]:createText(tostring(value), { halign = "left", color = color })
  return row
end

local function windowLabel(width)
  if not historyOn() then
    return ReadText(PAGE, 1346)
  end
  if menu.toOffset == 0 then
    return pageText(1305, widthLabel(width))
  end
  return pageText(1306, widthLabel(width), formatDuration(menu.toOffset))
end

-- Height of the first n rows, summed the way the helper sums a whole table.
local function rowsHeight(ftable, n)
  local height = 0
  for i = 1, math.min(n, #ftable.rows) do
    local row = ftable.rows[i]
    height = height + row:getHeight() + row.properties.paddingTop + row.properties.paddingBottom
    if i < #ftable.rows and row.properties.borderBelow then
      height = height + Helper.borderSize
    end
  end
  return height
end

-- A section as its own table under the counters: a fixed title row, then its rows
-- scroll. Position and visible height are set once every section exists. A side
-- title adds a third column of sideWidth pixels.
local function createSectionTable(x, width, tabOrder, title, selectable, sideTitle, sideWidth)
  local ftable = menu.infoFrame:addTable(sideTitle and 3 or 2, {
    tabOrder = tabOrder, width = width, x = x, y = 0, borderEnabled = true, highlightMode = (not selectable) and "off" or nil,
    backgroundID = "solid", backgroundColor = Color["frame_background_semitransparent"],
  })
  ftable:setColWidth(1, Helper.round(width * config.labelColShare), false)
  if sideTitle then
    ftable:setColWidth(3, sideWidth, false)
  end
  local row = ftable:addRow(false, { fixed = true, bgColor = Color["row_title_background"] })
  row[1]:setColSpan(2):createText(title, { halign = "left", font = Helper.standardFontBold })
  if sideTitle then
    row[3]:createText(sideTitle, { halign = "left", font = Helper.standardFontBold })
  end
  return ftable
end

local function addSubordinateRows(ftable, subs)
  for _, sub in ipairs(subs) do
    local color = (not sub.alive) and Color["text_inactive"] or nil
    local label = shipLabel(sub.name, sub.idcode)
    if not sub.alive then
      label = label .. ", " .. ReadText(PAGE, 1345)
    end
    statRow(ftable, label, sub.kills, color)
  end
end

local function addTargetRows(ftable, targets)
  menu.targetsByCode = {}
  for _, target in ipairs(targets) do
    menu.targetsByCode[target.idcode] = target
    local since = formatDuration(menu.view.now - target.firstAge)
    local reason
    if not target.uncatchable then
      reason = pageText(1343, target.attempts, since)
    elseif target.outran > target.sight then
      reason = pageText(1341, target.attempts, since)
    else
      reason = pageText(1342, target.attempts, since)
    end
    local color = target.uncatchable and Color["text_warning"] or nil
    local label = target.name .. " (" .. target.idcode .. ", " .. target.size .. "), " .. target.sectorName
    if target.uncatchable then
      label = ReadText(PAGE, 1344) .. ": " .. label
    end
    local row = statRow(ftable, label, reason, color, { "target", target.idcode })
    if target.idcode == menu.targetRow then
      ftable:setSelectedRow(row.index)
    end
  end
end

-- One point per window width over the whole depth, aligned to the window end and
-- oldest first; each is the sum the panel shows for the window ending there.
local function graphPoints(fleets, to, width)
  local now = menu.view.now
  local oldest = now - menu.view.depth * 3600
  local binTo = to + math.ceil((now - to) / width) * width
  local points = {}
  while binTo > oldest and #points < config.graphMaxPoints do
    table.insert(points, 1, { at = binTo, c = aggregate(fleets, binTo - width, binTo).c })
    binTo = binTo - width
  end
  return points
end

local function seriesValue(series, counters)
  local value = 0
  for _, key in ipairs(series.keys) do
    value = value + (counters[key] or 0)
  end
  return value
end

-- The smallest step that keeps the axis at or under maxTicks ticks.
local function axisStep(range, steps, maxTicks)
  for _, step in ipairs(steps) do
    if range / step <= maxTicks then
      return step
    end
  end
  return steps[#steps]
end

-- Legend with a toggle per series, then one line per series over the whole
-- history depth, x in hours before now; the selected point marks the window end.
local function createGraphPanel(x, width, y, height, points, to)
  local cols = 2 * #SERIES
  local graphTable = menu.infoFrame:addTable(cols, {
    tabOrder = 4, width = width, x = x, y = y, reserveScrollBar = false, highlightMode = "off",
    backgroundID = "solid", backgroundColor = Color["frame_background_semitransparent"],
  })
  for i = 1, #SERIES do
    graphTable:setColWidth(2 * i - 1, Helper.standardTextHeight + Helper.borderSize)
  end
  local row = graphTable:addRow({ "legend" }, { fixed = true })
  for i, series in ipairs(SERIES) do
    row[2 * i - 1]:createCheckBox(not menu.hiddenSeries[series.key], { width = Helper.standardTextHeight, height = Helper.standardTextHeight })
    row[2 * i - 1].handlers.onClick = function() return menu.toggleSeries(series.key) end
    row[2 * i]:createText(ReadText(PAGE, series.textId), { halign = "left", color = Color[series.color] })
    if series.key == menu.crosshairSeries then
      graphTable:setSelectedCol(2 * i - 1)
    end
  end
  local legendHeight = graphTable:getFullHeight()
  local graphRow = graphTable:addRow(false, { fixed = true })
  local graph = graphRow[1]:setColSpan(cols):createGraph({ height = height - legendHeight - Helper.borderSize, scaling = false })
  graphRow[1].handlers.onClick = function(_, data) return menu.selectGraphPoint(data) end

  local maxY, records, crosshairRecord = 0, 0, nil
  local markerSize = (#points > 96) and 4 or ((#points > 48) and 6 or 8)
  menu.graphCell, menu.graphRecords, menu.graphRecordOf, menu.crosshairDataIdx = graph, {}, {}, nil
  for _, series in ipairs(SERIES) do
    if not menu.hiddenSeries[series.key] then
      local record = graph:addDataRecord({
        markertype = "square", markersize = markerSize, markercolor = Color[series.color],
        linetype = "normal", linewidth = 2, linecolor = Color[series.color],
        mouseOverText = ReadText(PAGE, series.textId),
      })
      records = records + 1
      menu.graphRecords[records] = series.key
      menu.graphRecordOf[series.key] = records
      if series.key == menu.crosshairSeries then
        crosshairRecord = records
      end
      for _, point in ipairs(points) do
        local value = seriesValue(series, point.c)
        maxY = math.max(maxY, value)
        record:addData((point.at - menu.view.now) / 3600, value)
      end
    end
  end

  local depth = menu.view.depth
  local yTop = math.max(maxY, 1)
  local yStep = axisStep(yTop, Y_STEPS, 10)
  graph:setXAxis({ startvalue = -depth, endvalue = 0, granularity = axisStep(depth, X_STEPS, 8), offset = 0, gridcolor = Color["graph_grid"], unittext = ReadText(1001, 102) })
  graph:setXAxisLabel(ReadText(1001, 6519), { fontsize = 9 })
  graph:setYAxis({ startvalue = 0, endvalue = (math.ceil(yTop / yStep) + 0.5) * yStep, granularity = yStep, offset = 0, gridcolor = Color["graph_grid"] })
  graph:setYAxisLabel(ReadText(PAGE, 1352), { fontsize = 9 })

  if records > 0 then
    local dataIdx = 1
    for i, point in ipairs(points) do
      if math.abs(point.at - to) < 1 then
        dataIdx = i
      end
    end
    graph:setSelectedDataPoint(crosshairRecord or 1, dataIdx, true)
    menu.crosshairDataIdx = dataIdx
  end
  menu.graphPoints = points
end

function menu.createRightPanel(x, width)
  local bottom         = Helper.viewHeight - Helper.frameBorder
  local controlsHeight = Helper.scaleY(Helper.standardButtonHeight) + Helper.borderSize
  local y              = menu.panelTop

  local rightTable = menu.infoFrame:addTable(2, {
    tabOrder = 2, width = width, x = x, y = y, borderEnabled = true,
    maxVisibleHeight = bottom - controlsHeight - y, highlightMode = "off",
    backgroundID = "solid", backgroundColor = Color["frame_background_semitransparent"],
  })
  rightTable:setColWidth(1, Helper.round(width * config.labelColShare), false)

  if menu.view == nil or #menu.view.fleets == 0 then
    local row = rightTable:addRow(false, { fixed = true, bgColor = Color["row_title_background"] })
    row[1]:setColSpan(2):createText(ReadText(PAGE, 1300), Helper.titleTextProperties)
    noticeRow(rightTable, 2, (menu.view == nil) and 1302 or 1303)
    return menu.createControls(x, width, bottom, nil)
  end

  local fleets, title, fleet = scopeFleets()
  local from, to, windowWidth = windowRange()
  local sum = aggregate(fleets, from, to)

  local row = rightTable:addRow(false, { fixed = true, bgColor = Color["row_title_background"] })
  row[1]:setColSpan(2):createText(title, Helper.titleTextProperties)
  if fleet ~= nil then
    local state = stateLabel(fleet)
    local about = fleet.size .. ", " .. fleet.sectorName
    if state ~= "" then
      about = about .. ", " .. state
    end
    row = rightTable:addRow(false, { fixed = true })
    row[1]:setColSpan(2):createText(about, { halign = "left", color = (state ~= "") and Color["text_warning"] or nil })
  end
  row = rightTable:addRow(false, { fixed = true })
  row[1]:setColSpan(2):createText(ReadText(PAGE, 1304) .. ": " .. windowLabel(windowWidth), { halign = "left", color = Color["text_inactive"] })

  -- An empty window keeps every row with "-" values, and the sections and graph.
  local empty = (sum.fleets == 0)
  local function shown(value)
    return empty and "-" or value
  end
  local c = sum.c
  if fleet == nil then
    statRow(rightTable, ReadText(PAGE, 1313), sum.fleets .. " / " .. #fleets)
  end
  statRow(rightTable, ReadText(PAGE, 1314), shown(formatDuration(sum.coveredMax)))
  statRow(rightTable, ReadText(PAGE, 1320), shown(c.ks))
  statRow(rightTable, ReadText(PAGE, 1321), shown(c.kb))
  statRow(rightTable, ReadText(PAGE, 1322), shown(c.ko))
  statRow(rightTable, ReadText(PAGE, 1323), shown(c.a))
  statRow(rightTable, ReadText(PAGE, 1333), shown(c.rp))
  statRow(rightTable, ReadText(PAGE, 1324), shown(formatDuration(c.t)))
  statRow(rightTable, ReadText(PAGE, 1325), shown(c.f + c.h))
  statRow(rightTable, ReadText(PAGE, 1326), shown(c.r))
  statRow(rightTable, ReadText(PAGE, 1327), shown(c.b))
  statRow(rightTable, ReadText(PAGE, 1328), shown(idleShare(sum) .. " %"))
  statRow(rightTable, ReadText(PAGE, 1329), shown(c.e))
  statRow(rightTable, ReadText(PAGE, 1330), shown(c.s))
  statRow(rightTable, ReadText(PAGE, 1331), shown(math.floor(sum.hullMin) .. " %"))
  statRow(rightTable, ReadText(PAGE, 1334), shown(c.l))
  statRow(rightTable, ReadText(PAGE, 1332), shown(c.sc .. " (" .. c.se .. ")"))

  local subs = (fleet ~= nil) and subordinateRows(fleet, sum) or {}
  local targets = mergedTargets(fleets)
  local points = historyOn() and graphPoints(fleets, to, windowWidth) or {}
  local usableBottom = bottom - controlsHeight
  y = y + rightTable:getVisibleHeight() + Helper.borderSize
  local available = usableBottom - y
  if (#subs == 0 and #targets == 0 and #points == 0) or available < 2 * Helper.scaleY(Helper.standardTextHeight) then
    return menu.createControls(x, width, bottom, fleet)
  end

  local sections = {}
  if #subs > 0 then
    sections[#sections + 1] = createSectionTable(x, width, 5, ReadText(1001, 1503) .. " (" .. #subs .. ")")
    addSubordinateRows(sections[#sections], subs)
  end
  if #targets > 0 then
    sections[#sections + 1] = createSectionTable(x, width, 6, ReadText(PAGE, 1340) .. " (" .. #targets .. ")", true)
    addTargetRows(sections[#sections], targets)
  end

  -- Sections under the counters, the graph under them: sectionRows rows each, fewer
  -- when the graph would fall under its minimum height, no graph when it still would.
  local function sectionHeight(ftable, rows)
    return math.min(ftable:getFullHeight(), rowsHeight(ftable, rows + 1))
  end
  local function sectionsHeight(rows)
    local height = 0
    for _, ftable in ipairs(sections) do
      height = height + sectionHeight(ftable, rows) + Helper.borderSize
    end
    return height
  end
  local graphMin = Helper.scaleY(config.graphMinHeight)
  local rows, graphHeight = config.sectionRows, 0.0
  if #points > 0 then
    graphHeight = available - sectionsHeight(rows)
    if graphHeight < graphMin then
      rows = config.sectionMinRows
      graphHeight = available - sectionsHeight(rows)
    end
    if graphHeight < graphMin then
      rows, graphHeight = config.sectionRows, 0
    end
  end
  for _, ftable in ipairs(sections) do
    ftable.properties.y = y
    ftable.properties.maxVisibleHeight = math.max(rowsHeight(ftable, 1), math.min(sectionHeight(ftable, rows), usableBottom - y))
    y = y + ftable:getVisibleHeight() + Helper.borderSize
  end
  if graphHeight > 0 then
    createGraphPanel(x, width, y, usableBottom - y, points, to)
  end

  menu.createControls(x, width, bottom, fleet)
end

-- The fleet's board entry, the entry of its target and its holds; returns the
-- targets it involves, its own first.
---@return table[]
local function addBoardFleetRows(ftable, board, fleet)
  if fleet.assist then
    local row = ftable:addRow(false, {})
    row[1]:setColSpan(2):createText(pageText(1384, shipLabel(fleet.cmdName, fleet.cmdIdcode)), { halign = "left", wordwrap = true, color = Color["text_inactive"] })
  end
  local entry = boardEntryOf(board, fleet)
  if entry == nil then
    noticeRow(ftable, 2, 1385)
    return {}
  end
  local stateText, stateColor = boardStateText(boardState(board, entry))
  statRow(ftable, ReadText(1001, 12), stateText, stateColor)
  if entry.state == "engaged" then
    statRow(ftable, ReadText(PAGE, 1375), whyText(entry.why))
  end
  statRow(ftable, ReadText(PAGE, 1376), formatDuration(entry.since))
  statRow(ftable, ReadText(PAGE, 1388), ReadText(1001, entry.share and 2617 or 2618))

  local targets = {}
  local targetKey = (entry.target ~= "") and entry.target or entry.assigned
  local target = (targetKey ~= "") and board.targetByKey[targetKey] or nil
  if target then
    targets[1] = target
    statRow(ftable, ReadText(PAGE, 1374), boardTargetLabel(target))
    statRow(ftable, ReadText(PAGE, 1378), ratioValue(board, target.ratio))
    statRow(ftable, ReadText(PAGE, 1379), boardFleetNames(board, target.engaged, entry.key))
    statRow(ftable, ReadText(PAGE, 1380), boardFleetNames(board, target.pledged, entry.key))
    statRow(ftable, ReadText(PAGE, 1381), (target.help >= 0) and pageText(1382, formatDuration(target.help)) or "-")
  end
  for _, held in ipairs(board.holds[entry.key] or {}) do
    if held ~= target then
      targets[#targets + 1] = held
    end
  end
  return targets
end

-- Coordination tab, right side: the scope's board summary or the fleet's entry,
-- then the targets it involves as a selectable section.
function menu.createBoardPanel(x, width)
  local bottom         = Helper.viewHeight - Helper.frameBorder
  local controlsHeight = Helper.scaleY(Helper.standardButtonHeight) + Helper.borderSize
  local usableBottom   = bottom - controlsHeight
  local y              = menu.panelTop

  local infoTable = menu.infoFrame:addTable(2, {
    tabOrder = 2, width = width, x = x, y = y, borderEnabled = true,
    maxVisibleHeight = usableBottom - y, highlightMode = "off",
    backgroundID = "solid", backgroundColor = Color["frame_background_semitransparent"],
  })
  infoTable:setColWidth(1, Helper.round(width * config.labelColShare), false)

  local board = menu.view and menu.view.board
  if menu.view == nil or #menu.view.fleets == 0 or board == nil then
    local row = infoTable:addRow(false, { fixed = true, bgColor = Color["row_title_background"] })
    row[1]:setColSpan(2):createText(ReadText(PAGE, 1360), Helper.titleTextProperties)
    noticeRow(infoTable, 2, (menu.view == nil) and 1302 or ((#menu.view.fleets == 0) and 1303 or 1386))
    menu.boardTargetRow = nil
    return menu.createControls(x, width, bottom, nil)
  end

  local fleets, title, fleet = scopeFleets()
  local row = infoTable:addRow(false, { fixed = true, bgColor = Color["row_title_background"] })
  row[1]:setColSpan(2):createText(title, Helper.titleTextProperties)

  local targets = {}
  if fleet == nil then
    local entries = scopeEntries(board, fleets)
    local counts = { engaged = 0, idle = 0, away = 0, holding = 0, assigned = 0 }
    for _, entry in ipairs(entries) do
      local state = boardState(board, entry)
      counts[state] = counts[state] + 1
    end
    targets = scopeTargets(board, entries, (menu.selection.kind == "sector") and menu.selection.key or nil)
    local requests = 0
    for _, target in ipairs(targets) do
      if target.help >= 0 then
        requests = requests + 1
      end
    end
    statRow(infoTable, ReadText(PAGE, 1360), ReadText(1001, board.policy and 12642 or 12641))
    statRow(infoTable, ReadText(PAGE, 1366), counts.engaged)
    statRow(infoTable, ReadText(PAGE, 1367), counts.idle + counts.assigned)
    statRow(infoTable, ReadText(PAGE, 1368), counts.away)
    statRow(infoTable, ReadText(PAGE, 1369), counts.holding)
    statRow(infoTable, ReadText(PAGE, 1370), #targets)
    statRow(infoTable, ReadText(PAGE, 1371), requests)
  else
    targets = addBoardFleetRows(infoTable, board, fleet)
  end

  y = y + infoTable:getVisibleHeight() + Helper.borderSize
  if usableBottom - y < 2 * Helper.scaleY(Helper.standardTextHeight) then
    targets = {}
  end
  -- The current Targets row survives a refresh while its target is still listed.
  local current = nil
  for _, target in ipairs(targets) do
    if target.key == menu.boardTargetRow then
      current = target.key
    end
  end
  menu.boardTargetRow = current or (targets[1] and targets[1].key)

  if #targets > 0 then
    local section = createSectionTable(x, width, 5, ReadText(PAGE, 1370), true, ReadText(PAGE, 1399), viaColumnWidth())
    for _, target in ipairs(targets) do
      local value = pageText(1372, ratioValue(board, target.ratio), #target.engaged, #target.pledged)
      if target.help >= 0 then
        value = value .. ", " .. pageText(1373, formatDuration(target.help))
      end
      local label = boardTargetLabel(target)
      if menu.selection.kind == "all" then
        label = label .. ", " .. target.sectorName
      end
      row = statRow(section, label, value, nil, { "btarget", target.key })
      row[3]:createText(viaText(target.via), { halign = "left" })
      if target.key == menu.boardTargetRow then
        section:setSelectedRow(row.index)
      end
      -- All or a sector: the fleets on it by name, under its row
      if fleet == nil then
        local engagedRow = section:addRow(false, {})
        engagedRow[1]:createText(ReadText(PAGE, 1366), { halign = "left", x = Helper.standardIndentStep })
        engagedRow[2]:setColSpan(2):createText(boardFleetNames(board, target.engaged), { halign = "left", wordwrap = true })
      end
    end
    section.properties.y = y
    section.properties.maxVisibleHeight = usableBottom - y
  end

  menu.createControls(x, width, bottom, fleet)
end

function menu.buttonShowTarget()
  local target = currentBoardTarget()
  if target and canShowShip(target.ship) then
    return menu.buttonShowOnMap(target)
  end
end

-- Coordination tab: Refresh, Show on Map for the fleet and for the current Targets row.
local function createBoardControls(x, width, bottom, fleet)
  local buttonHeight = Helper.scaleY(Helper.standardButtonHeight)
  local target = currentBoardTarget()
  local controls = menu.infoFrame:addTable(3, {
    tabOrder = 3, width = width, x = x, y = bottom - buttonHeight, reserveScrollBar = false,
    backgroundID = "solid", backgroundColor = Color["frame_background_semitransparent"],
  })
  local row = controls:addRow(true, { fixed = true })
  row[1]:createButton({ active = not menu.pending }):setText(ReadText(1001, 6401), { halign = "center" })
  row[1].handlers.onClick = function() return menu.buttonRefresh() end
  row[2]:createButton({ active = canShowOnMap(fleet) }):setText(ReadText(1001, 3408), { halign = "center" })
  row[2].handlers.onClick = function() return menu.buttonShowOnMap(fleet) end
  row[3]:createButton({ active = (target ~= nil) and canShowShip(target.ship) }):setText(ReadText(PAGE, 1387), { halign = "center" })
  row[3].handlers.onClick = function() return menu.buttonShowTarget() end
end

-- Width, older, newer, Now, Refresh, Show on Map in one row under the right panel.
function menu.createControls(x, width, bottom, fleet)
  if menu.tab == "board" then
    return createBoardControls(x, width, bottom, fleet)
  end
  local buttonHeight = Helper.scaleY(Helper.standardButtonHeight)
  local hasData = (menu.view ~= nil) and (#menu.view.fleets > 0)
  local canWindow = hasData and historyOn()
  local canOlder, canNewer = false, false
  if canWindow then
    local _, to, windowWidth = windowRange()
    local oldest = menu.view.now - menu.view.depth * 3600
    canOlder = (to - windowWidth) > oldest
    canNewer = menu.toOffset > 0
  end
  local canMap = canShowOnMap(fleet)

  local controls = menu.infoFrame:addTable(6, {
    tabOrder = 3, width = width, x = x, y = bottom - buttonHeight, reserveScrollBar = false,
    backgroundID = "solid", backgroundColor = Color["frame_background_semitransparent"],
  })
  local arrowWidth = buttonHeight + Helper.borderSize
  controls:setColWidth(2, arrowWidth, false)
  controls:setColWidth(3, arrowWidth, false)

  local options = {}
  for i, windowWidth in ipairs(WIDTHS) do
    options[i] = { id = tostring(i), icon = "", text = widthLabel(windowWidth), displayremoveoption = false }
  end
  -- Interactive widgets need a selectable row, or the whole view is rejected.
  local row = controls:addRow(true, { fixed = true })
  row[1]:createDropDown(options, { startOption = tostring(menu.widthIndex), height = Helper.standardButtonHeight, active = canWindow })
  row[1].handlers.onDropDownConfirmed = menu.selectWidth
  row[2]:createButton({ active = canOlder }):setIcon("widget_arrow_left_01")
  row[2].handlers.onClick = function() return menu.shiftWindow(1) end
  row[3]:createButton({ active = canNewer }):setIcon("widget_arrow_right_01")
  row[3].handlers.onClick = function() return menu.shiftWindow(-1) end
  row[4]:createButton({ active = canNewer }):setText(ReadText(PAGE, 1307), { halign = "center" })
  row[4].handlers.onClick = function() return menu.goNow() end
  row[5]:createButton({ active = not menu.pending }):setText(ReadText(1001, 6401), { halign = "center" })
  row[5].handlers.onClick = function() return menu.buttonRefresh() end
  row[6]:createButton({ active = canMap }):setText(ReadText(1001, 3408), { halign = "center" })
  row[6].handlers.onClick = function() return menu.buttonShowOnMap(fleet) end
end

-- *** standard menu callbacks ***

function menu.onUpdate()
  -- Drained here, not where it was raised: onRowChanged runs inside the engine's own
  -- frame setup and HistoryReady inside an event.
  if menu.refreshQueued then
    menu.refreshQueued = nil
    return menu.createFrame()
  end
  if menu.open and ps.refreshInterval > 0 and (not menu.pending)
      and getElapsedTime() - menu.lastRequestTime >= ps.refreshInterval then
    requestHistory(true)
  end
  if menu.infoFrame then
    menu.infoFrame:update()
  end
end

function menu.onCloseElement(dueToClose)
  AddUITriggeredEvent("ProtectSector", "viewClosed")
  Helper.closeMenu(menu, dueToClose)
  menu.cleanup()
end

-- Read by onShowMenu as "restored", never for its value.
function menu.onSaveState()
  return true
end

local function Init()
  ps.playerId = ConvertStringTo64Bit(tostring(C.GetPlayerID()))
  init()
  RegisterEvent("ProtectSector.OpenMenu", onOpenMenuEvent)
  RegisterEvent("ProtectSector.HistoryReady", onHistoryReady)
end

Register_OnLoad_Init(Init)
