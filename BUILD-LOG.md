# Ghostty Windows x64 Build Log
**Started:** 2026-03-14
**System:** Wylie (Thr45h) — Ryzen 7800X3D / RTX 4060 8GB / 32GB RAM / Windows 11 Pro x64

---

## Goal
Build Ghostty terminal emulator natively on Windows x64 — no WSL, no emulation.
If it works: bragging rights. Virtually nobody has done this.

---

## Origin Story

Asked Claude to build Ghostty natively on Windows. Claude argued it wasn't designed for Windows, the ecosystem wasn't ready, strongly recommended against it. User said: so what, let's try anyway.

Back and forth. Claude eventually started the build — then ran out of credits mid-session.

GitHub Copilot picked it up. No debate, no disclaimers. `/yolo` — just started throwing things at it until something stuck.

Claude came back later to clean up the wreckage and figure out why things worked or didn't.

That's the whole methodology.

---

## Source Fork
**Repo:** https://github.com/adilahmeddev/ghostty-windows
**Branch:** `windows-apprt`
**Status as of 2026-03-14:** Actively developed, 14 commits ahead of upstream main
**Last commit:** 2026-03-14 — `feat(win32): add GDI command palette overlay and session docs`

This fork is the most complete Windows port in existence. 34,337 lines of Windows-specific code:
- Full Win32 API runtime (no GTK, no frameworks)
- DirectWrite font backend (native Windows font rendering)
- D3D11 + OpenGL rendering backends
- GDI UI overlays (tabs, search bar, command palette)
- Multi-window, tabbed, split pane support

---

## Architecture
```
App
 └── Window (top-level HWND "GhosttyWindow")
      ├── TabBar (child HWND "GhosttyTabBar", hidden when 1 tab)
      └── Tab[]
           └── SplitTree(Surface)
                └── Surface (child HWND "GhosttySurface", CS_OWNDC)
```

**Message loop:** PeekMessageW (non-blocking) + high-res waitable timer
**Renderer:** D3D11 primary, OpenGL fallback, GDI for UI chrome
**Font:** DirectWrite (Windows-native) + HarfBuzz for shaping

---

## Build Requirements
- **Zig:** 0.15.2 (exact — Zig is not version-flexible)
- **Target:** x86_64-windows (native, no cross-compilation needed)
- **No MSVC required** — Zig bundles its own libc/MinGW-w64
- **No pkg-config** — all deps managed by Zig build system
- **Windows SDK:** needed for Win32/DirectWrite/D3D11 headers (comes with VS2022)

VS2022 Community 17.14.28 with C++ workload is already installed — covers the Windows SDK.

---

## Build Command
```powershell
# Standard build (recommended starting point)
zig build -Dapp-runtime=win32 -Dwinui=false -Doptimize=ReleaseFast

# x64 explicit (should be default on x64 host, but to be safe)
zig build -Dapp-runtime=win32 -Dwinui=false -Doptimize=ReleaseFast -Dtarget=x86_64-windows

# Debug build (easier to diagnose failures)
zig build -Dapp-runtime=win32 -Dwinui=false
```

Output: `zig-out\bin\ghostty.exe` + `zig-out\bin\ghostty-vt.dll`

---

## IS THIS x64?
**YES.** Confirmed x64:
- Target: `x86_64-windows`
- Host machine is x64 (Zig defaults to host architecture)
- Using `-Dtarget=x86_64-windows` explicitly in build command ensures it
- The test binary in the fork (`zig-out-test/bin/ghostty.exe`) is 60.3MB — consistent with x64 release binary

---

## Known Working Features (as of this fork)
- ✅ Native Win32 window management
- ✅ Tabs, split panes
- ✅ DirectWrite font rendering
- ✅ D3D11 + OpenGL rendering
- ✅ Keyboard input (deferred key pattern)
- ✅ Mouse (click, move, scroll)
- ✅ Command palette (GDI overlay)
- ✅ Search bar in titlebar
- ✅ DPI awareness
- ✅ Dark/light mode detection
- ✅ Fullscreen, maximize
- ✅ Clipboard

## Known Missing Features
- ⚠️ Scrollbar — implemented (Win32 overlay, drag/click-to-jump/hover), needs visual polish
- ⚠️ Application icon — implemented this session
- ❌ IME cursor positioning
- ❌ IPC server (named pipe)
- ❌ Taskbar flash on completion
- ❌ Inspector overlay
- ❌ Secure keyboard input mode

---

## Research: Fixes for Known Issues

### Latency (reported by Lololegeek on an earlier build)
**Cause:** Small WriteFile() calls to ConPTY pipe — one char at a time kills throughput.
**Fix:** Batch output into large buffers before WriteFile(). Separate render thread from I/O thread.
**Reference:** Casey Muratori's refterm — 10x faster than Windows Terminal using this pattern.

### Scrollbar
**Approach:** Custom overlay rendered via D3D11/Direct2D — same approach Ghostty 1.3 used for macOS/GTK.
No Win32 scrollbar control needed. Pure GPU tile rendered on top of terminal surface.

### IME Cursor Positioning
**Fix:** One missing call on `WM_IME_STARTCOMPOSITION`:
```c
COMPOSITIONFORM cf = { CFS_POINT, { cursor_screen_x, cursor_screen_y } };
ImmSetCompositionWindow(ImmGetContext(hwnd), &cf);
```

### Named Pipe IPC
```c
CreateNamedPipe(L"\\\\.\\pipe\\ghostty-ipc-{pid}", PIPE_ACCESS_DUPLEX, ...)
```
ConPTY doesn't support overlapped I/O on its own pipes, but the IPC pipe is separate — async is fine.

### App Icon
```c
SetClassLong(hwnd, GCL_HICON, LoadIcon(hinst, MAKEINTRESOURCE(IDI_GHOSTTY)));
```
Needs a compiled .ico resource in the binary.

### Taskbar Flash
```c
FlashWindowEx(&fwi); // triggered on shell bell / command completion
```

---

## Other Forks / Community Builds
| Fork | Status | Notes |
|------|--------|-------|
| adilahmeddev/ghostty-windows | Active (this build) | Most complete Windows port |
| Labontese/win-ghostty | Created 2026-03-10, no activity | Abandoned |
| kociumba/ghostty-windows-nightly | Last build 2026-02-13 | Dead, no source mods |
| marler8997 PR #1519 | Closed 2025-02-15, branch deleted | Used Direct3D+DirectWrite, no ConPTY |

---

## Reference Links
- Fork: https://github.com/adilahmeddev/ghostty-windows/tree/windows-apprt
- Official build docs: https://ghostty.org/docs/install/build
- Windows discussion: https://github.com/ghostty-org/ghostty/discussions/2563
- marler8997 PR: https://github.com/ghostty-org/ghostty/pull/1519
- Refterm (latency reference): https://github.com/cmuratori/refterm
- Zig 0.15.2 download: https://ziglang.org/download/
- neurocyte/flow Win32 reference: https://github.com/neurocyte/flow (src/win32/)

---

## Build Attempts Log

### Attempt 1 — 2026-03-14
**Status:** Hit blocker — `build.zig.zon` referenced a missing local `../dev/libxev` path.

**Fix:**
- Swapped `libxev` in `build.zig.zon` back to the upstream Ghostty tarball URL.

### Attempt 2 — 2026-03-14
**Status:** Hit blocker — Zig 0.15.2 Windows build-system panic in `std.Build.Step.Run`.

**Symptoms:**
- `zig build -Dapp-runtime=win32 -Dwinui=false -Doptimize=ReleaseFast -Dtarget=x86_64-windows`
  panicked in `Run.zig:662` with `assert(!std.fs.path.isAbsolute(child_cwd_rel))`.

**Repo fixes applied:**
- `src/build/GhosttyDist.zig`
  - kept prebuilt dist resources enabled in git checkouts so Windows can reuse generated assets
- `src/build/GhosttyFrameData.zig`
  - replaced `addDirectoryArg(b.path(...))` with a relative CLI arg for `framegen`
- `src/build/GhosttyI18n.zig`
  - replaced source-tree `addFileArg(b.path(...))` usage with relative args plus `addFileInput(...)`
- `src/build/SharedDeps.zig`
  - replaced GTK blueprint source-tree `addFileArg(b.path(...))` with relative args plus `addFileInput(...)`

**Local workaround files used:**
- Existing `framegen.exe` in repo root was reused to generate:
  - `src\build\framegen\framedata.compressed`
- Created junction:
  - `D:\devbuilds\ghostty-windows\src\ucd` -> cached `uucode\ucd`

**Global local cache fixes applied (not part of repo):**
- Patched both cached `uucode` package copies under `C:\Users\Thr45h\AppData\Local\zig\p\...`
  to avoid absolute `setCwd(b.path(""))` on Windows, which triggers the same Zig 0.15.2 assert.

### Attempt 3 — 2026-03-14
**Status:** SUCCESS

**Command:**
```powershell
cd D:\devbuilds\ghostty-windows\src
zig build -Dapp-runtime=win32 -Dwinui=false -Doptimize=ReleaseFast -Dtarget=x86_64-windows
```

**Artifacts produced:**
- `D:\devbuilds\ghostty-windows\src\zig-out\bin\ghostty.exe`
- `D:\devbuilds\ghostty-windows\src\zig-out\bin\ghostty-vt.dll`
- `D:\devbuilds\ghostty-windows\src\zig-out\bin\ghostty-vt.pdb`
- `D:\devbuilds\ghostty-windows\src\zig-out\bin\ghostty.exe` size: 27,997,696 bytes

**Notes:**
- The repo now builds natively on Windows x64 in this environment.
- Some workarounds are local-only and should be cleaned up or upstreamed later:
  - cached `uucode` package edits
  - `ucd` junction
  - generated `framedata.compressed`
  - `framegen.exe` / `framegen.pdb`

### Attempt 4 — 2026-03-14
**Status:** Smoke test passed

**Launch check:**
- Started `D:\devbuilds\ghostty-windows\src\zig-out\bin\ghostty.exe`
- Process stayed alive for 6 seconds
- Process was responsive
- Test process was stopped cleanly afterward

**Observed details:**
- PID at launch: `2640`
- `MainWindowTitle` reported as `Administrator: C:\WINDOWS\System32\cmd.exe`
- `Path` confirmed as the newly built `ghostty.exe`

**Interpretation:**
- The built binary launches successfully in this environment.
- The title suggests the current console-subsystem behavior is still involved, which matches the fork's Windows launcher design.

### Attempt 5 — 2026-03-14
**Status:** SUCCESS — startup ghost animation integrated into Win32 surface

**Repo changes applied:**
- Added `src\StartupGhostAnimation.zig`
  - reuses the existing compressed Ghostty `+boo` frame data
  - uses the same raw-flate decompression path and frame splitting logic as the CLI animation
- Updated `src\apprt\win32\App.zig`
  - triggers the startup animation only once, on the first created Win32 surface
- Updated `src\apprt\win32\Surface.zig`
  - added per-surface startup animation state
  - added a timer-driven startup overlay rendered in the surface child window
  - dismisses the animation on first real input so the terminal stays responsive
- Updated `src\config\Config.zig`
  - added `window-startup-animation = true` default config toggle for Win32 runtime use

**Validation:**
- Rebuilt successfully with:
  ```powershell
  cd D:\devbuilds\ghostty-windows\src
  zig build -Dapp-runtime=win32 -Dwinui=false -Doptimize=ReleaseFast -Dtarget=x86_64-windows
  ```
- Launched the rebuilt `zig-out\bin\ghostty.exe`
- Confirmed the process created a top-level window and remained alive after startup
- Captured a startup window screenshot artifact to:
  - `C:\Users\Thr45h\.copilot\session-state\a21c05c6-d40c-48a5-905d-483e9682527b\files\ghostty-startup.png`

**Observed details:**
- PID at validation launch: `15544`
- `MainWindowTitle` reported as `Administrator: C:\WINDOWS\System32\cmd.exe`
- `MainWindowHandle` reported as `0x806BA`

**Notes:**
- This implementation intentionally avoids renderer-backend changes and uses a GDI overlay for lower-risk Windows integration.
- All existing builds, logs, generated artifacts, and workaround files were preserved.

**Post-validation issue:**
- Animation appeared glitchy during testing — flashing in and out, not smooth
- Claude attempted fixes, none resolved it during the session
- Root cause: stale GPU/driver state from the active session
- **Resolution:** Windows restart — animation runs perfectly on a clean boot
- Lesson: GPU overlay timing issues on Windows can be session-state artifacts, not code bugs

### Attempt 6 — 2026-03-14
**Status:** SUCCESS — Win32 inspector action gap partially fixed

**Problem observed:**
- `Ctrl+Shift+I` keypresses were reaching Ghostty on Win32, but nothing visible happened.
- Investigation showed:
  - `src\apprt\win32\App.zig` had no action handling for `.inspector`, `.show_gtk_inspector`, or `.render_inspector`
  - `src\apprt\win32\Surface.zig` had `redrawInspector()` implemented as a no-op

**Repo changes applied:**
- Updated `src\apprt\win32\App.zig`
  - added handling for `.inspector`
  - added handling for `.show_gtk_inspector`
  - added handling for `.render_inspector`
  - toggles core inspector data collection on the target surface
  - shows an explicit Win32 desktop notification that full inspector UI is not implemented yet
- Updated `src\apprt\win32\Surface.zig`
  - `redrawInspector()` now invalidates the surface HWND so inspector-triggered redraws are no longer dropped silently

**Validation:**
- Rebuilt successfully with:
  ```powershell
  cd D:\devbuilds\ghostty-windows\src
  zig build -Dtarget=x86_64-windows
  ```
- Confirmed the patched inspector strings exist in the rebuilt source tree.
- Confirmed GPU rendering remains active during smoke tests:
  - `renderer=renderer.generic.Renderer(renderer.OpenGL)`
  - `Loaded OpenGL 4.3`

**Important limitation:**
- This does **not** add a full Win32 inspector UI yet.
- It fixes the silent failure path and makes the backend gap explicit.
- A real Win32 inspector window/overlay would likely require reusing `dcimgui` + OpenGL backend plumbing similar to GTK/embedded paths.

### Attempt 7 — 2026-03-14
**Status:** SUCCESS — Win32 explicit command spawning and tab insertion behavior fixed

**Problems observed:**
- `ghostty -e pwsh -NoLogo -NoProfile -Command exit` failed on Win32 with:
  - `error.Unexpected: GetLastError(2): The system cannot find the file specified.`
- `ghostty -e cmd.exe /c exit` failed the same way.
- Root cause: `src\Command.zig` always passed `lpApplicationName=self.path` to `CreateProcessW`, which bypassed normal Windows `PATH`/`PATHEXT` resolution for non-absolute commands.
- Also observed: Win32 `Window.newTab()` always appended at the end and ignored `window-new-tab-position`.

**Repo changes applied:**
- Updated `src\Command.zig`
  - if the command path is non-absolute and has no directory component, Win32 now passes `lpApplicationName=null` to `CreateProcessW`
  - this restores normal Windows command lookup behavior for PATH-resolved commands such as `pwsh` and `cmd.exe`
- Updated `src\apprt\win32\Window.zig`
  - `newTab()` now reads `window-new-tab-position`
  - `.current` inserts after the active tab
  - `.end` appends at the end
  - WinUI tab ordering is kept in sync using the existing `tabview_move_tab` callback

**Validation:**
- Rebuilt successfully with:
  ```powershell
  cd D:\devbuilds\ghostty-windows\src
  zig build -Dtarget=x86_64-windows
  ```
- Explicit command spawn smoke tests now pass:
  - `ghostty -e pwsh -NoLogo -NoProfile -Command exit`
  - `ghostty -e cmd.exe /c exit`
- Validation logs confirm:
  - no `GetLastError(2)`
  - no `error.Unexpected`
  - subcommands start successfully and Ghostty exits cleanly afterward

**Artifacts:**
- `C:\Users\Thr45h\.copilot\session-state\a21c05c6-d40c-48a5-905d-483e9682527b\files\spawnfix-pwsh-noprofile-stderr.log`
- `C:\Users\Thr45h\.copilot\session-state\a21c05c6-d40c-48a5-905d-483e9682527b\files\spawnfix-cmd-exit-stderr.log`

### Attempt 8 — 2026-03-14
**Status:** SUCCESS — Shell preference order fixed + unsafe paste confirmation added

**Problems observed (from logs):**
- Initial launch: no shell found at all → fell back to `cmd.exe`
  - `warning(config): no default shell found, will default to using cmd`
- After shell config added: `error.Unexpected` in io_thread when using direct shell path
  - `warning(io_thread): error in io thread err=error.Unexpected`
- Clipboard paste rejected silently with no user feedback:
  - `info(surface): potentially unsafe paste detected, rejecting until confirmation`
  - `warning(win32_surface): Failed to complete clipboard request: error.UnsafePaste`

**Repo changes applied:**
- Updated shell fallback order in Win32 default shell detection:
  - now prefers `pwsh.exe` → `powershell.exe` → `cmd.exe` (instead of failing)
- Added native Win32 confirmation dialog for unsafe paste (instead of silent rejection)

**Validation:**
- `ghostty-fallback-test-stderr.log` confirms: `info(config): default shell source=path value=C:\Program Files\PowerShell\7\pwsh.exe`
- Shell now launches correctly without io_thread error

**Artifacts:**
- `C:\Users\Thr45h\.copilot\session-state\a21c05c6-d40c-48a5-905d-483e9682527b\files\ghostty-shellfix-test-stderr.log`
- `C:\Users\Thr45h\.copilot\session-state\a21c05c6-d40c-48a5-905d-483e9682527b\files\ghostty-fallback-test-stderr.log`

---

### Attempt 9 — 2026-03-14
**Status:** SUCCESS — Visual polish pass + working config

**Problem observed:**
- Config file existed at `C:\Users\Thr45h\AppData\Local\ghostty/config.ghostty` but was empty
  - `warning: error reading optional config file, not loading err=error.FileIsEmpty`
- No theme, default font, no opacity, default cursor — bare bones appearance

**Config established at `C:\Users\Thr45h\AppData\Local\ghostty/config.ghostty`:**
```
working-directory = home
window-startup-animation = true
shell-integration = none
theme = "Catppuccin Mocha"
font-family = "CaskaydiaCoveNerdFontMono-Regular"
font-family-bold = "CaskaydiaCoveNerdFontMono-Bold"
font-family-italic = "CaskaydiaCoveNerdFontMono-Italic"
font-family-bold-italic = "CaskaydiaCoveNerdFontMono-BoldItalic"
font-size = 16
background-opacity = 0.92
cursor-style = block
cursor-style-blink = false
cursor-color = #f97316
window-new-tab-position = end
```

**Native tab keybinds added to config:**
- New tab, close tab, switch tabs, jump to tab by number

**Validation:**
- `ghostty-vibe-startup-stderr.log` — debug build run confirming config loads, theme applies
- `ghostty-final-baseline-stderr.log` — release build with full config loaded, pwsh.exe detected

**Known issue discovered:**
- Explicit bold/italic font face names not resolved by DirectWrite:
  - `warning(font_shared_grid_set): font-family bold not found: CaskaydiaCoveNerdFontMono-Regular`
- DirectWrite falls back to synthetic bold/italic automatically — visually acceptable

**Artifacts:**
- `C:\Users\Thr45h\.copilot\session-state\a21c05c6-d40c-48a5-905d-483e9682527b\files\ghostty-vibe-startup-stderr.log`
- `C:\Users\Thr45h\.copilot\session-state\a21c05c6-d40c-48a5-905d-483e9682527b\files\ghostty-final-baseline-stderr.log`
- `C:\Users\Thr45h\.copilot\session-state\a21c05c6-d40c-48a5-905d-483e9682527b\files\ghostty-fontfaces-test-stderr.log`

---

### Attempt 10 — 2026-03-14/15
**Status:** SUCCESS — Scrollbar implemented

**Problem:** No scrollbar at all in Win32 build. Core scrollback buffer exists but no visual indicator.

**Approach:** Custom Win32 HWND overlay — separate child window positioned over the terminal surface.

**Implementation:**
- New file: `src\apprt\win32\Scrollbar.zig` (~400 lines)
  - Custom Win32 HWND overlay rendered via GDI
  - Drag to scroll
  - Click-to-jump (click anywhere on track)
  - Auto-show on scroll, auto-hide after idle timeout
  - Hover state highlight
- Integrated into `src\apprt\win32\Surface.zig` — scrollbar synced to terminal viewport

**Validation:**
- Scrollbar visible and functional on rebuilt binary
- Drag, click-to-jump, and hover all confirmed working
- Noted: visual polish still needed (sizing, colors, feel)

---

### Attempt 11 — 2026-03-15
**Status:** SUCCESS — Application icon implemented

**Problem:** No app icon in taskbar or window title bar. `ghostty.exe` showed generic Windows icon.

**Implementation:**
- Generated `ghostty.ico` (86KB, multi-resolution) from official Ghostty ghost SVG asset
- Embedded via Win32 resource: `SetClassLong(hwnd, GCL_HICON, LoadIcon(hinst, MAKEINTRESOURCE(IDI_GHOSTTY)))`
- Icon appears in: taskbar button, window title bar, Alt+Tab switcher

**Artifacts:**
- `D:\devbuilds\ghostty-windows\src\zig-out\bin\ghostty.ico` — 86,258 bytes

---

### Attempt 12 — 2026-03-15
**Status:** SUCCESS — Release build packaged with Inno Setup installer

**Note on dev vs release:**
The "release" build is the same binary as the dev build (`ReleaseFast` optimize flag used throughout).
The distinction is packaging only — Inno Setup strips the PDB debug symbols for the installed version.

**Binary sizes (Mar 15 17:24-17:25):**
- `ghostty.exe` — 28,718,592 bytes (identical across dev and installed)
- `ghostty-vt.dll` — 713,216 bytes (identical)
- `ghostty.pdb` — 93,700,096 bytes (dev only — stripped by installer)
- `ghostty-vt.pdb` — 3,448,832 bytes (dev only — stripped by installer)

**Build version:** `1.3.0-windows-apprt+0e5ca30`
**Fork version tag:** `1.3.0-dev` (upstream at time of build: `1.3.2-dev`)

**Installer:** `installer/ghostty.iss` (Inno Setup) — produces standard Windows installer
**Install location:** `C:\Program Files\Ghostty\bin\`

---

## Runtime Log — Confirmed Persistent Warnings

These appear in every launch log and are expected / known-unfixed:

| Warning | Cause | Status |
|---------|-------|--------|
| `warning(os_locale): setlocale failed` | Windows locale handling differs from POSIX | Harmless, en_US.UTF-8 fallback works |
| `warning(win32): Failed to set DPI awareness` | DPI awareness set too late in init sequence | Harmless, DPI scaling still works |
| `warning(stream): unimplemented mode: 9001` | Unknown VT mode — likely Win32-specific or PS7 | Unresolved, no visible impact observed |
| `conpty.dll not found, using system ConPTY` | Custom conpty.dll not shipped — uses Windows built-in | Expected behavior |

---

## Debug Build

A debug build was produced during inspector testing (Attempt 9):
```powershell
zig build -Dapp-runtime=win32 -Dwinui=false -Dtarget=x86_64-windows
# (no -Doptimize flag = Debug by default)
```
Debug binary warns: `"This is a debug build. Performance will be very poor."`
Used for: inspector action tracing, io_thread error diagnosis, input event logging.
Not suitable for daily use — ReleaseFast is the standard build.

