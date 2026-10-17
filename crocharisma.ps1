# PowerShell port of the oh-my-zsh "crocharisma" (agnoster-style) prompt.
# Dot-source from $PROFILE. Needs a Powerline-patched font.
# Glyphs are built from code points so the file stays ASCII (PS 5.1 misreads BOM-less UTF-8).

$script:ESC = [char]27
$script:SEP = [char]0xE0B0      # powerline arrow
$script:BRANCH = [char]0xE0A0   # powerline branch glyph

# ANSI color numbers: black=0 red=1 green=2 yellow=3 blue=4 cyan=6 default=9
function script:Add-Segment([int]$bg, [int]$fg, [string]$text) {
  if ($null -ne $script:CurrentBg -and $bg -ne $script:CurrentBg) {
    $script:out += " $ESC[4${bg}m$ESC[3$($script:CurrentBg)m$SEP$ESC[3${fg}m "
  } else {
    $script:out += "$ESC[4${bg}m$ESC[3${fg}m "
  }
  $script:CurrentBg = $bg
  $script:out += $text
}

function prompt {
  $lastOk = $?
  $lastCode = $global:LASTEXITCODE
  $script:CurrentBg = $null
  $script:out = ""

  # Status: error, admin, background jobs
  $symbols = ""
  if (-not $lastOk) { $symbols += "$ESC[31m$([char]0x2718)" }
  $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
  if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { $symbols += "$ESC[33m$([char]0x26A1)" }
  if (@(Get-Job).Count -gt 0) { $symbols += "$ESC[36m$([char]0x2699)" }
  if ($symbols) { Add-Segment 0 9 $symbols }

  # Virtualenv / AWS
  if ($env:VIRTUAL_ENV -and $env:VIRTUAL_ENV_DISABLE_PROMPT) { Add-Segment 4 0 "($(Split-Path -Leaf $env:VIRTUAL_ENV))" }
  if ($env:AWS_PROFILE -and $env:SHOW_AWS_PROMPT -ne 'false') {
    if ($env:AWS_PROFILE -match '-prod$|production') { Add-Segment 1 3 "AWS: $env:AWS_PROFILE" }
    else { Add-Segment 2 0 "AWS: $env:AWS_PROFILE" }
  }

  # Context: user@host
  if ($env:USERNAME -ne $env:DEFAULT_USER -or $env:SSH_CLIENT) {
    Add-Segment 0 9 "$env:USERNAME@$([System.Net.Dns]::GetHostName())"
  }

  # Dir: last path component (like %1/)
  $dir = $ExecutionContext.SessionState.Path.CurrentFileSystemLocation.Path
  $leaf = Split-Path -Leaf $dir
  Add-Segment 4 0 $(if ($leaf) { $leaf } else { $dir })

  # Git
  if ((Get-Command git -ErrorAction SilentlyContinue) -and
      (git rev-parse --is-inside-work-tree 2>$null) -eq 'true' -and
      (git config --get oh-my-zsh.hide-status 2>$null) -ne '1') {
    $gitdir = git rev-parse --absolute-git-dir 2>$null
    $ref = git symbolic-ref HEAD 2>$null
    if ($ref) { $ref = "$BRANCH $($ref -replace '^refs/heads/', '')" }
    else { $ref = "$([char]0x27A6) $(git rev-parse --short HEAD 2>$null)" }
    $porcelain = @(git --no-optional-locks status --porcelain 2>$null)
    $flags = ""
    if ($porcelain -match '^.[MDT]') { $flags += [char]0x00B1 }
    if ($porcelain -match '^[MADRCT]') { $flags += [char]0x271A }
    if ($flags) { $flags = " $flags" }
    $mode = ""
    if (Test-Path "$gitdir/BISECT_LOG") { $mode = " <B>" }
    elseif (Test-Path "$gitdir/MERGE_HEAD") { $mode = " >M<" }
    elseif ((Test-Path "$gitdir/rebase") -or (Test-Path "$gitdir/rebase-apply") -or (Test-Path "$gitdir/rebase-merge")) { $mode = " >R>" }
    if ($porcelain.Count -gt 0) { Add-Segment 3 0 } else { Add-Segment 2 0 }
    $script:out += "$ref$flags$mode"
  }

  # End prompt
  if ($null -ne $script:CurrentBg) { $script:out += " $ESC[49m$ESC[3$($script:CurrentBg)m$SEP" }
  $script:out += "$ESC[0m "

  $global:LASTEXITCODE = $lastCode
  $script:out
}
