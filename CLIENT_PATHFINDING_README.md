# 客户端寻路系统说明

## 概述

实现了一个完整的客户端寻路系统，支持在联机模式下进行地图点击移动。该系统使用地图信息自动规避障碍（特别是海洋），并沿海岸线寻找可行路径。

## 功能特性

### ✅ 已实现的功能

1. **障碍检测**
   - 检测海洋地形并自动规避
   - 检测不可行走地形（岩浆等）
   - 使用地图 tile 信息判断可行走性

2. **智能寻路**
   - 直线路径优先（最短路径）
   - 遇到障碍时自动寻找绕路点
   - 沿海岸线搜索可行路径
   - 多角度搜索最优绕路方案

3. **分段移动**
   - 自动将长距离路径分解为多个路径点
   - 每段距离不超过 60 单位（符合 RPC 限制）
   - 到达每个路径点后自动移动到下一个

4. **安全机制**
   - 卡住检测：连续 5 次未移动则自动停止
   - 到达检测：距离小于 2 单位视为到达
   - 最大路径长度限制：100 个路径点

5. **路径可视化**
   - 在地图上绘制完整路径
   - 显示所有中间路径点
   - 实时更新移动进度

## 工作原理

### 单机模式（ismastersim = true）
使用服务器端的 `locomotor:GoToPoint()` API，这是最优方案。

### 客户端模式（联机/洞穴）
1. **路径生成阶段**：
   ```
   起点 → [检查直线] → 可行？
                      ├─ 是 → 添加路径点 → 继续
                      └─ 否 → 寻找绕路点 → 添加绕路点 → 继续
   ```

2. **路径执行阶段**：
   ```
   每 0.5 秒：
   - 检查是否到达当前路径点
   - 已到达 → 移动到下一个路径点
   - 未到达 → 继续等待
   - 检测卡住 → 超过 5 次则停止
   ```

3. **绕路算法**：
   - 以当前位置为中心，半径 20 单位
   - 在 16 个角度搜索可行点
   - 左右两侧各搜索，选择最接近目标方向的点

## 配置参数

在 `client_pathfinder.lua` 中的 CONFIG：

```lua
MAX_RANGE = 60              -- 每次移动的最大距离（不要超过 64）
STEP_SIZE = 5               -- 路径采样步长（越小越精确，越慢）
COASTAL_SEARCH_RADIUS = 20  -- 沿海岸搜索半径
COASTAL_SEARCH_ANGLES = 16  -- 海岸搜索角度数量（越多越精确）
MAX_PATH_LENGTH = 100       -- 最大路径点数（防止无限循环）
ARRIVAL_THRESHOLD = 2       -- 到达阈值（距离小于此值视为到达）
```

## 使用方法

### 在地图上点击
1. 打开地图（M 键或手柄）
2. 启用虚拟光标（LB+RB+RT）
3. 点击目标位置（A 键或 RT）
4. 系统自动生成路径并开始移动

### 日志输出示例

**成功案例**：
```
StartPathfinding world pos: (123.4, 0.0, 456.7)
[StartPathfinding] ismastersim: false
[StartPathfinding] Client mode - using ClientPathfinder
[ClientPathfinder] Generating path from (10.0, 20.0) to (123.4, 456.7)
[ClientPathfinder] Path complete with 8 waypoints
[ClientPathfinder] Pathfinding started with 8 waypoints
[ClientPathfinder] Moving to waypoint 1/8 at (50.0, 60.0), distance: 56.3
```

**遇到障碍**：
```
[ClientPathfinder] Obstacle detected at (45.0, 55.0), searching for detour
[ClientPathfinder] Detour point found at (38.0, 62.0)
[ClientPathfinder] Moving to waypoint 2/8 at (38.0, 62.0), distance: 12.5
```

**到达目标**：
```
[ClientPathfinder] Arrived at waypoint 8
[ClientPathfinder] No more waypoints, pathfinding complete
[ClientPathfinder] Pathfinding stopped
```

## 限制与注意事项

### 已知限制

1. **不支持完整 A* 寻路**
   - 使用贪心算法，可能不是最短路径
   - 复杂地形可能找不到最优路径

2. **海洋绕路可能失败**
   - 如果海洋太宽（>20 单位），可能找不到绕路点
   - 可以增大 `COASTAL_SEARCH_RADIUS` 改善

3. **RPC 距离限制**
   - 每次移动不能超过 64 单位
   - 已设置为 60 单位留有余量

4. **性能考虑**
   - 路径生成可能需要 100-500ms
   - 长距离寻路会有明显延迟

### 不适用场景

- ❌ 目标在孤岛上（无法跨越大片海洋）
- ❌ 目标在完全封闭区域（四周都是障碍）
- ❌ 极远距离（超过 100 个路径点，约 6000 单位）

## 优化建议

### 性能优化
1. 减少 `STEP_SIZE`（如改为 10）- 降低精度换取速度
2. 减少 `COASTAL_SEARCH_ANGLES`（如改为 8）- 减少搜索次数

### 精度优化
1. 增加 `STEP_SIZE`（如改为 2）- 更精确的障碍检测
2. 增加 `COASTAL_SEARCH_ANGLES`（如改为 32）- 更多绕路选择

### 范围优化
1. 增加 `COASTAL_SEARCH_RADIUS`（如改为 30）- 绕过更宽的障碍
2. 增加 `MAX_PATH_LENGTH`（如改为 200）- 支持更远距离

## 调试技巧

### 启用详细日志
所有关键步骤都有 print 日志，控制台会显示：
- 路径生成过程
- 每个路径点的坐标和距离
- 障碍检测和绕路决策
- 到达和卡住检测

### 可视化路径
- 地图上会显示绿色路径点
- 可以看到完整的移动路线
- 路径点会随着移动逐渐清除

### 手动停止寻路
如果需要紧急停止：
```lua
ClientPathfinder.Stop()
```

或者简单地：
- 关闭地图
- 执行其他动作（寻路会自动被打断）

## 与服务器端寻路的对比

| 特性 | 服务器端寻路 | 客户端寻路 |
|------|------------|-----------|
| 可用性 | 仅单机模式 | 单机+联机 |
| 路径质量 | 完美（A*算法） | 良好（贪心算法） |
| 性能 | 极快 | 较快 |
| 障碍处理 | 完美 | 良好 |
| 复杂地形 | 完美 | 可能失败 |
| RPC限制 | 无 | 64单位/次 |

## 未来改进方向

1. **实现真正的 A* 算法**
   - 使用优先队列
   - 启发式函数优化
   - 更好的路径质量

2. **动态障碍检测**
   - 检测移动中的障碍物
   - 实时重新规划路径

3. **路径平滑**
   - 移除不必要的路径点
   - 使用贝塞尔曲线平滑路径

4. **多线程路径生成**
   - 避免卡顿
   - 后台计算路径

## 文件清单

- `scripts/dst-controller/utils/client_pathfinder.lua` - 客户端寻路核心逻辑
- `scripts/dst-controller/hooks/mapscreen-hook.lua` - 地图钩子集成
- `CLIENT_PATHFINDING_README.md` - 本文档

---

**版本**: 1.0.0
**作者**: feichao
**最后更新**: 2025-01-16
