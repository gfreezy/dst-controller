-- ============================================================================
-- DST UpdateControllerTargets Implementation
-- ============================================================================
-- This file contains the DST implementation of controller target selection.
-- You can modify the behavior here to customize target selection.
-- Original source: scripts-raw/components/playercontroller.lua
-- ============================================================================

local G = require("dst-controller/global")
local Helpers = require("dst-controller/utils/helpers")
local ConfigManager = require("dst-controller/utils/config_manager")
local TargetPolicy = require("dst-controller/target-selection/policy")

local TargetSelection = {}

-- ============================================================================
-- Constants
-- ============================================================================

-- Attack angle mode constants
local ATTACK_ANGLE_MODE = {
    FORWARD_ONLY = "forward_only",  -- 只能选择前方目标（原版行为）
    ALL_AROUND = "all_around",      -- 可以选择360度任意方向的目标
}

-- Interaction angle mode constants
local INTERACTION_ANGLE_MODE = {
    FORWARD_ONLY = "forward_only",  -- 只能选择前方交互目标（原版行为）
    ALL_AROUND = "all_around",      -- 可以选择360度任意方向的交互目标
}

-- Force attack mode constants
local FORCE_ATTACK_MODE = {
    HOSTILE_ONLY = "hostile_only",  -- 只能攻击敌对生物
    FORCE_ATTACK = "force_attack",  -- 可以攻击所有目标，包括盟友（原版行为）
}

local TARGET_EXCLUDE_TAGS = { "FX", "NOCLICK", "DECOR", "INLIMBO", "stealth" }
local REGISTERED_CONTROLLER_ATTACK_TARGET_TAGS = nil  -- Will be initialized on first use
local CATCHABLE_TAGS = { "catchable" }

-- Lazy initialization of registered tags (called on first use)
local function GetRegisteredAttackTargetTags()
    if REGISTERED_CONTROLLER_ATTACK_TARGET_TAGS == nil then
        REGISTERED_CONTROLLER_ATTACK_TARGET_TAGS = G.TheSim:RegisterFindTags({ "_combat" }, TARGET_EXCLUDE_TAGS)
    end
    return REGISTERED_CONTROLLER_ATTACK_TARGET_TAGS
end

-- ============================================================================
-- Module Configuration
-- ============================================================================

-- Get current configuration from ConfigManager
local function GetConfig()
    local settings = ConfigManager.GetRuntimeSettings()
    return {
        attack_angle_mode = settings.attack_angle_mode or ATTACK_ANGLE_MODE.ALL_AROUND,
        interaction_angle_mode = settings.interaction_angle_mode or INTERACTION_ANGLE_MODE.ALL_AROUND,
        force_attack_mode = settings.force_attack_mode or FORCE_ATTACK_MODE.HOSTILE_ONLY,
    }
end

-- ============================================================================
-- Helper Functions
-- ============================================================================

local function CheckControllerPriorityTagOrOverride(target, tag, override)
	if override ~= nil then
		return G.FunctionOrValue(override)
	end
	return target:HasTag(tag)
end

-- Check if a target is hostile
-- 检查目标是否敌对
local function IsHostileTarget(target, player)
    if not target then return false end

    -- Check if target is actively targeting the player
    -- 检查目标是否正在攻击玩家
    if target.replica.combat then
        local target_target = target.replica.combat:GetTarget()
        if target_target == player then
            return true
        end
    end

    -- Check if target has hostile tag
    -- 检查目标是否有敌对标签
    if target:HasTag("hostile") or target:HasTag("monster") then
        return true
    end

    return false
end

local function ClearItemUseTarget(controller)
    controller.controller_item_use_target = nil
    controller.controller_item_use_target_pending = nil
    controller.controller_item_use_target_age = 0
    controller.controller_item_use_scan_age = 0
    controller.controller_item_use_source = nil
end

local function ClearSecondaryInteractionTargets(controller)
    controller.controller_alternative_target = nil
    controller.controller_alternative_target_pending = nil
    controller.controller_alternative_target_age = 0
    controller.controller_examine_target = nil
    controller.controller_examine_target_pending = nil
    controller.controller_examine_target_age = 0
    ClearItemUseTarget(controller)
end

-- ============================================================================
-- UpdateControllerAttackTarget - 更新控制器攻击目标
-- ============================================================================
-- 功能：查找并更新 controller_attack_target（用于战斗/X按钮）
-- 这是手柄X按钮攻击时使用的目标
--
-- 主要行为：
-- 1. 在攻击范围内查找带有 _combat 标签的实体
-- 2. 基于以下因素对目标评分：
--    - 方向（与面向方向的点积）
--    - 距离（反平方衰减）
--    - 敌人类型（epic=5x > monster=4x > normal=1x，盟友=0.25x）
--    - 正在攻击玩家（6x倍率）
--    - 首选目标（按住攻击键时=10x倍率）
-- 3. 支持目标锁定功能
-- 4. 盟友攻击冷却，防止误伤
--
-- 参数：
--   self: PlayerController 实例
--   dt: 增量时间
--   x, y, z: 玩家世界坐标
--   dirx, dirz: 玩家面向方向向量
-- ============================================================================

local function UpdateControllerAttackTarget(self, dt, x, y, z, dirx, dirz)
    -- 获取当前配置
    local CONFIG = GetConfig()

    -- ========== 第一步：检查是否可以进行目标选择 ==========
	local inventory = self.inst.replica.inventory
	-- 搬重物、拿着漂浮物、或者是幽灵时，不能选择攻击目标
	if inventory:IsHeavyLifting() or inventory:IsFloaterHeld() or self.inst:HasTag("playerghost") then
        self.controller_attack_target = nil
        self.controller_attack_target_ally_cd = nil
		self.controller_targeting_lock_target = false  -- 禁用目标锁定
        return
    end

    local combat = self.inst.replica.combat

    -- ========== 第二步：更新盟友攻击冷却 ==========
    -- 盟友攻击冷却时间递减，防止玩家误伤队友
    self.controller_attack_target_ally_cd = math.max(0, (self.controller_attack_target_ally_cd or 1) - dt)

    -- ========== 第三步：验证当前目标是否仍然有效 ==========
    if self.controller_attack_target ~= nil and
        not (combat:CanTarget(self.controller_attack_target) and
            G.CanEntitySeeTarget(self.inst, self.controller_attack_target)) then
        self.controller_attack_target = nil
		self.controller_targeting_lock_target = false  -- 目标失效，禁用锁定
    end

    -- 注：目标闪烁防护已禁用（原代码注释掉了）
    --self.controller_attack_target_age = self.controller_attack_target_age + dt
    --if self.controller_attack_target_age < .3 then
    --    return  -- 防止目标闪烁
    --end

    -- ========== 第四步：计算搜索范围 ==========
	local equipped_item = inventory:GetEquippedItem(G.EQUIPSLOTS.HANDS)
    local forced_rad = equipped_item ~= nil and equipped_item.controller_use_attack_distance or 0

	local min_rad = 3  -- 最小搜索半径
	local max_rad = math.max(forced_rad, combat:GetAttackRangeWithWeapon()) + 3.5  -- 最大搜索半径
    local max_rad_sq = max_rad * max_rad

    -- ========== 第五步：查找附近的战斗实体 ==========
    -- 使用注册的查找，查找所有带 "_combat" 标签的实体（见 entity_replica.lua）
	local nearby_ents = G.TheSim:FindEntities_Registered(x, y, z, max_rad + 3, GetRegisteredAttackTargetTags())
    if self.controller_attack_target ~= nil then
        -- 如果已经有目标，把它插到列表最前面，确保只处理一次
        table.insert(nearby_ents, 1, self.controller_attack_target)
    end

    -- ========== 第六步：初始化评分变量 ==========
    local target = nil           -- 最佳目标
    local target_score = 0       -- 最高分数
    local target_isally = true   -- 最佳目标是否是盟友

    -- 首选目标：按住攻击键时使用当前目标，否则使用combat目标
    local preferred_target =
        G.TheInput:IsControlPressed(G.CONTROL_CONTROLLER_ATTACK) and
        self.controller_attack_target or
        combat:GetTarget() or
        nil

    -- ========== 第七步：遍历所有附近实体，计算评分 ==========
	local current_controller_targeting_targets = {}  -- 当前帧的所有可选目标列表
	local selected_target_index = 0                  -- 选中目标在列表中的索引

    for i, v in ipairs(nearby_ents) do
        -- 跳过自己，跳过重复的当前目标（除了我们插入的第一个）
        if v ~= self.inst and (v ~= self.controller_attack_target or i == 1) then
            local isally = combat:IsAlly(v)

            -- 跳过：盟友 且 在冷却中 且 不是首选目标
            -- 跳过：不可攻击的目标
            if not (isally and
                    self.controller_attack_target_ally_cd > 0 and
                    v ~= preferred_target) and
                combat:CanTarget(v) then

                -- 获取目标位置和距离（包含Y轴）
                local x1, y1, z1 = v.Transform:GetWorldPosition()
                local dx, dy, dz = x1 - x, y1 - y, z1 - z
                local dsq = dx * dx + dy * dy + dz * dz

				-- 获取物理半径，用于距离检查
				local phys_rad = v:GetPhysicsRadius(0)
				local max_range = max_rad + phys_rad

				-- 检查：在范围内 且 可见
				if dsq < max_range * max_range and G.CanEntitySeePoint(self.inst, x1, y1, z1) then
                    local dist = dsq > 0 and math.sqrt(dsq) or 0
                    local dot = dist > 0 and dx / dist * dirx + dz / dist * dirz or 0

                    -- ===== 角度检查（可配置） =====
                    -- ATTACK_ANGLE_MODE.FORWARD_ONLY: 只能选择前方目标 (dot > 0) 或非常近的目标
                    -- ATTACK_ANGLE_MODE.ALL_AROUND: 可以选择360度任意方向的目标
                    local angle_check = true
                    if CONFIG.attack_angle_mode == ATTACK_ANGLE_MODE.FORWARD_ONLY then
                        -- 原版行为：在玩家前方(dot>0) 或 非常近(dist<min_rad)
                        angle_check = dot > 0 or dist < min_rad + phys_rad
                    else
                        -- 360度模式：忽略角度限制，任何方向都可以
                        angle_check = true
                    end

					if angle_check then
						-- 减去物理半径后计算实际距离
						dist = math.max(0, dist - phys_rad)

						-- ===== 核心评分公式 =====
						-- 基础分数 = 方向分量 + 常数(1) - 距离惩罚
						-- 方向分量：dot ∈ [-1, 1]，面向目标时为1
						-- 距离惩罚：0.5 * (dist/max_rad)^2，距离越远惩罚越大
						local score = dot + 1 - 0.5 * dist * dist / max_rad_sq

                        -- ===== 敌人类型加权 =====
                        if isally and not v.controller_priority_override_is_ally then
                            score = score * 0.25  -- 盟友：0.25x（很低优先级）
						elseif CheckControllerPriorityTagOrOverride(v, "epic", v.controller_priority_override_is_epic) then
                            score = score * 5     -- Epic Boss：5x
						elseif CheckControllerPriorityTagOrOverride(v, "monster", v.controller_priority_override_is_monster) then
                            score = score * 4     -- 怪物：4x
						end
                        -- 普通敌人：1x（不改变score）

                        -- ===== 特殊情况加权 =====
						if v.replica.combat:GetTarget() == self.inst or FunctionOrValue(v.controller_priority_override_is_targeting_player) then
                            score = score * 6     -- 正在攻击玩家：6x（高优先级）
                        end

                        if v == preferred_target then
                            score = score * 10    -- 首选目标（按住攻击键）：10x（最高优先级）
                        end

                        -- ===== 敌对目标过滤（可配置） =====
                        -- FORCE_ATTACK_MODE.HOSTILE_ONLY: 只能攻击敌对生物
                        -- FORCE_ATTACK_MODE.FORCE_ATTACK: 可以攻击所有目标（原版行为）
                        -- 特殊：按下 LB 时，可以攻击所有目标
                        local can_attack = true
                        if CONFIG.force_attack_mode == FORCE_ATTACK_MODE.HOSTILE_ONLY and not Helpers.IsButtonPressed("LB") then
                            -- 仅敌对模式：必须是敌对目标才能攻击（除非按下 LB）
                            can_attack = IsHostileTarget(v, self.inst)
                        end
                        -- 强制攻击模式 或 按下 LB：can_attack 保持 true

                        if can_attack then
                            -- ===== 添加到可选目标列表 =====
						    table.insert(current_controller_targeting_targets, v)

                            -- 更新最佳目标
                            if score > target_score then
							    selected_target_index = #current_controller_targeting_targets
                                target = v
                                target_score = score
                                target_isally = isally
                            end
                        end
                    end
                end
            end
        end
    end

    -- ========== 第八步：处理目标锁定模式 ==========
	if self.controller_attack_target ~= nil and self.controller_targeting_lock_target then
		-- 如果启用了目标锁定，只更新可选目标列表，不改变当前锁定的目标

		-- 移除已经消失的目标
		for idx_outer = #self.controller_targeting_targets, 1, -1 do
			local found = false
			local existing_target = self.controller_targeting_targets[idx_outer]
			for idx_inner = #current_controller_targeting_targets, 1, -1 do
				if existing_target == current_controller_targeting_targets[idx_inner] then
					-- 找到了，从当前列表中移除（避免重复添加）
					table.remove(current_controller_targeting_targets, idx_inner)
					found = true
					break
				end
			end

			-- 如果旧目标不在新列表中，说明它消失了，移除
			if not found then
				table.remove(self.controller_targeting_targets, idx_outer)
			end
		end

		-- 添加新出现的目标
		for i, v in ipairs(current_controller_targeting_targets) do
			table.insert(self.controller_targeting_targets, v)
		end

		-- 目标锁定模式下，直接返回，不更新 controller_attack_target
		return
	end

    -- ========== 第九步：特殊情况处理 ==========
    -- 礼物机和墙的优先级处理
    if self.controller_target ~= nil and self.controller_target:IsValid() then
        if target ~= nil then
            if target:HasTag("wall") and
                self.classified ~= nil and
                self.classified.hasgift:value() and
                self.classified.hasgiftmachine:value() and
                self.controller_target:HasTag("giftmachine") then
                -- 如果礼物机有Y按钮优先级，那么它也应该有X按钮优先级（高于墙）
                target = nil
                target_isally = true
            end
        elseif self.controller_target:HasTag("wall") and not G.IsEntityDead(self.controller_target, true) then
            -- 如果没有X按钮目标，但Y按钮目标是墙，把墙给X按钮
            target = self.controller_target
            target_isally = false
        end
    end

    -- ========== 第十步：更新最终目标 ==========
    if target ~= self.controller_attack_target then
        self.controller_attack_target = target
		self.controller_targeting_target_index = selected_target_index
    end

    -- 重置盟友攻击冷却（当攻击非盟友时）
    if not target_isally then
        self.controller_attack_target_ally_cd = nil
    end
end

-- ============================================================================
-- UpdateControllerInteractionTarget - 更新控制器交互目标
-- ============================================================================
-- 功能：查找并更新 controller_target（用于交互/A按钮）
-- 这是手柄A按钮主要交互使用的目标
--
-- 主要行为：
-- 1. 如果启用目标锁定，X和Y按钮使用同一个目标
-- 2. 有0.2秒冷却，防止目标闪烁
-- 3. 特殊处理：
--    - 捕捉模式 (cancatch tag)
--    - 钓鱼竿 (fishingrod tag)
--    - 带有 controller_should_use_attack_target 标志的物品
-- 4. 基于以下因素对目标评分：
--    - 角度检查 (anglemax，船上和陆地不同)
--    - 距离（反平方）
--    - 迟滞效应（当前目标1.5x）
--    - 掉落物品近距离奖励
-- 5. 只目标有有效动作或可检查的实体
-- 6. 同时查找 controller_alternative_target（副动作目标，B按钮）
--
-- 参数：
--   self: PlayerController 实例
--   dt: 增量时间
--   x, y, z: 玩家世界坐标
--   dirx, dirz: 玩家面向方向向量
--   heading_angle: 玩家朝向角度
-- ============================================================================

local function UpdateControllerInteractionTarget(self, dt, x, y, z, dirx, dirz, heading_angle)
    -- 获取当前配置
    local CONFIG = GetConfig()

    -- ========== 第一步：特殊状态检查 ==========

    -- 如果启用了目标锁定，交互目标和攻击目标相同
	local attack_target = self:GetControllerAttackTarget()
	if self.controller_targeting_lock_target and attack_target then
		self.controller_target = attack_target
		self.controller_target_has_rmb = false
		ClearSecondaryInteractionTargets(self)
		return
	end

    -- 如果正在放置物品或使用魔法师工具，清除交互目标
	if self.placer ~= nil or (self.deployplacer ~= nil and self.deploy_mode) or self.inst:HasTag("usingmagiciantool") then
        self.controller_target = nil
        self.controller_target_age = 0
        self.controller_target_has_rmb = false
        ClearSecondaryInteractionTargets(self)
        return
    end

    -- 验证当前目标是否仍然有效
    if self.controller_target ~= nil
        and (not self.controller_target:IsValid() or
            self.controller_target:HasTag("INLIMBO") or
            self.controller_target:HasTag("NOCLICK") or
            not G.CanEntitySeeTarget(self.inst, self.controller_target)) then
        -- "FX" 和 "DECOR" 标签永远不会改变，可以安全跳过检查
        self.controller_target = nil
        self.controller_target_has_rmb = false
        -- 目标失效，但不重置 age（保留闪烁防护）
    end

    -- 光标物品改变代表玩家切换了操作意图。立即清空旧物品目标，
    -- 让新物品的第一个“对场景使用”按键可以直接命中正确目标。
    local cursor_item = self:GetCursorInventoryObject()
    local cursor_item_changed = cursor_item ~= self.controller_item_use_source
    if cursor_item_changed then
        self.controller_item_use_source = cursor_item
        self.controller_item_use_target = nil
        self.controller_item_use_target_pending = nil
        self.controller_item_use_target_age = 0
        self.controller_item_use_scan_age = TargetPolicy.ITEM_USE_TARGET_SCAN_INTERVAL
    end

    -- 主目标仍保留原来的防闪烁冷却，但不能让它阻塞副目标、检查目标
    -- 和光标物品目标的更新。
    self.controller_target_age = (self.controller_target_age or math.huge) + dt
    local can_update_primary_target = self.controller_target_age >= 0.2 or cursor_item_changed

    -- 物品动作查询开销较大，独立限制为 10Hz。实际按键时还会重新解析，
    -- 因此这里只缓存候选，不缓存最终动作。
    local item_use_scan_dt = 0
    local should_scan_item_use = false
    if cursor_item ~= nil then
        self.controller_item_use_scan_age = (self.controller_item_use_scan_age or TargetPolicy.ITEM_USE_TARGET_SCAN_INTERVAL) + dt
        if self.controller_item_use_scan_age >= TargetPolicy.ITEM_USE_TARGET_SCAN_INTERVAL then
            should_scan_item_use = true
            item_use_scan_dt = self.controller_item_use_scan_age
            self.controller_item_use_scan_age = 0
        end
    elseif self.controller_item_use_target ~= nil then
        ClearItemUseTarget(self)
    end

    -- ========== 第三步：特殊模式检查 ==========

    -- 捕捉模式（玩家有 cancatch 标签时）
    if self.inst:HasTag("cancatch") then
        local target = G.FindEntity(self.inst, 10, nil, CATCHABLE_TAGS, TARGET_EXCLUDE_TAGS)
        if G.CanEntitySeeTarget(self.inst, target) then
            if target ~= self.controller_target then
                self.controller_target = target
                self.controller_target_age = 0
            end
            self.controller_target_has_rmb = false
            ClearSecondaryInteractionTargets(self)
            return
        end
    end

    -- 检查手持物品
    local equiped_item = self.inst.replica.inventory:GetEquippedItem(G.EQUIPSLOTS.HANDS)

    -- 某些物品强制使用攻击目标作为交互目标
    if equiped_item and equiped_item.controller_should_use_attack_target and self.controller_attack_target ~= nil then
        if self.controller_target ~= self.controller_attack_target then
            self.controller_target = self.controller_attack_target
            self.controller_target_age = 0
        end
        self.controller_target_has_rmb = false
        ClearSecondaryInteractionTargets(self)
        return
    end

    -- ========== 第四步：初始化搜索参数 ==========

    -- 钓鱼模式：钓鱼目标通常有较大半径，需要特殊处理
    local fishing = equiped_item ~= nil and equiped_item:HasTag("fishingrod")

    -- 排除玩家自己的鱼钩（其他人的鱼钩可以被选中）
    local ocean_fishing_target = (equiped_item ~= nil and equiped_item.replica.oceanfishingrod ~= nil) and equiped_item.replica.oceanfishingrod:GetTarget() or nil

    -- 搜索范围设置
    local min_rad = 1.5  -- 最小搜索半径
    local max_rad = 8    -- 最大搜索半径
    local min_rad_sq = min_rad * min_rad
    local max_rad_sq = max_rad * max_rad

    -- 动态搜索半径（如果已有目标，使用其距离；否则使用最大半径）
    local rad =
            self.controller_target ~= nil and
            math.max(min_rad, math.min(max_rad, math.sqrt(self.inst:GetDistanceSqToInst(self.controller_target)))) or
            max_rad
    local rad_sq = rad * rad + 0.1  -- 允许小误差

    -- ========== 第五步：查找附近实体 ==========
    -- 仅在物品扫描到期时扩展到完整范围；其余帧维持原场景搜索半径。
    local search_rad = (fishing or should_scan_item_use) and max_rad or rad
    local nearby_ents = G.TheSim:FindEntities(x, y, z, search_rad, nil, TARGET_EXCLUDE_TAGS)
    if self.controller_target ~= nil then
        -- 如果已有目标，插到列表最前面，确保只处理一次
        table.insert(nearby_ents, 1, self.controller_target)
    end

    -- ========== 第六步：初始化评分变量 ==========
    local target = nil
    local target_score = 0
    local target_has_rmb = false  -- 记录主目标是否有副动作
    local alternative_target = nil
    local alternative_target_score = 0
    local item_use_target = nil
    local item_use_target_score = 0
    local inspect_target = nil
    local inspect_target_score = 0

    -- 判断是否可以检查物品（需要满足多个条件）
    local canexamine = (self.inst.CanExamine == nil or self.inst:CanExamine())
			and (not self.inst.HUD:IsPlayerAvatarPopUpOpen())
			and (self.inst.sg == nil or self.inst.sg:HasStateTag("moving") or self.inst.sg:HasStateTag("idle") or self.inst.sg:HasStateTag("channeling"))
			and (self.inst:HasTag("moving") or self.inst:HasTag("idle") or self.inst:HasTag("channeling"))

    -- 角度限制：船上和陆地不同
    local currentboat = self.inst:GetCurrentPlatform()
    local anglemax = currentboat and G.TUNING.CONTROLLER_BOATINTERACT_ANGLE or G.TUNING.CONTROLLER_INTERACT_ANGLE

    -- ========== 第七步：遍历所有附近实体，计算评分 ==========
    for i, v in ipairs(nearby_ents) do
		v = v.client_forward_target or v  -- 处理客户端转发目标

        -- 跳过自己的鱼钩
        if v ~= ocean_fishing_target then

            -- 跳过自己，跳过重复的当前目标（除了我们插入的第一个）
            if v ~= self.inst and (v ~= self.controller_target or i == 1) and v.entity:IsVisible() then
                -- 特殊处理：打包或建造中的物品
                if v.entity:GetParent() == self.inst and v:HasTag("bundle") then
                    target = v
                    break
                end

                -- 计算距离（先忽略Y轴）
                local x1, y1, z1 = v.Transform:GetWorldPosition()
                local dx, dy, dz = x1 - x, y1 - y, z1 - z
                local dsq = dx * dx + dz * dz  -- 先不计入Y轴

                -- 钓鱼特殊处理：如果在鱼点半径内，距离视为0
                if fishing and v:HasTag("fishable") then
                    local r = v:GetPhysicsRadius(0)
                    if dsq <= r * r then
                        dsq = 0
                    end
                end

                -- 距离和方向过滤
                local in_range = false
                if dsq < min_rad_sq then
                    -- 非常近的目标：总是在范围内
                    in_range = true
                elseif dsq <= rad_sq then
                    -- 在搜索半径内：需要进一步检查
                    if v == self.controller_target or v == self.controller_attack_target then
                        -- 是当前目标或攻击目标：总是在范围内
                        in_range = true
                    elseif CONFIG.interaction_angle_mode == INTERACTION_ANGLE_MODE.ALL_AROUND then
                        -- 360度模式：所有方向都在范围内
                        in_range = true
                    else
                        -- 前方模式：必须在前方
                        in_range = (dx * dirx + dz * dirz > 0)
                    end
                end

                -- 物品使用目标拥有独立搜索范围，不受当前主目标的动态半径限制。
                local in_item_use_range = should_scan_item_use and dsq <= max_rad_sq

                if (in_range or in_item_use_range) and G.CanEntitySeePoint(self.inst, x1, y1, z1) then  -- 在范围内且可见

                    -- 角度检查（可配置）
                    local shouldcheck = dsq < 1  -- 距离<1的目标直接通过
                    if not shouldcheck then
                        if CONFIG.interaction_angle_mode == INTERACTION_ANGLE_MODE.ALL_AROUND then
                            -- 360度模式：所有方向都可以检查
                            shouldcheck = true
                        else
                            -- 前方模式：只检查角度限制内的目标（原版行为）
                            local epos = v:GetPosition()
                            local angletoepos = self.inst:GetAngleToPoint(epos)
                            local angleto = math.abs(G.anglediff(-heading_angle, angletoepos))
                            shouldcheck = angleto < anglemax  -- 在角度限制内
                        end
                    end

                    if shouldcheck then
                        -- 现在加入Y轴分量（用作平局决胜）
                        dsq = dsq + (dy * dy)

                        local dist = dsq > 0 and math.sqrt(dsq) or 0
                        local dot = dist > 0 and dx / dist * dirx + dz / dist * dirz or 0

                        -- ===== 核心评分公式 =====
                        -- 角度分量：归一化到 [0..1]
                        local angle_component = (dot + 1) / 2

                        -- 距离分量：近距离为1，远距离反平方衰减
                        local dist_component = dsq < min_rad_sq and 1 or min_rad_sq / dsq

                        -- 近距离奖励（刚掉落的物品）
                        local add = dsq < 0.0625 and 1 or 0  -- 0.25 * 0.25

                        -- 每一类目标只对自己的当前目标应用迟滞，避免主目标影响物品目标。
                        local target_mult = v == self.controller_target and not v:HasTag("wall") and 1.5 or 1
                        local item_use_mult = v == self.controller_item_use_target and not v:HasTag("wall") and 1.5 or 1

                        local score = angle_component * dist_component * target_mult + add
                        local item_use_score = angle_component * dist_component * item_use_mult + add

                        -- ===== 特殊目标加权 =====
                        -- 传送门：活着时优先级降低，幽灵复活模式优先级提高
                        if v:HasTag("portal") then
                            local portal_mult = self.inst:HasTag("playerghost") and G.GetPortalRez() and 1.1 or 0.9
                            score = score * portal_mult
                            item_use_score = item_use_score * portal_mult
                        end

                        -- 家具装饰品：优先级降低
                        if v:HasTag("hasfurnituredecoritem") then
                            score = score * 0.5
                            item_use_score = item_use_score * 0.5
                        end

                        local lmb, rmb
                        if in_range then
                            -- ===== 第一级：场景物品有可用动作 =====
                            -- 检查是否有有效动作（开销较大，尽量少执行）
                            if currentboat ~= v or score * 0.75 < target_score then
                                -- 船上的场景物品优先级降低
                                lmb, rmb = self:GetSceneItemControllerAction(v)
                            end

                            local entity_lmb = TargetPolicy.IsEntityTargetedAction(lmb, v) and lmb or nil
                            local entity_rmb = TargetPolicy.IsEntityTargetedAction(rmb, v) and rmb or nil

                            -- ===== 独立选择主目标（A键）=====
                            if entity_lmb ~= nil then
                                -- 有主动作：候选为主目标
                                -- 检查分数和穿透优先级
                                if score > target_score or
                                    (score == target_score and
                                        not (target ~= nil and target.CanMouseThrough ~= nil and not target:CanMouseThrough()) and
                                        (v.CanMouseThrough == nil or not v:CanMouseThrough())) then
                                    -- 分数更高，或分数相同但优先级更高（不可穿透优先）
                                    target = v
                                    target_score = score
                                    target_has_rmb = entity_rmb ~= nil
                                end
                            end

                            -- ===== 独立选择副目标（B键）=====
                            if entity_rmb ~= nil and entity_lmb == nil then
                                -- 只有副动作：候选为副目标
                                -- 检查分数和穿透优先级
                                if score > alternative_target_score or
                                    (score == alternative_target_score and
                                        not (alternative_target ~= nil and alternative_target.CanMouseThrough ~= nil and not alternative_target:CanMouseThrough()) and
                                        (v.CanMouseThrough == nil or not v:CanMouseThrough())) then
                                    -- 分数更高，或分数相同但优先级更高（不可穿透优先）
                                    alternative_target = v
                                    alternative_target_score = score
                                end
                            end

                            -- ===== 独立选择检查目标（Inspect键）=====
                            -- 只有在 canexamine 为 true 且实体可检查时才候选
                            -- 注意：inspect_target 始终只选择前方目标，不受 interaction_angle_mode 配置影响
                            if canexamine and v:HasTag("inspectable") and entity_lmb == nil and entity_rmb == nil then
                                -- 检查目标必须在前方（点积 > 0）
                                local is_forward = (dx * dirx + dz * dirz > 0)

                                if is_forward then
                                    -- 可以检查且没有其他动作：候选为检查目标
                                    -- 检查分数和穿透优先级
                                    if score > inspect_target_score or
                                        (score == inspect_target_score and
                                            not (inspect_target ~= nil and inspect_target.CanMouseThrough ~= nil and not inspect_target:CanMouseThrough()) and
                                            (v.CanMouseThrough == nil or not v:CanMouseThrough())) then
                                        -- 分数更高，或分数相同但优先级更高（不可穿透优先）
                                        inspect_target = v
                                        inspect_target_score = score
                                    end
                                end
                            end
                        end

                        -- ===== 独立选择光标物品使用目标 =====
                        -- 无论该位置是否已有主/副场景动作，都继续检查物品动作。
                        if in_item_use_range then
                            local item_action = self:GetItemUseAction(cursor_item, v)
                            if TargetPolicy.IsEntityTargetedAction(item_action, v) then
                                if item_use_score > item_use_target_score or
                                    (item_use_score == item_use_target_score and
                                        not (item_use_target ~= nil and item_use_target.CanMouseThrough ~= nil and not item_use_target:CanMouseThrough()) and
                                        (v.CanMouseThrough == nil or not v:CanMouseThrough())) then
                                    item_use_target = v
                                    item_use_target_score = item_use_score
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- ========== 第八步：更新最终目标 ==========
    if target == self.controller_target then
        self.controller_target_has_rmb = target_has_rmb
    elseif can_update_primary_target then
        self.controller_target = target
        self.controller_target_has_rmb = target_has_rmb
        self.controller_target_age = 0  -- 重置age，开始新的闪烁防护
    end

    -- ========== 第九步：更新光标物品使用目标 ==========
    if should_scan_item_use then
        TargetPolicy.UpdateStableSecondaryTarget(
            self,
            "controller_item_use_target",
            "controller_item_use_target_pending",
            "controller_item_use_target_age",
            item_use_target,
            item_use_scan_dt
        )
    end

    -- ========== 第十步：更新副目标 ==========
    -- 注意：这里需要直接使用局部变量 alternative_target 和 target_has_rmb
    -- 副目标独立于主目标存在，但如果主目标已经支持副动作，则不需要副目标

    if self.controller_target_has_rmb then
        alternative_target = nil
    end
    TargetPolicy.UpdateStableSecondaryTarget(
        self,
        "controller_alternative_target",
        "controller_alternative_target_pending",
        "controller_alternative_target_age",
        alternative_target,
        dt
    )

    -- ========== 第十一步：更新检查目标 ==========
    -- 检查目标规则：
    -- 1. 如果主目标或副目标可以被检查（有inspectable tag），则清除检查目标
    -- 2. 否则，使用找到的检查目标
    local target_can_inspect = self.controller_target ~= nil and self.controller_target:HasTag("inspectable")
    local alt_target_can_inspect = self.controller_alternative_target ~= nil and self.controller_alternative_target:HasTag("inspectable")

    if target_can_inspect or alt_target_can_inspect then
        inspect_target = nil
    end
    TargetPolicy.UpdateStableSecondaryTarget(
        self,
        "controller_examine_target",
        "controller_examine_target_pending",
        "controller_examine_target_age",
        inspect_target,
        dt
    )
end

-- ============================================================================
-- UpdateControllerConflictingTargets
-- ============================================================================
-- Resolves conflicts when both controller_target and controller_attack_target
-- are set and point to different entities that should have priority rules
--
-- Current special cases:
-- 1. Merm throne + Merm: Merm takes priority
-- 2. Two crab king claws: Closest one takes priority
-- ============================================================================

local function UpdateControllerConflictingTargets(self)
    local target, attacktarget = self.controller_target, self.controller_attack_target
    if target == nil or attacktarget == nil then
        return
    end
        -- NOTES(JBK): This is for handling when there are two targets on a controller but one should take super priority over the other.
        -- Most of this will be workarounds in appearance as there are no sure fire ways to guarantee what two entities should be prioritized by actions alone as they need additional context.
        if target ~= attacktarget then
            if target:HasTag("mermthrone") and attacktarget:HasTag("merm") then
                -- Inspecting a throne but could interact with a Merm, Merm takes priority.
                target = attacktarget
                self.controller_target_age = 0
            elseif target:HasTag("crabking_claw") and attacktarget:HasTag("crabking_claw") then
                -- Two claws let us try targeting the closest one because it will most likely be the one next to a boat.
                if self.inst:GetDistanceSqToInst(target) < self.inst:GetDistanceSqToInst(attacktarget) then
                    attacktarget = target
                else
                    target = attacktarget
                    self.controller_target_age = 0
                end
            end
    end

    self.controller_target, self.controller_attack_target = target, attacktarget
end

-- ============================================================================
-- Main UpdateControllerTargets Function
-- ============================================================================
-- Called every frame to update controller targeting
--
-- Flow:
-- 1. Early exit if in special states (AOE targeting, sitting, weregoose, gym)
-- 2. Calculate player position and facing direction
-- 3. Update interaction target (Y button)
-- 4. Update attack target (X button)
-- 5. Resolve any conflicts between the two targets
-- ============================================================================

function TargetSelection.UpdateControllerTargets(controller, dt)
	if controller:IsAOETargeting() or
		controller.inst:HasTag("sitting_on_chair") or
		(controller.inst:HasTag("weregoose") and not controller.inst:HasTag("playerghost")) or
		(controller.classified and controller.classified.inmightygym:value() > 0) then
		controller.controller_target = nil
		controller.controller_target_age = 0
		controller.controller_target_has_rmb = false
		ClearSecondaryInteractionTargets(controller)
        controller.controller_attack_target = nil
        controller.controller_attack_target_ally_cd = nil
        controller.controller_targeting_lock_target = nil
        return
    end
    local x, y, z = controller.inst.Transform:GetWorldPosition()
    local heading_angle = -controller.inst.Transform:GetRotation()
    local dirx = math.cos(heading_angle * G.DEGREES)
    local dirz = math.sin(heading_angle * G.DEGREES)
    UpdateControllerInteractionTarget(controller, dt, x, y, z, dirx, dirz, heading_angle)
    UpdateControllerAttackTarget(controller, dt, x, y, z, dirx, dirz)
    UpdateControllerConflictingTargets(controller)
end

return TargetSelection
