@echo off
setlocal
pushd "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -STA -File "wallpaper_setter.ps1"
popd
endlocal
