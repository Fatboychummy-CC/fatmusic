---@meta

---@generic T
---@class Array<T> : {[integer]:T}

---@generic T
---@class Arrayn<T> : {[integer]:T}
---@field n integer The length of the array.

---@class music_info : {[string]:string} Music information in the format of ["song title"] = "song location" - This is downloaded from a remote server.

---@class song_info
---@field name string The name of the song.
---@field remote string The remote resource location of the song.
