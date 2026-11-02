# EmuSort for Onion OS

<img width="640" height="480" alt="Screenshot_000" src="https://github.com/user-attachments/assets/275e277c-4dc2-4acb-908a-6ee36cf463d6" />


A lightweight, native on-device console order manager for **Onion OS** (Miyoo Mini, Miyoo Mini v4, Miyoo Mini Plus, and Miyoo Mini Flip). 

By default, Onion OS sorts systems in the **Games** menu alphabetically (`A-Z`). **EmuSort** lets you reorder your consoles directly on the handheld using an interactive grab-and-drop list—without adding visible numbers (`01.`, `02.`) or shifting label alignment.

## Features

- **Clean Labels (No Visible Numbers):** Uses zero-width Unicode Byte Order Mark prefixes (`\uFEFF` / `\uFFFE`) so `MainUI` sorts systems in your exact custom order while keeping console names 100% clean and centered.
- **Interactive Grab & Move UI:** Move consoles up and down directly in a single vertical list.
- **Universal Resolution Support:** Automatically adapts to 640x480 (Miyoo Mini / Plus / Flip) and 750x560 (Miyoo Mini v4) displays.
- **One-Button Reset:** Restore the default alphabetical (`A-Z`) order anytime.
- **Auto Cache Refresh:** Automatically clears `MainUI` database caches (`_cache6.db` / `_cache7.db`) on save so changes apply immediately.

## Installation

1. Download and extract the `EmuSort` folder.
2. Copy the `EmuSort` folder into `/App/` on your Onion OS SD card (final path: `/mnt/SDCARD/App/EmuSort/launch.sh`).
3. Insert the SD card into your device and launch **EmuSort** from the **Apps** menu.

## Controls

| Button | Action |
| :--- | :--- |
| **D-Pad Up / Down** | Navigate list / Move grabbed console |
| **A** | Grab console / Drop console at new position |
| **B** | Cancel grab |
| **X** | Reset all consoles to default (`A-Z`) order |
| **START** | Save changes, refresh cache, and exit |
| **MENU** | Exit immediately without saving |

## How It Works

`MainUI` sorts entries in `/Emu/*/config.json` by comparing the raw UTF-8 byte sequence of the `"label"` field. Standard control characters (`0x01`-`0x1F`) render as missing glyph boxes (`[?]`) in `SDL_ttf`, and standard spaces shift text alignment. 

**EmuSort** encodes each console's index into a 5-bit binary sequence using `\uFEFF` (`0`) and `\uFFFE` (`1`), terminated by `\uFEFF`. Because `SDL_ttf` natively strips BOM characters prior to glyph rendering, the prefix remains completely invisible while enforcing a strict binary sort order.
