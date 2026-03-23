@echo off
setlocal enabledelayedexpansion
REM Set FrameSkip to higher/lower to increase/decrease final frame count
SET /A FrameSkip=10
REM
set "input=%~1"
set "folder=%~n1"

for /f "tokens=7" %%a in ('ffmpeg -i "%input%" 2^>^&1 ^| findstr /C:" fps"') do set "original_fps=%%a"

mkdir "%folder%"
cd "%folder%"

set "filter=select=not(mod(n\,!FrameSkip!))"

ffmpeg -i "%input%" -vf "!filter!" -fps_mode vfr frame_%%04d.png

SET /A fps_amount=original_fps / FrameSkip

echo !fps_amount! FPS > anomicinfo.txt
