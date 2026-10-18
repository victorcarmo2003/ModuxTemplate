param(
    [string]$Src    = "src",
    [string]$Filter = "*",
    [string]$Defs   = "",
    [switch]$Detail,
    # Quick mode while working: only the features touched since HEAD (git diff + untracked). Shared code (Shared, Libs,
    # Modux, ModuxTypes) or a changed signature can break other features, so the full gate still runs before a commit.
    [switch]$Changed
)

$ErrorActionPreference = "Stop"

if (-not $Defs) {
    $candidates = @(
        "$env:APPDATA/Code/User/globalStorage/johnnymorganz.luau-lsp/globalTypes.PluginSecurity.d.luau",
        "$env:APPDATA/Antigravity/User/globalStorage/johnnymorganz.luau-lsp/globalTypes.PluginSecurity.d.luau"
    )
    $Defs = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

$lsp = Get-ChildItem "$env:USERPROFILE/.vscode/extensions" -Filter "johnnymorganz.luau-lsp-*" -Directory -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending | Select-Object -First 1
if (-not $lsp) {
    Write-Error "luau-lsp not found. Install the johnnymorganz.luau-lsp extension in VS Code."
    exit 1
}
$engine = Join-Path $lsp.FullName "bin/server.exe"

& rogen build 2>&1 | Out-Null

$map = "sourcemap.json"
& rojo sourcemap default.project.json -o $map 2>&1 | Out-Null
if (-not (Test-Path -LiteralPath $map)) {
    Write-Error "rojo did not produce the sourcemap. Install it with: rokit add rojo-rbx/rojo"
    exit 1
}

Write-Host "engine: luau-lsp + Rojo sourcemap + Roblox definitions" -ForegroundColor DarkGray


# LuauTypeInferIterationLimit 160000 (default 20000; 40000 until the Anomaly/Showcase hooks 2026-10-12, 80000 until the TASK-480/485 merge 2026-10-18: PlateController): the Modux self of the biggest Services (10+ dependencies plus
# typeof(Net)) exceeds the default budget and reports "Code is too complex to typecheck" on correct code (TASK-048).
# Same value in .vscode/settings.json (luau-lsp.fflags.override) so editor and gate agree.
$base = @("analyze", "--sourcemap=$map", "--flag:LuauSolverV2=true", "--flag:LuauTypeInferIterationLimit=160000")
if ($Defs) { $base += "--definitions=$Defs" }

# What to analyze. ONE engine process whenever possible: every process type-checks the shared Modux / Net / Content
# types again from zero, so the old 9 batches of 100 files paid that cost 9 times (owner 2026-10-16: the gate was slow).
#   default          the whole $Src folder as one directory argument (the engine walks it)
#   -Changed         the touched feature folders only (src/<Feature>), or the whole folder when shared code changed
#   -Filter <glob>   the matching files, in batches (a file list can exceed the Windows command-line limit, which used
#                    to make the engine never run and report a false 0)
$targets = @()
if ($Changed) {
    $touched = @(& git diff --name-only HEAD 2>$null) + @(& git ls-files --others --exclude-standard 2>$null)
    $features = @{}
    $shared = $false
    foreach ($path in $touched) {
        # extension first: every -match / -notmatch that matches rewrites $Matches
        if (-not $path.EndsWith(".luau") -or $path -notmatch "^$Src/([^/]+)/") { continue }
        $feature = $Matches[1]
        if ($feature -in @("Shared", "Libs", "Modux", "ModuxTypes")) { $shared = $true } else { $features[$feature] = $true }
    }
    if ($shared) {
        Write-Host "changed: shared code, analyzing all of $Src" -ForegroundColor DarkGray
        $targets = @(, @($Src))
    } elseif ($features.Count -eq 0) {
        Write-Host "changed: no .luau under $Src since HEAD" -ForegroundColor DarkGray
        Write-Host "total: 0 error(s), 0 cycle(s)"
        exit 0
    } else {
        $dirs = @($features.Keys | Sort-Object | ForEach-Object { "$Src/$_" })
        Write-Host "changed: $($dirs -join ', ')" -ForegroundColor DarkGray
        $targets = @(, $dirs)
    }
} elseif ($Filter -eq "*") {
    $targets = @(, @($Src))
} else {
    $root = (Get-Location).Path
    $paths = @(Get-ChildItem -Path $Src -Recurse -Filter *.luau |
        Where-Object { $_.FullName -like $Filter } |
        ForEach-Object { $_.FullName.Substring($root.Length + 1) })
    $batch = 300
    for ($i = 0; $i -lt $paths.Count; $i += $batch) {
        $targets += , @($paths[$i..([Math]::Min($i + $batch, $paths.Count) - 1)])
    }
}

$output = @()
$previous = $ErrorActionPreference
$ErrorActionPreference = "Continue"
foreach ($chunk in $targets) {
    $output += & $engine @($base + $chunk) 2>&1 | ForEach-Object { "$_" } | Where-Object { $_ -notmatch '\[INFO\]' }
}
$ErrorActionPreference = $previous

$launch = @($output | Select-String 'too long|is not recognized|cannot find' )
if ($launch.Count -gt 0) {
    Write-Host "analyzer failed to run: $($launch[0].Line)" -ForegroundColor Red
    exit 1
}

$errors = @($output | Select-String 'TypeError|SyntaxError' | ForEach-Object { $_.Line } | Select-Object -Unique)
$cycles = @($output | Select-String 'Cyclic module dependency')

if ($Detail -and $errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Host "  $_" }
}
if ($cycles.Count -gt 0) {
    Write-Host "$($cycles.Count) cyclic require(s)." -ForegroundColor Red
}

Write-Host "total: $($errors.Count) error(s), $($cycles.Count) cycle(s)"
