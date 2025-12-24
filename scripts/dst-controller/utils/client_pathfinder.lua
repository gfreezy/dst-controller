-- Enhanced Controller - Client-side Pathfinder
-- 客户端寻路系统：使用 Dijkstra 算法基于地图网格寻路

local G = require("dst-controller/global")

local ClientPathfinder = {}

-- ============================================================================
-- 配置
-- ============================================================================

local CONFIG = {
    TILE_SCALE = 4,              -- DST 的 tile 大小
    GRID_SIZE = 4,               -- 寻路网格大小（与 TILE_SCALE 相同）
    MAX_SEARCH_NODES = 5000,     -- 最大搜索节点数（防止卡死）
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

function PriorityQueue:push(item, priority)
    self.size = self.size + 1
    self.heap[self.size] = {item = item, priority = priority}
    self:_bubbleUp(self.size)
end

function PriorityQueue:pop()
    if self.size == 0 then return nil end

    local top = self.heap[1].item
    self.heap[1] = self.heap[self.size]
    self.heap[self.size] = nil
    self.size = self.size - 1

    if self.size > 0 then
        self:_bubbleDown(1)
    end

    return top
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
    path = nil,
    current_waypoint = 1,
    target_pos = nil,
    last_position = nil,
    stuck_counter = 0,
    update_task = nil,
}

-- ============================================================================
-- 地图工具函数
-- ============================================================================

-- 世界坐标转网格坐标
local function WorldToGrid(x, z)
    return math.floor(x / CONFIG.GRID_SIZE), math.floor(z / CONFIG.GRID_SIZE)
end

-- 网格坐标转世界坐标（返回格子中心）
local function GridToWorld(gx, gz)
    return (gx + 0.5) * CONFIG.GRID_SIZE, (gz + 0.5) * CONFIG.GRID_SIZE
end

-- 生成网格节点的唯一键
local function GridKey(gx, gz)
    return gx .. "," .. gz
end

-- 检查世界坐标是否可通行
local function IsPassable(x, z)
    if not G.TheWorld or not G.TheWorld.Map then
        return false
    end

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
local function IsGridPassable(gx, gz)
    local wx, wz = GridToWorld(gx, gz)
    return IsPassable(wx, wz)
end

-- 检查对角线移动是否可行（需要两侧都可通行）
local function IsDiagonalPassable(from_gx, from_gz, dx, dz)
    -- 对角线移动需要两个相邻格子都可通行，否则会穿墙
    if dx ~= 0 and dz ~= 0 then
        if not IsGridPassable(from_gx + dx, from_gz) then
            return false
        end
        if not IsGridPassable(from_gx, from_gz + dz) then
            return false
        end
    end
    return true
end

-- ============================================================================
-- Dijkstra 寻路算法
-- ============================================================================

local function DijkstraPathfind(start_x, start_z, end_x, end_z)
    local start_gx, start_gz = WorldToGrid(start_x, start_z)
    local end_gx, end_gz = WorldToGrid(end_x, end_z)

    print(string.format("[Dijkstra] Start grid: (%d, %d), End grid: (%d, %d)",
        start_gx, start_gz, end_gx, end_gz))

    -- 调试：检查世界和地图状态
    print("[Dijkstra] TheWorld: " .. tostring(G.TheWorld))
    print("[Dijkstra] TheWorld.Map: " .. tostring(G.TheWorld and G.TheWorld.Map))
    if G.TheWorld then
        print("[Dijkstra] World prefab: " .. tostring(G.TheWorld.prefab))
        -- 检查是否在洞穴
        local is_cave = G.TheWorld:HasTag("cave")
        print("[Dijkstra] Is cave: " .. tostring(is_cave))
    end

    -- 检查起点是否可通行
    local start_passable = IsGridPassable(start_gx, start_gz)
    print("[Dijkstra] Start position passable: " .. tostring(start_passable))
    if not start_passable then
        -- 尝试在起点附近找一个可通行的点
        print("[Dijkstra] Start point is not passable, searching nearby...")
        local found = false
        for radius = 1, 3 do
            for dx = -radius, radius do
                for dz = -radius, radius do
                    if IsGridPassable(start_gx + dx, start_gz + dz) then
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
            print("[Dijkstra] Cannot find passable start point nearby")
            return nil
        end
        print(string.format("[Dijkstra] Adjusted start grid: (%d, %d)", start_gx, start_gz))
    end

    -- 检查终点是否可通行
    if not IsGridPassable(end_gx, end_gz) then
        print("[Dijkstra] End point is not passable, searching nearby...")
        -- 搜索附近可通行的点
        local found = false
        for radius = 1, 5 do
            for dx = -radius, radius do
                for dz = -radius, radius do
                    if IsGridPassable(end_gx + dx, end_gz + dz) then
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
            print("[Dijkstra] Cannot find passable end point nearby")
            return nil
        end
        print(string.format("[Dijkstra] Adjusted end grid: (%d, %d)", end_gx, end_gz))
    end

    -- 初始化
    local pq = PriorityQueue.new()
    local dist = {}      -- 距离表
    local prev = {}      -- 前驱节点表
    local visited = {}   -- 已访问节点

    local start_key = GridKey(start_gx, start_gz)
    local end_key = GridKey(end_gx, end_gz)

    dist[start_key] = 0
    pq:push({gx = start_gx, gz = start_gz}, 0)

    local nodes_searched = 0

    -- Dijkstra 主循环
    while not pq:isEmpty() do
        local current = pq:pop()
        local current_key = GridKey(current.gx, current.gz)

        -- 跳过已访问节点
        if not visited[current_key] then
            visited[current_key] = true
            nodes_searched = nodes_searched + 1

            -- 检查是否到达终点
            if current_key == end_key then
                print(string.format("[Dijkstra] Path found! Searched %d nodes", nodes_searched))
                break
            end

            -- 防止搜索过久
            if nodes_searched >= CONFIG.MAX_SEARCH_NODES then
                print(string.format("[Dijkstra] Max search nodes reached (%d)", CONFIG.MAX_SEARCH_NODES))
                break
            end

            -- 遍历邻居
            for _, dir in ipairs(CONFIG.NEIGHBOR_DIRS) do
                local next_gx = current.gx + dir.dx
                local next_gz = current.gz + dir.dz
                local next_key = GridKey(next_gx, next_gz)

                -- 检查是否可处理
                if not visited[next_key] and
                   IsGridPassable(next_gx, next_gz) and
                   IsDiagonalPassable(current.gx, current.gz, dir.dx, dir.dz) then
                    -- 计算新距离
                    local new_dist = dist[current_key] + dir.cost

                    -- 更新最短路径
                    if not dist[next_key] or new_dist < dist[next_key] then
                        dist[next_key] = new_dist
                        prev[next_key] = current_key
                        pq:push({gx = next_gx, gz = next_gz}, new_dist)
                    end
                end
            end
        end
    end

    -- 检查是否找到路径
    if not visited[end_key] then
        print("[Dijkstra] No path found")
        return nil
    end

    -- 重建路径
    local path = {}
    local current_key = end_key

    while current_key and current_key ~= start_key do
        local gx, gz = current_key:match("([^,]+),([^,]+)")
        gx, gz = tonumber(gx), tonumber(gz)
        local wx, wz = GridToWorld(gx, gz)
        table.insert(path, 1, {x = wx, z = wz})
        current_key = prev[current_key]
    end

    print(string.format("[Dijkstra] Path reconstructed with %d waypoints", #path))

    -- 简化路径（移除共线点）
    path = SimplifyPath(path)
    print(string.format("[Dijkstra] Path simplified to %d waypoints", #path))

    return path
end

-- ============================================================================
-- 路径简化（移除共线点）
-- ============================================================================

function SimplifyPath(path)
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

-- ============================================================================
-- 路径执行
-- ============================================================================

local function MoveToNextWaypoint()
    if not pathfinding_state.active or not pathfinding_state.path then
        return false
    end

    local player = G.ThePlayer
    if not player or not player:IsValid() then
        print("[ClientPathfinder] Player not valid")
        ClientPathfinder.Stop()
        return false
    end

    local controller = player.components.playercontroller
    if not controller then
        print("[ClientPathfinder] No playercontroller")
        ClientPathfinder.Stop()
        return false
    end

    -- 获取当前路径点
    local waypoint = pathfinding_state.path[pathfinding_state.current_waypoint]
    if not waypoint then
        print("[ClientPathfinder] Pathfinding complete!")
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
        print(string.format("[ClientPathfinder] Reached waypoint %d/%d",
            pathfinding_state.current_waypoint - 1, #pathfinding_state.path))
        return MoveToNextWaypoint()
    end

    -- 检查是否卡住（跳过游戏暂停时的检测）
    local is_paused = false
    if G.TheNet and G.TheNet.GetServerIsPaused then
        is_paused = G.TheNet:GetServerIsPaused()
    end
    if not is_paused and pathfinding_state.last_position then
        local last_dx = player_pos.x - pathfinding_state.last_position.x
        local last_dz = player_pos.z - pathfinding_state.last_position.z
        local moved_dist = math.sqrt(last_dx * last_dx + last_dz * last_dz)

        if moved_dist < 0.3 then
            pathfinding_state.stuck_counter = pathfinding_state.stuck_counter + 1
            if pathfinding_state.stuck_counter > CONFIG.STUCK_THRESHOLD then
                print("[ClientPathfinder] Player stuck, aborting")
                ClientPathfinder.Stop()
                return false
            end
        else
            pathfinding_state.stuck_counter = 0
        end
    elseif is_paused then
        -- 游戏暂停时重置卡住计数器
        pathfinding_state.stuck_counter = 0
    end

    pathfinding_state.last_position = {x = player_pos.x, z = player_pos.z}

    -- 发送移动指令
    print(string.format("[ClientPathfinder] Moving to waypoint %d: (%.1f, %.1f), dist: %.1f",
        pathfinding_state.current_waypoint, waypoint.x, waypoint.z, dist))

    -- 计算移动方向
    local dir_x = dx / dist
    local dir_z = dz / dist

    -- 方法1: 使用方向行走 (DirectWalking)
    if controller.SetDirWalking then
        controller:SetDirWalking(dir_x, dir_z)
        return true
    end

    -- 方法2: 使用 RemoteDirectWalking
    if controller.RemoteDirectWalking then
        controller:RemoteDirectWalking(dir_x, dir_z)
        return true
    end

    -- 方法3: 备用 - 使用 BufferedAction
    local target_pos = G.Vector3(waypoint.x, 0, waypoint.z)
    local action = G.BufferedAction(player, nil, G.ACTIONS.WALKTO, nil, target_pos)
    controller:DoAction(action)

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

function ClientPathfinder.Start(target_x, target_z)
    local player = G.ThePlayer
    if not player or not player:IsValid() then
        print("[ClientPathfinder] Cannot start: player not valid")
        return false
    end

    -- 检查世界和地图是否可用
    if not G.TheWorld then
        print("[ClientPathfinder] Cannot start: TheWorld is nil")
        return false
    end

    if not G.TheWorld.Map then
        print("[ClientPathfinder] Cannot start: TheWorld.Map is nil")
        return false
    end

    -- 停止之前的寻路
    ClientPathfinder.Stop()

    local player_pos = player:GetPosition()

    -- 输出当前世界信息
    local is_cave = G.TheWorld:HasTag("cave")
    print(string.format("[ClientPathfinder] World: %s, Is cave: %s",
        tostring(G.TheWorld.prefab), tostring(is_cave)))

    print(string.format("[ClientPathfinder] Starting pathfind from (%.1f, %.1f) to (%.1f, %.1f)",
        player_pos.x, player_pos.z, target_x, target_z))

    -- 使用 Dijkstra 算法生成路径
    local path = DijkstraPathfind(player_pos.x, player_pos.z, target_x, target_z)
    if not path or #path == 0 then
        print("[ClientPathfinder] Failed to generate path")
        return false
    end

    -- 保存寻路状态
    pathfinding_state.active = true
    pathfinding_state.path = path
    pathfinding_state.current_waypoint = 1
    pathfinding_state.target_pos = {x = target_x, z = target_z}
    pathfinding_state.last_position = nil
    pathfinding_state.stuck_counter = 0

    -- 开始更新任务
    if player.DoPeriodicTask then
        pathfinding_state.update_task = player:DoPeriodicTask(CONFIG.MOVE_INTERVAL, UpdatePathfinding)
    end

    print(string.format("[ClientPathfinder] Pathfinding started with %d waypoints", #path))

    -- 立即开始移动
    MoveToNextWaypoint()

    return true
end

function ClientPathfinder.Stop()
    if pathfinding_state.update_task then
        pathfinding_state.update_task:Cancel()
        pathfinding_state.update_task = nil
    end

    local was_active = pathfinding_state.active

    pathfinding_state.active = false
    pathfinding_state.path = nil
    pathfinding_state.current_waypoint = 1
    pathfinding_state.target_pos = nil
    pathfinding_state.last_position = nil
    pathfinding_state.stuck_counter = 0

    if was_active then
        print("[ClientPathfinder] Pathfinding stopped")
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

return ClientPathfinder
