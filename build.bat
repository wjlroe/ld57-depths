@echo off
setlocal

SET PATH=%PATH%;C:\dev\odin\2025-04

set build_release=no
set run_after_build=no

if "%1"=="run" set run_after_build=yes
if "%1"=="all" set build_release=yes

echo Debug build
odin build src ^
    -out:build/base_code_debug.exe ^
    -build-mode:exe ^
    -subsystem:console ^
    -debug ^
    -o:minimal ^
    -show-timings || goto :error

if "%run_after_build%"=="yes" .\build\base_code_debug.exe

rem echo Web build
rem odin build src ^
rem     -target:js_wasm32 ^
rem     -show-timings || goto :error

if NOT "%1"=="all" goto end

echo Release build
odin build src ^
    -out:build/base_code.exe ^
    -build-mode:exe ^
    -subsystem:windows ^
    -o:speed ^
    -disable-assert ^
    -show-timings || goto :error

goto :end

:error
echo Failed with error #%errorlevel%
exit /b %errorlevel%

:end
