local menus = require "menus"

local CHANNEL = 537

local BASE_URL = "https://fatboychummy.games/static/cc-audio/"
local STAT = BASE_URL .. "stat.lson"

local win = window.create(term.current(), 1, 1, term.getSize())
local modem = peripheral.find("modem")
if not modem then
  error("No modem attached! Craft an 'Ender Modem' and put the computer in the crafting table with it.", 0)
end

local deboog_win = window.create(term.current(), 1, 1, term.getSize())

modem.open(CHANNEL)

local function deboog(...)
  local old = term.redirect(deboog_win)
  print(...)
  term.redirect(old)
end

local function refresh_listings()
  local h, err = http.get(STAT)

  if not h then
    error("Failed to stat: " .. tostring(err), 0)
  end

  local data = h.readAll()
  h.close()

  return textutils.unserialise(data)
end

local action_id = 0
local function send_action(action, target, dont_debug, desc)
  if not dont_debug then
    deboog_win.setBackgroundColor(colors.black)
    deboog_win.clear()
    deboog_win.setCursorPos(1, 1)
    if desc then deboog(desc) end
  end

  action_id = action_id + 1

  local attempts = 0
  local acked = false
  local extra
  repeat
    attempts = attempts + 1
    if not dont_debug then
      deboog("Attempt:", attempts)
    end

    modem.transmit(CHANNEL, CHANNEL, {
      action = action,
      target = target,
      id = action_id
    })

    local timer = os.startTimer(1)

    repeat
      local event, tmr, _, _, msg = os.pullEvent()

      --      deboog(event, tmr, msg, "(", action_id, ")")
      --      if type(msg) == "table" then
      --        deboog(textutils.serialize(msg))
      --      end
      if type(msg) == "table" and msg.action == "ack" and msg.target == action_id then
        --        deboog("ACKED")
        acked = true
        extra = msg.extra
      end
    until acked or (event == "timer" and tmr == timer)
  until acked or attempts > (dont_debug and 0 or 5)

  if not dont_debug then
    if acked then
      deboog("Server acknowledged.")
    else
      deboog("Failed too many times.")
    end
    sleep(2)
  end

  return acked, extra
end

local function audio_menu()
  local menu = menus.create(win, "Play audio")

  local STOP = "stop"
  local REFRESH = "refresh"
  local EXIT = "exit"

  local overrides = { override_width = -2 }

  menu.addSelection(STOP, "Stop current audio", "", "Stop the currently playing audio.", overrides)
  menu.addSelection(REFRESH, "Refresh listing", "", "Refresh the available audio.", overrides)

  local listed = {}

  local function update()
    for i = #listed, 1, -1 do
      menu.removeSelection(listed[i])
      listed[i] = nil
    end

    local listings = refresh_listings()

    for k, v in pairs(listings) do
      menu.addSelection(v, k, "", "Play this song.", overrides)
      table.insert(listed, v)
    end

    menu.removeSelection(EXIT)
    menu.addSelection(EXIT, "Exit", "", "Exit this program.", overrides)
  end

  update()

  repeat
    local selection = menu.run()

    if selection == STOP then
      send_action("stop_audio", "")
    elseif selection == REFRESH then
      update()
    elseif selection ~= EXIT then
      send_action("play_audio", BASE_URL .. selection, nil, "Stopping audio")
    end
  until selection == EXIT
end

local function keep_alive()
  local x, y = term.getSize()
  while true do
    local connected = send_action("keep_alive", "", true)
    local status_acked, status = send_action("get_status", "", true)

    --    deboog(connected, status_acked, status)

    local old = term.getBackgroundColor()

    term.setCursorPos(x - 1, 1)
    if connected then
      term.setBackgroundColor(colors.green)
    else
      term.setBackgroundColor(colors.red)
    end
    term.write ' '

    if status then
      term.setBackgroundColor(colors.green)
    else
      term.setBackgroundColor(colors.red)
    end
    term.write ' '

    term.setBackgroundColor(old)
    sleep(1)
  end
end

local ok, err = pcall(parallel.waitForAny, audio_menu, keep_alive)
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
print()
if not ok then
  printError(err)
end
