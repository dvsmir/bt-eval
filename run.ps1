#Requires -Version 7.0
<#
.SYNOPSIS
  Windows runner for the build-tool agent eval. The PowerShell twin of run.sh.

.DESCRIPTION
  For every trap and every repeat it does this:
    1. It copies traps/<slug>/project into a fresh scratch directory.
    2. It runs the claude CLI on traps/<slug>/TASK.md in that directory.
    3. It calls traps/<slug>/oracle.sh through Git Bash to get a verdict.
    4. It appends one row to the results CSV.

  The oracles stay in bash on purpose. A PowerShell port would give the project
  two sources of truth for what counts as a PASS, and the two would drift. This
  runner therefore needs Git Bash. It refuses the WSL bash in System32, which
  mounts the C drive at /mnt/c and would break every path the oracles build.

.EXAMPLE
  .\run.ps1
  All traps, 5 repeats, model sonnet.

.EXAMPLE
  .\run.ps1 -Traps 01-test-task-mapping -Repeats 3

.EXAMPLE
  .\run.ps1 -Calibrate

.NOTES
  Read README.md before you believe any number this produces.
#>
[CmdletBinding()]
param(
  # Trap slugs. Accepts a list or one comma-separated string. Default: all traps.
  [string[]] $Traps = @(),
  [int]      $Repeats = 5,
  [string]   $Model = 'sonnet',
  [string]   $Out = '',
  [int]      $TimeoutSec = 1200,
  # The agent must run outside this repository. See the guard below.
  [string]   $ScratchRoot = '',
  # Windows-form Java home. Default: discovered.
  [string]   $JavaHome = '',
  [string]   $BashExe = '',
  # Remove the fair baseline CLAUDE.md. Inflates any saving. See README section 6.
  [switch]   $Naive,
  [switch]   $Skill,
  [switch]   $Calibrate,
  [switch]   $DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# The oracles write diagnostics to stderr and signal through their exit code.
# Without this, PowerShell turns both into terminating errors.
$PSNativeCommandUseErrorActionPreference = $false

$HERE = $PSScriptRoot

function Die {
  param([string]$Message)
  Write-Host "run.ps1: $Message" -ForegroundColor Red
  exit 1
}

# ------------------------------------------------------------------- path help
# Git Bash sees C:\foo\bar as /c/foo/bar. Every path handed to bash needs this.
function ConvertTo-BashPath {
  param([Parameter(Mandatory)][string]$Path)
  $full = [IO.Path]::GetFullPath($Path)
  if ($full -match '^([A-Za-z]):[\\/]?(.*)$') {
    $drive = $Matches[1].ToLowerInvariant()
    $rest = $Matches[2] -replace '\\', '/'
    return ("/$drive/" + $rest).TrimEnd('/')
  }
  return ($full -replace '\\', '/')
}

function ConvertFrom-BashPath {
  param([Parameter(Mandatory)][string]$Path)
  if ($Path -match '^/([A-Za-z])/(.*)$') {
    return ($Matches[1].ToUpperInvariant() + ':\' + ($Matches[2] -replace '/', '\'))
  }
  return $Path
}


# Delete inside the scratch tree only. Every removal this runner makes is a copy
# under the scratch root, never anything in the repository. Make that a rule the
# code enforces, not a habit the reader must trust.
function Clear-Scratch {
  param([Parameter(Mandatory)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return }
  # Normalise both sides the same way. Resolve-Path keeps an 8.3 short name such
  # as DMITRI~1.SMI, while Get-ChildItem reports the long name, so a plain string
  # comparison of the two rejects paths that are in fact inside the scratch tree.
  # GetFullPath expands the short form; run both sides through it.
  $full = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Path).Path)
  $root = [IO.Path]::GetFullPath($Scratch)
  if (-not $full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
    Die "refusing to delete outside the scratch tree: $full"
  }
  Remove-Item -LiteralPath $full -Recurse -Force -ErrorAction SilentlyContinue
}

# --------------------------------------------------------------- prerequisites
function Resolve-GitBash {
  param([string]$Explicit)
  $cands = [System.Collections.Generic.List[string]]::new()
  if ($Explicit) { $cands.Add($Explicit) }
  if ($env:BT_BASH) { $cands.Add($env:BT_BASH) }
  $git = Get-Command git -ErrorAction SilentlyContinue
  if ($git) {
    # ...\Git\cmd\git.exe  ->  ...\Git\bin\bash.exe
    $gitRoot = Split-Path (Split-Path $git.Source -Parent) -Parent
    $cands.Add((Join-Path $gitRoot 'bin\bash.exe'))
  }
  $cands.Add('C:\Program Files\Git\bin\bash.exe')
  $cands.Add('C:\Program Files (x86)\Git\bin\bash.exe')

  foreach ($c in $cands) {
    if (-not $c -or -not (Test-Path -LiteralPath $c)) { continue }
    # A functional test, not a path test. The WSL bash answers nothing here,
    # because it mounts the C drive at /mnt/c.
    $probe = & $c -c 'test -d /c/Users && echo ok' 2>$null
    if ($probe -eq 'ok') { return (Resolve-Path -LiteralPath $c).Path }
  }
  Die 'cannot find Git Bash. Install Git for Windows, or pass -BashExe. The bash in System32 is WSL and will not work.'
}

function Resolve-JavaHomeWin {
  param([string]$Explicit)
  if ($Explicit) { return $Explicit }
  if ($env:BT_JAVA_HOME_WIN) { return $env:BT_JAVA_HOME_WIN }
  # Keep parity with run.sh, which pins this exact JDK. The two runners must not
  # disagree about the JDK. Trap 03 measures toolchain behaviour, so a different
  # JVM there changes the verdict, not only the speed.
  $pinned = 'C:\Users\Dmitriy.Smirnov\.jdks\corretto-21.0.6'
  if (Test-Path -LiteralPath $pinned) { return $pinned }
  # Off that machine, prefer a plain JDK over the JetBrains Runtime.
  $jdks = Join-Path $env:USERPROFILE '.jdks'
  if (Test-Path -LiteralPath $jdks) {
    foreach ($pat in '^corretto[-_]?21', '^(temurin|openjdk|zulu|graalvm)[-_]?21', '^jbr[-_]?21') {
      $hit = Get-ChildItem -LiteralPath $jdks -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match $pat } |
        Sort-Object Name -Descending | Select-Object -First 1
      if ($hit) { return $hit.FullName }
    }
  }
  if ($env:JAVA_HOME) { return $env:JAVA_HOME }
  Die 'cannot find a Java 21 home. Pass -JavaHome, or set BT_JAVA_HOME_WIN.'
}

$Bash = Resolve-GitBash -Explicit $BashExe
$Claude = Get-Command claude -ErrorAction SilentlyContinue
if (-not $Claude) { Die 'the claude CLI is not on PATH' }
$Python = Get-Command python -ErrorAction SilentlyContinue
if (-not $Python) { Die 'python is not on PATH' }

$JavaHomeWin = Resolve-JavaHomeWin -Explicit $JavaHome
$JavaHomeBash = ConvertTo-BashPath $JavaHomeWin

# ------------------------------------------------------------------- locations
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$RunDir = Join-Path $HERE "results\$Stamp"
if (-not $Out) { $Out = Join-Path $RunDir 'results.csv' }
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path $Out -Parent) | Out-Null

if (-not $ScratchRoot) { $ScratchRoot = Join-Path $env:TEMP 'bt-eval' }
# Expand any 8.3 short name now, once, so every path derived from the scratch
# root is in the same long form the file-system cmdlets report back.
$Scratch = [IO.Path]::GetFullPath((Join-Path $ScratchRoot $Stamp))
New-Item -ItemType Directory -Force -Path $Scratch | Out-Null

# The agent under test must run OUTSIDE this repository. Claude Code collects every
# CLAUDE.md from the working directory upwards. A scratch directory inside the
# workspace gives the agent the workspace instructions, which is measured context
# pollution: a probe answered YES to a Next Move Theory question and paid about
# 1,500 extra tokens.
# Test the hazard itself, not a path prefix. An earlier version compared the
# scratch path against the repository root. That let a scratch directory beside
# the repository inherit the workspace CLAUDE.md, and nothing complained.
$probe = Get-Item -LiteralPath $Scratch
while ($probe) {
  $inherited = Join-Path $probe.FullName 'CLAUDE.md'
  if (Test-Path -LiteralPath $inherited) {
    Die "the scratch root inherits $inherited; pick another with -ScratchRoot"
  }
  $probe = $probe.Parent
}

# ----------------------------------------------------------------- claude call
# The prompt goes in through stdin. Passing a multi-line task as a command-line
# argument would need quoting that differs between PowerShell and the CLI.
function Invoke-Claude {
  param(
    [Parameter(Mandatory)][string] $WorkDir,
    [Parameter(Mandatory)][string] $PromptFile,
    [Parameter(Mandatory)][string] $StdoutFile,
    [Parameter(Mandatory)][string] $StderrFile,
    [Parameter(Mandatory)][AllowEmptyCollection()][string[]] $ExtraArgs,
    [Parameter(Mandatory)][int]    $TimeoutSeconds,
    [Parameter(Mandatory)][string] $JavaHomeForRun,
    [string] $ExtraPath = '',
    [string] $MockDir = ''
  )
  $argv = @('-p', '--output-format', 'json', '--model', $Model) + $ExtraArgs
  $prev = Get-Location
  $prevJava = $env:JAVA_HOME
  $prevPath = $env:PATH
  $prevMock = $env:BT_MOCK_DIR
  try {
    Set-Location -LiteralPath $WorkDir
    $env:JAVA_HOME = $JavaHomeForRun
    if ($ExtraPath) { $env:PATH = "$ExtraPath;$env:PATH" }
    $env:BT_MOCK_DIR = $MockDir
    $proc = Start-Process -FilePath $Claude.Source -ArgumentList $argv `
      -RedirectStandardInput $PromptFile `
      -RedirectStandardOutput $StdoutFile `
      -RedirectStandardError $StderrFile `
      -PassThru -NoNewWindow
    if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
      try { $proc.Kill($true) } catch { }
      $proc.WaitForExit()
      return $false
    }
    $proc.WaitForExit()
    return $true
  }
  finally {
    $env:JAVA_HOME = $prevJava
    $env:PATH = $prevPath
    $env:BT_MOCK_DIR = $prevMock
    Set-Location -LiteralPath $prev
  }
}

# ----------------------------------------------------------------- calibration
# Every headless run pays a fixed token cost for the system prompt and the tool
# definitions, before it does any work on the task. Subtract this number, or a
# real saving on the task looks much smaller than it is.
if ($Calibrate) {
  if ($DryRun) { Write-Host "would calibrate with model $Model"; exit 0 }
  $dir = Join-Path $Scratch '_calibration'
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $promptFile = Join-Path $dir 'prompt.txt'
  Set-Content -LiteralPath $promptFile -Value 'Reply with exactly: OK' -Encoding utf8 -NoNewline
  Write-Host "Calibrating fixed harness overhead (model $Model) ..."
  $null = Invoke-Claude -WorkDir $dir -PromptFile $promptFile `
    -StdoutFile (Join-Path $dir 'result.json') `
    -StderrFile (Join-Path $dir 'stderr.log') `
    -ExtraArgs @() -TimeoutSeconds $TimeoutSec -JavaHomeForRun $JavaHomeWin
  & $Python.Source (Join-Path $HERE 'lib\append_row.py') $Out (Join-Path $dir 'result.json') `
    '_calibration' '0' 'PASS' 'fixed harness overhead' $Model '0' $Stamp 'calibration'
  $calStore = Join-Path $HERE 'results\calibration.csv'
  New-Item -ItemType Directory -Force -Path (Join-Path $HERE 'results') | Out-Null
  # Persist the calibration where a later trap run can find it. summarize.py walks up
  # from results\<stamp>\results.csv and reads results\calibration.csv, so one
  # calibration serves every run that follows, with no need to force -Out onto one file.
  & $Python.Source (Join-Path $HERE 'lib\append_row.py') $calStore (Join-Path $dir 'result.json') `
    '_calibration' '0' 'PASS' 'fixed harness overhead' $Model '0' $Stamp 'calibration'
  $fixed = & $Python.Source (Join-Path $HERE 'lib\jsonget.py') (Join-Path $dir 'result.json') `
    'usage.cache_creation_input_tokens' '0'
  Write-Host "Fixed overhead (cache_creation_input_tokens): $fixed"
  Write-Host "Recorded as trap _calibration in $calStore"
  exit 0
}

# ------------------------------------------------------------------- trap list
$trapList = @()
if ($Traps.Count -gt 0) {
  # Accept both -Traps a,b and -Traps a,b -Traps c.
  $trapList = @(($Traps -join ',') -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}
else {
  $trapList = @(Get-ChildItem -LiteralPath (Join-Path $HERE 'traps') -Directory -ErrorAction SilentlyContinue |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'TASK.md') } |
    Sort-Object Name | ForEach-Object { $_.Name })
}
if (-not $trapList) { Die 'no traps found; each trap needs traps/<slug>/TASK.md' }

$baselineLabel = if ($Naive) { 'naive (no CLAUDE.md)' } else { 'fair (BASELINE_CLAUDE.md)' }
Write-Host ('Run       : {0}' -f $Stamp)
Write-Host ('Model     : {0}' -f $Model)
Write-Host ('Repeats   : {0}' -f $Repeats)
Write-Host ('Traps     : {0}' -f ($trapList -join ' '))
Write-Host ('Baseline  : {0}' -f $baselineLabel)
Write-Host ('Skill     : {0}' -f $(if ($Skill) { 'on (install declared skills)' } else { 'off' }))
Write-Host ('Java home : {0}' -f $JavaHomeWin)
Write-Host ('Bash      : {0}' -f $Bash)
Write-Host ('Results   : {0}' -f $Out)
Write-Host ''

if ($DryRun) {
  foreach ($slug in $trapList) { Write-Host ('would run {0} x{1}' -f $slug, $Repeats) }
  exit 0
}

# ---------------------------------------------------------------------- driver
foreach ($slug in $trapList) {
  $trapDir = Join-Path $HERE "traps\$slug"
  if (-not (Test-Path -LiteralPath $trapDir)) { Write-Host "SKIP ${slug}: no such trap"; continue }
  if (-not (Test-Path -LiteralPath (Join-Path $trapDir 'TASK.md'))) { Write-Host "SKIP ${slug}: no TASK.md"; continue }
  if (-not (Test-Path -LiteralPath (Join-Path $trapDir 'oracle.sh'))) { Write-Host "SKIP ${slug}: no oracle.sh"; continue }
  if (-not (Test-Path -LiteralPath (Join-Path $trapDir 'project'))) { Write-Host "SKIP ${slug}: no project/"; continue }

  # A trap about JDK versions may pin its own JAVA_HOME, and a trap about hidden
  # build state may inject a Gradle home or Maven args. Read the values out of the
  # trap env.sh through bash, rather than parsing them here, so that run.sh and
  # run.ps1 cannot disagree about what that file means. Clear the injected pair
  # first, so one trap's env.sh cannot leak into the next.
  [Environment]::SetEnvironmentVariable('GRADLE_USER_HOME', $null)
  [Environment]::SetEnvironmentVariable('MAVEN_ARGS', $null)
  $trapJavaBash = $JavaHomeBash
  $trapGradleHome = ''
  $trapMavenArgs = ''
  $envSh = Join-Path $trapDir 'env.sh'
  if (Test-Path -LiteralPath $envSh) {
    $envShBash = ConvertTo-BashPath $envSh
    # Source env.sh once and read back the variables it may export, separated by a
    # character that cannot appear in a Windows path. env.sh already puts
    # GRADLE_USER_HOME and MAVEN_ARGS in Windows form (cygpath -w), so they are
    # used as-is, not converted.
    $cmd = ". '$envShBash' >/dev/null 2>&1; " +
      'printf ''%s|%s|%s'' "$BT_JAVA_HOME" "$GRADLE_USER_HOME" "$MAVEN_ARGS"'
    $raw = & $Bash -c $cmd 2>$null
    $parts = "$raw" -split '\|', 3
    if ($parts.Count -ge 1 -and $parts[0].Trim()) { $trapJavaBash = $parts[0].Trim() }
    if ($parts.Count -ge 2 -and $parts[1].Trim()) { $trapGradleHome = $parts[1].Trim() }
    if ($parts.Count -ge 3 -and $parts[2].Trim()) { $trapMavenArgs = $parts[2].Trim() }
  }
  $trapJavaWin = ConvertFrom-BashPath $trapJavaBash

  # Inject the hidden build state for both the agent and the oracle, the way run.sh
  # does by sourcing env.sh into the shell that launches them. These stay set for
  # every repeat of this trap and are cleared at the top of the next one.
  if ($trapGradleHome) { $env:GRADLE_USER_HOME = $trapGradleHome }
  if ($trapMavenArgs) { $env:MAVEN_ARGS = $trapMavenArgs }

  for ($i = 1; $i -le $Repeats; $i++) {
    $workRoot = Join-Path $RunDir "$slug\run$i"
    $work = Join-Path $Scratch "$slug\run$i\work"
    New-Item -ItemType Directory -Force -Path $workRoot | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path $work -Parent) | Out-Null
    if (Test-Path -LiteralPath $work) { Clear-Scratch $work }
    Copy-Item -LiteralPath (Join-Path $trapDir 'project') -Destination $work -Recurse

    # The agent must never see the trap documentation. Only project/ is copied,
    # but strip any stray answer file, in case a trap author slipped.
    foreach ($stray in 'TRAP.md', 'EXPECTED.md', 'oracle.sh') {
      $strayPath = Join-Path $work $stray
      if (Test-Path -LiteralPath $strayPath) { Clear-Scratch $strayPath }
    }

    $baseline = Join-Path $HERE 'template\BASELINE_CLAUDE.md'
    if (-not $Naive -and (Test-Path -LiteralPath $baseline)) {
      Copy-Item -LiteralPath $baseline -Destination (Join-Path $work 'CLAUDE.md') -Force
    }

    # A skill run installs the trap's declared skills into the session, and if the trap
    # ships mock fixtures it puts the mock CLI on PATH and serves them. The agent then
    # sees the skill and the tool as a user who had installed them would. skill.txt names
    # one shared skill per line. Comments and blank lines are ignored.
    $condition = 'baseline'
    $skillBin = ''
    $mockDir = ''
    $skillFile = Join-Path $trapDir 'skill.txt'
    if ($Skill -and (Test-Path -LiteralPath $skillFile)) {
      $skillNames = @(Get-Content -LiteralPath $skillFile |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith('#') })
      foreach ($sname in $skillNames) {
        $skillSrc = Join-Path $HERE ('skills\' + $sname)
        if (Test-Path -LiteralPath $skillSrc) {
          $skillDst = Join-Path $work '.claude\skills'
          New-Item -ItemType Directory -Force -Path $skillDst | Out-Null
          Copy-Item -LiteralPath $skillSrc -Destination $skillDst -Recurse -Force
          $condition = 'skill'
        }
        else {
          Write-Host "WARN ${slug}: skill '$sname' not found in skills\" -ForegroundColor Yellow
        }
      }
      # Serve the trap's mock fixtures through the shared CLI. Both sit outside the
      # agent's working tree, so the answer reaches the agent only through the tool.
      if ($condition -eq 'skill' -and (Test-Path -LiteralPath (Join-Path $trapDir 'mock'))) {
        $runRoot = Split-Path $work -Parent
        $skillBin = Join-Path $runRoot 'bin'
        $mockDir = Join-Path $runRoot 'mock'
        New-Item -ItemType Directory -Force -Path $skillBin, $mockDir | Out-Null
        Copy-Item -Path (Join-Path $HERE 'lib\mock\*') -Destination $skillBin -Force
        Copy-Item -Path (Join-Path $trapDir 'mock\*') -Destination $mockDir -Force
      }
    }

    # A trap may need extra flags on the claude command. Trap 07 denies the web
    # tools, because a question it asks is only meaningful when the agent cannot
    # look the answer up. One argument per line, blank lines and # comments ignored.
    $trapArgs = @()
    $argsFile = Join-Path $trapDir 'agent-args.txt'
    if (Test-Path -LiteralPath $argsFile) {
      $trapArgs = @(Get-Content -LiteralPath $argsFile |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith('#') })
    }

    Write-Host ('{0,-28} run {1}/{2} ... ' -f $slug, $i, $Repeats) -NoNewline

    $resultJson = Join-Path $workRoot 'result.json'
    $stderrLog = Join-Path $workRoot 'stderr.log'
    $oracleErr = Join-Path $workRoot 'oracle.err'

    $sw = [Diagnostics.Stopwatch]::StartNew()
    $finished = Invoke-Claude -WorkDir $work -PromptFile (Join-Path $trapDir 'TASK.md') `
      -StdoutFile $resultJson -StderrFile $stderrLog `
      -ExtraArgs (@('--permission-mode', 'bypassPermissions') + $trapArgs) `
      -TimeoutSeconds $TimeoutSec -JavaHomeForRun $trapJavaWin -ExtraPath $skillBin -MockDir $mockDir
    $sw.Stop()
    $wall = [int]$sw.Elapsed.TotalSeconds
    if (-not $finished) {
      Add-Content -LiteralPath $stderrLog -Value "run.ps1: killed after ${TimeoutSec}s"
    }

    $verdict = 'INCONCLUSIVE'
    $detail = 'oracle did not run'
    $line = ''
    $prevBtJava = $env:BT_JAVA_HOME
    $env:BT_JAVA_HOME = $trapJavaBash
    try {
      $oracleOut = & $Bash (ConvertTo-BashPath (Join-Path $trapDir 'oracle.sh')) `
        (ConvertTo-BashPath $work) `
        (ConvertTo-BashPath $resultJson) 2>$oracleErr
      $line = ($oracleOut | Where-Object { $_ -match '\|' } | Select-Object -Last 1)
    }
    finally { $env:BT_JAVA_HOME = $prevBtJava }

    if ($line) {
      $parts = "$line" -split '\|', 2
      $verdict = $parts[0]
      $detail = $parts[1]
    }
    else {
      $detail = 'oracle produced no verdict line'
    }
    Set-Content -LiteralPath (Join-Path $workRoot 'verdict.txt') -Value "$line" -Encoding utf8

    & $Python.Source (Join-Path $HERE 'lib\append_row.py') $Out $resultJson `
      $slug $i $verdict $detail $Model $wall $Stamp $condition

    Write-Host ('{0,-12} {1} ({2}s)' -f $verdict, $detail, $wall)

    # The build output is large and it is not evidence. Drop it, then keep
    # the source tree the agent left behind, so a verdict can be checked by hand.
    # Maven writes target/, Gradle writes build/ and .gradle/.
    $junk = @(Get-ChildItem -LiteralPath $work -Directory -Recurse -Force -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -in @('build', '.gradle', 'target') })
    foreach ($d in $junk) { Clear-Scratch $d.FullName }
    Copy-Item -LiteralPath $work -Destination (Join-Path $workRoot 'work-final') -Recurse -ErrorAction SilentlyContinue
    Clear-Scratch $work
  }
}

Write-Host ''
Write-Host "Done. Rows in $Out"
Write-Host ('Summary: python "{0}\lib\summarize.py" "{1}"' -f $HERE, $Out)
