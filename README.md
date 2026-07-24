# JDK 一键配置工具

Windows 系统下一键检测并配置 JDK 环境变量的小工具。

## 使用方法

1. 下载 `JDK一键配置工具.bat`
2. **右键 → 以管理员身份运行**（或双击，自动弹 UAC 提权）
3. 从列表中选择要配置的 JDK 版本，或按 `M` 手动输入路径
4. 工具自动完成：
   - 设置系统环境变量 `JAVA_HOME`
   - 将 JDK 的 `bin` 目录追加到系统 `PATH`

## 功能特性

- **全自动检测** — 扫描注册表（Oracle JDK 8+）和常见安装目录
- **多版本支持** — 列出所有检测到的 JDK，自由选择
- **手动输入** — 未检测到时可手动指定路径
- **智能去重** — 同一路径只显示一次
- **自提权** — 非管理员运行时自动弹 UAC 提权
- **中文界面** — GBK 编码，Windows CMD 窗口原生显示

## 支持的 JDK 发行版

| 发行版 | 注册表路径 | 安装目录 |
|--------|-----------|---------|
| Oracle JDK | `HKLM\SOFTWARE\JavaSoft\Java Development Kit` | `C:\Program Files\Java\jdk*` |
| Oracle JDK 9+ | `HKLM\SOFTWARE\JavaSoft\JDK` | `C:\Program Files\Java\jdk*` |
| Eclipse Adoptium / Temurin | `HKLM\SOFTWARE\Eclipse Adoptium` | `C:\Program Files\Eclipse Adoptium\jdk*` |
| Amazon Corretto | `HKLM\SOFTWARE\Amazon Corretto` | `C:\Program Files\Amazon Corretto\jdk*` |
| Microsoft JDK | `HKLM\SOFTWARE\Microsoft\JDK` | `C:\Program Files\Microsoft\jdk*` |

## 原理说明

工具分三步执行：

1. **检测** — 通过 PowerShell 读取注册表 `HKLM\SOFTWARE\JavaSoft` 下各版本子项的 `JavaHome` 值，同时扫描 `C:\Program Files\Java` 等常见目录，找到所有包含 `bin\javac.exe` 的 JDK 安装
2. **选择** — 列出所有去重后的 JDK，让用户通过编号或手动输入指定目标
3. **配置** — `setx` 设置系统级 `JAVA_HOME`，PowerShell 的 `[Environment]::SetEnvironmentVariable` 更新系统 `PATH`

## 系统要求

- Windows 7 / 8 / 10 / 11
- 已安装任意 JDK（Oracle / Adoptium / Corretto / Microsoft 等）

## 许可证

MIT
