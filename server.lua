local CHANNEL = 537

local modem = peripheral.find("modem", function(_, wrapped) return wrapped.isWireless() end)
if not modem then error("No modem!", 0) end
modem.open(CHANNEL)

local monitor = peripheral.find("monitor")
monitor.setTextScale(1)
local monitor_name = peripheral.getName(monitor)

local playing = false

local win = window.create(term.current(), 1, 1, term.getSize())
local _print = print
function print(...)
  local old = term.redirect(win)
  local ret = _print(...)
  term.redirect(old)

  return ret
end

local action_id = 0
local function send_action(action, target, extra)
  action_id = action_id + 1
  modem.transmit(CHANNEL, CHANNEL, {
    action = action,
    target = target,
    extra = extra,
    id = action_id
  })
end

local function ack(msg, extra)
  send_action("ack", msg.id, extra)
end

local function play_audio()
  while true do
    local url

    monitor.clear()
    monitor.setCursorPos(1, 1)

    repeat
      local event, _, _, _, msg = os.pullEvent("modem_message")

      if type(msg) == "table" then
        if msg.action == "play_audio" then
          url = msg.target
        elseif msg.action == "stop_audio" then
          ack(msg) -- no audio is playing! Just ack it.
        end
      end
    until url

    print("Playing audio from", url)

    playing = true
    parallel.waitForAny(
      function()
        shell.run("monitor", monitor_name, "austream", url)
      end,
      function()
        while true do
          local event, _, _, _, msg = os.pullEvent("modem_message")

          if type(msg) == "table" then
            if msg.action == "stop_audio" then
              ack(msg)
              print("Stop requested.")
              break
            elseif msg.action == "play_audio" then
              ack(msg, "You must stop the currently playing audio first!")
            end
          end
        end
      end
    )
    playing = false
    print("Player stopped.")
  end
end

local function keep_alive()
  while true do
    local event, _, _, _, msg = os.pullEvent()

    if type(msg) == "table" then
      if msg.action == "keep_alive" then
        print("Received keepalive, ACKing")
        ack(msg)
      elseif msg.action == "get_status" then
        print("Received getstatus, ACKing")
        ack(msg, playing)
      end
    end
  end
end

local ok, err = pcall(parallel.waitForAny, play_audio, keep_alive)

if not ok then
  printError(err)
end
