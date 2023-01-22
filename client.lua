local transmission = require "transmission"
local menus        = require "menus"
local logging      = require "logging"
local file_helper  = require "file_helper"
local QIT          = require "QIT"

local DIR = fs.getDir(shell.getRunningProgram()) --- Working directory of the program.
local REMOTES_FILE = fs.combine(DIR, "remotes.lson") --- Remotes storage file.
local CONFIG_FILE = fs.combine(DIR, "client-config.lson") --- Config storage file.

local main_context = logging.createContext("MAIN", colors.black, colors.blue)
local http_context = logging.createContext("HTTP", colors.black, colors.brown)
local net_context  = logging.createContext("NET", colors.black, colors.brown)

local log_win      = window.create(term.current(), 1, 1, term.getSize())
local main_win     = window.create(term.current(), 1, 1, term.getSize())
local playlist_win = window.create(term.current(), 1, 1, term.getSize())
local old_win      = term.redirect(main_win)
logging.setWin(log_win)
log_win.setVisible(false)
playlist_win.setVisible(false)

if ... == "debug" then
  logging.setLevel(logging.logLevel.DEBUG)
  logging.setFile("fatmusic_debug-client.txt")
end

main_context.debug("Starting client in '/%s'", DIR)
main_context.debug("Remotes: /%s", REMOTES_FILE)
main_context.debug("Config : /%s", CONFIG_FILE)

---@type Array<string>
local remotes = file_helper.unserialize(REMOTES_FILE, {
  "https://fatboychummy.games/static/cc-audio/stat.lson"
})
-- Ensure the remotes file exists after first run.
file_helper.serialize(REMOTES_FILE, remotes)

---@type table<string, any>
local config = file_helper.unserialize(CONFIG_FILE, {
  channel = 1471,
  response_channel = 1470
})
-- Ensure the config file exists after first run.
file_helper.serialize(CONFIG_FILE, config)

---@type table
local modem = peripheral.find("modem", function(_, w) return w.isWireless() end)
if not modem then
  modem = peripheral.find("modem")
end
if not modem then
  error("No modem connected!", 0)
end

local transmitter = transmission.create(config.channel, config.response_channel, modem,
  logging.createContext("TRAN", colors.black, colors.green))

---@type Array<string>
local TIPS = {
  "Press 'c' to open or close the console.",
  ("You can add your own remote locations by adding to the file %s!"):format(REMOTES_FILE),
  "Press 'p' to view the current playlist.",
  "The server runs a queue, you don't need to wait for a song to end to add another.",
  "Press 'm' to reopen the menus."
}
local tip_n = 0
local function get_tip()
  tip_n = (tip_n + 1) % #TIPS

  return "Tip: " .. TIPS[tip_n + 1]
end

--- Notify the user that something that takes time is occurring.
---@param message string The message to display.
---@param is_error boolean? If the message is an error being displayed, display it in red.
local function notify(message, is_error)
  local old = term.redirect(main_win)
  local old_color = main_win.getTextColor()

  main_win.clear()
  main_win.setCursorPos(1, 1)
  main_win.setTextColor(is_error and colors.red or colors.white)

  print(message)
  print()

  main_win.setTextColor(colors.yellow)
  print(get_tip())

  main_win.setTextColor(old_color)
  term.redirect(old)
end

local function controls_menu()
  local old = term.redirect(main_win)

  main_win.clear()
  main_win.setCursorPos(1, 1)

  print("Controls:\n")

  print("c: Switch to console")
  print("m: Switch to menu")
  print("p: Switch to playlist view\n")

  print("In the menu and playlist view, use up/down arrow keys to move the cursor")
  print("In the menu view, press enter to select an option.\n\n")

  print("Press any key to continue...")
  term.redirect(old)

  sleep()
  os.pullEvent "key"
end

local configs = {
  channel = "number",
  response_channel = "number"
}

local function config_menu()
  local menu = menus.create(main_win, "Configuration")

  local CHANNEL = "channel"
  local RESPONSE_CHANNEL = "response_channel"
  local RETURN = "return"

  local function config_get(value)
    return function()
      return tostring(config[value])
    end
  end

  local overrides = {
    override_width = 13
  }

  menu.addSelection(CHANNEL, "Channel", config_get("channel"), "The channel to send messages on.", overrides)
  menu.addSelection(RESPONSE_CHANNEL, "R-Channel", config_get("response_channel"),
    "The channel to listen for responses on.", overrides)
  menu.addSelection(RETURN, "Return", "", "Return to the previous menu.", overrides)

  repeat
    local selection = menu.run()

    if selection ~= RETURN then
      if configs[selection] == "number" then
        local response
        repeat
          response = tonumber(menus.question(main_win, "Change config",
            ("Enter a number to use for: %s. Enter -1 to cancel."):format(selection)))
        until response
        if response ~= -1 then
          config[selection] = response
          file_helper.serialize(CONFIG_FILE, config)
        end
      end
    end
  until selection == RETURN
end

--- Get information about the remotes.
---@return Arrayn<{remote:string, files:Arrayn<song_info>}>
local function get_remotes()
  local info = QIT()

  http_context.debug("Get remotes")

  for index, remote in ipairs(remotes) do
    local remote_info = { name = remote, files = QIT() }

    http_context.info("Downloading remote: %s", remote)
    local handle, err = http.get(remote)

    if handle then
      local data = handle.readAll()
      handle.close()
      http_context.debug("Success.")

      local unserialized = textutils.unserialize(data)

      if unserialized then
        for name, file in pairs(unserialized) do
          remote_info.files:Insert({ name = name, remote = file }--[[@as song_info]] )
        end

        remote_info.files:Clean()
        info:Insert(remote_info)
      else
        http_context.error("Failed to unserialize remote: %s", remote)
      end
    else
      http_context.error("Failed to download remote: %s (%s)", remote, err)
    end
  end

  http_context.debug("Downloaded all remotes")

  return info:Clean()
end

local function send_action(action)
  local acked, err = transmitter:send(
    action
  )

  if not acked then
    notify("Server did not respond.", true)
    net_context.error("Server did not respond.")
  elseif err then
    notify(("Server responded with error: %s"):format(err), true)
    net_context.error("Server responded with error: %s", err)
  end
  if not acked or err then
    sleep(3)
  else
    notify("Success")
    sleep(0.5)
  end
end

--- Add songs menu: Get remotes, display all available songs.
local function add_songs()
  notify("Downloading remotes... Please wait.")

  local remote_info = get_remotes()

  local menu = menus.create(main_win, "Add Songs")

  local overrides = { override_width = -1 }

  local SEP = "seperator"
  local SKIP = "skip"
  local CLEAR = "clear"
  local RETURN = "return"

  local function make_seperator()
    menu.addSelection(SEP, ("\x8C"):rep(20), "", "", overrides)
  end

  for _, remote in ipairs(remote_info) do
    for _, info in ipairs(remote.files) do
      menu.addSelection(info.remote .. ":::" .. info.name, info.name, "", ("Add '%s' to queue."):format(info.name),
        overrides)
    end
  end

  make_seperator()
  menu.addSelection(SKIP, "Skip current song", "", "Skip the currently playing song.", overrides)
  menu.addSelection(CLEAR, "Clear song queue", "", "Clear the song queue on the server.", overrides)
  menu.addSelection(RETURN, "Return", "", "Return to the previous menu.", overrides)

  repeat
    local selection = menu.run()

    if selection == SKIP then
      notify("Attempting to skip current song.")
      net_context.info("Skip song.")
      send_action(transmission.make_action("skip"))
    elseif selection == CLEAR then
      -- Send the clear notification to the server.
      notify("Attempting to clear song queue.")
      net_context.info("Clear playlist")

      send_action(transmission.make_action("stop"))
    elseif selection ~= RETURN and selection ~= SEP then
      -- Send the information to the server.
      local name = selection:match(":::(.-)$")
      local remote = selection:match("^(.-):::")

      notify(("Attempting to play song '%s'"):format(name))
      net_context.info("Add to playlist '%s'", name)

      send_action(transmission.make_action(
        "add-to-playlist",
        {
          name = name,
          remote = remote
        }
      ))
    end
  until selection == RETURN
end

--- Display the main menu.
local function main_menu()
  local menu = menus.create(main_win, "Main menu")

  local ADD_SONGS = "addsongs"
  local CONFIG = "config"
  local CONTROLS = "controls"
  local EXIT = "exit"

  local overrides = { override_width = -1 }

  menu.addSelection(ADD_SONGS, "Songs", "", "Add/remove songs to/from the queue.", overrides)
  menu.addSelection(CONFIG, "Config", "", "Change configation settings.", overrides)
  menu.addSelection(CONTROLS, "Controls", "", "View the controls.", overrides)
  menu.addSelection(EXIT, "Exit", "", "Exit this program.", overrides)

  repeat
    local selection = menu.run()

    if selection == ADD_SONGS then
      add_songs()
    elseif selection == CONFIG then
      config_menu()
    elseif selection == CONTROLS then
      controls_menu()
    end
  until selection == EXIT
  main_context.info("Exiting program.")
end

--- Generate a random 8-length string
---@return string randomized_string The random string generated.
local function gen_random_string8()
  local str = ""
  for i = 1, 8 do
    str = str .. string.char(math.random(0, 255))
  end
  return str
end

local playlist_context = logging.createContext("PLAYLIST", colors.black, colors.purple)
--- Get the current playlist
---@return Arrayn<song_info>? playlist The playlist.
local function get_playlist()
  playlist_context.debug("No playlist supplied - must request.")
  local acked, err, data = transmitter:send(
    transmission.make_action(
      "get-playlist"
    )
  )

  if not acked then
    playlist_context.error("get-playlist not ACKed")
    return
  end
  if err then
    playlist_context.error("get-playlist error: %s", err)
    return
  end
  if not data then
    playlist_context.error("get-playlist ACKed but no data supplied.")
    return { n = 0 }
  end

  return data or { n = 0 }
end

--- Get the currently playing song.
---@return song_info? info Song information.
local function get_playing()
  local acked, err, data = transmitter:send(
    transmission.make_action(
      "get-playing"
    )
  )

  if not acked then
    playlist_context.error("get-playing not ACKed")
    return
  end
  if err then
    playlist_context.error("get-playing error: %s", err)
    return
  end

  return data
end

local function playlist()
  local menu = menus.create(playlist_win, "Current playlist")

  --- Get the playlist, add it to the menu.
  ---@param current song_info? The currently playing song.
  ---@param list Arrayn<song_info>? The playlist.
  local function update_list(current, list)
    if not list then
      list = get_playlist()
      current = get_playing()
    end
    if not list then return end

    playlist_context.debug("Got %d items in playlist.", list.n)

    local overrides = { override_width = -1 }

    menu.clearSelections()
    menu.addSelection("refresh", "Refresh", "", "Refresh this listing.", overrides)

    if current then
      menu.addSelection(gen_random_string8(), current.name, "", current.name, overrides)
    end

    for _, song_info in ipairs(list) do
      menu.addSelection(gen_random_string8(), song_info.name, "", song_info.name, overrides)
    end
  end

  parallel.waitForAny(
    function()
      while true do
        local sel = menu.run()

        if sel == "refresh" then update_list() menu.redraw() end
      end
    end,
    function()
      update_list()
      menu.redraw()

      while true do
        local action = transmitter:receive("song-update")

        playlist_context.debug(textutils.serialize(action.data.playlist))

        update_list(action.data.playing, action.data.playlist)
        menu.redraw()
      end
    end
  )
end

local function window_controller()
  while true do
    local _, key = os.pullEvent "key"

    if key == keys.c then
      playlist_win.setVisible(false)
      main_win.setVisible(false)
      log_win.setVisible(true)
    elseif key == keys.p then
      main_win.setVisible(false)
      log_win.setVisible(false)
      playlist_win.setVisible(true)
    elseif key == keys.m then
      log_win.setVisible(false)
      playlist_win.setVisible(false)
      main_win.setVisible(true)
    end
  end
end

--- Main function which runs all of the code.
local function main()
  parallel.waitForAny(main_menu, window_controller, playlist)
end

local ok, err = pcall(main)

term.redirect(old_win)
log_win.setVisible(true)

if not ok then
  main_context.error(err)
end
