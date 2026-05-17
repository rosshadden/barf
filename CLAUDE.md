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

All files are in the root `main` module. C interop files use the `.c.v` suffix convention.

- `main.v` — GtkApplication lifecycle, activate signal
- `bar.v` — layer surface setup (anchors, exclusive zone, CSS), left/center/right box layout
- `config.v` — suckless-style compile-time Config struct
- `clock.v` — clock label updated via `g_timeout_add`
- `workspaces.v` — Hyprland workspace display via IPC socket (`.socket2.sock`)
- `gtk.c.v` — GTK3 C function/struct declarations (`#pkgconfig gtk+-3.0`)
- `layer_shell.c.v` — gtk-layer-shell C declarations (`#pkgconfig gtk-layer-shell-0`)

## C FFI Patterns

- Declare C functions as `fn C.gtk_xxx(...)` — V does not parse C headers automatically
- Use `c'literal'` for C string constants, `s.str` for V string → `&char`
- GTK callbacks must be plain `fn` (not closures/methods); thread state through `voidptr` user_data
- Cast widget types with `unsafe { &C.GtkWindow(widget_ptr) }`
- Use `g_idle_add` to push updates to GTK from spawned goroutines

## Code Style

- V files use tabs for indentation.
- Files use LF line endings, UTF-8, with a trailing newline.
