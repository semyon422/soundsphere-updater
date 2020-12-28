@echo off
set PATH=%PATH%;curl;luajit
luajit main.lua
pause