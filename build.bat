@echo off
cd %~dp0
odin build . -o:none -debug
@REM odin build . -o:speed -debug -no-bounds-check -disable-assert