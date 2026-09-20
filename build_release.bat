@echo off
setlocal
set OUT=%USERPROFILE%\Desktop\rarm
cd /d "%~dp0"

call flutter build apk --release || goto :fail
call flutter build windows --release || goto :fail

if exist "%OUT%" rmdir /s /q "%OUT%"
mkdir "%OUT%\windows"
copy /y "build\app\outputs\flutter-apk\app-release.apk" "%OUT%\rarm.apk" >nul || goto :fail
xcopy /e /i /y /q "build\windows\x64\runner\Release" "%OUT%\windows" >nul || goto :fail

echo Done: %OUT%
exit /b 0

:fail
echo BUILD FAILED
exit /b 1
