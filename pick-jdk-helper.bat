@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion
cd /d "%~dp0"

rem ============================================================
rem  从路径里读 JDK 版本
rem
rem  为什么单独一个脚本：主脚本逻辑已经够长了，
rem  再塞进去会让人不敢改。这个只做一件事，改错了也好回退。
rem
rem  用法：pick-jdk-helper.bat "C:\Program Files\Java\jdk-17.0.9"
rem  输出：两行，第一行是主版本号（如 17），第二行是原始版本串
rem  读不出来时输出 0
rem ============================================================

set "P=%~1"
if not defined P ( echo 0 & exit /b 1 )

set "MAJOR=0"
set "RAW="

rem 优先读目录里自带的 release 文件 —— 这是 JDK 的权威版本来源，
rem 比猜目录名可靠（用户可能把 jdk-17 改名成 jdk-my）。
if exist "!P!\release" (
    for /f "tokens=1,2 delims==" %%a in ('findstr /b /i "JAVA_VERSION=" "!P!\release" 2^>nul') do (
        set "RAW=%%b"
    )
)

if not defined RAW (
    rem 退而求其次：从目录名里找 8/11/17/21 这类数字
    for /f "tokens=*" %%n in ("!P!") do set "BASE=%%~nxn"
    for %%v in (8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25) do (
        echo !BASE! | findstr /r /c:"[-_. ]%%v\.[0-9]" /c:"[-_. ]%%v$" >nul && (
            if "!MAJOR!"=="0" set "MAJOR=%%v"
        )
    )
    echo !MAJOR!
    exit /b 0
)

rem RAW 形如 "17.0.9"（带引号）或 17.0.9
set "RAW=!RAW:"=!"
for /f "tokens=1 delims=." %%m in ("!RAW!") do set "MAJOR=%%m"

rem 1.x.y 是 JDK 8 及更早的老格式
if "!MAJOR!"=="1" (
    for /f "tokens=2 delims=." %%m in ("!RAW!") do set "MAJOR=%%m"
)

echo !MAJOR!
exit /b 0
