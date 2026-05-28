# AGENTS.md

## Project Overview

onion.nvim is a Neovim plugin that provides layered configuration - clean defaults with user overrides on top.

## Plugin Structure

This is a Neovim plugin written in Lua. Standard Neovim plugin structure applies:
- `lua/onion/` - Main plugin modules
- `lua/onion/init.lua` - just returns `require("onion.config")`
- `lua/onion/config.lua` - Entry point, typically exports `setup()` function
- `lua/onion/ui.lua` - functions that implement ui, if any
- `lua/onion/commands.lua` - defines vim commands if any. loaded by the plugin
- `plugin/` - Auto-loaded Vim/Lua files (optional)
- `doc/` - Help documentation in vimdoc format (optional)
- `README.md`
- 'spec/onion_spec.lua' - test definitions for "busted"

## Think Before Coding
Before editing, identify the goal, assumptions, and any ambiguity. Ask only when ambiguity blocks progress.

## Simplicity First
Prefer the smallest working change. Do not add abstractions, dependencies, frameworks, or configuration unless directly required.

## Surgical Changes
Change only files relevant to the task. Avoid unrelated cleanup, formatting, renaming, or refactoring.

## Goal-Driven Execution
Define what “done” means before implementation. After changes, run the most relevant checks or explain why they were not run.

## Preserve Existing Behavior
Do not change public APIs, data formats, tests, or UX behavior unless explicitly requested.

## Communicate Clearly
Summarize what changed, what was verified, and any risks or follow-up work.
## Development Commands

Do NOT run tests or build command unless prompted.

## Code Style Guidelines

**Formatting (.stylua.toml):**
- 2-space indentation, 100 character line width
- Single quotes preferred, call parentheses always
- Sort requires automatically

**Type Annotations:**
- Use `---@class`, `---@field`, `---@param`, `---@return` extensively
- LS annotations for better type checking and autocompletion

**Naming Conventions:**
- Module exports: `local M = {}`
- Private functions: `local function function_name()`
- Public functions: `function M.function_name()`
- Constants: `UPPER_CASE_WITH_UNDERSCORES`

**Error Handling:**
- Use `vim.log.levels` with `[onion]` prefix for logging
- Graceful fallbacks and nil checks
- Deep copy protection for returned values

## Testing

- Use busted framework, stub vim API in tests
- Follow patterns in spec/onion_spec.lua for test structure
- Note that busted doesn't have the `vim` available. so everything that touches
  `vim` needs to be stubbed in the specs.
