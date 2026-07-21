@echo off
setlocal enabledelayedexpansion
chcp 936 >nul 2>&1
cd /d "%~dp0"

net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process cmd -ArgumentList '/c cd /d \"%~dp0\" && \"%~dp0%~nx0\" && pause' -Verb RunAs"
    exit /b
)

echo ==========================================
echo       JDK 一键配置工具  by 极客港
echo ==========================================
echo.

set IDX=0
set K1=HKLM\SOFTWARE\JavaSoft\Java Development Kit
set K2=HKLM\SOFTWARE\JavaSoft\JDK
for %%r in ("!K1!" "!K2!") do (
    set "RK=%%~r"
    for /f "skip=2 tokens=3" %%v in ('reg query "!RK!" /v CurrentVersion 2^>nul') do (
        set "JV=%%v"
        for /f "skip=2 tokens=2,*" %%a in ('reg query "!RK!\!JV!" /v JavaHome 2^>nul') do (
            set "p=%%b"
            if exist "!p!\bin\javac.exe" (
                set "dup="
                for /l %%i in (1,1,!IDX!) do if "!JDK_%%i!"=="!p!" set dup=1
                if not defined dup (
                    set /a IDX+=1
                    set "JDK_!IDX!=!p!"
                    set "VER_!IDX!=!JV!"
                )
            )
        )
    )
)

set DIRS="C:\Program Files\Java" "C:\Program Files\Eclipse Adoptium" "C:\Program Files\Eclipse Foundation" "C:\Program Files\Amazon Corretto" "C:\Program Files\Microsoft" "D:\Program Files\Java"
for %%d in (!DIRS!) do (
    if exist %%d (
        for /f "delims=" %%j in ('dir /b /ad "%%d\jdk*" "%%d\jre*" 2^>nul') do (
            set "JJ=%%d\%%j"
            if exist "!JJ!\bin\javac.exe" (
                set "dup="
                for /l %%i in (1,1,!IDX!) do if "!JDK_%%i!"=="!JJ!" set dup=1
                if not defined dup (
                    set /a IDX+=1
                    set "JDK_!IDX!=!JJ!"
                    set "VER_!IDX!=%%j"
                )
            )
        )
    )
)

if !IDX! equ 0 (
    echo [提示] 未检测到 JDK
    set /p JDK_PATH="请输入 JDK 路径："
    if not exist "!JDK_PATH!\bin\javac.exe" ( echo [错误] 无效路径 & pause & exit /b 1 )
    goto APPLY
)

echo 检测到以下 JDK：
for /l %%i in (1,1,!IDX!) do echo   [%%i] !VER_%%i!  --  !JDK_%%i!
set /p CH="请选择 (1-!IDX!) 或 M："
if /i "!CH!"=="M" (
    set /p JDK_PATH="请输入 JDK 路径："
    if not exist "!JDK_PATH!\bin\javac.exe" ( echo [错误] 无效路径 & pause & exit /b 1 )
    goto APPLY
)
echo !CH!|findstr /x "[1-9][0-9]*" >nul || ( echo [错误] 输入无效 & pause & exit /b 1 )
if !CH! lss 1 ( echo [错误] 输入无效 & pause & exit /b 1 )
if !CH! gtr !IDX! ( echo [错误] 输入无效 & pause & exit /b 1 )
set JDK_PATH=!JDK_%CH%!

:APPLY
cls
echo [目标] !JDK_PATH!
setx JAVA_HOME "!JDK_PATH!" -m >nul
if %errorlevel% equ 0 ( echo [成功] JAVA_HOME = !JDK_PATH! ) else ( echo [失败] 无法设置 JAVA_HOME & pause & exit /b 1 )

set PSFILE=%TEMP%\jdk_update_path.ps1
echo $p=[Environment]::GetEnvironmentVariable("Path","Machine") > "!PSFILE!"
echo $b="!JDK_PATH!\bin" >> "!PSFILE!"
echo if ($p.Split(";") -contains $b) { write-host "已存在" } else { [Environment]::SetEnvironmentVariable("Path",$p+";"+$b,"Machine"); write-host "已添加" } >> "!PSFILE!"
powershell -ExecutionPolicy Bypass -File "!PSFILE!"
del "!PSFILE!" 2>nul
if %errorlevel% neq 0 echo [失败] 无法更新 PATH

echo.
echo ==========================================
echo       配置完成！
echo ==========================================
echo.
echo JAVA_HOME = !JDK_PATH!
echo.
echo 请重新打开终端/IDE 以生效
echo.
pause
