@echo off
chcp 65001 >nul
setlocal
if "%~1"=="" (
    echo.
    echo  用法：patch-cmdline.bat 盘符
    echo  例如：patch-cmdline.bat I:
    echo.
    echo  盘符在"此电脑"里看那个叫 bootfs 的 512MB 小分区。
    echo.
    pause
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0patch-cmdline.ps1" -Drive "%~1"
pause