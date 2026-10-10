--!nonstrict
-- Alarm timer desktop widget: +/- duration adjusters, progress bar and
-- start/pause/reset. While the alarm rings the controls give way to a Stop
-- button. Desktop widgets cannot take keyboard focus, hence no text input.

local color = noctalia.getConfig("color")
local showProgress = noctalia.getConfig("show_progress")

local STATE = "IDLE"
local remaining = 0
local formattedTime = "0"
local duration = 0

local function timeColor()
  if STATE == "NOTIFY" then
    return "error"
  elseif remaining > 0 then
    return color
  end
  return "outline"
end

local function render()
  local rows = {
    ui.label({
      text = STATE == "NOTIFY" and noctalia.tr("ui.notify_body") or (remaining > 0 and formattedTime or "--:--"),
      fontSize = STATE == "NOTIFY" and 26 or 34,
      fontWeight = "bold",
      color = timeColor(),
    }),
  }

  if STATE == "NOTIFY" then
    table.insert(rows, ui.button({
      text = noctalia.tr("ui.stop"),
      glyph = "player-stop",
      variant = "destructive",
      onClick = "onDismiss",
    }))
    desktopWidget.render(ui.column({ gap = 10, align = "center" }, rows))
    return
  end

  if showProgress then
    table.insert(rows, ui.progress({
      progress = duration > 0 and remaining / duration or 0,
      fill = color,
      width = 160,
      height = 6,
      radius = 3,
    }))
  end

  if STATE == "IDLE" then
    table.insert(rows, ui.row({ gap = 4, justify = "center" }, {
      ui.button({ text = "-1m", variant = "ghost", controlSize = "sm", onClick = "onMinus1" }),
      ui.button({ text = "+1m", variant = "ghost", controlSize = "sm", onClick = "onPlus1" }),
      ui.button({ text = "+5m", variant = "ghost", controlSize = "sm", onClick = "onPlus5" }),
    }))
  end

  table.insert(rows, ui.row({ gap = 8, justify = "center" }, {
    ui.button({ text = noctalia.tr("ui.reset"), variant = "destructive", onClick = "onReset" }),
    ui.button({
      text = STATE == "RUNNING" and noctalia.tr("ui.pause") or noctalia.tr("ui.start"),
      variant = STATE == "RUNNING" and "secondary" or "primary",
      onClick = "onToggle",
      enabled = remaining > 0,
    }),
  }))

  desktopWidget.render(ui.column({ gap = 10, align = "center" }, rows))
end

local function adjust(deltaSeconds)
  if STATE ~= "IDLE" then
    return
  end
  noctalia.state.set("timer.remaining", math.max(0, remaining + deltaSeconds))
end

noctalia.state.watch("timer.state", function(value) STATE = value; render() end)
noctalia.state.watch("timer.formattedTime", function(value) formattedTime = value; render() end)
noctalia.state.watch("timer.remaining", function(value) remaining = value; render() end)
noctalia.state.watch("timer.duration", function(value) duration = value; render() end)

function onMinus1() adjust(-60) end
function onPlus1() adjust(60) end
function onPlus5() adjust(300) end
function onReset() noctalia.state.set("timer.cmd", "RESET" .. ":" .. noctalia.nowMs()) end
function onDismiss() noctalia.state.set("timer.cmd", "DISMISS" .. ":" .. noctalia.nowMs()) end

function onToggle()
  noctalia.state.set("timer.cmd", (STATE == "RUNNING" and "PAUSE" or "START") .. ":" .. noctalia.nowMs())
end

STATE = noctalia.state.get("timer.state") or "IDLE"
remaining = noctalia.state.get("timer.remaining") or 0
formattedTime = noctalia.state.get("timer.formattedTime") or "0"
duration = noctalia.state.get("timer.duration") or 0
render()
