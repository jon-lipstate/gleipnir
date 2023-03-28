@echo off
cd %~dp0
odin build . -o:none -debug
@REM odin run . -o:speed -no-bounds-check -disable-assert