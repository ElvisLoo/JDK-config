# JDK 一键配置工具

Windows 下检测已安装的 JDK，并配置 `JAVA_HOME` 与 `PATH` 的小工具。

## 使用方法

1. 下载 `JDK一键配置工具.bat`
2. **右键 → 以管理员身份运行**（或双击，会自动弹 UAC 提权）
3. 从列表选择 JDK，或按 `M` 手动输入路径
4. 确认后，工具会：
   - 备份当前系统环境变量到 `backup_<时间戳>\system_env.reg`
   - 生成 `restore.bat`（双击即可回滚）
   - 设置 `JAVA_HOME`
   - 把 JDK 的 `bin` 加入系统 `PATH`（并移除其它 JDK 的 bin，避免新旧版本串台）

也可以直接传路径，跳过交互：

```bat
JDK一键配置工具.bat "C:\Program Files\Java\jdk-17"
```

## 功能特性

- **全自动检测** — 注册表 + 常见安装目录，路径含空格也能正确识别
- **多版本支持** — 列出所有检测到的 JDK
- **可回滚** — 修改前自动备份，生成 `restore.bat`
- **保留变量引用** — `PATH` 里的 `%SystemRoot%`、`%JAVA_HOME%` 不会被展开固化
- **自提权** — 非管理员运行时自动弹 UAC
- **中英双语提示** — UTF-8 编码，避免跨语言系统乱码

## 支持的 JDK 发行版

| 发行版 | 注册表键 |
|---|---|
| Oracle JDK 8 / 9+ | `HKLM\SOFTWARE\JavaSoft\Java Development Kit`、`...\JavaSoft\JDK` |
| Eclipse Adoptium / Temurin | `HKLM\SOFTWARE\Eclipse Adoptium\JDK` |
| Amazon Corretto | `HKLM\SOFTWARE\Amazon Corretto\JDK` |
| Microsoft JDK | `HKLM\SOFTWARE\Microsoft\JDK` |

目录扫描覆盖：`%ProgramFiles%\Java`、`%ProgramFiles%\Eclipse Adoptium`、
`%ProgramFiles%\Amazon Corretto`、`%ProgramFiles%\Microsoft`、`%USERPROFILE%\.jdks`。

> Adoptium / Corretto / Microsoft 的子键结构各不相同（没有统一的 `CurrentVersion`），
> 所以用 `reg query /s /v JavaHome` 递归查找，而不是拼版本号。

## 原理

1. **检测** — `reg query` 递归读各发行版的 `JavaHome`，同时扫描常见安装目录，找含 `bin\javac.exe` 的目录
2. **选择** — 去重后列出，或手动输入
3. **备份** — `reg export` 导出整个环境变量键，并生成 `restore.bat`
4. **写入** — 通过 .NET 的 `Microsoft.Win32.Registry` 直接读写：
   - `JAVA_HOME` 写成 `REG_SZ`
   - `PATH` 用 `DoNotExpandEnvironmentNames` 读原始值、以 `REG_EXPAND_SZ` 写回

### 为什么不用 `setx` / `SetEnvironmentVariable`

`setx` 和 `[Environment]::SetEnvironmentVariable` 读 `PATH` 时会把
`%JAVA_HOME%`、`%SystemRoot%` 这类引用**展开成实际路径**再写回。
一旦写回，PATH 就被固化了：之后再换 JDK，`%JAVA_HOME%\bin` 也不会跟着变，
而且 `%SystemRoot%` 变成固定的 `C:\Windows`，系统盘符一变就出问题。

必须用 Registry API 配 `DoNotExpandEnvironmentNames`，才能保住变量引用。

## 系统要求

- Windows 7 / 8 / 10 / 11
- 已安装任意 JDK 或 JRE

## 常见问题

**提示「不是有效的 JDK 目录」**
该目录下需要有 `bin\javac.exe`。只装了 JRE 的目录不含 javac，无法用于编译。

**配置完成后 `java -version` 还是旧版本**
环境变量只对新开的终端生效。关掉所有 CMD / PowerShell / IDE 重开。
如果还是旧版，检查 PATH 里是否有更靠前的其它 JDK，或用户级 PATH 覆盖了系统级。

**想撤销**
双击工具生成的 `restore.bat`。

## 许可证

MIT
