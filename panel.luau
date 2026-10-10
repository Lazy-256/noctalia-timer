--!nonstrict
-- Setup panel: type a duration (300 -> 3:00, 10300 -> 1:03:00), then
-- start/pause/reset. Closes itself on start.

local inputDigits = ""
local remaining = 0
local formattedTime = "0"
local STATE = "IDLE"
-- bumped to push a value into the input programmatically
local inputKey = 0

local function parseDigits(digits)
  digits = digits:gsub("[^0-9]", "")
  if digits == "" then
    return 0
  end
  local secs, mins, hours = 0, 0, 0
  if #digits <= 2 then
    secs = tonumber(digits)
  elseif #digits <= 4 then
    secs = tonumber(digits:sub(-2)) or 0
    mins = tonumber(digits:sub(1, -3)) or 0
  else
    secs = math.min(59, tonumber(digits:sub(-2)) or 0)
    mins = math.min(59, tonumber(digits:sub(-4, -3)) or 0)
    hours = tonumber(digits:sub(1, -5)) or 0
  end
  return hours * 3600 + mins * 60 + secs
end

local function render()
  local remainingText = remaining > 0 and formattedTime or "--:--"
  local btnText = STATE == "RUNNING" and noctalia.tr("ui.pause") or noctalia.tr("ui.start")
  local btnVariant = STATE == "RUNNING" and "secondary" or "primary"

  panel.render(ui.column({ gap = 12, padding = 16 }, {
    ui.label({ text = noctalia.tr("ui.duration_label"), fontSize = 16, fontWeight = "bold", color = "primary" }),
    ui.column({ gap = 8, padding = 8, fill = "surface_variant/0.4", radius = 8 }, {
      ui.row({ justify = "center" }, {
        ui.label({
          text = remainingText,
          fontSize = 36,
          fontWeight = "bold",
          color = remaining > 0 and "primary" or "outline",
        }),
      }),
      ui.input({
        key = "dur-" .. inputKey,
        value = inputDigits,
        placeholder = noctalia.tr("ui.duration_placeholder"),
        fontSize = 14,
        focus = true,
        onChange = "onInputChange",
        onSubmit = "onInputSubmit",
        enabled = STATE == "IDLE",
      }),
    }),
    ui.row({ gap = 8, justify = "space_between" }, {
      ui.button({ text = noctalia.tr("ui.reset"), variant = "destructive", onClick = "onReset" }),
      ui.button({ text = btnText, variant = btnVariant, onClick = "onToggle", enabled = remaining > 0 }),
    }),
  }))
end

local function resetInputDigits()
  inputDigits = remaining == 0 and "" or formattedTime
  inputKey = inputKey + 1
end

local function start()
  if STATE == "IDLE" then
    noctalia.state.set("timer.remaining", parseDigits(inputDigits))
  end
  noctalia.state.set("timer.cmd", "START" .. ":" .. noctalia.nowMs())
  panel.close()
end

function onOpen(_context)
  STATE = noctalia.state.get("timer.state") or "IDLE"
  remaining = noctalia.state.get("timer.remaining") or 0
  formattedTime = noctalia.state.get("timer.formattedTime") or "0"
  resetInputDigits()
  render()
end

noctalia.state.watch("timer.state", function(value)
  if STATE == "NOTIFY" and value == "IDLE" then
    resetInputDigits()
  end
  STATE = value
  render()
end)

noctalia.state.watch("timer.formattedTime", function(value)
  formattedTime = value
  render()
end)

noctalia.state.watch("timer.remaining", function(value)
  remaining = value
  render()
end)

function onReset()
  noctalia.state.set("timer.cmd", "RESET" .. ":" .. noctalia.nowMs())
  inputDigits = ""
  inputKey = inputKey + 1
  render()
end

function onInputChange(value)
  if STATE == "IDLE" then
    noctalia.state.set("timer.remaining", parseDigits(value))
    -- do not bump inputKey here: reseeding mid-keystroke resets the cursor
    inputDigits = value
    render()
  end
end

function onInputSubmit()
  if STATE == "IDLE" or STATE == "PAUSED" then
    start()
  end
end

function onToggle()
  if STATE == "RUNNING" then
    noctalia.state.set("timer.cmd", "PAUSE" .. ":" .. noctalia.nowMs())
  elseif STATE == "IDLE" or STATE == "PAUSED" then
    start()
  end
end
