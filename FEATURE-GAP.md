# Ghostty Win32 Feature Gap Analysis
Generated: 2026-03-15 | Upstream: ghostty-org/ghostty main

## Legend
- ✅ Implemented in Win32
- 🔧 Stub/no-op in Win32
- ❌ Missing from Win32 (not in performAction switch at all)
- 🍎 macOS-only (skip)
- 🐧 GTK-only (skip or Win32 equivalent needed)
- 🎯 High priority for implementation

---

## Actions Gap

### Missing from Win32, Implemented in GTK

| Action | Priority | Notes |
|--------|----------|-------|
| `copy_title_to_clipboard` | 🎯 High | Copy window title to clipboard — trivial Win32 |
| `set_tab_title` | 🎯 High | Set tab title override — Win32 has TabBar, needs `setTabTitle` |
| `toggle_quick_terminal` | 🎯 High | Visor/quake-style dropdown terminal — needs WS_EX_TOOLWINDOW + slide animation |
| `toggle_tab_overview` | Medium | GTK uses Adwaita TabOverview widget — Win32 needs custom overlay |
| `show_on_screen_keyboard` | Low | `TabTip.exe` / `osk.exe` on Windows |
| `undo` / `redo` | Low | GTK also unimplemented — skip for now |
| `check_for_updates` | Low | Would need auto-update infra |
| `secure_input` | Medium | Block screen capture while password prompt active — `SetWindowDisplayAffinity(WDA_EXCLUDEFROMCAPTURE)` |

### In Win32 Switch But Missing Logic (stubs)
| Action | Status |
|--------|--------|
| `inspector` | Opens inspector overlay — needs implementation |
| `render_inspector` | Render loop for inspector |
| `show_gtk_inspector` | GTK-only, Win32 could open debug window |

---

## Non-Action Feature Gaps

### UI / Shell
| Feature | Priority | Upstream reference | Notes |
|---------|----------|--------------------|-------|
| **Quick Terminal** (visor mode) | 🎯 High | `gtk/class/window.zig` `isQuickTerminal` | Dropdown terminal on hotkey. Needs: always-on-top, borderless, slide-down animation, auto-hide on focus loss |
| **Tab title override** | 🎯 High | `gtk/class/tab.zig` `setTitleOverride` | Win32 TabBar already draws titles — just needs override storage + `set_tab_title` action |
| **Copy title to clipboard** | High | `gtk/class/surface.zig` | Win32: `OpenClipboard` + `SetClipboardData` with window title |
| **Tab overview / switcher** | Medium | `gtk/class/window.zig` `toggleTabOverview` | Custom GDI overlay showing all tabs as thumbnails |
| **IPC server** | Medium | `gtk/ipc/` | Named pipe listener on Windows for CLI control |
| **Secure input mode** | Medium | macOS: `SecureEventInput` | Win32: `SetWindowDisplayAffinity(WDA_EXCLUDEFROMCAPTURE)` |

### Rendering / Display
| Feature | Priority | Notes |
|---------|----------|-------|
| **Resize overlay** | Medium | GTK shows cell count on resize. `gtk/class/resize_overlay.zig`. GDI overlay |
| **Key state overlay** | Low | Debug overlay showing held modifier keys. `gtk/class/key_state_overlay.zig` |

### Input
| Feature | Priority | Notes |
|---------|----------|-------|
| **IME cursor positioning** | 🎯 High | Currently uses mouse pos. Should use text cursor pos. CLAUDE.md mentions this |
| **On-screen keyboard** | Low | `TabTip.exe` / `osk.exe` |

### Platform Integration
| Feature | Priority | Notes |
|---------|----------|-------|
| **Taskbar progress** | 🎯 High | `ITaskbarList3::SetProgressValue` — already partially done (FlashWindowEx exists) |
| **Jump lists** | Low | Recent sessions in taskbar right-click |
| **System tray** | Low | Quick terminal minimize-to-tray |
| **App icon** | ✅ Done | Implemented this session |

### Scrollbar
| Feature | Status |
|---------|--------|
| **Scrollbar overlay** | ✅ Done (this session) — drag, click-to-jump, auto-show/hide |

---

## Implementation Order (Recommended)

### Phase 1 — Quick wins (< 1 day each)
1. `copy_title_to_clipboard` — 10 lines of Win32 clipboard code
2. `set_tab_title` — add `title_override` field to Tab, update TabBar paint
3. **IME cursor positioning** — use `core_surface.cursorPixelPos()`
4. **Taskbar progress** — `ITaskbarList3` COM interface, map to `progress_report` action
5. `secure_input` — `SetWindowDisplayAffinity`

### Phase 2 — Medium effort (1-3 days each)
6. **Quick terminal (visor mode)** — most requested feature after scrollbar
7. **Resize overlay** — GDI text overlay during WM_SIZE
8. `show_on_screen_keyboard` — `ShellExecuteW("TabTip.exe")`

### Phase 3 — Complex (week+)
9. **Tab overview** — custom thumbnail grid overlay
10. **IPC server** — named pipe + CLI commands
11. **Inspector** — debug terminal overlay

---

## Files to Study in Upstream

| Win32 need | Upstream reference |
|------------|--------------------|
| Quick terminal | `src/apprt/gtk/class/window.zig` lines ~200-350 |
| Tab title override | `src/apprt/gtk/class/tab.zig` |
| Resize overlay | `src/apprt/gtk/class/resize_overlay.zig` |
| Key state overlay | `src/apprt/gtk/class/key_state_overlay.zig` |
| IPC | `src/apprt/gtk/ipc/` |
| Inspector | `src/apprt/gtk/class/inspector_window.zig` |
