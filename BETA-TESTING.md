# Ghostty Windows — Beta Testing Checklist
**Tester:** Wylie (Thr45h)
**Binary:** `D:\devbuilds\ghostty-windows\src\zig-out\bin\ghostty.exe`
**Started:** 2026-03-15

Legend: ✅ Works | ❌ Broken | ⚠️ Partial | 🔲 Not tested | 🚧 Known missing

---

## Core Terminal

| Feature | Status | Notes |
|---------|--------|-------|
| Launches without crashing | ✅ | |
| Renders text | 🔲 | |
| Cursor visible and blinking | 🔲 | |
| Correct colors (256 / truecolor) | 🔲 | |
| Scrollback buffer | 🔲 | |
| Scrollbar | 🚧 | Not implemented yet |
| Mouse scroll | 🔲 | |
| Mouse click to position cursor | 🔲 | |
| Copy (Ctrl+Shift+C) | 🔲 | |
| Paste (Ctrl+Shift+V) | 🔲 | |
| Right-click paste | 🔲 | |
| Selection with mouse | 🔲 | |
| Resize terminal | 🔲 | |
| Fullscreen (F11 or keybind) | 🔲 | |
| Maximize / restore | ✅ | Confirmed in smoke test |
| DPI awareness / HiDPI | 🔲 | |
| Multi-monitor move | 🔲 | |

---

## Shell Integration

| Feature | Status | Notes |
|---------|--------|-------|
| PS7 launches as default shell | 🔲 | |
| Shell prompt renders correctly | 🔲 | |
| Shell integration scripts load | 🔲 | |
| `ghostty +` CLI commands work | 🔲 | |
| `ghostty +boo` animation | 🔲 | framedata.compressed is present |
| Working directory tracking | 🔲 | |
| Command completion notifications | 🔲 | |
| Taskbar flash on completion | 🚧 | Not implemented yet |
| Hyperlinks (OSC 8) | 🔲 | |

---

## Tabs & Splits

| Feature | Status | Notes |
|---------|--------|-------|
| New tab (Ctrl+Shift+T) | 🔲 | |
| Close tab | 🔲 | |
| Switch tabs | 🔲 | |
| Tab bar hides when 1 tab | 🔲 | |
| Split pane horizontal | 🔲 | |
| Split pane vertical | 🔲 | |
| Navigate splits | 🔲 | |
| Resize splits | 🔲 | |
| Close split | 🔲 | |

---

## Fonts & Rendering

| Feature | Status | Notes |
|---------|--------|-------|
| DirectWrite font rendering | 🔲 | |
| Custom font in config | 🔲 | |
| Bold / italic / bold-italic | 🔲 | |
| Nerd Font icons render | 🔲 | |
| Emoji render | 🔲 | |
| Ligatures | 🔲 | |
| Font size change (Ctrl+/Ctrl-) | 🔲 | |
| Box drawing characters | 🔲 | |
| Powerline symbols | 🔲 | |

---

## Config

| Feature | Status | Notes |
|---------|--------|-------|
| Config file loads (`~/.config/ghostty/config`) | 🔲 | |
| Color scheme from config | 🔲 | |
| Font from config | 🔲 | |
| Keybinding overrides | 🔲 | |
| `window-startup-animation` toggle | ✅ | Added in build |
| Opacity / transparency | 🔲 | |
| Padding config | 🔲 | |

---

## Keyboard

| Feature | Status | Notes |
|---------|--------|-------|
| All standard keys work | 🔲 | |
| Ctrl+C sends SIGINT | 🔲 | |
| Ctrl+Z suspends | 🔲 | |
| Arrow keys | 🔲 | |
| Home/End/PgUp/PgDn | 🔲 | |
| Function keys (F1-F12) | 🔲 | |
| Alt key combos | 🔲 | |
| IME input | 🚧 | Cursor positioning broken |
| Secure keyboard input | 🚧 | Not implemented |

---

## UI / Window Chrome

| Feature | Status | Notes |
|---------|--------|-------|
| Title bar renders | 🔲 | |
| Window title updates with shell | 🔲 | |
| App icon in taskbar | 🚧 | Not implemented |
| Command palette (Ctrl+Shift+P) | 🔲 | Implemented in fork |
| Search bar | 🔲 | Implemented in fork |
| Inspector (Ctrl+Shift+I) | ⚠️ | Shows notification, no UI yet |
| Dark/light mode follows OS | 🔲 | |
| Window close confirmation | 🔲 | |

---

## Advanced / Graphics

| Feature | Status | Notes |
|---------|--------|-------|
| OpenGL renderer active | ✅ | OpenGL 4.3 confirmed |
| D3D11 renderer | 🔲 | |
| Kitty graphics protocol | 🔲 | |
| Sixel graphics | 🔲 | |
| IPC / `ghostty @ ...` commands | 🚧 | Named pipe not implemented |

---

## Known Issues (pre-testing)
- Scrollbar not implemented
- IME cursor positioning wrong (candidate window bottom-left instead of at cursor)
- IPC server (named pipe) missing — `ghostty @` commands won't work
- Application icon missing from taskbar/window
- Taskbar flash on completion missing
- Full inspector UI not implemented (shows Win32 notification instead)
- Secure keyboard input mode not implemented

---

## Bug Log

| Date | Description | Status |
|------|-------------|--------|
| | | |

---

## Notes
- Report upstream-relevant bugs to: https://github.com/adilahmeddev/ghostty-windows/issues
- Reference official Ghostty docs for expected behavior: https://ghostty.org/docs
- Build command: `zig build -Dapp-runtime=win32 -Dwinui=false -Doptimize=ReleaseFast -Dtarget=x86_64-windows`
