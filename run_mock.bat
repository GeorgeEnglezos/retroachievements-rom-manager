@echo off
rem Screenshot mock: real library under a fake RetroAchievements name, one
rem console maker only. Close the real app first.
rem   run_mock.bat            Sony
rem   run_mock.bat Nintendo   another maker (ConsoleMap names)
rem   run_mock.bat all        every system
setlocal
cd /d "%~dp0"
set ONLY=%~1
if "%ONLY%"=="" set ONLY=Sony
if /i "%ONLY%"=="all" set ONLY=
call flutter run -d windows --profile -t tool/demo/main_mock.dart --dart-define=ONLY=%ONLY%
