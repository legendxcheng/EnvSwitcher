# Codex 配置功能实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 扩展 evs 工具以支持 Codex CLI 配置文件的切换，通过自动检测 profile 类型（目录 vs JSON 文件）实现统一的命令接口。

**Architecture:** 在现有代码中添加 profile 类型检测机制。对于目录类型的 profile，复制其中的 config.toml 和 auth.json 到 ~/.codex/；对于 JSON 文件类型，保持现有的环境变量处理逻辑。

**Tech Stack:** PowerShell, Bash, TOML, JSON

---

## 实现概览

本实现计划分为以下几个主要部分：

1. **前置准备** - 创建测试用的 codex profiles
2. **PowerShell 实现** - 修改 evs.ps1 支持 codex 配置
3. **Bash 实现** - 修改 evs.sh 支持 codex 配置
4. **测试验证** - 综合测试和文档更新

每个部分包含多个小任务，每个任务都有明确的步骤和验证方法。

---

## 详细实现步骤

由于实现计划较长，完整的步骤请参考设计文档：`docs/plans/2026-03-03-codex-config-design.md`

### 核心实现要点

**PowerShell (evs.ps1) 需要添加/修改的函数：**

1. `Test-CodexProfile` - 检测是否为 codex profile（目录类型）
2. `Get-CodexProfilePath` - 获取 codex profile 路径
3. `Apply-CodexConfig` - 应用 codex 配置（复制文件到 ~/.codex/）
4. `Get-AllProfiles` - 扩展以支持目录类型
5. `Invoke-List` - 显示 profile 类型标识
6. `Invoke-Use` - 支持 codex profile 切换
7. `Invoke-Show` - 显示 codex profile 信息

**Bash (evs.sh) 需要添加/修改的函数：**

1. `_evs_is_codex_profile` - 检测是否为 codex profile
2. `_evs_get_codex_profile_path` - 获取 codex profile 路径
3. `_evs_apply_codex_config` - 应用 codex 配置
4. `_evs_list` - 扩展以支持目录类型
5. `_evs_use` - 支持 codex profile 切换
6. `_evs_show` - 显示 codex profile 信息

### 实现顺序

建议按以下顺序实现：

1. 创建测试 profiles（gcodex, mcodex）
2. 实现 PowerShell 版本的所有功能
3. 测试 PowerShell 版本
4. 实现 Bash 版本的所有功能
5. 测试 Bash 版本
6. 综合测试和文档更新

### 关键代码片段

**检测 Profile 类型 (PowerShell):**
```powershell
function Test-CodexProfile {
    param([string]$ProfileName)
    $dirPath = Join-Path $script:ProfilesDir $ProfileName
    return (Test-Path $dirPath -PathType Container)
}
```

**应用 Codex 配置 (PowerShell):**
```powershell
function Apply-CodexConfig {
    param([string]$ProfileName)
    $profilePath = Get-CodexProfilePath $ProfileName
    $codexDir = Join-Path $env:USERPROFILE ".codex"

    # 确保目录存在
    if (-not (Test-Path $codexDir)) {
        New-Item -ItemType Directory -Path $codexDir -Force | Out-Null
    }

    # 复制配置文件
    Copy-Item (Join-Path $profilePath "config.toml") (Join-Path $codexDir "config.toml") -Force
    Copy-Item (Join-Path $profilePath "auth.json") (Join-Path $codexDir "auth.json") -Force
}
```

**检测 Profile 类型 (Bash):**
```bash
_evs_is_codex_profile() {
    local name="$1"
    local dir_path="$EVS_PROFILES_DIR/$name"
    [[ -d "$dir_path" ]]
}
```

**应用 Codex 配置 (Bash):**
```bash
_evs_apply_codex_config() {
    local profile_name="$1"
    local profile_path="$EVS_PROFILES_DIR/$profile_name"
    local codex_dir="$HOME/.codex"

    mkdir -p "$codex_dir"
    cp "$profile_path/config.toml" "$codex_dir/config.toml"
    cp "$profile_path/auth.json" "$codex_dir/auth.json"
}
```

---

## 测试计划

### 功能测试

1. **列出 profiles** - `evs list` 应显示所有 JSON 和目录类型的 profiles，并标注类型
2. **切换到 codex profile** - `evs use gcodex` 应复制配置文件到 ~/.codex/
3. **切换到环境变量 profile** - `evs use dev` 应设置环境变量
4. **显示 profile 信息** - `evs show <profile>` 应显示相应类型的信息
5. **显示当前状态** - `evs show` 应显示当前激活的 profile 信息

### 错误处理测试

1. Profile 不存在 - 应显示错误并列出可用 profiles
2. Codex 配置文件不完整 - 应显示错误，不执行复制
3. 权限问题 - 应显示友好的错误信息

### 跨平台测试

1. Windows PowerShell - 测试所有功能
2. WSL/Linux Bash - 测试所有功能
3. 验证配置文件路径处理正确

---

## 完成标准

- [ ] 所有函数实现完成并通过测试
- [ ] PowerShell 和 Bash 版本功能一致
- [ ] 错误处理完善
- [ ] 文档更新（README.md）
- [ ] 所有更改已提交到 git

---

## 参考文档

- 设计文档: `docs/plans/2026-03-03-codex-config-design.md`
- 现有代码: `evs.ps1`, `evs.sh`
- Profile 示例: `profiles/dev.json`, `profiles/gcodex/`, `profiles/mcodex/`
