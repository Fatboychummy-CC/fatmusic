# Fat Music

Plays music from "repositories" (aka just a list of songs given). Can queue
music and has a remote control. Actually it's all controlled by the remote.

## Installation

By default, the installer will install to your current directory. To install
somewhere different, add the path to the end of this.

### Client

```
wget run https://raw.githubusercontent.com/Fatboychummy-CC/fatmusic/main/installer.lua client
```

### Server

```
wget run https://raw.githubusercontent.com/Fatboychummy-CC/fatmusic/main/installer.lua server
```

## Repositories

A "repository" is simply a file on the internet somewhere which states the names
and locations of audio files, in the following format:

```
{
  ["Audio Title"] = "download link"
}
```

Please note that currently this only supports `WAV` files, but I plan on adding
more audio functionality soon.

Double note that if I add more functionality, I will most likely need to change
the "repository" specification.

### Adding/removing repositories

It is planned to add this to a menu in the program, but currently the way to add
repositories is to edit the `remotes.lson` file that is generated after the
first run of the client. It is simply a list of strings pointing to a file on
the internet which match the repository spec.

Simply add a link to the repository file, and the client will use that.

## To-do

- [ ] Allow easy addition/removal of repositories.
- [ ] "Skip to this song" feature in the playlist view.
- [ ] More filetype support (should be easy-ish with aukit, but may require a
      breaking change to the way repositories are read)
- [ ] Less clunkiness?
- [ ] Better README?
