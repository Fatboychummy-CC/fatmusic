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
---@field current_position integer The current position in the song. Is -1 if not playing.
---@field remote string The remote url location of the song.
---@field file_type audio_types The audio file type to be used.
---@field audio_options audio_options The audio options to be used.

---@alias audio_types
---| '"pcm"'
---| '"dfpwm"'
---| '"wav"'
---| '"aiff"'
---| '"au"'
---| '"flac"'

---@class audio_options
---@field mono boolean? Whether to mix the audio down to mono.

---@class pcm_options : audio_options
---@field bit_depth pcm_bit_depth? The bit depth of the audio, if data_type is "float", then this MUST be 32.
---@field data_type pcm_data_type? The type of each sample.
---@field channels integer? The amount of channels present in the audio.
---@field sample_rate integer? The sample rate of the audio in Hertz.
---@field big_endian boolean? Whether the audio is big-endian instead of little-endian; ignored if data is a table.

---@class dfpwm_options : audio_options
---@field sample_rate integer? The sample rate of the audio in Hertz.
---@field channels integer? The amount of channels present in the audio.

---@class wav_options : audio_options
---@field ignore_header boolean? Whether to ignore additional headers if they appear later in the audio stream.

---@class aiff_options : audio_options
---@field ignore_header boolean? Whether to ignore additional headers if they appear later in the audio stream.

---@class au_options : audio_options
---@field ignore_header boolean? Whether to ignore additional headers if they appear later in the audio stream.

---@class flac_options : audio_options

---@alias pcm_bit_depth
---| '8'
---| '16'
---| '24'
---| '32'

---@alias pcm_data_type
---| '"signed"'
---| '"unsigned"'
---| '"float"' # Requires 32 bit depth!