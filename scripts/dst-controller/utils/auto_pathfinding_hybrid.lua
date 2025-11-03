-- Hybrid Auto Pathfinding Utility
-- 混合寻路算法：预先规划关键路径点 + 实时微调waypoint
-- 阶段1：使用双向海岸线跟随算法找到绕水的关键点
-- 阶段2：在关键点之间移动，实时避开敌对生物和小障碍

local G = require("dst-controller/global")
local MapPathDrawer = require("dst-controller/utils/map_path_drawer")

local HybridPathfinding = {}

-- 状态管理
local STATE = {
    active = false,
    final_target = nil,          -- 最终目标 Vector3
    key_points = {},             -- 关键路径点列表
    current_key_point_index = 1, -- 当前目标关键点索引
    current_waypoint = nil,      -- 当前微观waypoint Vector3
    avoid_hostiles = true,
    avoid_spider_dens = true,    -- 是否避开蜘蛛巢穴（默认开启）
    arrival_distance = 0.5,
    key_point_distance = 2.0,    -- 到达关键点的判定距离（更大，因为是宏观点）
    check_interval = 0.5,
    time_since_check = 0,
    stuck_time = 0,
    stuck_threshold = 3,
    last_position = nil,
}

-- 配置
local CONFIG = {
    -- 阶段1：关键点规划配置
    key_point_step = 20,              -- 关键点采样步长（米）
    direct_path_sample_step = 2,      -- 直线检测采样步长（米）- 用于检测细河
    coastline_search_angles = 8,      -- 海岸线搜索角度数量
    max_planning_iterations = 100,    -- 最大规划迭代次数（防止死循环）
    bidirectional_search = true,      -- 是否使用双向搜索

    -- 阶段2：微观移动配置
    waypoint_distance = 8,            -- 微观waypoint距离（米）
    hostile_detection_radius = 6,     -- 敌对生物检测半径
    safe_distance = 4,                -- 与敌对生物的安全距离

    -- 可视化配置
    show_debug_path = true,           -- 是否显示调试路径（关键点连线）
    debug_path_lifetime = 5,          -- 调试线条显示时长（秒）
}

-- ============================================================================
-- 工具函数
-- ============================================================================

-- 绘制调试路径（同时在3D世界和地图上显示）
local function DrawDebugPath(key_points, player_pos)
    if not CONFIG.show_debug_path or not key_points or #key_points == 0 then
        return
    end

    -- 1. 在3D世界中绘制（用于游戏内观察）
    local gp = G.TheWorld.components.globalposition
    if gp then
        -- 绘制从玩家位置到第一个关键点的线
        if key_points[1] then
            gp:DrawLine(
                player_pos.x, player_pos.y, player_pos.z,
                key_points[1].x, key_points[1].y, key_points[1].z,
                0, 1, 0, 1,  -- 绿色 (RGBA)
                CONFIG.debug_path_lifetime
            )
        end

        -- 绘制关键点之间的连线
        for i = 1, #key_points - 1 do
            local p1 = key_points[i]
            local p2 = key_points[i + 1]

            gp:DrawLine(
                p1.x, p1.y, p1.z,
                p2.x, p2.y, p2.z,
                0, 1, 0, 1,  -- 绿色 (RGBA)
                CONFIG.debug_path_lifetime
            )
        end

        -- 在每个关键点绘制一个小球
        for _, point in ipairs(key_points) do
            gp:DrawSphere(
                point.x, point.y, point.z,
                0.5,  -- 半径
                1, 1, 0, 1,  -- 黄色 (RGBA)
                CONFIG.debug_path_lifetime
            )
        end
    end

    -- 2. 在地图界面上绘制（如果地图已打开）
    local mapscreen = MapPathDrawer.GetMapScreen()
    if mapscreen then
        MapPathDrawer.DrawPathPoints(key_points, player_pos)
    end
end

-- 检查位置是否在迷雾中
local function IsPositionInFog(x, y, z)
    local map = G.TheWorld.Map
    if not map then return false end

    local tile_x, tile_z = map:GetTileCoordsAtPoint(x, y, z)
    if tile_x and tile_z then
        return not map:IsExplored(tile_x, tile_z)
    end
    return false
end

-- 检查位置附近是否有蜘蛛巢穴（会产生蜘蛛网地毯）
-- @param x, y, z: 要检查的位置
-- @param radius: 检测半径（默认4米 - 蜘蛛网的典型影响范围）
-- @return boolean: 是否在蜘蛛巢穴附近
local function IsNearSpiderDen(x, y, z, radius)
    radius = radius or 4  -- 默认4米检测半径（蜘蛛巢穴的蜘蛛网影响范围约3-4米）

    -- 查找附近的蜘蛛巢穴相关实体
    -- 包括：spider_cocoon（蜘蛛茧/巢穴）、spiderden（蜘蛛巢穴标签）
    local ents = G.TheSim:FindEntities(x, y, z, radius,
        nil,                              -- 不限制必须标签
        {"FX", "INLIMBO", "NOCLICK"},    -- 排除特效、隐藏、不可点击的实体
        {"spider_cocoon", "spiderden"})  -- 必须有其中一个标签

    return #ents > 0
end

-- 检查实体是否为敌对生物
local function IsHostileEntity(entity, player)
    if not entity or not entity:IsValid() or entity == player or entity:HasTag("player") then
        return false
    end

    local combat = entity.components.combat
    if combat then
        if combat:TargetIs(player) or combat.target == player then
            return true
        end
        if entity:HasTag("monster") or entity:HasTag("hostile") then
            return true
        end
    end
    return false
end

-- 查找附近的敌对生物
local function FindNearbyHostiles(player, position, radius)
    local x, y, z = position.x, position.y, position.z
    local entities = G.TheSim:FindEntities(x, y, z, radius, nil, {"FX", "INLIMBO", "NOCLICK", "notarget"})

    local hostiles = {}
    for _, entity in ipairs(entities) do
        if IsHostileEntity(entity, player) then
            table.insert(hostiles, entity)
        end
    end
    return hostiles
end

-- 计算避开敌对生物的方向调整
local function CalculateHostileAvoidance(player_pos, target_dir, hostiles)
    if #hostiles == 0 then
        return G.Vector3(0, 0, 0)
    end

    local avoidance = G.Vector3(0, 0, 0)
    for _, hostile in ipairs(hostiles) do
        local hostile_pos = G.Vector3(hostile.Transform:GetWorldPosition())
        local to_hostile = hostile_pos - player_pos
        to_hostile.y = 0

        local distance = to_hostile:Length()
        if distance < CONFIG.safe_distance then
            local push_away = -to_hostile:GetNormalized()
            local strength = (CONFIG.safe_distance - distance) / CONFIG.safe_distance
            avoidance = avoidance + push_away * strength * 2
        end
    end
    return avoidance
end

-- ============================================================================
-- 阶段1：预先规划关键路径点（双向海岸线跟随）
-- ============================================================================

-- 单向海岸线搜索
-- 返回：{found = true/false, points = {关键点列表}, iterations = 迭代次数}
local function SearchCoastlineDirection(start_pos, target_pos, turn_direction, map)
    local points = {}
    local current_pos = start_pos
    local iterations = 0
    local max_iterations = CONFIG.max_planning_iterations / 2  -- 每个方向最多一半迭代次数

    while iterations < max_iterations do
        iterations = iterations + 1

        -- 检查是否接近目标
        local distance_to_target = (target_pos - current_pos):Length()
        if distance_to_target < CONFIG.key_point_step then
            table.insert(points, target_pos)
            return {found = true, points = points, iterations = iterations}
        end

        -- 计算朝向目标的理想方向
        local ideal_direction = (target_pos - current_pos):GetNormalized()
        ideal_direction.y = 0

        -- 检查理想方向是否可行走（直线可达）
        local test_point = current_pos + ideal_direction * CONFIG.key_point_step
        if map:IsPassableAtPoint(test_point.x, test_point.y, test_point.z) and
           not IsPositionInFog(test_point.x, test_point.y, test_point.z) then
            -- 可以直线前进
            table.insert(points, test_point)
            current_pos = test_point
        else
            -- 需要沿海岸线绕行
            -- 根据turn_direction确定搜索角度范围
            local angle_start, angle_end, angle_step
            if turn_direction == "left" then
                angle_start = -90
                angle_end = 90
                angle_step = 180 / CONFIG.coastline_search_angles
            else  -- "right"
                angle_start = 90
                angle_end = -90
                angle_step = -180 / CONFIG.coastline_search_angles
            end

            -- 搜索可行走的方向
            local found_direction = nil
            local best_score = -math.huge

            for angle_deg = angle_start, angle_end, angle_step do
                local angle_rad = angle_deg * G.DEGREES
                local rotated_dir = G.Vector3(
                    ideal_direction.x * math.cos(angle_rad) - ideal_direction.z * math.sin(angle_rad),
                    0,
                    ideal_direction.x * math.sin(angle_rad) + ideal_direction.z * math.cos(angle_rad)
                )

                local sample_point = current_pos + rotated_dir * CONFIG.key_point_step

                -- 检查是否可行走且已探索
                if map:IsPassableAtPoint(sample_point.x, sample_point.y, sample_point.z) and
                   not IsPositionInFog(sample_point.x, sample_point.y, sample_point.z) then
                    -- 计算分数：距离目标越近越好，角度偏移越小越好
                    local to_target_dist = (target_pos - sample_point):Length()
                    local angle_penalty = math.abs(angle_deg) / 90
                    local score = -to_target_dist - angle_penalty * 10

                    if score > best_score then
                        best_score = score
                        found_direction = sample_point
                    end
                end
            end

            if found_direction then
                table.insert(points, found_direction)
                current_pos = found_direction
            else
                -- 找不到可行走的方向，搜索失败
                return {found = false, points = points, iterations = iterations}
            end
        end
    end

    -- 达到最大迭代次数，搜索失败
    return {found = false, points = points, iterations = iterations}
end

-- 双向海岸线搜索，选择最优路径
local function PlanKeyPointsWithBidirectionalCoastline(player_pos, target_pos, map)
    print("[HybridPathfinding] Planning key points with bidirectional coastline search")

    -- 检查是否可以直线到达
    local direction = (target_pos - player_pos):GetNormalized()
    direction.y = 0
    local distance = (target_pos - player_pos):Length()
    local can_go_straight = true

    -- 使用更密集的采样检测直线路径（防止漏检细河）
    local sample_step = CONFIG.direct_path_sample_step  -- 2米一次采样
    local sample_count = math.ceil(distance / sample_step)

    print(string.format("[HybridPathfinding] Checking direct path with %d samples (every %.1fm)",
        sample_count, sample_step))

    for i = 1, sample_count do
        local sample_dist = math.min(i * sample_step, distance)
        local sample_point = player_pos + direction * sample_dist

        -- 检查是否可通行、是否在迷雾中（规划阶段只考虑水域障碍）
        if not map:IsPassableAtPoint(sample_point.x, sample_point.y, sample_point.z) or
           IsPositionInFog(sample_point.x, sample_point.y, sample_point.z) then
            can_go_straight = false
            print(string.format("[HybridPathfinding] Obstacle detected at %.1fm", sample_dist))
            break
        end
    end

    -- 如果可以直线到达，直接返回目标点
    if can_go_straight then
        print("[HybridPathfinding] Direct path available, no key points needed")
        return {target_pos}
    end

    -- 需要绕路，执行双向海岸线搜索
    print("[HybridPathfinding] Obstacle detected, starting bidirectional coastline search")

    if not CONFIG.bidirectional_search then
        -- 单向搜索（默认左转）
        local result = SearchCoastlineDirection(player_pos, target_pos, "left", map)
        if result.found then
            print(string.format("[HybridPathfinding] Left search succeeded with %d key points", #result.points))
            return result.points
        else
            print("[HybridPathfinding] Left search failed, trying right")
            result = SearchCoastlineDirection(player_pos, target_pos, "right", map)
            if result.found then
                print(string.format("[HybridPathfinding] Right search succeeded with %d key points", #result.points))
                return result.points
            else
                print("[HybridPathfinding] Both directions failed, no path found")
                return nil
            end
        end
    else
        -- 双向并行搜索
        local left_result = SearchCoastlineDirection(player_pos, target_pos, "left", map)
        local right_result = SearchCoastlineDirection(player_pos, target_pos, "right", map)

        -- 选择最优路径
        if left_result.found and right_result.found then
            -- 两边都找到了，选择关键点少的（路径更短）
            if #left_result.points <= #right_result.points then
                print(string.format("[HybridPathfinding] Both directions succeeded, chose left (%d points vs %d points)",
                    #left_result.points, #right_result.points))
                return left_result.points
            else
                print(string.format("[HybridPathfinding] Both directions succeeded, chose right (%d points vs %d points)",
                    #right_result.points, #left_result.points))
                return right_result.points
            end
        elseif left_result.found then
            print(string.format("[HybridPathfinding] Only left direction succeeded with %d key points", #left_result.points))
            return left_result.points
        elseif right_result.found then
            print(string.format("[HybridPathfinding] Only right direction succeeded with %d key points", #right_result.points))
            return right_result.points
        else
            print("[HybridPathfinding] Both directions failed, no path found")
            return nil
        end
    end
end

-- ============================================================================
-- 阶段2：微观移动（在关键点之间使用简化waypoint）
-- ============================================================================

-- 寻找下一个微观waypoint（不考虑水域，只考虑敌对生物）
local function FindNextWaypoint(player_pos, target_key_point)
    local direction = (target_key_point - player_pos):GetNormalized()
    direction.y = 0
    local distance = (target_key_point - player_pos):Length()

    -- 如果目标关键点很近，直接返回
    if distance < CONFIG.waypoint_distance then
        return target_key_point
    end

    -- 返回前方waypoint_distance米处的点
    return player_pos + direction * CONFIG.waypoint_distance
end

-- 执行移动
local function DoMove(player)
    if not player or not player:IsValid() then
        return false
    end

    local player_pos = G.Vector3(player.Transform:GetWorldPosition())
    local current_key_point = STATE.key_points[STATE.current_key_point_index]

    if not current_key_point then
        return false
    end

    -- 检查是否到达当前关键点
    local distance_to_key_point = (current_key_point - player_pos):Length()
    if distance_to_key_point < STATE.key_point_distance then
        print(string.format("[HybridPathfinding] Reached key point %d/%d",
            STATE.current_key_point_index, #STATE.key_points))

        -- 移动到下一个关键点
        STATE.current_key_point_index = STATE.current_key_point_index + 1

        -- 检查是否到达最终目标
        if STATE.current_key_point_index > #STATE.key_points then
            print("[HybridPathfinding] Reached final target!")
            return false  -- 完成寻路
        end

        -- 更新目标关键点
        current_key_point = STATE.key_points[STATE.current_key_point_index]
    end

    -- 计算微观waypoint
    STATE.current_waypoint = FindNextWaypoint(player_pos, current_key_point)

    -- 检查敌对生物并调整方向
    local move_target = STATE.current_waypoint
    if STATE.avoid_hostiles then
        local hostiles = FindNearbyHostiles(player, player_pos, CONFIG.hostile_detection_radius)
        if #hostiles > 0 then
            local direction_to_waypoint = (STATE.current_waypoint - player_pos):GetNormalized()
            local avoidance = CalculateHostileAvoidance(player_pos, direction_to_waypoint, hostiles)

            if avoidance:Length() > 0.1 then
                local adjusted_dir = direction_to_waypoint + avoidance * 0.5
                adjusted_dir.y = 0
                adjusted_dir = adjusted_dir:GetNormalized()
                move_target = player_pos + adjusted_dir * 5
                print(string.format("[HybridPathfinding] Avoiding %d hostiles", #hostiles))
            end
        end
    end

    -- 检查蜘蛛巢穴并调整方向
    if STATE.avoid_spider_dens then
        -- 检查当前移动目标是否靠近蜘蛛巢穴
        if IsNearSpiderDen(move_target.x, move_target.y, move_target.z) then
            -- 蜘蛛巢穴在前方，尝试绕路
            local direction_to_waypoint = (STATE.current_waypoint - player_pos):GetNormalized()
            local found_detour = false

            -- 尝试左右两侧绕路（各尝试30度和60度）
            for _, angle_deg in ipairs({-30, 30, -60, 60, -90, 90}) do
                local angle_rad = angle_deg * G.DEGREES
                local rotated_dir = G.Vector3(
                    direction_to_waypoint.x * math.cos(angle_rad) - direction_to_waypoint.z * math.sin(angle_rad),
                    0,
                    direction_to_waypoint.x * math.sin(angle_rad) + direction_to_waypoint.z * math.cos(angle_rad)
                )

                local detour_point = player_pos + rotated_dir * 5

                -- 检查绕路点是否远离蜘蛛巢穴
                if not IsNearSpiderDen(detour_point.x, detour_point.y, detour_point.z) then
                    move_target = detour_point
                    found_detour = true
                    print(string.format("[HybridPathfinding] Detouring around spider den (angle: %d°)", angle_deg))
                    break
                end
            end

            if not found_detour then
                print("[HybridPathfinding] Warning: Cannot find detour around spider den, moving cautiously")
            end
        end
    end

    -- 执行移动
    local locomotor = player.components.locomotor
    if locomotor then
        local action = G.BufferedAction(player, nil, G.ACTIONS.WALKTO, nil, move_target)
        locomotor:PushAction(action, true)
        return true
    end

    return false
end

-- ============================================================================
-- 公共接口
-- ============================================================================

-- 更新函数
function HybridPathfinding.OnUpdate(dt)
    if not STATE.active then
        return
    end

    STATE.time_since_check = STATE.time_since_check + dt
    if STATE.time_since_check < STATE.check_interval then
        return
    end
    STATE.time_since_check = 0

    local player = G.ThePlayer
    if not player or not player:IsValid() then
        HybridPathfinding.Stop()
        return
    end

    -- 检查是否卡住
    local current_pos = G.Vector3(player.Transform:GetWorldPosition())
    if STATE.last_position then
        local moved_distance = (current_pos - STATE.last_position):Length()
        if moved_distance < 0.1 then
            STATE.stuck_time = STATE.stuck_time + STATE.check_interval
            if STATE.stuck_time > STATE.stuck_threshold then
                print("[HybridPathfinding] Player stuck, attempting recovery")
                -- 尝试跳过当前关键点
                if STATE.current_key_point_index < #STATE.key_points then
                    STATE.current_key_point_index = STATE.current_key_point_index + 1
                    print(string.format("[HybridPathfinding] Skipping to next key point %d/%d",
                        STATE.current_key_point_index, #STATE.key_points))
                else
                    print("[HybridPathfinding] Stuck at last key point, stopping")
                    HybridPathfinding.Stop()
                    return
                end
                STATE.stuck_time = 0
            end
        else
            STATE.stuck_time = 0
        end
    end
    STATE.last_position = current_pos

    -- 执行移动
    local should_continue = DoMove(player)
    if not should_continue then
        HybridPathfinding.Stop()
    end
end

-- 查找通往迷雾目标的最近已探索点
-- 返回一个中间目标点（在迷雾边缘）
local function FindPathToFoggedTarget(player_pos, target_pos)
    local map = G.TheWorld.Map
    if not map then
        return target_pos
    end

    -- 计算方向向量
    local direction = (target_pos - player_pos):GetNormalized()

    -- 沿着方向向量，每隔2米检查一次，找到迷雾边缘
    local max_distance = (target_pos - player_pos):Length()
    local step_size = 2  -- 每次前进2米

    for distance = step_size, max_distance, step_size do
        local check_pos = player_pos + direction * distance

        -- 检查这个点是否在迷雾中
        if IsPositionInFog(check_pos.x, check_pos.y, check_pos.z) then
            -- 找到迷雾边缘，返回上一个已探索的点
            local safe_distance = math.max(0, distance - step_size)
            local waypoint = player_pos + direction * safe_distance

            print(string.format("[HybridPathfinding] Target is in fog, navigating to fog edge at distance %.1f", safe_distance))
            return waypoint
        end
    end

    -- 整条路径都已探索，可以直接前往目标
    return target_pos
end

-- 开始混合寻路
-- @param x, y, z: 目标世界坐标
-- @param options: 选项表 {avoid_hostiles, auto_explore_fog, avoid_spider_dens, arrival_distance}
--                 所有选项默认开启（nil时），可以显式设置为false来关闭
function HybridPathfinding.Start(x, y, z, options)
    options = options or {}

    -- 解析选项（所有选项默认开启）
    local avoid_hostiles = options.avoid_hostiles ~= false  -- 默认 true
    local auto_explore_fog = options.auto_explore_fog ~= false  -- 默认 true
    local avoid_spider_dens = options.avoid_spider_dens ~= false  -- 默认 true
    local arrival_dist = options.arrival_distance or 0.5

    local player = G.ThePlayer
    if not player or not player:IsValid() then
        print("[HybridPathfinding] Error: Player not found")
        return false
    end

    local map = G.TheWorld.Map
    if not map then
        print("[HybridPathfinding] Error: Map not found")
        return false
    end

    local player_pos = G.Vector3(player.Transform:GetWorldPosition())
    local target_pos = G.Vector3(x, y, z)

    -- 检查目标是否在迷雾中
    if IsPositionInFog(x, y, z) then
        if auto_explore_fog then
            -- 自动探索迷雾：调整目标到迷雾边缘
            print("[HybridPathfinding] Warning: Target is in fog, auto-exploring to fog edge")
            target_pos = FindPathToFoggedTarget(player_pos, target_pos)
            print(string.format("[HybridPathfinding] Adjusted target to: (%.1f, %.1f, %.1f)",
                target_pos.x, target_pos.y, target_pos.z))
        else
            -- 不允许探索迷雾
            print("[HybridPathfinding] Error: Target is in unexplored area (fog)")
            print("[HybridPathfinding] Hint: Use {auto_explore_fog=true} to enable fog exploration")
            return false
        end
    end

    -- 检查调整后的目标是否可行走（只对非迷雾区域检查）
    if not IsPositionInFog(target_pos.x, target_pos.y, target_pos.z) then
        if not map:IsPassableAtPoint(target_pos.x, target_pos.y, target_pos.z) then
            print("[HybridPathfinding] Error: Target is not passable (water/invalid terrain)")
            return false
        end
    end

    -- 阶段1：预先规划关键路径点
    local key_points = PlanKeyPointsWithBidirectionalCoastline(player_pos, target_pos, map)

    if not key_points or #key_points == 0 then
        print("[HybridPathfinding] Error: Failed to plan path, no route found")
        return false
    end

    -- 初始化状态
    STATE.active = true
    STATE.final_target = target_pos
    STATE.key_points = key_points
    STATE.current_key_point_index = 1
    STATE.current_waypoint = nil
    STATE.avoid_hostiles = avoid_hostiles
    STATE.avoid_spider_dens = avoid_spider_dens
    STATE.arrival_distance = arrival_dist
    STATE.time_since_check = 0
    STATE.stuck_time = 0
    STATE.last_position = player_pos

    local distance = (target_pos - player_pos):Length()
    print(string.format("[HybridPathfinding] Starting hybrid pathfinding"))
    print(string.format("  Target: (%.1f, %.1f, %.1f), distance: %.1f", x, y, z, distance))
    print(string.format("  Key points: %d, avoid hostiles: %s, auto_explore_fog: %s, avoid_spider_dens: %s",
        #key_points, tostring(avoid_hostiles), tostring(auto_explore_fog), tostring(avoid_spider_dens)))

    -- 绘制调试路径
    DrawDebugPath(key_points, player_pos)

    -- 立即执行第一次移动
    DoMove(player)

    return true
end

-- 停止寻路
function HybridPathfinding.Stop()
    if not STATE.active then
        return
    end

    print("[HybridPathfinding] Stopped")
    STATE.active = false
    STATE.final_target = nil
    STATE.key_points = {}
    STATE.current_key_point_index = 1
    STATE.current_waypoint = nil

    local player = G.ThePlayer
    if player and player:IsValid() and player.components.locomotor then
        player.components.locomotor:Stop()
    end
end

-- 检查是否正在寻路
function HybridPathfinding.IsActive()
    return STATE.active
end

-- 获取距离目标的距离
function HybridPathfinding.GetDistanceToTarget()
    if not STATE.active or not STATE.final_target then
        return nil
    end

    local player = G.ThePlayer
    if not player or not player:IsValid() then
        return nil
    end

    local player_pos = G.Vector3(player.Transform:GetWorldPosition())
    return (STATE.final_target - player_pos):Length()
end

-- 获取当前关键点路径（用于调试可视化）
function HybridPathfinding.GetKeyPoints()
    return STATE.key_points
end

-- 设置是否显示调试路径
function HybridPathfinding.SetDebugPath(enabled)
    CONFIG.show_debug_path = enabled
    print(string.format("[HybridPathfinding] Debug path visualization %s", enabled and "enabled" or "disabled"))
end

-- 获取调试路径状态
function HybridPathfinding.IsDebugPathEnabled()
    return CONFIG.show_debug_path
end

return HybridPathfinding
