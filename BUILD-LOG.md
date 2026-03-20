# Ghostty Windows x64 Build Log
**Started:** 2026-03-14
**System:** Wylie (Thr45h) — Ryzen 7800X3D / RTX 4060 8GB / 32GB RAM / Windows 11 Pro x64

---

## Goal
Build Ghostty terminal emulator natively on Windows x64 — no WSL, no emulation.
If it works: bragging rights. Virtually nobody has done this.

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

