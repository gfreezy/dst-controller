# Client Mod Compatibility Report

## 检查时间
2025-01-16

## 检查范围
所有 `scripts/dst-controller/` 目录下的 Lua 文件（共 34 个）

## 检查结果

### ✅ 正确的代码模式

#### 1. **Component 访问 - 使用 Replica 回退**
以下文件正确实现了 replica → components 的回退模式：

- **helpers.lua**: `GetInventory()` 先检查 `player.replica.inventory`，然后才回退到 `player.components.inventory`
- **equipment.lua**: `IsItemEquippedInSlot()` 和 `equip_item()` 都先检查 replica
- **crafting.lua**: `craft_item()` 使用 `player.replica.builder` 或 `player.components.builder`

```lua
// 正确模式
local inventory = player.replica.inventory or player.components.inventory
```

#### 2. **PlayerController 访问**
`playercontroller` 组件在客户端也存在，可以直接访问：
- inspection.lua
- playerhud-hook.lua
- helpers.lua

这是**安全的**，因为 `playercontroller` 是客户端组件。

#### 3. **动作执行**
所有动作都通过 `controller:DoAction(action)` 执行，**没有**直接调用：
- ❌ `locomotor:PushAction()`
- ❌ `locomotor:PreviewAction()`
- ❌ `SendRPCToServer()`

这是正确的做法，controller 会自动处理客户端-服务器通信。

### ✅ 已修复的问题

#### 1. **character.lua - 服务器端组件检查**
**问题**: 访问了 `ember.components.aoespell:CanCast()`（仅服务器端）

**修复**: 移除了 CanCast 检查，让服务器自行验证

```lua
// 修复前
if ember.components and ember.components.aoespell then
    can_cast = ember.components.aoespell:CanCast(player, target_pos)
end

// 修复后
// 移除检查，直接提交动作，让服务器验证
```

#### 2. **mapscreen-hook.lua - Locomotor 访问**
**问题**: `player.components.locomotor` 仅在服务器端存在

**修复**: 添加 `ismastersim` 检查，仅在单机模式下访问

```lua
local is_mastersim = G.TheWorld and G.TheWorld.ismastersim
if not is_mastersim then
    print("Client mode - pathfinding not supported")
    return
end
local locomotor = player.components.locomotor  // 只在单机模式下访问
```

### 🔍 潜在限制

#### 1. **地图寻路功能**
**限制**: 仅在单机模式下可用

**原因**: DST 的防作弊机制限制客户端无法远距离移动

**影响**: 联机模式（包括专用服务器的洞穴）中，地图点击寻路不可用

**解决方案**: 无法在纯客户端 mod 中解决。如需支持，必须改为服务器端 mod。

### ✅ 检查通过的项目

1. **无直接状态修改**: 未发现直接修改 `player.health`、`player.hunger` 等服务器端状态
2. **无网络代码**: 未使用 `SendRPCToServer` 或其他网络函数
3. **正确使用 Replica**: 所有库存/装备操作都优先使用 replica
4. **符合客户端模式**: 所有操作都通过标准的动作系统 (BufferedAction)

## 总结

### 兼容性评级: ✅ **完全兼容**

你的 mod 现在是**完全兼容**的客户端 mod：
- ✅ `client_only_mod = true` 可以保留
- ✅ 不需要服务器安装
- ✅ 符合 DST 客户端 mod 的所有限制
- ⚠️ 地图寻路仅在单机模式可用（这是 DST 设计限制，无法避免）

### 建议

1. **保持当前架构**: 继续使用 replica → components 回退模式
2. **文档说明**: 在 modinfo.lua 中说明地图寻路功能仅限单机模式
3. **错误提示**: 当前已有清晰的日志提示用户限制（mapscreen-hook.lua:28-30）

## 修改的文件

1. `scripts/dst-controller/actions/character.lua` - 移除服务器端组件检查
2. `scripts/dst-controller/hooks/mapscreen-hook.lua` - 添加 ismastersim 检查

## 测试建议

1. **单机模式**: 测试所有功能，包括地图寻路
2. **联机客户端**: 验证除地图寻路外的所有功能正常
3. **专用服务器**: 确认 mod 不影响服务器稳定性

---

生成时间: 2025-01-16
检查工具: Claude Code
