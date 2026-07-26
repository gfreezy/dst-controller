-- Enhanced Controller - Automatic crafting transaction coordinator

local G = require("dst-controller/global")
local Policy = require("dst-controller/crafting/policy")
local ContainerCache = require("dst-controller/crafting/container-cache")
local Finder = require("dst-controller/crafting/material-finder")
local Planner = require("dst-controller/crafting/material-planner")

local Coordinator = {}

local active_tasks = {}

local function GetTime()
    return G.GetTime ~= nil and G.GetTime() or os.clock()
end

local function Notify(player, message)
    print("[Enhanced Controller] " .. message)
    local announcer = player and player.HUD and player.HUD.eventannouncer
    if announcer ~= nil and announcer.ShowNewAnnouncement ~= nil then
        announcer:ShowNewAnnouncement(message, { 1, 0.85, 0.35, 1 })
    elseif G.Networking_SystemMessage ~= nil then
        G.Networking_SystemMessage("[Enhanced Controller] " .. message)
    end
end

local function AddCount(counts, prefab, amount)
    counts[prefab] = (counts[prefab] or 0) + amount
end

local function RecordExternalAcquisition(ctx, prefab)
    if Policy.ShouldReturnExternalRemainder(ctx.initial_owned, prefab) then
        ctx.return_prefabs[prefab] = true
    end
end

local function MakePlannerOptions(player, max_stacks)
    local builder = player.replica.builder
    return {
        ingredient_mod = builder:IngredientMod(),
        round = G.RoundBiasedUp or function(value) return math.floor(value + 0.5) end,
        resolve_recipe = function(prefab)
            return G.GetValidRecipe(prefab)
        end,
        can_craft_recipe = function(recipe)
            if recipe == nil or not builder:CanLearn(recipe.name) then
                return false, "NO_CHARACTER"
            end

            for _, ingredient in ipairs(recipe.character_ingredients or {}) do
                if not builder:HasCharacterIngredient(ingredient) then
                    return false, "NO_CHARACTER_INGREDIENT"
                end
            end
            for _, ingredient in ipairs(recipe.tech_ingredients or {}) do
                if not builder:HasTechIngredient(ingredient) then
                    return false, "NO_TECH_INGREDIENT"
                end
            end

            if builder:KnowsRecipe(recipe) then
                return true
            end
            local tech = builder:GetTechTrees()
            if G.CanPrototypeRecipe ~= nil and G.CanPrototypeRecipe(recipe.level, tech) then
                return true
            end
            return false, recipe.nounlock and "NO_STATION" or "NO_TECH"
        end,
        get_yield = function(recipe)
            if recipe.override_numtogive_fn ~= nil then
                local ok, amount = pcall(recipe.override_numtogive_fn, recipe, player)
                if ok and amount ~= nil then
                    return amount
                end
            end
            return recipe.numtogive or 1
        end,
        get_max_stack = function(prefab)
            return max_stacks[prefab] or 40
        end,
    }
end

function Coordinator.CanUseRecipe(player, recipe)
    if player == nil or recipe == nil or player.replica == nil or player.replica.builder == nil then
        return false, "NO_BUILDER"
    end
    return MakePlannerOptions(player, {}).can_craft_recipe(recipe)
end

function Coordinator.BuildPlan(player, recipe, owned, external, max_stacks)
    return Planner.Build(recipe, owned, external, MakePlannerOptions(player, max_stacks or {}))
end

local Task = {}
Task.__index = Task

function Task:OnComplete(callback)
    if self.status ~= "pending" then
        callback(self.status, self.reason)
    else
        table.insert(self.callbacks, callback)
    end
    return self
end

function Task:Cancel(reason)
    Coordinator.Interrupt(self.player, reason or "cancelled")
end

local function RemoveListener(ctx, listener)
    if listener ~= nil and listener.source ~= nil and listener.source.RemoveEventCallback ~= nil then
        listener.source:RemoveEventCallback(listener.event, listener.fn)
    end
end

local function Complete(ctx, status, reason)
    if ctx.task.status ~= "pending" then
        return
    end

    ctx.task.status = status
    ctx.task.pending = false
    ctx.task.reason = reason
    if active_tasks[ctx.player.GUID] == ctx then
        active_tasks[ctx.player.GUID] = nil
    end

    for _, scheduled in ipairs(ctx.scheduled) do
        if scheduled.Cancel ~= nil then
            scheduled:Cancel()
        end
    end
    ctx.scheduled = {}
    for _, listener in ipairs(ctx.listeners) do
        RemoveListener(ctx, listener)
    end
    ctx.listeners = {}

    if status == "success" then
        Notify(ctx.player, "自动建造完成")
    elseif status == "interrupted" then
        -- Stop only the automation-owned in-flight movement/action. Already
        -- moved or crafted items are intentionally left exactly where they are.
        local controller = ctx.player.components and ctx.player.components.playercontroller
        if ctx.player.ClearBufferedAction ~= nil then
            ctx.player:ClearBufferedAction()
        end
        if controller ~= nil and controller.locomotor ~= nil then
            controller.locomotor:SetBufferedAction(nil)
            controller.locomotor:Stop()
        elseif controller ~= nil and controller.RemoteStopWalking ~= nil then
            controller:RemoteStopWalking()
        end
        Notify(ctx.player, "自动建造已中断：" .. tostring(reason or "未知原因"))
    end

    for _, callback in ipairs(ctx.task.callbacks) do
        callback(status, reason)
    end
    ctx.task.callbacks = {}
end

local function Interrupt(ctx, reason)
    if ctx ~= nil and ctx.task.status == "pending" then
        Complete(ctx, "interrupted", reason)
    end
end

function Coordinator.Interrupt(player, reason)
    if player ~= nil then
        Interrupt(active_tasks[player.GUID], reason or "用户操作")
    end
end

function Coordinator.IsActive(player)
    return player ~= nil and active_tasks[player.GUID] ~= nil
end

function Coordinator.OnUserControl(player, control, down)
    if down and Coordinator.IsActive(player) then
        Coordinator.Interrupt(player, "用户接管")
        return true
    end
    return false
end

local function Schedule(ctx, delay, callback)
    if ctx.task.status ~= "pending" or not ctx.player:IsValid() then
        return
    end
    local scheduled
    scheduled = ctx.player:DoTaskInTime(delay, function()
        for index, value in ipairs(ctx.scheduled) do
            if value == scheduled then
                table.remove(ctx.scheduled, index)
                break
            end
        end
        if ctx.task.status == "pending" and ctx.player:IsValid() then
            callback()
        end
    end)
    table.insert(ctx.scheduled, scheduled)
end

local function Listen(ctx, source, event, fn)
    source:ListenForEvent(event, fn)
    local listener = { source = source, event = event, fn = fn }
    table.insert(ctx.listeners, listener)
    return listener
end

local function StopListening(ctx, listener)
    RemoveListener(ctx, listener)
    for index, value in ipairs(ctx.listeners) do
        if value == listener then
            table.remove(ctx.listeners, index)
            break
        end
    end
end

local function WaitUntil(ctx, predicate, timeout, on_success, failure_reason)
    local deadline = GetTime() + timeout
    local function Poll()
        local ok, result = pcall(predicate)
        if ok and result then
            on_success()
        elseif GetTime() >= deadline then
            Interrupt(ctx, failure_reason or "操作超时")
        else
            Schedule(ctx, Policy.POLL_INTERVAL, Poll)
        end
    end
    Poll()
end

local function WaitForBuild(ctx, action, verify, on_success)
    local completed = false
    local listener
    local function Success()
        if completed or ctx.task.status ~= "pending" then
            return
        end
        completed = true
        StopListening(ctx, listener)
        Schedule(ctx, Policy.POLL_INTERVAL, function()
            if verify == nil or verify() then
                on_success()
            else
                Interrupt(ctx, "制作结果未同步")
            end
        end)
    end
    listener = Listen(ctx, ctx.player, "buildsuccess", Success)
    action()
    Schedule(ctx, Policy.BUILD_TIMEOUT, function()
        if not completed then
            completed = true
            StopListening(ctx, listener)
            Interrupt(ctx, "制作超时")
        end
    end)
end

local function DoWorldAction(ctx, target, action)
    local controller = ctx.player.components.playercontroller
    local buffered = G.BufferedAction(ctx.player, target, action)
    if not controller.ismastersim then
        local function SendAction()
            controller:RemoteActionButton(buffered)
        end
        if controller.locomotor == nil then
            buffered.non_preview_cb = SendAction
        else
            buffered.preview_cb = SendAction
        end
    end
    controller:DoAction(buffered)
end

local function AddVerified(ctx, entity)
    if not ctx.verified_set[entity] then
        ctx.verified_set[entity] = true
        table.insert(ctx.verified, entity)
    end
end

local function OpenContainer(ctx, entity, callback)
    if entity == nil or not entity:IsValid() or not Policy.IsStorageContainer(entity, ctx.player) then
        Interrupt(ctx, "容器不可用")
        return
    end

    local container = entity.replica.container
    if container:IsOpenedBy(ctx.player) then
        ContainerCache.Snapshot(entity, ctx.player)
        AddVerified(ctx, entity)
        callback()
        return
    end

    local controller = ctx.player.components.playercontroller
    if controller == nil or controller:IsBusy() then
        WaitUntil(ctx, function()
            return controller ~= nil and not controller:IsBusy()
        end, Policy.ACTION_TIMEOUT, function()
            OpenContainer(ctx, entity, callback)
        end, "无法打开容器")
        return
    end

    DoWorldAction(ctx, entity, G.ACTIONS.RUMMAGE)
    WaitUntil(ctx, function()
        return entity:IsValid() and container:IsOpenedBy(ctx.player)
    end, Policy.ACTION_TIMEOUT, function()
        ContainerCache.Snapshot(entity, ctx.player)
        AddVerified(ctx, entity)
        callback()
    end, "打开容器失败")
end

local function BuildExternalSnapshot(ctx)
    local counts = {}
    local max_stacks = {}

    for _, item in ipairs(ctx.ground_candidates) do
        if Policy.IsGroundCraftingItem(item, ctx.player) then
            AddCount(counts, item.prefab, Finder.GetStackCount(item))
            max_stacks[item.prefab] = math.max(max_stacks[item.prefab] or 1, Finder.GetMaxStack(item))
        end
    end

    for _, entity in ipairs(ctx.verified) do
        local cached = ContainerCache.Get(entity)
        if cached ~= nil then
            for prefab, count in pairs(cached.items or {}) do
                AddCount(counts, prefab, count)
            end
        end
    end
    return counts, max_stacks
end

local ExecutePlan

local function PlanAfterVerification(ctx)
    local external, max_stacks = BuildExternalSnapshot(ctx)
    local owned = Finder.GetPersonalCounts(ctx.player)
    local plan, reason, detail = Coordinator.BuildPlan(ctx.player, ctx.recipe, owned, external, max_stacks)
    if plan ~= nil then
        ctx.plan = plan
        ctx.needed_prefabs = plan.needed_prefabs
        ExecutePlan(ctx, 1)
        return
    end

    ctx.last_plan_reason = reason
    ctx.last_plan_detail = detail
    local missing = detail ~= nil and (tostring(detail.prefab) .. " ×" .. tostring(math.max(0, detail.amount - detail.available))) or tostring(reason)
    Interrupt(ctx, "材料或科技不足（" .. missing .. "）")
end

local function VerifyNextContainer(ctx)
    local entity = ctx.container_candidates[ctx.next_container_index]
    ctx.next_container_index = ctx.next_container_index + 1
    if entity == nil then
        PlanAfterVerification(ctx)
        return
    end
    OpenContainer(ctx, entity, function()
        VerifyNextContainer(ctx)
    end)
end

local function EnsureRoom(ctx, prefab, callback, allow_staging)
    if Finder.HasRoomForPrefab(ctx.player, prefab) then
        callback()
        return
    end

    if allow_staging == false then
        Interrupt(ctx, "完成后没有空间恢复临时物品")
        return
    end

    local item = Finder.FindSafeStageItem(ctx.player, ctx.needed_prefabs)
    if item == nil then
        Interrupt(ctx, "背包没有可安全腾出的格子")
        return
    end

    local inventory_item = item.replica.inventoryitem
    ctx.player.components.playercontroller:DoControllerDropItemFromInvTile(item)
    WaitUntil(ctx, function()
        return not item:IsValid() or not inventory_item:IsGrandOwner(ctx.player)
    end, Policy.ACTION_TIMEOUT, function()
        table.insert(ctx.staged_items, item)
        callback()
    end, "临时腾格失败")
end

local function FindOpenContainerRecord(ctx, prefab)
    for _, entity in ipairs(ctx.verified) do
        if entity:IsValid() and entity.replica.container:IsOpenedBy(ctx.player) then
            for _, record in ipairs(Finder.GetContainerItems(entity, ctx.player)) do
                if record.prefab == prefab and Policy.IsCraftingItem(record.item) then
                    return entity, record
                end
            end
        end
    end
end

local function FindContainerRecord(ctx, prefab)
    local open_entity, open_record = FindOpenContainerRecord(ctx, prefab)
    if open_entity ~= nil then
        return open_entity, open_record
    end
    for _, entity in ipairs(ctx.verified) do
        local cached = ContainerCache.Get(entity)
        if entity:IsValid() and cached ~= nil and (cached.items[prefab] or 0) > 0 then
            return entity
        end
    end
end

local function FindGroundItem(ctx, prefab)
    table.sort(ctx.ground_candidates, function(a, b)
        local ac = a:IsValid() and Finder.GetStackCount(a) or math.huge
        local bc = b:IsValid() and Finder.GetStackCount(b) or math.huge
        return ac < bc
    end)
    for _, item in ipairs(ctx.ground_candidates) do
        if item.prefab == prefab and Policy.IsGroundCraftingItem(item, ctx.player) then
            return item
        end
    end
end

local AcquirePrefab

local function MoveFromContainer(ctx, entity, record, prefab, amount, callback)
    EnsureRoom(ctx, prefab, function()
        local before = Finder.GetPersonalCount(ctx.player, prefab)
        local take = math.min(amount, record.count)
        record.container:MoveItemFromCountOfSlot(record.slot, ctx.player, take)
        WaitUntil(ctx, function()
            return Finder.GetPersonalCount(ctx.player, prefab) > before
        end, Policy.ACTION_TIMEOUT, function()
            ContainerCache.Snapshot(entity, ctx.player)
            local gained = Finder.GetPersonalCount(ctx.player, prefab) - before
            if gained <= 0 then
                Interrupt(ctx, "从容器取材失败")
            else
                RecordExternalAcquisition(ctx, prefab)
                AcquirePrefab(ctx, prefab, amount - math.min(amount, gained), callback)
            end
        end, "从容器取材超时")
    end)
end

local function PickupGround(ctx, item, prefab, amount, callback)
    EnsureRoom(ctx, prefab, function()
        local before = Finder.GetPersonalCount(ctx.player, prefab)
        local stack_count = Finder.GetStackCount(item)
        DoWorldAction(ctx, item, G.ACTIONS.PICKUP)
        WaitUntil(ctx, function()
            return Finder.GetPersonalCount(ctx.player, prefab) > before or not item:IsValid()
        end, Policy.ACTION_TIMEOUT, function()
            local gained = math.max(0, Finder.GetPersonalCount(ctx.player, prefab) - before)
            if gained <= 0 then
                Interrupt(ctx, "拾取材料失败")
                return
            end
            RecordExternalAcquisition(ctx, prefab)
            local used = math.min(amount, gained)
            local excess = gained - used
            if excess > 0 then
                ctx.acquire_credit[prefab] = (ctx.acquire_credit[prefab] or 0) + excess
            elseif stack_count > gained and not item:IsValid() then
                -- Keep the accounting conservative when a predicted stack merges.
                local predicted_excess = math.max(0, stack_count - used)
                ctx.acquire_credit[prefab] = (ctx.acquire_credit[prefab] or 0) + predicted_excess
            end
            AcquirePrefab(ctx, prefab, amount - used, callback)
        end, "拾取材料超时")
    end)
end

AcquirePrefab = function(ctx, prefab, amount, callback)
    if amount <= 0 then
        callback()
        return
    end

    local credit = math.min(amount, ctx.acquire_credit[prefab] or 0)
    if credit > 0 then
        ctx.acquire_credit[prefab] = ctx.acquire_credit[prefab] - credit
        amount = amount - credit
        if amount <= 0 then
            callback()
            return
        end
    end

    local entity, record = FindContainerRecord(ctx, prefab)
    if entity ~= nil and record ~= nil then
        MoveFromContainer(ctx, entity, record, prefab, amount, callback)
        return
    elseif entity ~= nil then
        OpenContainer(ctx, entity, function()
            local refreshed_entity, refreshed_record = FindOpenContainerRecord(ctx, prefab)
            if refreshed_entity == nil then
                Interrupt(ctx, "容器缓存已失效，缺少 " .. tostring(prefab))
            else
                MoveFromContainer(ctx, refreshed_entity, refreshed_record, prefab, amount, callback)
            end
        end)
        return
    end

    local ground_item = FindGroundItem(ctx, prefab)
    if ground_item ~= nil then
        PickupGround(ctx, ground_item, prefab, amount, callback)
        return
    end

    Interrupt(ctx, "已验证材料发生变化，缺少 " .. tostring(prefab))
end

local function CloseOpenContainers(ctx, callback, index)
    index = index or 1
    local entity = ctx.verified[index]
    if entity == nil then
        callback()
        return
    elseif not entity:IsValid() or not entity.replica.container:IsOpenedBy(ctx.player) then
        CloseOpenContainers(ctx, callback, index + 1)
        return
    end

    ContainerCache.Snapshot(entity, ctx.player)
    DoWorldAction(ctx, entity, G.ACTIONS.RUMMAGE)
    WaitUntil(ctx, function()
        return not entity:IsValid() or not entity.replica.container:IsOpenedBy(ctx.player)
    end, Policy.ACTION_TIMEOUT, function()
        CloseOpenContainers(ctx, callback, index + 1)
    end, "关闭容器失败")
end

local function CraftIntermediate(ctx, step, callback)
    CloseOpenContainers(ctx, function()
        local builder = ctx.player.replica.builder
        if not builder:HasIngredients(step.recipe) then
            Interrupt(ctx, "合成前材料校验失败：" .. tostring(step.recipe.name))
            return
        end
        local before = Finder.GetPersonalCount(ctx.player, step.product)
        WaitForBuild(ctx, function()
            builder:MakeRecipeFromMenu(step.recipe)
        end, nil, function()
            if Finder.GetPersonalCount(ctx.player, step.product) > before then
                callback()
                return
            end

            -- Native crafting auto-equips a newly crafted equippable when its
            -- slot is empty. Intermediate products must be moved back into the
            -- inventory before Builder can consume them as ingredients.
            local inventory = ctx.player.replica.inventory
            local equipped_slot = nil
            for slot, item in pairs(inventory:GetEquips() or {}) do
                if item ~= nil and item.prefab == step.product then
                    equipped_slot = slot
                    break
                end
            end
            if equipped_slot == nil then
                Interrupt(ctx, "制作结果未进入背包：" .. tostring(step.product))
                return
            end
            inventory:TakeActiveItemFromEquipSlot(equipped_slot)
            WaitUntil(ctx, function()
                return Finder.GetPersonalCount(ctx.player, step.product) > before
            end, Policy.ACTION_TIMEOUT, callback, "无法收回自动装备的次级材料")
        end)
    end)
end

local function IsAuthoritativelyBuffered(builder, recipe_name)
    local classified = builder.classified
    local netvar = classified and classified.bufferedbuilds and classified.bufferedbuilds[recipe_name]
    return netvar ~= nil and netvar:value() or false
end

local ReturnExternalRemainders
local RestoreStaged

local function FinishRecipe(ctx)
    CloseOpenContainers(ctx, function()
        local builder = ctx.player.replica.builder
        if not builder:HasIngredients(ctx.recipe) then
            Interrupt(ctx, "最终建造前材料校验失败")
            return
        end

        if ctx.recipe.placer ~= nil then
            builder:BufferBuild(ctx.recipe.name)
            WaitUntil(ctx, function()
                return IsAuthoritativelyBuffered(builder, ctx.recipe.name)
            end, Policy.BUILD_TIMEOUT, function()
                ReturnExternalRemainders(ctx, function()
                    RestoreStaged(ctx, function()
                        local controller = ctx.player.components.playercontroller
                        controller:StartBuildPlacementMode(ctx.recipe, ctx.skin)
                        Complete(ctx, "success")
                    end)
                end)
            end, "建筑缓冲失败")
        elseif ctx.recipe.manufactured then
            local before = {}
            for _, ingredient in ipairs(ctx.recipe.ingredients or {}) do
                before[ingredient.type] = Finder.GetPersonalCount(ctx.player, ingredient.type)
            end
            builder:MakeRecipeFromMenu(ctx.recipe, ctx.skin)
            local has_material_ingredient = next(before) ~= nil
            WaitUntil(ctx, function()
                if not has_material_ingredient then
                    return not builder:IsBusy()
                end
                for prefab, count in pairs(before) do
                    if Finder.GetPersonalCount(ctx.player, prefab) < count then
                        return true
                    end
                end
                return false
            end, Policy.BUILD_TIMEOUT, function()
                ReturnExternalRemainders(ctx, function()
                    RestoreStaged(ctx, function()
                        Complete(ctx, "success")
                    end)
                end)
            end, "制作站未确认制造结果")
        else
            WaitForBuild(ctx, function()
                builder:MakeRecipeFromMenu(ctx.recipe, ctx.skin)
            end, nil, function()
                ReturnExternalRemainders(ctx, function()
                    RestoreStaged(ctx, function()
                        Complete(ctx, "success")
                    end)
                end)
            end)
        end
    end)
end

local function FindPersonalItem(ctx, prefab)
    for _, record in ipairs(Finder.GetPersonalItems(ctx.player)) do
        if record.prefab == prefab then
            return record.item
        end
    end
end

local function DropWholeStack(ctx, prefab, callback)
    local item = FindPersonalItem(ctx, prefab)
    if item == nil then
        callback(false)
        return
    end
    local before = Finder.GetPersonalCount(ctx.player, prefab)
    ctx.player.components.playercontroller:DoControllerDropItemFromInvTile(item)
    WaitUntil(ctx, function()
        return Finder.GetPersonalCount(ctx.player, prefab) < before
    end, Policy.ACTION_TIMEOUT, function()
        callback(true)
    end, "归还外部材料失败")
end

ReturnExternalRemainders = function(ctx, callback)
    local prefabs = {}
    for prefab in pairs(ctx.return_prefabs) do
        table.insert(prefabs, prefab)
    end
    local function DropPrefab(index)
        local prefab = prefabs[index]
        if prefab == nil then
            callback()
            return
        end
        local function DropRemaining()
            DropWholeStack(ctx, prefab, function(dropped)
                if dropped then
                    DropRemaining()
                else
                    DropPrefab(index + 1)
                end
            end)
        end
        DropRemaining()
    end
    DropPrefab(1)
end

RestoreStaged = function(ctx, callback)
    local function Restore(index)
        local item = ctx.staged_items[index]
        if item == nil then
            callback()
            return
        elseif not item:IsValid() then
            Notify(ctx.player, "临时放下的物品已不存在：" .. tostring(item.prefab))
            Restore(index + 1)
            return
        end

        EnsureRoom(ctx, item.prefab, function()
            DoWorldAction(ctx, item, G.ACTIONS.PICKUP)
            WaitUntil(ctx, function()
                return item.replica.inventoryitem:IsGrandOwner(ctx.player)
            end, Policy.ACTION_TIMEOUT, function()
                Restore(index + 1)
            end, "恢复临时物品失败")
        end, false)
    end
    Restore(1)
end

ExecutePlan = function(ctx, index)
    local step = ctx.plan.steps[index]
    if step == nil then
        Interrupt(ctx, "建造计划不完整")
    elseif step.kind == "acquire" then
        AcquirePrefab(ctx, step.prefab, step.amount, function()
            ExecutePlan(ctx, index + 1)
        end)
    elseif step.kind == "craft" then
        CraftIntermediate(ctx, step, function()
            ExecutePlan(ctx, index + 1)
        end)
    elseif step.kind == "finish" then
        FinishRecipe(ctx)
    else
        Interrupt(ctx, "未知建造步骤")
    end
end

local function InstallInterruptionListeners(ctx)
    local function OnInterrupted(_, data)
        local reason = data and data.reason or "游戏状态变化"
        Interrupt(ctx, reason)
    end
    Listen(ctx, ctx.player, "death", OnInterrupted)
    Listen(ctx, ctx.player, "onremove", OnInterrupted)
    Listen(ctx, ctx.player, "playerdeactivated", OnInterrupted)
    Listen(ctx, ctx.player, "actionfailed", OnInterrupted)
end

function Coordinator.Start(player, recipe, skin)
    if player == nil or recipe == nil or player.replica == nil or player.replica.builder == nil then
        return nil
    end

    Coordinator.Interrupt(player, "启动了新的自动建造")

    local task = setmetatable({
        pending = true,
        status = "pending",
        reason = nil,
        callbacks = {},
        player = player,
    }, Task)
    local ctx = {
        player = player,
        recipe = recipe,
        skin = skin,
        task = task,
        scheduled = {},
        listeners = {},
        verified = {},
        verified_set = {},
        staged_items = {},
        initial_owned = Finder.GetPersonalCounts(player),
        return_prefabs = {},
        acquire_credit = {},
        next_container_index = 1,
    }
    active_tasks[player.GUID] = ctx

    ctx.ground_candidates = Finder.FindNearbyGroundItems(player, Policy.SEARCH_RADIUS)
    ctx.container_candidates = Finder.FindNearbyContainers(player, Policy.SEARCH_RADIUS)

    -- Cached containers likely to contain a direct ingredient are checked first;
    -- unknown containers remain optimistic and are then checked by distance.
    local direct = {}
    for _, ingredient in ipairs(recipe.ingredients or {}) do direct[ingredient.type] = true end
    table.sort(ctx.container_candidates, function(a, b)
        local function Score(entity)
            local record = ContainerCache.Get(entity)
            if record == nil then return 0 end
            local score = 1
            for prefab, count in pairs(record.items or {}) do
                if direct[prefab] then score = score + count end
            end
            return score
        end
        return Score(a) > Score(b)
    end)

    InstallInterruptionListeners(ctx)
    local controller = player.components.playercontroller
    if controller ~= nil and controller.placer_recipe ~= nil then
        controller:CancelPlacement()
    end
    if player.HUD ~= nil and player.HUD.IsCraftingOpen ~= nil and player.HUD:IsCraftingOpen() then
        player.HUD:CloseCrafting()
    end
    Notify(player, "开始自动搜索建造：" .. tostring(recipe.name))
    Schedule(ctx, 0, function()
        -- Inspect every eligible nearby container before planning so an existing
        -- direct ingredient always wins over crafting that ingredient from raw
        -- materials found in an earlier container.
        VerifyNextContainer(ctx)
    end)
    return task
end

return Coordinator
