---@meta

---@class server_info
---@field connected_server string? The currently connected server's name, or nil if not connected to one.
---@field song_info song_info? The current song info, if one is playing.
---@field playlist song_info_list_c

---@alias song_info_list table<integer, song_info>

---@class song_info_list_c
---@field list song_info_list The list of songs.
---@field current integer The current song index. Index 0 means no playlist is running.

---@class song_info
---@field name string The name of the song.
---@field genre string The genre of the song.
---@field artist string The artist of the song.
---@field length integer The length of the song in seconds (rounded up).
---@field playing boolean If the song is currently playing (true) or paused (false).
