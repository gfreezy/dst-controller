-- Enhanced Controller - Client-side Pathfinder
-- 客户端寻路系统：使用 A* 算法和地形代价基于地图网格寻路

local G = require("dst-controller/global")
local Helpers = require("dst-controller/utils/helpers")
local PathfindingPolicy = require("dst-controller/utils/pathfinding-policy")

local ClientPathfinder = {}

-- ============================================================================
-- 配置
-- ============================================================================

local CONFIG = {
    TILE_SCALE = 4,              -- DST 的 tile 大小
    GRID_SIZE = 4,               -- 寻路网格大小（与 TILE_SCALE 相同）
    COARSE_GRID_SIZE = 16,       -- 远距离搜索先使用粗网格
    COARSE_DISTANCE = 160,       -- 启用粗网格的最小世界距离
    COARSE_MAX_SEARCH_NODES = 4000,
    MEDIUM_GRID_SIZE = 8,        -- 可直达路线比较时提高道路采样精度
    MEDIUM_DISTANCE = 480,
    ROUTE_IMPROVEMENT_MARGIN = 0.02, -- 至少快 2% 才接受绕行，避免路线抖动
    MAX_SEARCH_NODES = 20000,    -- 分帧后可安全扩大搜索范围
    SEARCH_QUERIES_PER_TICK = 180, -- 每帧最多执行的地图查询数
    HEURISTIC_WEIGHT = 1.3,      -- 牺牲少量最优性，显著减少展开节点
    DIRECT_SAMPLE_SPACING = 2,   -- 直线路径检测采样间隔
    MAX_PATH_LENGTH = 200,       -- 最大路径点数
    ARRIVAL_THRESHOLD = 2,       -- 路径点到达阈值
    FINAL_ARRIVAL_THRESHOLD = 4, -- 终点到达阈值（更大，因为终点可能是树等障碍物）
    MOVE_INTERVAL = 0.3,         -- 移动指令间隔（秒）
    STUCK_THRESHOLD = 10,        -- 卡住检测次数（增加以应对地图关闭延迟）
    NEIGHBOR_DIRS = {            -- 8 方向邻居（包括对角线）
        {dx = 1, dz = 0, cost = 1},
        {dx = -1, dz = 0, cost = 1},
        {dx = 0, dz = 1, cost = 1},
        {dx = 0, dz = -1, cost = 1},
        {dx = 1, dz = 1, cost = 1.414},
        {dx = 1, dz = -1, cost = 1.414},
        {dx = -1, dz = 1, cost = 1.414},
        {dx = -1, dz = -1, cost = 1.414},
    },
}

-- ============================================================================
-- 优先队列（最小堆）
-- ============================================================================

local PriorityQueue = {}
PriorityQueue.__index = PriorityQueue

function PriorityQueue.new()
    return setmetatable({heap = {}, size = 0}, PriorityQueue)
end

function PriorityQueue:push(item, priority, distance)
    self.size = self.size + 1
    self.heap[self.size] = {
        item = item,
        priority = priority,
        distance = distance,
    }
    self:_bubbleUp(self.size)
end

function PriorityQueue:pop()
    if self.size == 0 then return nil end

    local top = self.heap[1]
    self.heap[1] = self.heap[self.size]
    self.heap[self.size] = nil
    self.size = self.size - 1

    if self.size > 0 then
        self:_bubbleDown(1)
    end

    return top.item, top.distance
end

function PriorityQueue:isEmpty()
    return self.size == 0
end

function PriorityQueue:_bubbleUp(idx)
    while idx > 1 do
        local parent = math.floor(idx / 2)
        if self.heap[parent].priority <= self.heap[idx].priority then
            break
        end
        self.heap[parent], self.heap[idx] = self.heap[idx], self.heap[parent]
        idx = parent
    end
end

function PriorityQueue:_bubbleDown(idx)
    while true do
        local smallest = idx
        local left = idx * 2
        local right = idx * 2 + 1

        if left <= self.size and self.heap[left].priority < self.heap[smallest].priority then
            smallest = left
        end
        if right <= self.size and self.heap[right].priority < self.heap[smallest].priority then
            smallest = right
        end

        if smallest == idx then break end

        self.heap[idx], self.heap[smallest] = self.heap[smallest], self.heap[idx]
        idx = smallest
    end
end

-- ============================================================================
-- 寻路状态
-- ============================================================================

local pathfinding_state = {
    active = false,
    searching = false,
    path = nil,
    current_waypoint = 1,
    target_pos = nil,
    last_position = nil,
    stuck_counter = 0,
    update_task = nil,
    search_thread = nil,
    search_generation = 0,
    on_path_ready = nil,
}

-- ============================================================================
-- 地图工具函数
-- ============================================================================

-- 地面类型代价系数（越小越优先）
-- 代价计算基于 DST 官方速度修正值：cost = 1 / speed_multiplier
-- 参考：https://dontstarve.wiki.gg/wiki/Survivor_Speed
local GROUND_COST = {
    -- 道路类型 - 强烈优先走
    -- 官方: +30% 速度 (1.3x) → 理论代价 1/1.3 ≈ 0.77
    ROAD = 0.77,          -- 道路（卵石路、Stone Road Turf 等）
    CARPET = 0.77,        -- 人造地板（Brick Flooring 等，同样 +30%）

    -- 普通地面 - 正常代价
    DEFAULT = 1.0,

    -- 困难地面 - 尽量避开（代价高）
    MARSH = 1.5,          -- 沼泽（有毒气，无官方减速但危险）
    ROCKY = 1.2,          -- 岩石地（无减速，但路径不佳）
    METEOR = 1.5,         -- 陨石区（有陨石坑和障碍物）

    -- 严重减速地面 - 强烈避开
    -- 官方: -70% 速度 (0.3x) → 代价 1/0.3 ≈ 3.33
    SINKHOLE = 3.33,      -- 地陷区（Antlion Sinkhole）

    -- 官方: -40% 速度 (0.6x) → 代价 1/0.6 ≈ 1.67
    -- 但蜘蛛巢附近有蜘蛛攻击风险，使用更高代价强烈避开
    SPIDER_CREEP = 5.0,   -- 蜘蛛网地面（减速 + 蜘蛛攻击）
}

-- 世界坐标转网格坐标
local function WorldToGrid(x, z, grid_size)
    grid_size = grid_size or CONFIG.GRID_SIZE
    return math.floor(x / grid_size), math.floor(z / grid_size)
end

-- 网格坐标转世界坐标（返回格子中心）
local function GridToWorld(gx, gz, grid_size)
    grid_size = grid_size or CONFIG.GRID_SIZE
    return (gx + 0.5) * grid_size, (gz + 0.5) * grid_size
end

-- 调试：记录找到的道路格子数量
local debug_road_count = 0

local function ConsumeSearchQuery(work)
    if work == nil then
        return
    end
    work.query_count = work.query_count + 1
    if work.can_yield and
        work.query_count >= CONFIG.SEARCH_QUERIES_PER_TICK then
        work.query_count = 0
        coroutine.yield()
    end
end

local function GetCachedGridValue(cache, gx, gz)
    local column = cache[gx]
    if column ~= nil and column[gz] ~= nil then
        return column[gz], true
    end
    return nil, false
end

local function SetCachedGridValue(cache, gx, gz, value)
    local column = cache[gx]
    if column == nil then
        column = {}
        cache[gx] = column
    end
    column[gz] = value
end

local function GetRoadCost(work)
    if work ~= nil and work.road_cost ~= nil then
        return work.road_cost
    end
    local player = G.ThePlayer
    local controller = player and player.components and
        player.components.playercontroller or nil
    local locomotor = controller and controller.locomotor or
        (player and player.components and player.components.locomotor)
    if locomotor ~= nil and locomotor.FasterOnRoad ~= nil then
        local ok, faster = pcall(locomotor.FasterOnRoad, locomotor)
        if ok and not faster then
            if work ~= nil then
                work.road_cost = GROUND_COST.DEFAULT
            end
            return GROUND_COST.DEFAULT
        end
    end
    if work ~= nil then
        work.road_cost = GROUND_COST.ROAD
    end
    return GROUND_COST.ROAD
end

-- 获取地面类型的移动代价
local function GetGroundCost(x, z, work)
    if not G.TheWorld or not G.TheWorld.Map then
        return GROUND_COST.DEFAULT
    end

    ConsumeSearchQuery(work)
    local map = G.TheWorld.Map
    local tile = map:GetTileAtPoint(x, 0, z)

    if not tile then
        return GROUND_COST.DEFAULT
    end

    -- 方法1: 使用 RoadManager 检测道路（最准确，包括程序生成的道路）
    local RoadManager = G.RoadManager
    if RoadManager and RoadManager.IsOnRoad then
        local is_on_road = RoadManager:IsOnRoad(x, 0, z)
        if is_on_road then
            debug_road_count = debug_road_count + 1
            return GetRoadCost(work)
        end
    end

    -- 方法2: 使用 GROUND_ROADWAYS 表（DST 内置的道路类型表）
    local GROUND_ROADWAYS = G.GROUND_ROADWAYS
    if GROUND_ROADWAYS and GROUND_ROADWAYS[tile] then
        debug_road_count = debug_road_count + 1
        return GetRoadCost(work)
    end

    -- 方法3: 手动检查常见的道路类型
    local GROUND = G.GROUND
    if GROUND then
        -- 道路类型 (GROUND.ROAD = 2)
        if tile == GROUND.ROAD then
            debug_road_count = debug_road_count + 1
            return GetRoadCost(work)
        -- 人造地板
        elseif tile == GROUND.WOODFLOOR or tile == GROUND.CHECKER or tile == GROUND.CARPET then
            debug_road_count = debug_road_count + 1
            return GetRoadCost(work)
        -- 沼泽（减速）
        elseif tile == GROUND.MARSH then
            return GROUND_COST.MARSH
        -- 岩石地（稍慢）
        elseif tile == GROUND.ROCKY then
            return GROUND_COST.ROCKY
        -- 陨石区（有陨石坑和障碍物）
        elseif tile == GROUND.METEOR then
            return GROUND_COST.METEOR
        -- 地陷区（有坑洞）
        elseif tile == GROUND.SINKHOLE then
            return GROUND_COST.SINKHOLE
        -- 蜘蛛地毯（人造蜘蛛网地板）
        elseif tile == GROUND.WEB then
            return GROUND_COST.SPIDER_CREEP
        end
    end

    -- 检查是否有蜘蛛网覆盖层（蜘蛛巢蔓延的蜘蛛网）
    -- 使用 TheWorld.GroundCreep:OnCreep(x, 0, z) 检测
    if G.TheWorld and G.TheWorld.GroundCreep and G.TheWorld.GroundCreep.OnCreep then
        local on_creep = G.TheWorld.GroundCreep:OnCreep(x, 0, z)
        if on_creep then
            return GROUND_COST.SPIDER_CREEP
        end
    end

    return GROUND_COST.DEFAULT
end

-- 检查世界坐标是否可通行
local function IsPassable(x, z, work)
    if not G.TheWorld or not G.TheWorld.Map then
        return false
    end

    ConsumeSearchQuery(work)
    local map = G.TheWorld.Map

    -- 方法1: 使用 IsPassableAtPoint (最可靠)
    -- allow_water = false: 不允许走水
    -- exclude_boats = true: 排除船只平台
    local passable = map:IsPassableAtPoint(x, 0, z, false, true)
    if passable then
        return true
    end

    -- 方法2: 在洞穴中，尝试使用 IsAboveGroundAtPoint
    -- 有些洞穴地形 IsPassableAtPoint 可能返回 false，但实际上是可以走的
    if G.TheWorld:HasTag("cave") then
        if map.IsAboveGroundAtPoint then
            local above_ground = map:IsAboveGroundAtPoint(x, 0, z, false)
            if above_ground then
                return true
            end
        end
    end

    return false
end

-- 检查网格是否可通行
local function IsGridPassable(gx, gz, grid_size, cache, work)
    local cached, found = GetCachedGridValue(cache, gx, gz)
    if found then
        return cached
    end

    local wx, wz = GridToWorld(gx, gz, grid_size)
    local passable = IsPassable(wx, wz, work)
    SetCachedGridValue(cache, gx, gz, passable)
    return passable
end

-- 检查对角线移动是否可行（需要两侧都可通行）
local function IsDiagonalPassable(from_gx, from_gz, dx, dz,
    grid_size, passable_cache, work)
    -- 对角线移动需要两个相邻格子都可通行，否则会穿墙
    if dx ~= 0 and dz ~= 0 then
        if not IsGridPassable(
            from_gx + dx, from_gz, grid_size, passable_cache, work) then
            return false
        end
        if not IsGridPassable(
            from_gx, from_gz + dz, grid_size, passable_cache, work) then
            return false
        end
    end
    return true
end

local function GetGridGroundCost(gx, gz, grid_size, cache, work)
    local cached, found = GetCachedGridValue(cache, gx, gz)
    if found then
        return cached
    end

    local wx, wz = GridToWorld(gx, gz, grid_size)
    local cost = GetGroundCost(wx, wz, work)
    SetCachedGridValue(cache, gx, gz, cost)
    return cost
end

local function IsLinePassable(start_x, start_z, end_x, end_z, work)
    local dx = end_x - start_x
    local dz = end_z - start_z
    local distance = math.sqrt(dx * dx + dz * dz)
    local steps = math.max(1, math.ceil(distance / CONFIG.DIRECT_SAMPLE_SPACING))

    for i = 0, steps do
        local t = i / steps
        if not IsPassable(start_x + dx * t, start_z + dz * t, work) then
            return false
        end
    end
    return true
end

local function EstimateLineTravelCost(start_x, start_z, end_x, end_z, work)
    local dx = end_x - start_x
    local dz = end_z - start_z
    local distance = math.sqrt(dx * dx + dz * dz)
    if distance <= 0 then
        return 0
    end

    local steps = math.max(1, math.ceil(distance / CONFIG.DIRECT_SAMPLE_SPACING))
    local segment_length = distance / steps
    local cost = 0
    for i = 1, steps do
        local t = (i - 0.5) / steps
        cost = cost + segment_length *
            GetGroundCost(start_x + dx * t, start_z + dz * t, work)
    end
    return cost
end

local function EstimatePathTravelCost(start_x, start_z, path, work)
    local cost = 0
    local previous_x, previous_z = start_x, start_z
    for _, point in ipairs(path) do
        cost = cost + EstimateLineTravelCost(
            previous_x, previous_z, point.x, point.z, work)
        previous_x, previous_z = point.x, point.z
    end
    return cost
end

-- ============================================================================
-- 直线寻路（用于幽灵/死亡状态，无障碍物，无距离限制）
-- ============================================================================

local function StraightLinePathfind(start_x, start_z, end_x, end_z)
    Helpers.DebugPrintf("Direct path from (%.1f, %.1f) to (%.1f, %.1f)",
        start_x, start_z, end_x, end_z)

    -- 只返回终点，让角色直线行走
    return {
        {x = end_x, z = end_z}
    }
end

-- 检查玩家是否是幽灵（死亡状态）
local function IsPlayerGhost()
    local player = G.ThePlayer
    if not player or not player:IsValid() then
        return false
    end
    return player:HasTag("playerghost")
end

-- ============================================================================
-- A* 寻路算法
-- ============================================================================

local SimplifyPath

local function AStarPathfind(start_x, start_z, end_x, end_z, options, work)
    options = options or {}
    local grid_size = options.grid_size or CONFIG.GRID_SIZE
    local max_search_nodes = options.max_search_nodes or CONFIG.MAX_SEARCH_NODES
    local search_name = options.search_name or "AStar"
    local heuristic_weight = options.heuristic_weight or CONFIG.HEURISTIC_WEIGHT

    -- 重置调试计数器
    debug_road_count = 0

    local start_gx, start_gz = WorldToGrid(start_x, start_z, grid_size)
    local end_gx, end_gz = WorldToGrid(end_x, end_z, grid_size)
    local passable_cache = {}
    local ground_cost_cache = {}

    Helpers.DebugPrint(string.format(
        "[%s] Grid size: %d, Start: (%d, %d), End: (%d, %d)",
        search_name, grid_size, start_gx, start_gz, end_gx, end_gz))

    -- 调试：检查世界和地图状态
    Helpers.DebugPrint("[AStar] TheWorld: " .. tostring(G.TheWorld))
    Helpers.DebugPrint("[AStar] TheWorld.Map: " .. tostring(G.TheWorld and G.TheWorld.Map))
    if G.TheWorld then
        Helpers.DebugPrint("[AStar] World prefab: " .. tostring(G.TheWorld.prefab))
        -- 检查是否在洞穴
        local is_cave = G.TheWorld:HasTag("cave")
        Helpers.DebugPrint("[AStar] Is cave: " .. tostring(is_cave))
    end

    -- 检查起点是否可通行
    local start_passable = IsGridPassable(
        start_gx, start_gz, grid_size, passable_cache, work)
    Helpers.DebugPrint("[AStar] Start position passable: " .. tostring(start_passable))
    if not start_passable then
        -- 尝试在起点附近找一个可通行的点
        Helpers.DebugPrint("[AStar] Start point is not passable, searching nearby...")
        local found = false
        for radius = 1, 3 do
            for dx = -radius, radius do
                for dz = -radius, radius do
                    if IsGridPassable(start_gx + dx, start_gz + dz,
                        grid_size, passable_cache, work) then
                        start_gx, start_gz = start_gx + dx, start_gz + dz
                        found = true
                        break
                    end
                end
                if found then break end
            end
            if found then break end
        end
        if not found then
            Helpers.DebugPrint("[AStar] Cannot find passable start point nearby")
            return nil
        end
        Helpers.DebugPrint(string.format("[AStar] Adjusted start grid: (%d, %d)", start_gx, start_gz))
    end

    -- 检查终点是否可通行
    if not IsGridPassable(
        end_gx, end_gz, grid_size, passable_cache, work) then
        Helpers.DebugPrint("[AStar] End point is not passable, searching nearby...")
        -- 搜索附近可通行的点
        local found = false
        for radius = 1, 5 do
            for dx = -radius, radius do
                for dz = -radius, radius do
                    if IsGridPassable(end_gx + dx, end_gz + dz,
                        grid_size, passable_cache, work) then
                        end_gx, end_gz = end_gx + dx, end_gz + dz
                        found = true
                        break
                    end
                end
                if found then break end
            end
            if found then break end
        end
        if not found then
            Helpers.DebugPrint("[AStar] Cannot find passable end point nearby")
            return nil
        end
        Helpers.DebugPrint(string.format("[AStar] Adjusted end grid: (%d, %d)", end_gx, end_gz))
    end

    -- 初始化
    local pq = PriorityQueue.new()
    local nodes = {}
    local function GetNode(gx, gz)
        local column = nodes[gx]
        if column == nil then
            column = {}
            nodes[gx] = column
        end
        local node = column[gz]
        if node == nil then
            node = {gx = gx, gz = gz, distance = math.huge}
            column[gz] = node
        end
        return node
    end

    local start_node = GetNode(start_gx, start_gz)
    local end_node = GetNode(end_gx, end_gz)
    start_node.distance = 0
    pq:push(
        start_node,
        PathfindingPolicy.EstimateWeightedCost(
            start_gx, start_gz, end_gx, end_gz, heuristic_weight),
        0)

    local nodes_searched = 0

    -- A* 主循环
    while not pq:isEmpty() do
        local current, queued_distance = pq:pop()

        -- 同一格子可能以更短距离重新入堆；丢弃旧条目。
        if not current.closed and queued_distance == current.distance then
            current.closed = true
            nodes_searched = nodes_searched + 1

            -- 检查是否到达终点
            if current == end_node then
                Helpers.DebugPrint(string.format(
                    "[%s] Path found after %d nodes", search_name, nodes_searched))
                break
            end

            -- 防止搜索过久
            if nodes_searched >= max_search_nodes then
                Helpers.DebugPrint(string.format(
                    "[%s] Max search nodes reached (%d)",
                    search_name, max_search_nodes))
                break
            end

            -- 遍历邻居
            for _, dir in ipairs(CONFIG.NEIGHBOR_DIRS) do
                local next_gx = current.gx + dir.dx
                local next_gz = current.gz + dir.dz
                local next_node = GetNode(next_gx, next_gz)

                -- 检查是否可处理
                if not next_node.closed and
                   IsGridPassable(next_gx, next_gz,
                       grid_size, passable_cache, work) and
                   IsDiagonalPassable(current.gx, current.gz, dir.dx, dir.dz,
                       grid_size, passable_cache, work) then
                    -- 计算新距离（考虑地面类型代价）
                    local ground_cost = GetGridGroundCost(
                        next_gx, next_gz, grid_size, ground_cost_cache, work)
                    local new_dist = current.distance + dir.cost * ground_cost

                    -- 更新最短路径
                    if new_dist < next_node.distance then
                        next_node.distance = new_dist
                        next_node.parent = current
                        local priority = new_dist +
                            PathfindingPolicy.EstimateWeightedCost(
                                next_gx, next_gz, end_gx, end_gz,
                                heuristic_weight)
                        pq:push(next_node, priority, new_dist)
                    end
                end
            end
        end
    end

    -- 检查是否找到路径
    if not end_node.closed then
        Helpers.DebugPrint("[" .. search_name .. "] No path found")
        return nil
    end

    -- 反向收集后原地翻转，避免 table.insert(path, 1, ...) 的 O(n²) 搬移。
    local path = {}
    local current = end_node
    while current ~= nil and current ~= start_node do
        local wx, wz = GridToWorld(current.gx, current.gz, grid_size)
        path[#path + 1] = {x = wx, z = wz}
        current = current.parent
    end
    for left = 1, math.floor(#path / 2) do
        local right = #path - left + 1
        path[left], path[right] = path[right], path[left]
    end

    Helpers.DebugPrint(string.format(
        "[%s] Reconstructed %d waypoints; road tiles: %d",
        search_name, #path, debug_road_count))

    return path
end

-- ============================================================================
-- 路径简化（移除共线点）
-- ============================================================================

SimplifyPath = function(path)
    if #path <= 2 then
        return path
    end

    local simplified = {path[1]}

    for i = 2, #path - 1 do
        local prev_point = simplified[#simplified]
        local curr_point = path[i]
        local next_point = path[i + 1]

        -- 计算方向向量
        local dx1 = curr_point.x - prev_point.x
        local dz1 = curr_point.z - prev_point.z
        local dx2 = next_point.x - curr_point.x
        local dz2 = next_point.z - curr_point.z

        -- 如果方向改变，保留该点
        -- 使用叉积判断是否共线
        local cross = dx1 * dz2 - dz1 * dx2
        if math.abs(cross) > 0.001 then
            table.insert(simplified, curr_point)
        end
    end

    -- 始终保留终点
    table.insert(simplified, path[#path])

    return simplified
end

local function AppendExactTarget(path, end_x, end_z, work, required)
    local last = path[#path]
    if last == nil then
        return {{x = end_x, z = end_z}}
    end

    if IsLinePassable(last.x, last.z, end_x, end_z, work) then
        path[#path + 1] = {x = end_x, z = end_z}
    elseif required then
        return nil
    end
    return path
end

local function ValidatePathFrom(start_x, start_z, path, work)
    local previous_x, previous_z = start_x, start_z
    for _, point in ipairs(path) do
        if not IsLinePassable(
            previous_x, previous_z, point.x, point.z, work) then
            return false
        end
        previous_x, previous_z = point.x, point.z
    end
    return true
end

local function ChooseFasterRoute(start_x, start_z, direct_cost,
    candidate, candidate_mode, end_x, end_z, work)
    if candidate == nil then
        return {{x = end_x, z = end_z}}, "direct"
    end

    candidate = AppendExactTarget(candidate, end_x, end_z, work, true)
    if candidate == nil then
        return {{x = end_x, z = end_z}}, "direct"
    end
    candidate = SimplifyPath(candidate)
    if not ValidatePathFrom(start_x, start_z, candidate, work) then
        return {{x = end_x, z = end_z}}, "direct"
    end

    local candidate_cost = EstimatePathTravelCost(
        start_x, start_z, candidate, work)
    local required_cost = direct_cost * (1 - CONFIG.ROUTE_IMPROVEMENT_MARGIN)
    Helpers.DebugPrintf(
        "Route comparison: direct %.2f, %s %.2f, threshold %.2f",
        direct_cost, candidate_mode, candidate_cost, required_cost)
    if candidate_cost < required_cost then
        return candidate, candidate_mode
    end
    return {{x = end_x, z = end_z}}, "direct"
end

local function FindClientPath(start_x, start_z, end_x, end_z, work)
    local dx = end_x - start_x
    local dz = end_z - start_z
    local distance = math.sqrt(dx * dx + dz * dz)
    local direct_passable = IsLinePassable(
        start_x, start_z, end_x, end_z, work)

    if direct_passable then
        local direct_cost = EstimateLineTravelCost(
            start_x, start_z, end_x, end_z, work)
        local fastest_possible = distance * GetRoadCost(work)
        local required_cost = direct_cost * (1 - CONFIG.ROUTE_IMPROVEMENT_MARGIN)

        -- A straight route already on the fastest terrain cannot be improved
        -- enough to justify a map search.
        if fastest_possible >= required_cost then
            return {{x = end_x, z = end_z}}, "direct"
        end

        local grid_size = CONFIG.GRID_SIZE
        local max_nodes = CONFIG.MAX_SEARCH_NODES
        local search_name = "FastestFineAStar"
        local mode = "fine"
        if distance >= CONFIG.MEDIUM_DISTANCE then
            grid_size = CONFIG.COARSE_GRID_SIZE
            max_nodes = CONFIG.COARSE_MAX_SEARCH_NODES
            search_name = "FastestCoarseAStar"
            mode = "coarse"
        elseif distance >= CONFIG.COARSE_DISTANCE then
            grid_size = CONFIG.MEDIUM_GRID_SIZE
            max_nodes = CONFIG.COARSE_MAX_SEARCH_NODES
            search_name = "FastestMediumAStar"
            mode = "medium"
        end

        -- Weight 1 keeps the terrain heuristic admissible while comparing
        -- travel time; the normal obstacle-only search remains weighted.
        local candidate = AStarPathfind(
            start_x, start_z, end_x, end_z,
            {
                grid_size = grid_size,
                max_search_nodes = max_nodes,
                search_name = search_name,
                heuristic_weight = 1,
            },
            work)
        return ChooseFasterRoute(
            start_x, start_z, direct_cost, candidate, mode,
            end_x, end_z, work)
    end

    -- 远距离先在粗网格上寻找安全走廊。所有线段会用客户端地图
    -- 重新采样验证；验证失败时自动退回精细网格，不牺牲正确性。
    if distance >= CONFIG.COARSE_DISTANCE then
        local coarse_path = AStarPathfind(
            start_x, start_z, end_x, end_z,
            {
                grid_size = CONFIG.COARSE_GRID_SIZE,
                max_search_nodes = CONFIG.COARSE_MAX_SEARCH_NODES,
                search_name = "CoarseAStar",
            },
            work)
        if coarse_path ~= nil then
            coarse_path = AppendExactTarget(
                coarse_path, end_x, end_z, work, true)
            if coarse_path ~= nil and
                ValidatePathFrom(start_x, start_z, coarse_path, work) then
                return SimplifyPath(coarse_path), "coarse"
            end
            Helpers.DebugPrint(
                "[CoarseAStar] Route validation failed; falling back to fine grid")
        end
    end

    local path = AStarPathfind(
        start_x, start_z, end_x, end_z,
        {
            grid_size = CONFIG.GRID_SIZE,
            max_search_nodes = CONFIG.MAX_SEARCH_NODES,
            search_name = "WeightedAStar",
        },
        work)
    if path == nil then
        return nil, "failed"
    end

    path = AppendExactTarget(path, end_x, end_z, work, false)
    return SimplifyPath(path), "fine"
end

-- ============================================================================
-- 路径执行
-- ============================================================================

local function MoveToNextWaypoint()
    if not pathfinding_state.active or not pathfinding_state.path then
        return false
    end

    local player = G.ThePlayer
    if not player or not player:IsValid() then
        Helpers.DebugPrint("Player not valid")
        ClientPathfinder.Stop()
        return false
    end

    local controller = player.components.playercontroller
    if not controller then
        Helpers.DebugPrint("No player controller")
        ClientPathfinder.Stop()
        return false
    end

    -- 获取当前路径点
    local waypoint = pathfinding_state.path[pathfinding_state.current_waypoint]
    if not waypoint then
        Helpers.DebugPrint("Pathfinding complete")
        ClientPathfinder.Stop()
        return false
    end

    local player_pos = player:GetPosition()
    local dx = waypoint.x - player_pos.x
    local dz = waypoint.z - player_pos.z
    local dist = math.sqrt(dx * dx + dz * dz)

    -- 判断是否是最后一个路径点（终点）
    local is_final = pathfinding_state.current_waypoint == #pathfinding_state.path
    local threshold = is_final and CONFIG.FINAL_ARRIVAL_THRESHOLD or CONFIG.ARRIVAL_THRESHOLD

    -- 检查是否已到达当前路径点
    if dist < threshold then
        pathfinding_state.current_waypoint = pathfinding_state.current_waypoint + 1
        Helpers.DebugPrintf("Reached waypoint %d/%d",
            pathfinding_state.current_waypoint - 1, #pathfinding_state.path)
        return MoveToNextWaypoint()
    end

    -- 检查是否卡住（跳过游戏暂停时和幽灵状态的检测）
    -- 幽灵可以穿越任何障碍物，不需要卡住检测
    -- 只读取本地暂停状态，不查询服务器状态。
    local is_paused = G.IsPaused ~= nil and G.IsPaused() or false
    local is_ghost = IsPlayerGhost()
    if not is_paused and not is_ghost and pathfinding_state.last_position then
        local last_dx = player_pos.x - pathfinding_state.last_position.x
        local last_dz = player_pos.z - pathfinding_state.last_position.z
        local moved_dist = math.sqrt(last_dx * last_dx + last_dz * last_dz)

        if moved_dist < 0.3 then
            pathfinding_state.stuck_counter = pathfinding_state.stuck_counter + 1
            if pathfinding_state.stuck_counter > CONFIG.STUCK_THRESHOLD then
                Helpers.DebugPrint("Player stuck, aborting pathfinding")
                ClientPathfinder.Stop()
                return false
            end
        else
            pathfinding_state.stuck_counter = 0
        end
    elseif is_paused or is_ghost then
        -- 游戏暂停或幽灵状态时重置卡住计数器
        pathfinding_state.stuck_counter = 0
    end

    pathfinding_state.last_position = {x = player_pos.x, z = player_pos.z}

    -- 发送移动指令
    -- print(string.format("[ClientPathfinder] Moving to waypoint %d: (%.1f, %.1f), dist: %.1f",
    --     pathfinding_state.current_waypoint, waypoint.x, waypoint.z, dist))

    -- 计算移动方向（归一化）
    local dir_x = dx / dist
    local dir_z = dz / dist

    -- 只驱动客户端已有的 locomotor，不直接调用服务器移动接口。
    if controller.locomotor ~= nil then
        if controller:CanLocomote() then
            player:ClearBufferedAction()
            controller.locomotor:SetBufferedAction(nil)
            controller.locomotor:RunInDirection(-math.atan2(dir_z, dir_x) / G.DEGREES)
        end
    else
        Helpers.DebugPrint("Movement unavailable; stopping pathfinding")
        ClientPathfinder.Stop()
        return false
    end

    return true
end

local function UpdatePathfinding()
    if not pathfinding_state.active then
        return
    end
    MoveToNextWaypoint()
end

-- ============================================================================
-- 公共 API
-- ============================================================================

local function NotifyPathReady(success, path, mode)
    local callback = pathfinding_state.on_path_ready
    pathfinding_state.on_path_ready = nil
    if callback ~= nil then
        local ok, err = pcall(callback, success, path, mode)
        if not ok then
            Helpers.DebugPrint("Path callback failed: " .. tostring(err))
        end
    end
end

local function FinishSearch(generation, path, mode)
    if generation ~= pathfinding_state.search_generation or
        not pathfinding_state.active then
        return false
    end

    pathfinding_state.search_thread = nil
    pathfinding_state.searching = false

    if path == nil or #path == 0 then
        Helpers.DebugPrint("Failed to generate path")
        pathfinding_state.active = false
        NotifyPathReady(false, nil, mode)
        return false
    end

    pathfinding_state.path = path
    pathfinding_state.current_waypoint = 1
    pathfinding_state.last_position = nil
    pathfinding_state.stuck_counter = 0

    local player = G.ThePlayer
    if player ~= nil and player.DoPeriodicTask ~= nil then
        pathfinding_state.update_task = player:DoPeriodicTask(
            CONFIG.MOVE_INTERVAL, UpdatePathfinding)
    end

    Helpers.DebugPrintf("%s path ready with %d waypoints",
        tostring(mode), #path)
    NotifyPathReady(true, path, mode)
    MoveToNextWaypoint()
    return true
end

local function ResumeSearch(generation)
    if generation ~= pathfinding_state.search_generation or
        not pathfinding_state.searching or
        pathfinding_state.search_thread == nil then
        return false
    end

    local ok, path, mode = coroutine.resume(pathfinding_state.search_thread)
    if not ok then
        Helpers.DebugPrint("Path search failed: " .. tostring(path))
        return FinishSearch(generation, nil, "error")
    end
    if coroutine.status(pathfinding_state.search_thread) == "dead" then
        return FinishSearch(generation, path, mode)
    end
    return nil
end

function ClientPathfinder.Start(target_x, target_z, on_path_ready)
    local player = G.ThePlayer
    if not player or not player:IsValid() then
        Helpers.DebugPrint("Cannot start pathfinding: player unavailable")
        return false
    end

    -- 检查世界和地图是否可用
    if not G.TheWorld then
        Helpers.DebugPrint("Cannot start pathfinding: world unavailable")
        return false
    end

    if not G.TheWorld.Map then
        Helpers.DebugPrint("Cannot start pathfinding: map unavailable")
        return false
    end

    local controller = player.components and player.components.playercontroller
    if controller == nil or controller.locomotor == nil then
        Helpers.DebugPrint("Cannot start pathfinding: movement unavailable")
        if on_path_ready ~= nil then
            on_path_ready(false, nil, "no_client_locomotor")
        end
        return false
    end

    -- 停止之前的寻路
    ClientPathfinder.Stop()

    local player_pos = player:GetPosition()

    -- 输出当前世界信息
    local is_cave = G.TheWorld:HasTag("cave")
    Helpers.DebugPrintf("World: %s, Is cave: %s",
        tostring(G.TheWorld.prefab), tostring(is_cave))

    Helpers.DebugPrintf("Starting pathfind from (%.1f, %.1f) to (%.1f, %.1f)",
        player_pos.x, player_pos.z, target_x, target_z)

    local generation = pathfinding_state.search_generation + 1
    pathfinding_state.search_generation = generation
    pathfinding_state.active = true
    pathfinding_state.searching = true
    pathfinding_state.path = nil
    pathfinding_state.target_pos = {x = target_x, z = target_z}
    pathfinding_state.on_path_ready = on_path_ready

    pathfinding_state.search_thread = coroutine.create(function()
        if IsPlayerGhost() then
            Helpers.DebugPrint("Ghost pathfinding uses a direct route")
            return StraightLinePathfind(
                player_pos.x, player_pos.z, target_x, target_z), "ghost"
        end
        return FindClientPath(
            player_pos.x, player_pos.z, target_x, target_z,
            {query_count = 0, can_yield = true})
    end)

    -- 先执行一帧预算；短直线路径通常可以立即完成。
    local immediate_result = ResumeSearch(generation)
    if immediate_result ~= nil then
        return immediate_result
    end

    return true
end

-- 由 TheFrontEnd 的本地逐帧更新驱动。它使用墙钟帧而不是世界模拟帧，
-- 因此单机打开地图、世界自动暂停时，搜索仍能按预算继续执行。
function ClientPathfinder.UpdateSearch()
    if pathfinding_state.searching then
        return ResumeSearch(pathfinding_state.search_generation)
    end
    return false
end

function ClientPathfinder.Stop()
    if pathfinding_state.update_task then
        pathfinding_state.update_task:Cancel()
        pathfinding_state.update_task = nil
    end

    local was_active = pathfinding_state.active

    -- 停止客户端本地移动；不直接调用服务器停止接口。
    if was_active and pathfinding_state.path ~= nil and
        G.ThePlayer and G.ThePlayer:IsValid() then
        local controller = G.ThePlayer.components.playercontroller
        if controller then
            if controller.locomotor ~= nil then
                -- 与预测移动的启动方式配对，触发本地 idle 状态并由
                -- PlayerController:DoPredictWalking 同步停止位置。
                if controller:CanLocomote() then
                    controller.locomotor:Stop()
                end
            end
        end
    end

    pathfinding_state.search_generation = pathfinding_state.search_generation + 1
    pathfinding_state.active = false
    pathfinding_state.searching = false
    pathfinding_state.path = nil
    pathfinding_state.current_waypoint = 1
    pathfinding_state.target_pos = nil
    pathfinding_state.last_position = nil
    pathfinding_state.stuck_counter = 0
    pathfinding_state.search_thread = nil
    pathfinding_state.on_path_ready = nil

    if was_active then
        Helpers.DebugPrint("Pathfinding stopped")
    end
end

function ClientPathfinder.IsActive()
    return pathfinding_state.active
end

function ClientPathfinder.GetCurrentPath()
    if pathfinding_state.active and pathfinding_state.path then
        return pathfinding_state.path
    end
    return nil
end

-- 获取当前进度
function ClientPathfinder.GetProgress()
    if not pathfinding_state.active or not pathfinding_state.path then
        return 0, 0
    end
    return pathfinding_state.current_waypoint, #pathfinding_state.path
end

-- Pure client-side test helpers. Production calls use the same search routine.
ClientPathfinder._Test = {
    FindPathSync = function(start_x, start_z, end_x, end_z)
        local thread = coroutine.create(function()
            return FindClientPath(
                start_x, start_z, end_x, end_z,
                {query_count = 0, can_yield = true})
        end)
        while true do
            local ok, path, mode = coroutine.resume(thread)
            assert(ok, path)
            if coroutine.status(thread) == "dead" then
                return path, mode
            end
        end
    end,
    CONFIG = CONFIG,
}

return ClientPathfinder
