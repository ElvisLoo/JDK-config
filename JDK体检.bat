@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion
cd /d "%~dp0"

rem ============================================================
rem  JDK 体检
rem
rem  为什么需要：配好了 JAVA_HOME 不等于环境能用。
rem  中文 Windows 上最常见的两个坑：
rem    1) javac 默认按 GBK 解码源码，UTF-8 中文注释直接编译失败，
rem       报错文案是"编码 GBK 的不可映射字符"，行号看着完全正常，
rem       新手几乎不可能联想到是编码问题；
rem    2) 环境变量里残留了别的 JDK 路径，java 和 javac 版本不一致，
rem       编译能过运行就炸（UnsupportedClassVersionError）。
rem  这两类问题都不算"没装 JDK"，但用户体感就是"JDK 坏了"。
rem ============================================================

echo ==========================================
echo            JDK 体检  by 极客港
echo ==========================================
echo.

set "PROBLEM=0"

rem ---------- 1. java 能不能跑 ----------
echo [1/6] java 命令
where java >nul 2>&1
if errorlevel 1 (
    echo   [FAIL] PATH 里找不到 java
    set "PROBLEM=1"
    goto NEXT_JAVAC
)
for /f "tokens=*" %%v in ('java -version 2^>^&1 ^| findstr /i "version"') do (
    echo   [ OK ] %%v
)
echo   [信息] 实际路径: 
for /f "delims=" %%p in ('where java') do echo          %%p

:NEXT_JAVAC
rem ---------- 2. javac 能不能跑 ----------
echo.
echo [2/6] javac 命令
where javac >nul 2>&1
if errorlevel 1 (
    echo   [FAIL] PATH 里找不到 javac —— 装的是 JRE 不是 JDK
    echo          编译 Java 代码必须用 JDK。JRE 只能运行，不能编译。
    set "PROBLEM=1"
    goto NEXT_MATCH
)
for /f "tokens=*" %%v in ('javac -version 2^>^&1') do (
    echo   [ OK ] %%v
)

:NEXT_MATCH
rem ---------- 3. java 与 javac 版本是否一致 ----------
rem 这是最隐蔽的一类故障：环境变量里两个 JDK 混着，编译用新版、运行用旧版。
echo.
echo [3/6] java 与 javac 版本一致性
set "JV="
set "CV="
for /f "tokens=3" %%v in ('java -version 2^>^&1 ^| findstr /i "version"') do (
    if not defined JV set "JV=%%~v"
)
for /f "tokens=2" %%v in ('javac -version 2^>^&1') do (
    if not defined CV set "CV=%%v"
)
if not defined JV goto SKIP_MATCH
if not defined CV goto SKIP_MATCH
if /i "!JV!"=="!CV!" (
    echo   [ OK ] 两者都是 !JV!
) else (
    echo   [WARN] java=!JV!  但 javac=!CV!
    echo          版本不一致：编译产物可能在你自己的机器上跑不起来。
    echo          常见原因：PATH 里残留了另一个 JDK 的 bin 目录。
    set "PROBLEM=1"
)
:SKIP_MATCH

rem ---------- 4. 源码编码 ----------
echo.
echo [4/6] 源码编码（中文 Windows 的高频坑）
set "ENC="
for /f "tokens=2 delims==" %%e in ('java -XshowSettings:properties -version 2^>^&1 ^| findstr /i "file.encoding"') do (
    if not defined ENC set "ENC=%%e"
)
if defined ENC (
    for /f "tokens=*" %%e in ("!ENC!") do set "ENC=%%e"
    echo   [信息] 默认编码: !ENC!
    if /i not "!ENC!"=="UTF-8" (
        echo   [WARN] 默认不是 UTF-8。源码里有中文注释时会报
        echo          "编码 GBK 的不可映射字符"，而且行号看起来完全正常。
        echo          解决办法：javac 加 -encoding UTF-8，
        echo                    或运行时加 -Dfile.encoding=UTF-8。
        set "PROBLEM=1"
    )
) else (
    echo   [信息] 无法读取默认编码
)

rem ---------- 5. JAVA_HOME 是否指向存在的 JDK ----------
echo.
echo [5/6] JAVA_HOME
if not defined JAVA_HOME (
    echo   [WARN] 未设置 JAVA_HOME
    echo          Maven / Gradle / Tomcat 等工具默认读这个变量，
    echo          不设会导致它们找不到 JDK。
    set "PROBLEM=1"
    goto NEXT_PATH
)
echo   [信息] JAVA_HOME = !JAVA_HOME!
if not exist "!JAVA_HOME!\bin\javac.exe" (
    echo   [FAIL] 这个目录下没有 bin\javac.exe
    echo          要么路径写错了，要么指向的是 JRE。
    set "PROBLEM=1"
) else (
    echo   [ OK ] 目录有效
)

:NEXT_PATH
rem ---------- 6. PATH 里的 Java 是否唯一 ----------
echo.
echo [6/6] PATH 里有几个 Java
set "CNT=0"
for /f "delims=" %%p in ('where java 2^>nul') do (
    set /a CNT+=1
    echo   [!CNT!] %%p
)
if !CNT! GTR 1 (
    echo   [WARN] PATH 里有多个 java，实际生效的是最上面那个。
    echo          顺序不对就会出现"改了环境变量但没生效"。
    set "PROBLEM=1"
) else (
    if !CNT!==1 echo   [ OK ] 只有一个
)

echo.
echo ==========================================
if "!PROBLEM!"=="0" (
    echo   体检结论：没有发现明显问题
) else (
    echo   体检结论：发现问题，见上方 [WARN] / [FAIL]
    echo   最省事的办法：运行「JDK一键配置工具.bat」重新配置一遍。
)
echo ==========================================
echo.
pause
exit /b !PROBLEM!
