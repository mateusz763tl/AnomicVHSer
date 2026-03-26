@echo off
setlocal enabledelayedexpansion
REM Set FrameSkip to higher/lower to increase/decrease final frame count
SET /A FrameSkip=5
REM
set "input=%~1"
set "folder=%~n1"

for /f "tokens=7" %%a in ('ffmpeg -i "%input%" 2^>^&1 ^| findstr /C:" fps"') do set "original_fps=%%a"

set "filter=select=not(mod(n\,!FrameSkip!))"

ffmpeg -i "%input%" -vf "!filter!" -fps_mode vfr %folder%.mp4

SET /A fps_amount=original_fps / FrameSkip