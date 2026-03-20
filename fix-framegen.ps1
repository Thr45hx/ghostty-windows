# fix-framegen.ps1
# Fixes the Windows build blocker: framegen absolute path panic in Zig 0.15.2
# Run from D:\devbuilds\ghostty-windows\src as Administrator

$ErrorActionPreference = "Stop"
$src = "D:\devbuilds\ghostty-windows\src"

Write-Host ""
Write-Host "=== Ghostty Windows Build Fix: framegen ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Compile framegen using zig cc with bundled zlib
Write-Host "[1/3] Compiling framegen with zig cc..." -ForegroundColor Yellow

$zlibSources = Get-ChildItem "$src\pkg\zlib" -Filter "*.c" -Recurse | Select-Object -ExpandProperty FullName
$zlibArgs = $zlibSources -join " "

$cmd = "zig cc `"$src\src\build\framegen\main.c`" $zlibArgs -I `"$src\pkg\zlib`" -o `"$src\framegen.exe`" -lkernel32"
Write-Host "  $cmd"
Invoke-Expression $cmd
Write-Host "  Done." -ForegroundColor Green

# Step 2: Run framegen to produce framedata.compressed
Write-Host "[2/3] Running framegen to generate framedata.compressed..." -ForegroundColor Yellow

$framesDir = "$src\src\build\framegen\frames"
$outFile = "$src\src\build\framegen\framedata.compressed"

& "$src\framegen.exe" $framesDir $outFile
if ($LASTEXITCODE -ne 0) { throw "framegen failed" }
Write-Host "  Written to $outFile" -ForegroundColor Green

# Step 3: Patch GhosttyDist.zig to not block prebuilt files in git checkouts
Write-Host "[3/3] Patching GhosttyDist.zig to allow prebuilt dist files..." -ForegroundColor Yellow

$distFile = "$src\src\build\GhosttyDist.zig"
$content = Get-Content $distFile -Raw

$old = @'
    pub fn exists(self: *const Resource, b: *std.Build) bool {
        if (b.build_root.handle.access(self.dist, .{})) {
            // If we have a ".git" directory then we're a git checkout
            // and we never want to use the dist path. This shouldn't happen
            // so show a warning to the user.
            if (b.build_root.handle.access(".git", .{})) {
                std.log.warn(
                    "dist resource '{s}' should not be in a git checkout",
                    .{self.dist},
                );
                return false;
            } else |_| {}

            return true;
        } else |_| {
            return false;
        }
    }
'@

$new = @'
    pub fn exists(self: *const Resource, b: *std.Build) bool {
        // Windows build patch: allow prebuilt dist files even in git checkouts.
        // The .git check was added to prevent stale dist files, but on Windows
        // the framegen Run step panics due to Zig 0.15.2 absolute path bug.
        if (b.build_root.handle.access(self.dist, .{})) {
            return true;
        } else |_| {
            return false;
        }
    }
'@

if ($content -notmatch [regex]::Escape("Windows build patch")) {
    $patched = $content.Replace($old, $new)
    if ($patched -eq $content) {
        Write-Host "  WARNING: Pattern not found exactly - check GhosttyDist.zig manually" -ForegroundColor Red
    } else {
        Set-Content $distFile $patched -NoNewline
        Write-Host "  Patched." -ForegroundColor Green
    }
} else {
    Write-Host "  Already patched, skipping." -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== Fix applied. Now run the build: ===" -ForegroundColor Cyan
Write-Host "  cd D:\devbuilds\ghostty-windows\src"
Write-Host "  zig build -Dapp-runtime=win32 -Dwinui=false -Doptimize=ReleaseFast -Dtarget=x86_64-windows"
Write-Host ""
