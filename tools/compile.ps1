param([string]$RuntimePath = 'C:\ProgramData\GameMakerStudio2-LTS2026\Cache\runtimes\runtime-2026.0.0.23')
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskBuild = Join-Path $taskRoot 'build'
New-Item -ItemType Directory -Force -Path (Join-Path $taskBuild 'cache'),(Join-Path $taskBuild 'temp') | Out-Null
$taskIgor = Join-Path $RuntimePath 'bin\igor\windows\x64\Igor.exe'
if (-not (Test-Path -LiteralPath $taskIgor)) { throw 'Pass -RuntimePath for an installed GameMaker runtime.' }
& $taskIgor "--project=$taskRoot\LNPreserve\LNPreserve.yyp" "--runtimePath=$RuntimePath" "--cache=$taskBuild\cache" "--temp=$taskBuild\temp" "--of=$taskBuild\LNPreserve.win" --runtime=VM --config=Default windows Compile *> (Join-Path $taskBuild 'compile.log')
$taskResult = $LASTEXITCODE
Get-Content -LiteralPath (Join-Path $taskBuild 'compile.log') -Tail 16
if ($taskResult -ne 0) { throw "GameMaker compilation failed: $taskResult. See build/compile.log." }
