# Football Club Tycoon

A 3D Roblox football-club management tycoon. See [CLAUDE.md](CLAUDE.md) for the full design and build plan.

## Layout

```
src/shared/   ModuleScripts shared by client and server  -> ReplicatedStorage.Shared
src/server/   Server modules + entry script              -> ServerScriptService.Server
src/client/   Client scripts                             -> StarterPlayer.StarterPlayerScripts.Client
```

`default.project.json` maps these folders for Rojo 7. Until Rojo is installed, scripts are
pushed into Studio through the Roblox Studio MCP; the files on disk are the source of truth.

## Status

Milestone 1: ugly playable loop (play match -> earn -> buy one upgrade).
All economy numbers in `src/shared/Config.luau` are TEMP placeholders.
