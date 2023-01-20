--- Server program that actually plays audio.

--#region Type definitions

---@class song_info
---@field name string The name of the song.
---@field remote string The remote resource location of the song.

--#endregion

local transmission = require "transmission"
local file_helper  = require "file_helper"
local aukit        = require "aukit"
local deep_copy    = require "deep_copy"
local QIT          = require "QIT"

local mon = peripheral.find "monitor"

local config = file_helper.unserialize(".fatmusic_config", {
  channel = 1470,
  response_channel = 1471
})

local modem
modem = peripheral.find("modem", function(_, wrapped) return wrapped.isWireless() end)
if not modem then
  modem = peripheral.find("modem")

  if not modem then
    error("No modem is connected to the computer!", 0)
  end
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
      while true do
        local action = transmitter:receive()

        if seen_messages[action.system_id] and seen_messages[action.system_id][action.transmission_id] then
          -- If we receive a duplicate message, send the same response back.
          transmitter:send(seen_messages[action.system_id][action.transmission_id], true)
        else
          local response

          if not seen_messages[action.system_id] then
            seen_messages[action.system_id] = {}
          end

          if action.action == "get-playlist" then
            response = get_playlist()
          elseif action.action == "get-playing" then
            response = get_currently_playing()
          elseif action.action == "add-to-playlist" then
            if type(action.data) == "table" then
              if not action.data.name then
                response = transmission.error(action, "Song information table is missing field 'name'.")
              elseif not action.data.remote then
                response = transmission.error(action, "Song information table is missing field 'remote'.")
              else
                play_audio(action.data.name, action.data.remote)
                response = transmission.ack(action)
                os.queueEvent("fatmusic:song_update") -- broadcast the new playlist.
              end
            else
              response = transmission.error(action, "Expected song information table for data.")
            end
          elseif action.action == "stop" then
            playlist = QIT()
            os.queueEvent("fatmusic:stop")
            response = transmission.ack(action)
          elseif action.action == "skip" then
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
      local was_playing = false
      while true do
        currently_playing = get_next_song()

        if currently_playing then
          os.queueEvent("fatmusic:song_update")
          was_playing = true

          parallel.waitForAny(
          --- Actually plays the music, displays info to the monitor as well.
            function()
              if currently_playing.remote:match("%.wav$") then
                local handle = http.get(currently_playing.remote)
                local data = handle.readAll()
                handle.close()

                local iter, length = aukit.stream.wav(data, true)
                local formatter = "%02d:%02d / %02d:%02d"
                local w, h = mon.getSize()

                mon.setCursorPos(math.floor(w / 2 - #currently_playing.name / 2 + 0.5), math.ceil(h / 2) - 1)
                mon.write(currently_playing.name)

                aukit.play(iter, function(pos)
                  pos = math.min(pos, 5999)
                  mon.setCursorPos(math.floor(w / 2 - #formatter / 2 + 0.5), math.ceil(h / 2))
                  mon.write(formatter:format(math.floor(pos / 60), pos % 60, math.floor(length / 60), length % 60))
                end, 1, peripheral.find "speaker")
              else
                transmitter:send(transmission.make_action("song-error", nil,
                  ("Song %s is not of .wav type."):format(currently_playing.name)), true)
              end
            end,

            --- Listens for stop or skip events, stops the song that is currently playing when it receives one.
            function()
              while true do
                local event = os.pullEvent()
                if event == "fatmusic:stop" or event == "fatmusic:skip" then
                  break
                end
              end
            end
          )
        elseif was_playing then
          was_playing = false
          os.queueEvent("fatmusic:song_update")
        end

        sleep(1)
      end
    end
  )
end

local ok, err = pcall(server)

if not ok then
  printError(err)
end
