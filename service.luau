--!nonstrict
-- Alarm timer service - the headless [[service]] entry.
--
-- Owns the countdown and publishes it through noctalia.state; the bar widget,
-- setup panel, alert panel and desktop widget are thin clients that send
-- commands through "timer.cmd".
--
-- States: IDLE, RUNNING, PAUSED, NOTIFY. NOTIFY (time is up) never times out:
-- the alarm keeps ringing and the alert panel stays open until DISMISS/RESET.

noctalia.setUpdateInterval(1000)

local ALERT_PANEL = "lazy/alarm-timer:alert"

local function formatTime(seconds)
  local m = seconds // 60
  local s = seconds % 60
  if m >= 60 then
    return `{m // 60}:{string.format("%02d", m % 60)}:{string.format("%02d", s)}`
  end
  return `{m}:{string.format("%02d", s)}`
end

noctalia.state.set("timer.state", "IDLE")
noctalia.state.set("timer.remaining", 0)
noctalia.state.set("timer.formattedTime", "0")
-- Countdown total captured on start, for progress bars. 0 when cleared.
noctalia.state.set("timer.duration", 0)

noctalia.state.watch("timer.remaining", function(value)
  noctalia.state.set("timer.formattedTime", formatTime(value))
end)

---- Alarm sound
-- The shell's own noctalia.sound.* honors [audio].enable_sounds, which many
-- people keep off, so an alarm that depends on it can stay silent. The alarm is
-- played through a system player instead and replayed from the tick for as long
-- as the state is NOTIFY.
local FALLBACK_PLAYER = "paplay"
local playing = false

local function soundPath()
  local custom = noctalia.getConfig("sound_file")
  if type(custom) == "string" and custom ~= "" then
    return custom
  end
  local dir = noctalia.pluginDir()
  return dir and (dir .. "/sounds/alarm.wav") or "sounds/alarm.wav"
end

local function playAlarm()
  if playing or noctalia.getConfig("sound") ~= true then
    return
  end
  local player = noctalia.getConfig("sound_player")
  if type(player) ~= "string" or player == "" then
    player = "pw-play"
  end
  local path = soundPath()
  playing = true
  local function done(result)
    if result.exitCode ~= 0 and player ~= FALLBACK_PLAYER then
      -- Player missing or failed: try the PulseAudio client once per beep.
      local started = noctalia.runAsync({ FALLBACK_PLAYER, path }, function(r2)
        playing = false
        if r2.exitCode ~= 0 then
          noctalia.log(`Alarm sound failed: {r2.stderr}`)
        end
      end)
      if not started then
        playing = false
      end
    else
      playing = false
    end
  end
  if not noctalia.runAsync({ player, path }, done) then
    playing = false
  end
end

---- Alert panel
local function openAlert()
  noctalia.runAsync({ "noctalia", "msg", "panel-open", ALERT_PANEL }, function(result)
    if result.exitCode ~= 0 then
      noctalia.log(`Could not open alert panel: {result.stderr}`)
    end
  end)
end

local function closeAlert()
  noctalia.runAsync({ "noctalia", "msg", "panel-close", ALERT_PANEL }, function() end)
end

---- Transitions
local function resetTimer()
  local wasNotify = noctalia.state.get("timer.state") == "NOTIFY"
  noctalia.state.set("timer.remaining", 0)
  noctalia.state.set("timer.duration", 0)
  noctalia.state.set("timer.state", "IDLE")
  if wasNotify then
    closeAlert()
  end
end

local function finish()
  noctalia.state.set("timer.state", "NOTIFY")
  if noctalia.getConfig("notify") == true then
    noctalia.notify(noctalia.tr("ui.notify_title"), noctalia.tr("ui.notify_body"))
  end
  openAlert()
  playAlarm()
end

local actions = {
  PAUSE = function()
    noctalia.state.set("timer.state", "PAUSED")
  end,
  START = function()
    local remaining = noctalia.state.get("timer.remaining")
    local state = noctalia.state.get("timer.state")
    if (state == "IDLE" or state == "PAUSED") and remaining > 0 then
      if state == "IDLE" then
        noctalia.state.set("timer.duration", remaining)
      end
      noctalia.state.set("timer.state", "RUNNING")
    end
  end,
  RESET = resetTimer,
  DISMISS = resetTimer,
}

noctalia.state.watch("timer.cmd", function(cmd)
  -- UIs append ":<ms>" so that repeating a command still changes the value
  local name = string.match(cmd, "^[^:]+")
  local action = name and actions[name]
  if action then
    action()
  else
    noctalia.log(`Unknown command: {cmd}`)
  end
end)

function update()
  local state = noctalia.state.get("timer.state")
  if state == "RUNNING" then
    local remaining = noctalia.state.get("timer.remaining")
    if remaining > 0 then
      noctalia.state.set("timer.remaining", remaining - 1)
    else
      finish()
    end
  elseif state == "NOTIFY" then
    playAlarm()
  end
end

-- IPC: noctalia msg plugin lazy/alarm-timer:timer all <event> [payload]
--   start <minutes>   ignored while a countdown is running; otherwise replaces
--                     the countdown (also out of a ringing alarm)
--   pause             pause, or resume when paused
--   cancel | reset    back to idle
--   dismiss           stop the ringing alarm and close the alert
function onIpc(event, payload)
  local state = noctalia.state.get("timer.state")
  if event == "start" then
    local mins = tonumber(payload)
    local seconds = mins and math.floor(mins * 60)
    if seconds and seconds > 0 and seconds < math.huge and state ~= "RUNNING" then
      local wasNotify = state == "NOTIFY"
      noctalia.state.set("timer.remaining", seconds)
      noctalia.state.set("timer.duration", seconds)
      noctalia.state.set("timer.state", "RUNNING")
      if wasNotify then
        closeAlert()
      end
    end
  elseif event == "pause" then
    if state == "RUNNING" then
      actions.PAUSE()
    elseif state == "PAUSED" then
      actions.START()
    end
  elseif event == "cancel" or event == "reset" or event == "dismiss" then
    resetTimer()
  end
end
