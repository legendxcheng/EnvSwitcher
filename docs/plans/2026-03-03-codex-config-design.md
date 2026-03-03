# Codex 配置功能设计文档

**日期**: 2026-03-03
**功能**: 为 EnvVarSwitcher (evs) 工具添加 Codex 配置切换功能

## 概述

扩展 evs 工具以支持 Codex CLI 工具的配置文件切换。用户可以通过 evs 命令快速切换不同的 Codex 服务商配置（config.toml 和 auth.json）。

## 需求

- 支持管理多套 Codex 配置（每套包含 config.toml 和 auth.json）
- 使用完全替换模式：切换时直接覆盖 ~/.codex/ 目录下的配置文件
- 与现有的环境变量切换功能共存
- 使用统一的命令接口，自动识别 profile 类型
- 支持 Windows PowerShell 和 WSL/Linux Bash

## 整体架构

### Profile 类型识别

- **环境变量 Profile**: `profiles/dev.json`（JSON 文件）
- **Codex 配置 Profile**: `profiles/gcodex/`（目录，包含 config.toml 和 auth.json）

### 处理流程

1. 用户执行 `evs use <profile-name>`
2. 检查 `profiles/<profile-name>` 是目录还是文件
3. 如果是目录：复制其中的 config.toml 和 auth.json 到 ~/.codex/
4. 如果是 JSON 文件：按现有逻辑设置环境变量

### 目录结构

```
profiles/
├── gcodex/              # Codex 配置 profile（目录）
│   ├── config.toml
│   └── auth.json
├── mcodex/              # 另一个 Codex 配置 profile
│   ├── config.toml
│   └── auth.json
├── dev.json             # 环境变量 profile（文件）
└── prod.json            # 环境变量 profile（文件）
```

## 组件设计

### PowerShell (evs.ps1) 需要修改的函数

1. **Get-AllProfiles** - 扩展以支持目录类型的 profile
   - 检测 profiles/ 下的目录和 JSON 文件
   - 为目录类型添加类型标识（如 "codex"）

2. **Read-ProfileConfig** - 新增或扩展以读取 codex 配置
   - 检测是目录还是文件
   - 如果是目录，返回特殊标记表示这是 codex 配置

3. **Switch-Profile** (或类似的切换函数) - 添加 codex 配置处理逻辑
   - 检测 profile 类型
   - 如果是目录：复制 config.toml 和 auth.json 到 ~/.codex/
   - 如果是 JSON：按现有逻辑处理环境变量

### Bash (evs.sh) 需要修改的函数

1. **_evs_list_profiles** - 扩展以支持目录类型
   - 使用 find 或 ls 检测目录和文件
   - 显示类型标识

2. **_evs_switch_profile** - 添加 codex 配置处理
   - 类型检测逻辑
   - 文件复制逻辑（使用 cp 命令）

### 新增辅助函数

- **Test-CodexProfile** / **_evs_is_codex_profile** - 检测是否为 codex 配置
- **Apply-CodexConfig** / **_evs_apply_codex_config** - 应用 codex 配置

## 数据流和操作流程

### 1. 列出所有 profiles (evs list)

```
用户执行 evs list
  ↓
扫描 profiles/ 目录
  ↓
识别 JSON 文件（环境变量）和目录（codex 配置）
  ↓
显示列表，标注类型：
  - dev (env)
  - prod (env)
  - gcodex (codex)
  - mcodex (codex)
```

### 2. 切换到 codex 配置 (evs use gcodex)

```
用户执行 evs use gcodex
  ↓
检查 profiles/gcodex 是否存在
  ↓
检测类型：是目录 → codex 配置
  ↓
验证目录中包含 config.toml 和 auth.json
  ↓
创建 ~/.codex/ 目录（如果不存在）
  ↓
复制 profiles/gcodex/config.toml → ~/.codex/config.toml
复制 profiles/gcodex/auth.json → ~/.codex/auth.json
  ↓
记录当前激活的 profile（EVS_ACTIVE_PROFILE=gcodex）
  ↓
显示成功消息
```

### 3. 切换到环境变量配置 (evs use dev)

```
用户执行 evs use dev
  ↓
检查 profiles/dev.json 是否存在
  ↓
检测类型：是文件 → 环境变量配置
  ↓
按现有逻辑处理（清除旧变量，设置新变量）
  ↓
记录当前激活的 profile（EVS_ACTIVE_PROFILE=dev）
```

### 4. 显示当前配置 (evs show)

```
用户执行 evs show
  ↓
读取 EVS_ACTIVE_PROFILE
  ↓
如果是 codex 配置：
  - 显示 ~/.codex/config.toml 的关键配置项
  - 显示 auth.json 的存在（不显示密钥内容）
如果是环境变量配置：
  - 显示当前设置的环境变量
```

## 错误处理

### 1. Profile 不存在

```
用户执行 evs use nonexistent
  ↓
检查 profiles/nonexistent 和 profiles/nonexistent.json 都不存在
  ↓
显示错误：Profile 'nonexistent' not found
列出可用的 profiles
```

### 2. Codex 配置文件不完整

```
用户执行 evs use gcodex
  ↓
检测到 profiles/gcodex/ 是目录
  ↓
验证目录中的文件：
  - 缺少 config.toml → 错误：Missing config.toml in profile 'gcodex'
  - 缺少 auth.json → 错误：Missing auth.json in profile 'gcodex'
  ↓
不执行复制操作，保持当前配置不变
```

### 3. 目标目录权限问题

```
复制文件到 ~/.codex/ 时权限被拒绝
  ↓
显示错误：Failed to copy config files. Permission denied.
提示：Check permissions for ~/.codex/ directory
```

### 4. 配置文件格式错误

- 对于 JSON profile：JSON 解析失败 → 显示错误和文件路径
- 对于 TOML/JSON 配置文件：不验证内容格式（由 codex 工具自己验证），只确保文件存在且可读

### 5. 混合类型检测失败

```
如果同时存在 profiles/dev/ 和 profiles/dev.json
  ↓
优先使用目录类型（codex 配置）
显示警告：Found both directory and JSON file for 'dev', using directory
```

## 测试策略

### 1. 基本功能测试

- **evs list**: 应显示所有 JSON 文件和目录，正确标注类型
- **evs use <codex-profile>**: 应成功复制配置文件到 ~/.codex/
- **evs use <env-profile>**: 应按现有逻辑设置环境变量

### 2. 边界情况测试

- 空 profiles 目录：应显示 "No profiles found"
- 混合类型（同名目录和文件）：应优先使用目录类型并显示警告
- 不完整的 codex 配置：应显示错误，不执行部分复制

### 3. 跨平台测试

- **Windows (PowerShell)**: 测试所有命令，验证路径处理
- **WSL/Linux (Bash)**: 测试所有命令，验证 profiles 目录优先级和文件权限

### 4. 手动验证步骤

1. 创建测试 profiles：
   - 复制当前 ~/.codex/ 配置到 profiles/gcodex/
   - 创建新的 profiles/mcodex/ 配置

2. 测试切换：
   - evs use gcodex → 验证 ~/.codex/ 文件内容
   - evs use mcodex → 验证 ~/.codex/ 文件内容已更新

3. 测试回退：
   - evs use dev（环境变量 profile）→ 验证环境变量已设置，~/.codex/ 文件未被修改

## 实现优先级

1. **高优先级**：
   - Profile 类型检测逻辑
   - Codex 配置文件复制功能
   - evs list 显示类型标识

2. **中优先级**：
   - 错误处理和验证
   - evs show 显示 codex 配置信息

3. **低优先级**：
   - 优化用户体验（更详细的提示信息）
   - 性能优化

## 向后兼容性

- 现有的环境变量 profile（JSON 文件）完全不受影响
- 现有的命令行为保持不变
- 用户可以继续使用现有的 profiles，无需迁移
