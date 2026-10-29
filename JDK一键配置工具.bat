@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion
cd /d "%~dp0"

rem ============================================================
rem  JDK 一键配置工具  by 极客港
rem
rem  修复的三个致命问题：
rem   1. 目录扫描把多个带空格的路径塞进一个变量，被空格切碎，
rem      C:\Program Files\Java 下的标准安装永远检测不到
rem   2. 用 PowerShell 读 Machine PATH 会展开 %JAVA_HOME% 等变量再写回，
rem      永久固化，之后换 JDK 再也不能靠 JAVA_HOME 生效
rem   3. del 覆盖了 PowerShell 的退出码，PATH 写失败也显示「配置完成」
rem
rem  另外新增：改之前自动备份 + 生成 restore.bat 回滚。
rem ============================================================

rem ---------- 提权 ----------
rem 用 fltmc 而不是 net session：后者依赖 Server 服务，
rem 精简系统上管理员也会被判成非管理员，导致反复弹 UAC。
fltmc >nul 2>&1
if errorlevel 1 (
    powershell -NoProfile -Command "try { Start-Process -FilePath '%~f0' -Verb RunAs -ErrorAction Stop } catch { exit 2 }"
    if errorlevel 2 echo [ERROR] 提权被取消，未做任何修改。
    exit /b
)

echo ==========================================
echo       JDK 一键配置工具  by 极客港
echo ==========================================
echo.

set "IDX=0"

rem ---------- 1. 注册表检测 ----------
rem Adoptium / Corretto / Microsoft 的子键结构不同（没有 CurrentVersion），
rem 所以用 /s 递归找 JavaHome，而不是拼 CurrentVersion。
for %%K in (
  "HKLM\SOFTWARE\JavaSoft\Java Development Kit"
  "HKLM\SOFTWARE\JavaSoft\JDK"
  "HKLM\SOFTWARE\Eclipse Adoptium\JDK"
  "HKLM\SOFTWARE\Amazon Corretto\JDK"
  "HKLM\SOFTWARE\Microsoft\JDK"
) do (
    for /f "tokens=2,*" %%a in ('reg query %%K /s /v JavaHome 2^>nul ^| findstr /i "JavaHome"') do (
        call :TRY_ADD "%%b"
    )
)

rem ---------- 2. 目录扫描 ----------
rem 每个目录单独判断，路径含空格也不会被切碎。
for %%D in (
  "%ProgramFiles%\Java"
  "%ProgramFiles%\Eclipse Adoptium"
  "%ProgramFiles%\Amazon Corretto"
  "%ProgramFiles%\Microsoft"
  "%USERPROFILE%\.jdks"
) do (
    if exist "%%~D" (
        for /f "delims=" %%j in ('dir /b /ad "%%~D\jdk*" "%%~D\jre*" 2^>nul') do (
            call :TRY_ADD "%%~D\%%j"
        )
    )
)

rem ---------- 3. 命令行参数（便于脚本化） ----------
if not "%~1"=="" (
    call :TRY_ADD "%~1"
    if "!IDX!"=="0" (
        echo [ERROR] 不是有效的 JDK 目录: %~1
        exit /b 1
    )
    call :PICK_LAST
    goto APPLY
)

rem ---------- 4. 交互选择 ----------
if "!IDX!"=="0" goto ASK_MANUAL

echo 检测到以下 JDK：
for /l %%i in (1,1,!IDX!) do echo   [%%i] !JDK_%%i!
set /p "CH=请选择序号，或输入 M 手动指定："
if /i "!CH!"=="M" goto ASK_MANUAL
echo !CH!|findstr /x "[1-9][0-9]*" >nul || ( echo [ERROR] 输入无效 & pause & exit /b 1 )
if !CH! lss 1 ( echo [ERROR] 输入无效 & pause & exit /b 1 )
if !CH! gtr !IDX! ( echo [ERROR] 输入无效 & pause & exit /b 1 )
set "JDK_PATH=!JDK_%CH%!"
goto APPLY

:ASK_MANUAL
echo [提示] 请输入 JDK 安装目录（例如 C:\Program Files\Java\jdk-17）
set /p "JDK_PATH=路径："
call :NORMALIZE
if not defined JDK_PATH_OK (
    echo [ERROR] 无效路径，未做任何修改。
    pause & exit /b 1
)

:APPLY
cls
echo ==========================================
echo     即将修改系统环境变量
echo ==========================================
echo.
echo   JDK 目录 : !JDK_PATH!
echo   JAVA_HOME: !JAVA_HOME!
echo.
echo   修改前会自动备份，可双击 restore.bat 回滚。
echo.
set "OK="
set /p "OK=确认继续? (Y/N): "
if /i not "!OK!"=="Y" (
    echo [已取消] 未做任何修改。
    pause & exit /b 1
)

rem ---------- 备份 ----------
rem 时间戳用 PowerShell 取：wmic 在新版 Windows 已弃用，且经 for /f 传递时易被拆坏
for /f %%t in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"') do set "STAMP=%%t"
if not defined STAMP set "STAMP=backup"
set "BAK=%~dp0backup_!STAMP!"
mkdir "!BAK!" >nul 2>&1
reg export "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "!BAK!\system_env.reg" /y >nul
if errorlevel 1 (
    echo [ERROR] 备份失败，已中止，未修改任何东西。
    pause & exit /b 1
)
echo [OK] 已备份到 "!BAK!\system_env.reg"

> "%~dp0restore.bat" echo @echo off
>> "%~dp0restore.bat" echo echo 正在回滚到 !STAMP! 的备份...
>> "%~dp0restore.bat" echo reg import "!BAK!\system_env.reg"
>> "%~dp0restore.bat" echo echo 回滚完成，请重新打开终端。
>> "%~dp0restore.bat" echo pause
echo [OK] 已生成 restore.bat

rem ---------- 写 JAVA_HOME 与 PATH ----------
rem 关键：用 Registry API 读写，PropertyType 保持 ExpandString，
rem 否则 PATH 里的 %JAVA_HOME% / %SystemRoot% 会被展开固化。
set "PSFILE=%TEMP%\jdk_set_%RANDOM%.ps1"
> "!PSFILE!" echo $ErrorActionPreference = 'Stop'
>> "!PSFILE!" echo $BS = [char]92
>> "!PSFILE!" echo $rk = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment', $true)
>> "!PSFILE!" echo $jh = '!JDK_PATH!'
>> "!PSFILE!" echo $rk.SetValue('JAVA_HOME', $jh, [Microsoft.Win32.RegistryValueKind]::String)
>> "!PSFILE!" echo $v = $rk.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
>> "!PSFILE!" echo if ($null -eq $v) { $v = '' }
>> "!PSFILE!" echo $keep = @()
>> "!PSFILE!" echo foreach ($p in $v.Split(';')) {
>> "!PSFILE!" echo   if ($p -eq '') { continue }
>> "!PSFILE!" echo   $seg = $p.Split($BS)
>> "!PSFILE!" echo   $isJdk = $false
>> "!PSFILE!" echo   if ($seg.Count -ge 2 -and $seg[-1] -eq 'bin') {
>> "!PSFILE!" echo     $par = $seg[-2]
>> "!PSFILE!" echo     if ($par -like 'jdk*' -or $par -like 'jre*') { $isJdk = $true }
>> "!PSFILE!" echo   }
>> "!PSFILE!" echo   if (-not $isJdk) { $keep += $p }
>> "!PSFILE!" echo }
>> "!PSFILE!" echo $keep += ($jh + $BS + 'bin')
>> "!PSFILE!" echo $rk.SetValue('Path', ($keep -join ';'), [Microsoft.Win32.RegistryValueKind]::ExpandString)
>> "!PSFILE!" echo Write-Host ('[OK] JAVA_HOME = ' + $jh)
>> "!PSFILE!" echo $rk.Close()

powershell -NoProfile -ExecutionPolicy Bypass -File "!PSFILE!"
set "PS_RC=!errorlevel!"
del "!PSFILE!" >nul 2>&1

if not "!PS_RC!"=="0" (
    echo.
    echo [错误] 写入失败。可双击 restore.bat 回滚。
    pause & exit /b 1
)

echo.
echo ==========================================
echo      配置完成
echo ==========================================
echo  JAVA_HOME = !JDK_PATH!
echo.
echo  请重新打开终端 / IDE 才会生效。
echo  如需回滚: 双击 restore.bat
echo.
pause
exit /b 0

rem ============================================================
rem  子过程
rem ============================================================

:TRY_ADD
set "CAND=%~1"
if not exist "!CAND!\bin\javac.exe" exit /b 0
for %%i in ("!CAND!") do set "CAND=%%~fi"
for /l %%i in (1,1,!IDX!) do if /i "!JDK_%%i!"=="!CAND!" exit /b 0
set /a IDX+=1
set "JDK_!IDX!=!CAND!"
exit /b 0

:PICK_LAST
set "JDK_PATH=!JDK_%IDX%!"
exit /b 0

:NORMALIZE
set "JDK_PATH_OK="
if not defined JDK_PATH exit /b 0
set "JDK_PATH=!JDK_PATH:"=!"
if "!JDK_PATH!"=="" exit /b 0
for %%i in ("!JDK_PATH!") do set "JDK_PATH=%%~fi"
if not exist "!JDK_PATH!\bin\javac.exe" exit /b 0
set "JDK_PATH_OK=1"
exit /b 0
