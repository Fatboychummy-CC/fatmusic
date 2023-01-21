--- Server program that actually plays audio.

local transmission = require "transmission"
local file_helper  = require "file_helper"
local aukit        = require "aukit"
local logging      = require "logging"
local deep_copy    = require "deep_copy"
local QIT          = require "QIT"

local DIR = fs.getDir(shell.getRunningProgram())
local CONFIG_FILE = fs.combine(DIR, "server-config.lson")

local main_context = logging.createContext("MAIN", colors.black, colors.blue)
local mon = peripheral.find "monitor"
local log_win = window.create(term.current(), 1, 1, term.getSize())
logging.setWin(log_win)

local config = file_helper.unserialize(CONFIG_FILE, {
  channel = 1470,
  response_channel = 1471
})

if ... == "debug" then
  logging.setLevel(logging.logLevel.DEBUG)
  logging.setFile("fatmusic_debug-server.txt")
end

main_context.debug("Starting server in '/%D'", DIR)
main_context.debug("Config : %s", CONFIG_FILE)

main_context.debug("Finding modem.")
local modem
modem = peripheral.find("modem", function(_, wrapped) return wrapped.isWireless() end)
if not modem then
  modem = peripheral.find("modem")
end
if not modem then
  main_context.error("No modem is connected to the computer!", 0)
  return
end

local transmitter = transmission.create(config.channel, config.response_channel, modem)

--- Run the server.
local function server()
  local playlist = QIT() ---@type QIT<song_info>
  local currently_playing ---@type song_info?

  --- Add music to the playlist.
  ---@param name string
  ---@param remote string
  local function play_audio(name, remote)
    playlist:Insert({ name = name, remote = remote }--[[@as song_info]] )
  end

  --- Get the current playlist as an action to send to the client.
  ---@return action playlist The playlist information.
  local function get_playlist()
    return transmission.make_action("playlist", deep_copy(playlist):Clean())
  end

  --- Get the currently playing song.
  ---@return action currently_playing The song currently playing.
  local function get_currently_playing()
    return transmission.make_action("now-playing", deep_copy(currently_playing))
  end

  --- When the song updates, get information about everything and transmit it.
  ---@return action song_update The updated information.
  local function get_broadcast_info()
    return transmission.make_action(
      "song-update",
      {
        playing = deep_copy(currently_playing),
        playlist = deep_copy(playlist):Clean()
      }
    )
  end

  --- Get the next song in the queue.
  ---@return song_info song_info The song information
  local function get_next_song()
    return playlist:Drop()
  end

  local seen_messages = {}

  parallel.waitForAny(
  --- Listener coroutine - listen for commands from clients.
    function()
      local listener_context = logging.createContext("LISTENER", colors.black, colors.yellow)

      listener_context.info("Listening for commands.")
      while true do
        local action = transmitter:receive()

        if seen_messages[action.system_id] and seen_messages[action.system_id][action.transmission_id] then
          -- If we receive a duplicate message, send the same response back.
          transmitter:send(seen_messages[action.system_id][action.transmission_id], true)
          listener_context.debug("Got duplicate message, resending response.")
        else
          local response

          if not seen_messages[action.system_id] then
            seen_messages[action.system_id] = {}
          end

          if action.action == "get-playlist" then
            listener_context.debug("Get playlist")
            response = get_playlist()
          elseif action.action == "get-playing" then
            listener_context.debug("Get currently playing")
            response = get_currently_playing()
          elseif action.action == "add-to-playlist" then
            listener_context.debug("Add to playlist")
            if type(action.data) == "table" then
              if not action.data.name then
                listener_context.error("Received song information table missing field 'name'.")
                response = transmission.error(action, "Song information table is missing field 'name'.")
              elseif not action.data.remote then
                listener_context.error("Received song information table missing field 'remote'.")
                response = transmission.error(action, "Song information table is missing field 'remote'.")
              else
                listener_context.debug("Add to playlist: %s (%s)", action.data.name, action.data.remote)
                play_audio(action.data.name, action.data.remote)
                response = transmission.ack(action)
                os.queueEvent("fatmusic:song_update") -- broadcast the new playlist.
              end
            else
              listener_context.error("Received song information was not a table.")
              response = transmission.error(action, "Expected song information table for data.")
            end
          elseif action.action == "stop" then
            listener_context.debug("Stop")
            playlist = QIT()
            os.queueEvent("fatmusic:stop")
            response = transmission.ack(action)
          elseif action.action == "skip" then
            listener_context.debug("Skip")
            os.queueEvent("fatmusic:skip")
            response = transmission.ack(action)
          elseif action.action == "alive" then
            response = transmission.ack(action)
          end

          seen_messages[action.system_id][action.transmission_id] = response
          transmitter:send(response, true)
        end
      end
    end,

    --- Music update coroutine - Send information to clients when song changes.
    function()
      while true do
        os.pullEvent("fatmusic:song_update")
        transmitter:send(get_broadcast_info())
      end
    end,

    --- Music playing coroutine - Plays the music.
    function()
      local play_context = logging.createContext("PLAYER", colors.black, colors.green)
      local was_playing = false
      while true do
        currently_playing = get_next_song()

        if currently_playing then
          play_context.info("Next song: %s", currently_playing.name)
          play_context.debug("Playing from: %s", currently_playing.remote)
          os.queueEvent("fatmusic:song_update")
          was_playing = true

          parallel.waitForAny(
          --- Actually plays the music, displays info to the monitor as well.
            function()
              if currently_playing.remote:match("%.wav$") then
                play_context.debug("Downloading remote...")
                local handle, err = http.get(currently_playing.remote)
                if not handle then
                  play_context.error("Failed to download file: %s", err)
                  return
                end
                local data = handle.readAll()
                handle.close()
                play_context("Song downloaded.")

                local iter, length = aukit.stream.wav(data, true)
                local formatter = "%02d:%02d / %02d:%02d"
                local w, h = mon.getSize()

                mon.setCursorPos(math.floor(w / 2 - #currently_playing.name / 2 + 0.5), math.ceil(h / 2) - 1)
                mon.write(currently_playing.name)

                play_context.debug("Begin playing song.")
                aukit.play(iter, function(pos)
                  pos = math.min(pos, 5999)
                  mon.setCursorPos(math.floor(w / 2 - #formatter / 2 + 0.5), math.ceil(h / 2))
                  mon.write(formatter:format(math.floor(pos / 60), pos % 60, math.floor(length / 60), length % 60))
                end, 1, peripheral.find "speaker")

                play_context.debug("Song finished.")
              else
                play_context.error("Song %s is not of .wav type.", currently_playing.name)
                transmitter:send(transmission.make_action("song-error", nil,
                  ("Song %s is not of .wav type."):format(currently_playing.name)), true)
              end
            end,

            --- Listens for stop or skip events, stops the song that is currently playing when it receives one.
            function()
              while true do
                local event = os.pullEvent()
                if event == "fatmusic:stop" or event == "fatmusic:skip" then
                  play_context.warn("Stop or skip requested during playback.")
                  break
                end
              end
            end
          )
        elseif was_playing then
          was_playing = false
          os.queueEvent("fatmusic:song_update")
          play_context.info("Next song: None.")
        end

        sleep(1)
      end
    end
  )
end

main_context.debug("Start.")
local ok, err = pcall(server)

if not ok then
  printError(err)
end
