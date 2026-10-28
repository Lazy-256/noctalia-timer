--!nonstrict
-- Time-is-up alert - a persistent overlay [[panel]] opened by the service.
--
-- It has no outside-click dismissal and is not replaced by other panels; the
-- Stop button (or the bar widget / IPC "dismiss") ends it. Closing it any other
-- way (Escape) counts as an acknowledgement and stops the alarm too, so the
-- sound never keeps ringing with nothing on screen to stop it.

local is_open = false

local function formatTime(seconds)
  local m = seconds // 60
  local s = seconds % 60
  if m >= 60 then
    return `{m // 60}:{string.format("%02d", m % 60)}:{string.format("%02d", s)}`
  end
  return `{m}:{string.format("%02d", s)}`
end

local function render()
  local duration = noctalia.state.get("timer.duration") or 0
  local took = duration > 0 and (noctalia.tr("ui.alert_took") .. " " .. formatTime(duration)) or ""

  panel.render(ui.column({ gap = 14, padding = 20, align = "center", justify = "center", fill = "surface", radius = 12 }, {
    ui.glyph({ name = "bell-ringing", size = 52, color = "error" }),
    ui.label({ text = noctalia.tr("ui.notify_body"), fontSize = 24, fontWeight = "bold" }),
    ui.label({ text = took, fontSize = 12, color = "on_surface/0.6", visible = took ~= "" }),
    ui.button({
      text = noctalia.tr("ui.stop"),
      glyph = "player-stop",
      variant = "destructive",
      onClick = "onStop",
    }),
  }))
end

function onOpen(_context)
  is_open = true
  render()
end

-- Escape or any other close while still ringing = acknowledged.
function onClose()
  is_open = false
  if noctalia.state.get("timer.state") == "NOTIFY" then
    noctalia.state.set("timer.cmd", "DISMISS" .. ":" .. noctalia.nowMs())
  end
end

-- Space stops the alarm; only delivered while the panel holds keyboard focus
-- (capture_keys in plugin.toml).
function onKey(chord, pressed)
  if chord == "space" and pressed then
    noctalia.state.set("timer.cmd", "DISMISS" .. ":" .. noctalia.nowMs())
  end
end

function onStop()
  noctalia.state.set("timer.cmd", "DISMISS" .. ":" .. noctalia.nowMs())
end

noctalia.state.watch("timer.state", function(value)
  if is_open and value ~= "NOTIFY" then
    panel.close()
  end
end)
