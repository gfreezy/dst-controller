# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Don't Starve Together (DST) mod** that enhances gamepad/controller functionality with custom button combinations and camera controls. It's a client-only mod written in Lua using the DST Modding API (version 10).

## DST Game Scripts Reference

The `scripts/` directory in this project contains the **original DST game interface and implementation files**. These are reference files for understanding DST's internal APIs and should NOT be modified. Use them to:
- Understand DST's control system ([scripts/input.lua](scripts/input.lua))
- Look up component APIs (scripts/components/)
- Find control constants and mappings
- Understand how the game's internal systems work

When implementing mod features, reference these files to understand the game's behavior, but implement your mod logic in `modmain.lua`.

## Core Architecture

### Entry Points
- **modinfo.lua**: Mod metadata and configuration options (exposed in game UI)
- **modmain.lua**: Core implementation with three main systems