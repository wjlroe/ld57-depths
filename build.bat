@echo off
setlocal

echo Debug build
C:\dev\odin\dev-master\odin build src ^
    -out:build/base_code.exe ^
    -build-mode:exe ^
    -subsystem:console ^
    -debug ^
    -show-timings

if NOT "%1"=="all" goto End

echo Release build
C:\dev\odin\dev-master\odin build src ^
    -out:build/base_code_release.exe ^
    -build-mode:exe ^
    -subsystem:windows ^
    -o:speed ^
    -disable-assert ^
    -show-timings

:End
