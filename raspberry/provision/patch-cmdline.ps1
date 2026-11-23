# 利用 PowerShell 把一次性启动钩子写进卡的 cmdline.txt
# 由 patch-cmdline.bat 调用，也可以直接运行：
#   powershell -ExecutionPolicy Bypass -File patch-cmdline.ps1 I:
param(
    [Parameter(Mandatory = $false)]
    [string]$Drive = "I:"
)

$ErrorActionPreference = "Stop"
$path = Join-Path $Drive "cmdline.txt"

if (-not (Test-Path $path)) {
    Write-Host "找不到 $path" -ForegroundColor Red
    Write-Host "把卡插好后，用 bootfs 分区的盘符再试一次，例如： patch-cmdline.bat I:" -ForegroundColor Yellow
    exit 1
}

Copy-Item $path "$path.bak" -Force
$line = (Get-Content $path -Raw).Trim()

$args = "systemd.run=/boot/firmware/lyrichud/firstrun.sh " +
        "systemd.run_success_action=none " +
        "systemd.run_failure_action=none " +
        "systemd.unit=kernel-command-line.target"

if ($line -match "systemd\.run=") {
    # 已经写过：先把旧参数剥掉再重写，保持幂等
    $line = $line -replace " systemd\.run=[^ ]*", "" `
                  -replace " systemd\.run_success_action=[^ ]*", "" `
                  -replace " systemd\.run_failure_action=[^ ]*", "" `
                  -replace " systemd\.unit=kernel-command-line\.target", ""
}

$new = ($line.Trim() + " " + $args).Trim()
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($path, $new + "`n", $utf8)

Write-Host "已写入 $path" -ForegroundColor Green
Write-Host $new
Write-Host ""
Write-Host "首次开机会自动执行 /boot/firmware/lyrichud/firstrun.sh 完成安装。" -ForegroundColor Cyan
Write-Host "装完的日志在卡上：lyrichud\report.txt" -ForegroundColor Cyan