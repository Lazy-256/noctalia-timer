--!nonstrict
-- Alarm timer bar widget. Shows an hourglass, plus the countdown while it runs.
-- Click opens the setup panel; while the alarm rings, click stops it instead.

local STATE = "IDLE"
local formattedTime = "00:00"
local isVertical = false
local hasTooltip = false

local function showTooltip()
  barWidget.setTooltip(formattedTime)
  hasTooltip = true
end

local function hideTooltip()
  -- clearing a tooltip that was never set crashes the plugin
  if hasTooltip then
    barWidget.clearTooltip()
    hasTooltip = false
  end
end

local function render()
  local color = STATE == "NOTIFY" and "error" or nil
  local glyph = STATE == "NOTIFY" and "bell-ringing" or "hourglass"

  if isVertical then
    barWidget.render(ui.column({ align = "center" }, {
      ui.glyph({ name = glyph, color = color }),
    }))
    if STATE == "RUNNING" then
      showTooltip()
    end
    return
  end

  if STATE == "IDLE" and noctalia.getConfig("show_idle_on_horizontal") == false then
    barWidget.render(ui.row({ align = "center" }, {
      ui.glyph({ name = glyph, color = color }),
    }))
    return
  end

  barWidget.render(ui.row({ gap = 6, align = "center" }, {
    ui.glyph({ name = glyph, color = color }),
    ui.label({ text = formattedTime, fontWeight = "bold", color = color }),
  }))
end

-- update runs once on load; it only learns the orientation
function update()
  isVertical = barWidget.isVertical()
  STATE = noctalia.state.get("timer.state") or "IDLE"
  formattedTime = noctalia.state.get("timer.formattedTime") or "00:00"
  render()
end

noctalia.state.watch("timer.state", function(value)
  if isVertical and STATE == "RUNNING" and value ~= "RUNNING" then
    hideTooltip()
  end
  STATE = value
  render()
end)

noctalia.state.watch("timer.formattedTime", function(value)
  formattedTime = value
  if STATE == "RUNNING" then
    render()
  end
end)

function onClick()
  if STATE == "NOTIFY" then
    noctalia.state.set("timer.cmd", "DISMISS" .. ":" .. noctalia.nowMs())
    return
  end
  noctalia.togglePanel("lazy/alarm-timer:panel")
end
