@echo off
setlocal enabledelayedexpansion
REM Set FrameSkip to higher/lower to increase/decrease final frame count
SET /A FrameSkip=5
set "input=%~f1"
set "folder=%~n1"

if /i NOT "%~x1"==".gif" goto regularfps

echo SPECIAL FPS ROUTINE: GIF
for /f "tokens=7" %%a in ('ffmpeg -i "%input%" 2^>^&1 ^| findstr /C:" fps"') do set "original_fps=%%a"
goto fpsdone

:regularfps
echo Regular FPS Routine
for /f "skip=8 tokens=4" %%a in ('mediainfo "%input%"') do (
    set "original_fps=%%a"
    goto stripdecimals
)
:stripdecimals
for /f "tokens=1 delims=." %%a in ("!original_fps!") do set "original_fps=%%a"

:fpsdone
echo [DEBUG] original_fps = !original_fps!
mkdir "%folder%"
cd "%folder%"
set "filter=select=not(mod(n\,!FrameSkip!))"
ffmpeg -i "%input%" -vf "!filter!" -fps_mode vfr frame_%%04d.png
SET /A fps_amount=original_fps / FrameSkip
echo !fps_amount! FPS > anomicinfo.txt
pause