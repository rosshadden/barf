# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Barv is an eww-like Wayland bar for Hyprland, written in V (`vlang` 0.5.1). It uses GTK3 + gtk-layer-shell via V's C FFI to render a layer surface anchored to the top of the screen.

## Commands

- **Build:** `v .` (produces `barv` binary)
- **Run:** `v run .`
- **Test:** `v test .`
- **Format:** `v fmt -w .`

## Architecture

Root files are in the `main` module. Each subdirectory under `modules/` is its own V module, imported by name (e.g., `import bar`). C interop files use the `.c.v` suffix convention.

- `main.v` — entry point, GtkApplication lifecycle
- `config.v` — suckless-style compile-time Config struct
- `modules/gtk/` — GTK3 C bindings (`#pkgconfig gtk+-3.0`)
- `modules/layershell/` — gtk-layer-shell C bindings (`#pkgconfig gtk-layer-shell-0`)
- `modules/bar/` — layer surface setup, CSS, left/center/right layout, BarConfig
- `modules/clock/` — clock label updated via `g_timeout_add`
- `modules/workspaces/` — Hyprland workspace display via IPC socket (`.socket2.sock`)

Every module that calls GTK C functions must `import gtk` to get the function declarations.

## C FFI Patterns

- Declare C functions as `fn C.gtk_xxx(...)` — V does not parse C headers automatically
- Use `c'literal'` for C string constants, `s.str` for V string → `&char`
- GTK callbacks must be plain `fn` (not closures/methods); thread state through `voidptr` user_data
- Cast widget types with `unsafe { &C.GtkWindow(widget_ptr) }`
- Use `g_idle_add` to push updates to GTK from spawned goroutines

## Code Style

- V files use tabs for indentation.
- Files use LF line endings, UTF-8, with a trailing newline.
