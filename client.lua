local transmission = require "transmission"
local menus        = require "menus"
local logging      = require "logging"
local file_helper  = require "file_helper"
local QIT          = require "QIT"
local deep_copy    = require "deep_copy"

local DIR = fs.getDir(shell.getRunningProgram()) --- Working directory of the program.
local REMOTES_FILE = fs.combine(DIR, "remotes.lson") --- Remotes storage file.
local CONFIG_FILE = fs.combine(DIR, "client-config.lson") --- Config storage file.

local main_context = logging.createContext("MAIN", colors.black, colors.blue)
local http_context = logging.createContext("HTTP", colors.black, colors.brown)
local log_win = window.create(term.current(), 1, 1, term.getSize())
logging.setWin(log_win)
local main_win = window.create(term.current(), 1, 1, term.getSize())
local old_win = term.redirect(main_win)

log_win.setVisible(false)

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

local transmitter = transmission.create(config.channel, config.response_channel, modem)

---@type Array<string>
local TIPS = {
  "Press 'c' to open or close the console.",
  ("You can add your own remote locations by adding to the file %s!"):format(REMOTES_FILE),
  "The server runs a queue, you don't need to wait for a song to end to add another.",

}
local tip_n = 0
local function get_tip()
  tip_n = (tip_n + 1) % #TIPS

  return "Tip: " .. TIPS[tip_n + 1]
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

--- Add songs menu: Get remotes, display all available songs.
local function add_songs()
  main_win.clear()
  local old = term.redirect(main_win)
  print("Downloading remotes... Please wait.")
  print()
  local old_color = main_win.getTextColor()
  main_win.setTextColor(colors.yellow)
  print(get_tip())
  main_win.setTextColor(old_color)

  term.redirect(old)


  local remote_info = get_remotes()

  local menu = menus.create(main_win, "Add Songs")

  local overrides = { override_width = -1 }
  for _, remote in ipairs(remote_info) do
    for _, info in ipairs(remote.files) do
      menu.addSelection(info.remote .. ":::" .. info.name, info.name, "", ("Add '%s' to queue."):format(info.name),
        overrides)
    end
  end

  local CLEAR = "clear"
  local RETURN = "return"

  menu.addSelection(CLEAR, "Clear song queue", "", "Clear the song queue on the server.", overrides)
  menu.addSelection(RETURN, "Return", "", "Return to the previous menu.", overrides)

  repeat
    local selection = menu.run()

    if selection == CLEAR then
      -- Send the clear notification to the server.
    elseif selection ~= RETURN then
      -- Send the information to the server.
      transmitter:send(transmission.make_action("add-to-playlist",
        { name = selection:match(":::(.-)$"), remote = selection:match("^(.-):::") }))
    end
  until selection == RETURN
end

--- Display the main menu.
local function main_menu()
  local menu = menus.create(main_win, "Main menu")

  local ADD_SONGS = "addsongs"
  local VIEW_QUEUE = "viewqueue"
  local CONFIG = "config"
  local EXIT = "exit"

  local overrides = { override_width = -1 }

  menu.addSelection(ADD_SONGS, "Add songs to queue", "", "Add songs to the player's queue.", overrides)
  menu.addSelection(VIEW_QUEUE, "View the queue", "", "View the player's queue.", overrides)
  menu.addSelection(CONFIG, "Config", "", "Change configation settings.", overrides)
  menu.addSelection(EXIT, "Exit", "", "Exit this program, returning to the CraftOS shell.", overrides)

  repeat
    local selection = menu.run()

    if selection == ADD_SONGS then
      add_songs()
    elseif selection == VIEW_QUEUE then

    elseif selection == CONFIG then

    end
  until selection == EXIT
  main_context.info("Exiting program.")
end

local function console()
  --- Controls whether the console is currently visible or the menus are visible.
  local console_visible = false

  while true do
    local _, key = os.pullEvent "key"
    if key == keys.c then
      if console_visible then
        -- set the main window visible second.
        log_win.setVisible(false)
        main_win.setVisible(true)
      else
        -- Set the log window visible second.
        main_win.setVisible(false)
        log_win.setVisible(true)
      end

      console_visible = not console_visible
    end
  end
end

--- Main function which runs all of the code.
local function main()
  parallel.waitForAny(main_menu, console)
end

local ok, err = pcall(main)

term.redirect(old_win)
log_win.setVisible(true)

if not ok then
  main_context.error(err)
end
