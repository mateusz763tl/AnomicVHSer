@echo off
setlocal enabledelayedexpansion

:: ============================================================
::  Roblox Bulk Decal Uploader
::  Uses the Roblox Open Cloud Assets API (no cookie needed)
::
::  SETUP:
::  1. Get your API key from: https://create.roblox.com/credentials
::     - Add "Assets API" with Read + Write access
::  2. Put your API key in "apikey.txt" next to this script
::  3. Put your Roblox user ID in "userid.txt" next to this script
::     OR set GROUP_ID below if uploading to a group
::
::  USAGE:
::  - Drag and drop image files or folders onto this script
::  - Or double-click to use the default "images" folder
::
::  OUTPUT:
::  - ids.txt written into the dragged folder (or images folder)
::  - upload_log.txt written next to this script
::
::  Supports: .png, .jpg, .jpeg, .bmp, .tga
::  Ignores:  anomicinfo.txt
:: ============================================================

:: ---------- CONFIGURATION ----------
set "GROUP_ID="
set "DECAL_DESCRIPTION=Uploaded via bulk uploader"
set "DELAY_SECONDS=2"
set "POLL_ATTEMPTS=15"
set "POLL_DELAY=4"
set "LOG_FILE=%~dp0upload_log.txt"
:: -----------------------------------

:: Load API key
set "APIKEY_FILE=%~dp0apikey.txt"
if not exist "!APIKEY_FILE!" (
    echo ERROR: apikey.txt not found next to this script.
    pause & exit /b 1
)
set /p API_KEY=<"!APIKEY_FILE!"
if "!API_KEY!"=="" (
    echo ERROR: apikey.txt is empty.
    pause & exit /b 1
)

:: Load User ID
set "USER_ID="
if "!GROUP_ID!"=="" (
    set "USERID_FILE=%~dp0userid.txt"
    if not exist "!USERID_FILE!" (
        echo ERROR: userid.txt not found next to this script.
        pause & exit /b 1
    )
    set /p USER_ID=<"!USERID_FILE!"
    if "!USER_ID!"=="" (
        echo ERROR: userid.txt is empty.
        pause & exit /b 1
    )
)

:: Check curl
where curl >nul 2>&1
if errorlevel 1 (
    echo ERROR: curl is not available. Please update Windows or install curl.
    pause & exit /b 1
)

:: Start log
echo ============================================================ > "%LOG_FILE%"
echo  Roblox Bulk Decal Upload Log >> "%LOG_FILE%"
echo  Started: %date% %time% >> "%LOG_FILE%"
echo ============================================================ >> "%LOG_FILE%"

echo.
echo ============================================================
echo  Roblox Bulk Decal Uploader
echo ============================================================

set /a TOTAL=0
set /a SUCCESS=0
set /a FAILED=0

:: ---- Determine input source ----
if "%~1"=="" (
    set "IMAGES_DIR=%~dp0images"
    if not exist "!IMAGES_DIR!" (
        echo ERROR: No files dragged, and default images folder not found:
        echo   !IMAGES_DIR!
        pause & exit /b 1
    )
    echo  Mode: Default folder
    echo  Path: !IMAGES_DIR!
    echo ============================================================
    echo.
    if exist "!IMAGES_DIR!\ids.txt" del "!IMAGES_DIR!\ids.txt"
    set "CURRENT_IDS_FILE=!IMAGES_DIR!\ids.txt"
    call :process_dir "!IMAGES_DIR!"
    goto summary
)

echo  Mode: Drag and drop
echo ============================================================
echo.

:arg_loop
if "%~1"=="" goto summary
set "ARG=%~1"

if exist "!ARG!\*" (
    echo [Folder] !ARG!
    if exist "!ARG!\ids.txt" del "!ARG!\ids.txt"
    set "CURRENT_IDS_FILE=!ARG!\ids.txt"
    call :process_dir "!ARG!"
) else if exist "!ARG!" (
    for %%F in ("!ARG!") do set "CURRENT_IDS_FILE=%%~dpFids.txt"
    call :process_file "!ARG!"
) else (
    echo [SKIP] Not found: !ARG!
)
shift
goto arg_loop

:summary
echo.
echo ============================================================
echo  DONE!
echo  Total : !TOTAL!
echo  OK    : !SUCCESS!
echo  Failed: !FAILED!
echo ============================================================
echo.
echo Full log saved to: %LOG_FILE%
echo.

echo. >> "%LOG_FILE%"
echo ============================================================ >> "%LOG_FILE%"
echo  Finished: %date% %time% >> "%LOG_FILE%"
echo  Total: !TOTAL! / Success: !SUCCESS! / Failed: !FAILED! >> "%LOG_FILE%"
echo ============================================================ >> "%LOG_FILE%"

pause
endlocal
exit /b 0


:: ================================================================
::  SUBROUTINE: process_dir
:: ================================================================
:process_dir
set "SCAN_DIR=%~1"
for %%E in (png jpg jpeg bmp tga) do (
    for %%F in ("!SCAN_DIR!\*.%%E") do (
        call :process_file "%%F"
    )
)
exit /b 0


:: ================================================================
::  SUBROUTINE: process_file
:: ================================================================
:process_file
set "FILE=%~1"
set "FILENAME=%~nx1"
set "DISPLAY_NAME=%~n1"
set "FILE_EXT=%~x1"

:: Skip anomicinfo.txt
if /i "!FILENAME!"=="anomicinfo.txt" (
    echo [SKIP] !FILENAME! ^(anomicinfo.txt ignored^)
    exit /b 0
)

:: Skip non-image files
set "VALID_EXT=0"
for %%E in (png jpg jpeg bmp tga) do (
    if /i "!FILE_EXT!"==".%%E" set "VALID_EXT=1"
)
if "!VALID_EXT!"=="0" (
    echo [SKIP] !FILENAME! ^(unsupported type^)
    exit /b 0
)

:: Extract frame number from filename (e.g. frame_0001 -> 1)
set "FRAME_NUM=0"
for /f "tokens=2 delims=_." %%N in ("!DISPLAY_NAME!") do (
    set "RAW_NUM=%%N"
    for /f "tokens=* delims=0" %%Z in ("!RAW_NUM!") do set "FRAME_NUM=%%Z"
    if "!FRAME_NUM!"=="" set "FRAME_NUM=0"
)

set /a TOTAL+=1
echo [!TOTAL!] Uploading: !FILENAME!

:: Build creator JSON
if not "!GROUP_ID!"=="" (
    set "CREATOR_JSON={\"groupId\":\"!GROUP_ID!\"}"
) else (
    set "CREATOR_JSON={\"userId\":\"!USER_ID!\"}"
)

set "REQUEST_JSON={\"assetType\":\"Decal\",\"displayName\":\"!DISPLAY_NAME!\",\"description\":\"%DECAL_DESCRIPTION%\",\"creationContext\":{\"creator\":!CREATOR_JSON!}}"

:: Upload
curl -s -X POST "https://apis.roblox.com/assets/v1/assets" ^
    -H "x-api-key: !API_KEY!" ^
    -F "request=!REQUEST_JSON!" ^
    -F "fileContent=@\"!FILE!\"" ^
    -o "%TEMP%\rblx_response.json" 2>&1

:: Use PowerShell to extract the operation ID from the JSON
for /f "delims=" %%I in ('powershell -NoProfile -Command ^
    "try { $j = Get-Content '%TEMP%\rblx_response.json' -Raw | ConvertFrom-Json; $p = $j.path; if ($p) { $p.Split('/')[-1] } else { '' } } catch { '' }"') do set "OPERATION_ID=%%I"

if "!OPERATION_ID!"=="" (
    set /a FAILED+=1
    set /p UPLOAD_RESPONSE=<"%TEMP%\rblx_response.json"
    echo    FAILED - Could not parse operation ID
    echo    Response: !UPLOAD_RESPONSE!
    echo [FAILED]  !FILENAME! - Could not parse operation ID >> "%LOG_FILE%"
    echo.
    timeout /t %DELAY_SECONDS% /nobreak >nul
    exit /b 0
)

echo    Uploaded. Polling for asset ID ^(operation: !OPERATION_ID!^)...

:: Poll using PowerShell to parse the nested response correctly
:: Response structure: { done: bool, path: str, response: { assetId: str, ... } }
set "ASSET_ID="
set /a POLL_COUNT=0

:poll_loop
set /a POLL_COUNT+=1
if !POLL_COUNT! GTR %POLL_ATTEMPTS% (
    echo    TIMEOUT - Asset not ready after %POLL_ATTEMPTS% attempts
    echo [TIMEOUT] !FILENAME! - operation !OPERATION_ID! >> "%LOG_FILE%"
    goto poll_done
)

timeout /t %POLL_DELAY% /nobreak >nul

curl -s "https://apis.roblox.com/assets/v1/operations/!OPERATION_ID!" ^
    -H "x-api-key: !API_KEY!" ^
    -o "%TEMP%\rblx_op.json" 2>&1

:: Use PowerShell to check done flag and extract assetId from nested response
for /f "delims=" %%R in ('powershell -NoProfile -Command ^
    "try { $j = Get-Content '%TEMP%\rblx_op.json' -Raw | ConvertFrom-Json; if ($j.done -eq $true -and $j.response.assetId) { $j.response.assetId } elseif ($j.done -eq $true) { 'DONE_NO_ID' } else { 'PENDING' } } catch { 'ERROR' }"') do set "POLL_RESULT=%%R"

if "!POLL_RESULT!"=="PENDING" (
    echo    Attempt !POLL_COUNT! - still processing...
    goto poll_loop
)
if "!POLL_RESULT!"=="ERROR" (
    echo    Attempt !POLL_COUNT! - parse error, retrying...
    goto poll_loop
)
if "!POLL_RESULT!"=="DONE_NO_ID" (
    set /a FAILED+=1
    echo    FAILED - Upload done but no asset ID returned ^(moderation rejected?^)
    echo [FAILED]  !FILENAME! - done but no assetId returned >> "%LOG_FILE%"
    goto poll_done
)

:: Got a valid asset ID
set "ASSET_ID=!POLL_RESULT!"

:poll_done
if not "!ASSET_ID!"=="" (
    set /a SUCCESS+=1
    echo    OK - Asset ID: !ASSET_ID!
    echo [SUCCESS] !FILENAME! - Asset ID: !ASSET_ID! >> "%LOG_FILE%"
    echo ,!ASSET_ID! >> "!CURRENT_IDS_FILE!"
)

echo.
timeout /t %DELAY_SECONDS% /nobreak >nul
exit /b 0
