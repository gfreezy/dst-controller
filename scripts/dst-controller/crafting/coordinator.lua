-- Enhanced Controller - Automatic crafting transaction coordinator

local G = require("dst-controller/global")
local Policy = require("dst-controller/crafting/policy")
local ContainerCache = require("dst-controller/crafting/container-cache")
local Finder = require("dst-controller/crafting/material-finder")
local Planner = require("dst-controller/crafting/material-planner")
local Helpers = require("dst-controller/utils/helpers")
local WorldAction = require("dst-controller/utils/world-action")
local L = require("dst-controller/localization").L

local Coordinator = {}

local active_tasks = {}

local function GetTime()
    return G.GetTime ~= nil and G.GetTime() or os.clock()
end

local function Notify(player, message)
    local output = "[Enhanced Controller] " .. message
    Helpers.DebugPrint(message)
    local announcer = player and player.HUD and player.HUD.eventannouncer
    if announcer ~= nil and announcer.ShowNewAnnouncement ~= nil then
        announcer:ShowNewAnnouncement(output, { 1, 0.85, 0.35, 1 })
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
    Coordinator.Interrupt(self.player, reason or L("AUTO_CRAFT_REASON_CANCELLED"))
end

function Task:GetProgress()
    return {
        phase = self.progress.phase,
        checked = self.progress.checked,
        total = self.progress.total,
    }
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
    ctx.task.progress.phase = status
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
        Notify(ctx.player, L("AUTO_CRAFT_COMPLETE"))
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
        Notify(ctx.player, L("AUTO_CRAFT_INTERRUPTED",
            tostring(reason or L("AUTO_CRAFT_UNKNOWN_REASON"))))
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
        Interrupt(active_tasks[player.GUID], reason or L("AUTO_CRAFT_REASON_USER_ACTION"))
    end
end

function Coordinator.IsActive(player)
    return player ~= nil and active_tasks[player.GUID] ~= nil
end

function Coordinator.OnUserControl(player, control, down)
    if down and Coordinator.IsActive(player) then
        Coordinator.Interrupt(player, L("AUTO_CRAFT_REASON_USER_ACTION"))
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
            Interrupt(ctx, failure_reason or L("AUTO_CRAFT_REASON_OPERATION_TIMEOUT"))
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
                Interrupt(ctx, L("AUTO_CRAFT_REASON_BUILD_NOT_SYNCED"))
            end
        end)
    end
    listener = Listen(ctx, ctx.player, "buildsuccess", Success)
    action()
    Schedule(ctx, Policy.BUILD_TIMEOUT, function()
        if not completed then
            completed = true
            StopListening(ctx, listener)
            Interrupt(ctx, L("AUTO_CRAFT_REASON_BUILD_TIMEOUT"))
        end
    end)
end

local function DoWorldAction(ctx, target, action)
    return WorldAction.Do(ctx.player, target, action)
end

local function AddVerified(ctx, entity)
    if not ctx.verified_set[entity] then
        ctx.verified_set[entity] = true
        table.insert(ctx.verified, entity)
    end
end

local function OpenContainer(ctx, entity, callback)
    if entity == nil or not entity:IsValid() or not Policy.IsStorageContainer(entity, ctx.player) then
        Interrupt(ctx, L("AUTO_CRAFT_REASON_CONTAINER_UNAVAILABLE"))
        return
    end

    if Policy.IsStorageOpenedBy(entity, ctx.player) and
        Policy.GetStorageContainer(entity, ctx.player) ~= nil then
        ContainerCache.Snapshot(entity, ctx.player)
        AddVerified(ctx, entity)
        callback()
        return
    end

    if not Policy.CanOpenStorage(entity) then
        WaitUntil(ctx, function()
            return entity:IsValid() and Policy.CanOpenStorage(entity)
        end, Policy.ACTION_TIMEOUT, function()
            OpenContainer(ctx, entity, callback)
        end, L("AUTO_CRAFT_REASON_CONTAINER_OPEN_FAILED"))
        return
    end

    local controller = ctx.player.components.playercontroller
    if controller == nil or controller:IsBusy() then
        WaitUntil(ctx, function()
            return controller ~= nil and not controller:IsBusy()
        end, Policy.ACTION_TIMEOUT, function()
            OpenContainer(ctx, entity, callback)
        end, L("AUTO_CRAFT_REASON_CONTAINER_BUSY"))
        return
    end

    local previously_open = Policy.CaptureOpenContainers(ctx.player)
    if not DoWorldAction(ctx, entity, G.ACTIONS.RUMMAGE) then
        Interrupt(ctx, L("AUTO_CRAFT_REASON_CONTAINER_OPEN_FAILED"))
        return
    end
    WaitUntil(ctx, function()
        return entity:IsValid() and Policy.IsStorageOpenedBy(entity, ctx.player) and
            Policy.GetStorageContainer(entity, ctx.player, previously_open) ~= nil
    end, Policy.ACTION_TIMEOUT, function()
        ContainerCache.Snapshot(entity, ctx.player)
        AddVerified(ctx, entity)
        callback()
    end, L("AUTO_CRAFT_REASON_CONTAINER_OPEN_FAILED"))
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

local function PlanAfterVerification(ctx, final_attempt)
    local external, max_stacks = BuildExternalSnapshot(ctx)
    local owned = Finder.GetPersonalCounts(ctx.player)
    local plan, reason, detail = Coordinator.BuildPlan(ctx.player, ctx.recipe, owned, external, max_stacks)
    if plan ~= nil then
        ctx.plan = plan
        ctx.needed_prefabs = plan.needed_prefabs
        ctx.task.progress.phase = "executing"
        ExecutePlan(ctx, 1)
        return true
    end

    ctx.last_plan_reason = reason
    ctx.last_plan_detail = detail
    local missing = detail ~= nil and (tostring(detail.prefab) .. " ×" .. tostring(math.max(0, detail.amount - detail.available))) or tostring(reason)
    if final_attempt then
        Interrupt(ctx, L("AUTO_CRAFT_REASON_INSUFFICIENT", missing))
    end
    return false
end

local function VerifyNextContainer(ctx)
    if ctx.next_container_index > ctx.container_limit then
        ctx.task.progress.phase = "planning"
        PlanAfterVerification(ctx, true)
        return
    end
    local entity = ctx.container_candidates[ctx.next_container_index]
    ctx.next_container_index = ctx.next_container_index + 1
    if entity == nil then
        ctx.task.progress.phase = "planning"
        PlanAfterVerification(ctx, true)
        return
    end
    OpenContainer(ctx, entity, function()
        ctx.task.progress.checked = ctx.task.progress.checked + 1
        if ctx.search_mode == "smart" and PlanAfterVerification(ctx, false) then
            return
        end
        VerifyNextContainer(ctx)
    end)
end

local function EnsureRoom(ctx, prefab, callback, allow_staging)
    if Finder.HasRoomForPrefab(ctx.player, prefab) then
        callback()
        return
    end

    if allow_staging == false then
        Interrupt(ctx, L("AUTO_CRAFT_REASON_NO_RESTORE_SPACE"))
        return
    end

    local item = Finder.FindSafeStageItem(ctx.player, ctx.needed_prefabs)
    if item == nil then
        Interrupt(ctx, L("AUTO_CRAFT_REASON_NO_SAFE_SLOT"))
        return
    end

    local inventory_item = item.replica.inventoryitem
    ctx.player.components.playercontroller:DoControllerDropItemFromInvTile(item)
    WaitUntil(ctx, function()
        return not item:IsValid() or not inventory_item:IsGrandOwner(ctx.player)
    end, Policy.ACTION_TIMEOUT, function()
        table.insert(ctx.staged_items, item)
        callback()
    end, L("AUTO_CRAFT_REASON_STAGE_FAILED"))
end

local function FindOpenContainerRecord(ctx, prefab)
    for _, entity in ipairs(ctx.verified) do
        if entity:IsValid() and Policy.IsStorageOpenedBy(entity, ctx.player) then
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
                Interrupt(ctx, L("AUTO_CRAFT_REASON_CONTAINER_TAKE_FAILED"))
            else
                RecordExternalAcquisition(ctx, prefab)
                AcquirePrefab(ctx, prefab, amount - math.min(amount, gained), callback)
            end
        end, L("AUTO_CRAFT_REASON_CONTAINER_TAKE_TIMEOUT"))
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
                Interrupt(ctx, L("AUTO_CRAFT_REASON_PICKUP_FAILED"))
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
        end, L("AUTO_CRAFT_REASON_PICKUP_TIMEOUT"))
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
                Interrupt(ctx, L("AUTO_CRAFT_REASON_CACHE_STALE", tostring(prefab)))
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

    Interrupt(ctx, L("AUTO_CRAFT_REASON_SOURCE_CHANGED", tostring(prefab)))
end

local function CloseOpenContainers(ctx, callback, index)
    index = index or 1
    local entity = ctx.verified[index]
    if entity == nil then
        callback()
        return
    elseif not entity:IsValid() or not Policy.IsStorageOpenedBy(entity, ctx.player) then
        CloseOpenContainers(ctx, callback, index + 1)
        return
    end

    ContainerCache.Snapshot(entity, ctx.player)
    DoWorldAction(ctx, entity, G.ACTIONS.RUMMAGE)
    WaitUntil(ctx, function()
        return not entity:IsValid() or not Policy.IsStorageOpenedBy(entity, ctx.player)
    end, Policy.ACTION_TIMEOUT, function()
        CloseOpenContainers(ctx, callback, index + 1)
    end, L("AUTO_CRAFT_REASON_CONTAINER_CLOSE_FAILED"))
end

local function CraftIntermediate(ctx, step, callback)
    CloseOpenContainers(ctx, function()
        local builder = ctx.player.replica.builder
        if not builder:HasIngredients(step.recipe) then
            Interrupt(ctx, L("AUTO_CRAFT_REASON_PRECHECK_FAILED", tostring(step.recipe.name)))
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
                Interrupt(ctx, L("AUTO_CRAFT_REASON_PRODUCT_NOT_STORED", tostring(step.product)))
                return
            end
            inventory:TakeActiveItemFromEquipSlot(equipped_slot)
            WaitUntil(ctx, function()
                return Finder.GetPersonalCount(ctx.player, step.product) > before
            end, Policy.ACTION_TIMEOUT, callback,
                L("AUTO_CRAFT_REASON_UNEQUIP_PRODUCT_FAILED"))
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
            Interrupt(ctx, L("AUTO_CRAFT_REASON_FINAL_PRECHECK_FAILED"))
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
            end, L("AUTO_CRAFT_REASON_BUFFER_FAILED"))
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
            end, L("AUTO_CRAFT_REASON_MANUFACTURE_FAILED"))
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
    end, L("AUTO_CRAFT_REASON_RETURN_FAILED"))
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
            Notify(ctx.player, L("AUTO_CRAFT_STAGED_ITEM_MISSING", tostring(item.prefab)))
            Restore(index + 1)
            return
        end

        EnsureRoom(ctx, item.prefab, function()
            DoWorldAction(ctx, item, G.ACTIONS.PICKUP)
            WaitUntil(ctx, function()
                return item.replica.inventoryitem:IsGrandOwner(ctx.player)
            end, Policy.ACTION_TIMEOUT, function()
                Restore(index + 1)
            end, L("AUTO_CRAFT_REASON_RESTORE_FAILED"))
        end, false)
    end
    Restore(1)
end

ExecutePlan = function(ctx, index)
    local step = ctx.plan.steps[index]
    if step == nil then
        Interrupt(ctx, L("AUTO_CRAFT_REASON_PLAN_INCOMPLETE"))
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
        Interrupt(ctx, L("AUTO_CRAFT_REASON_UNKNOWN_STEP"))
    end
end

local function InstallInterruptionListeners(ctx)
    local function OnInterrupted(_, data)
        local reason = data and data.reason or L("AUTO_CRAFT_REASON_GAME_STATE")
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

    Coordinator.Interrupt(player, L("AUTO_CRAFT_REASON_REPLACED"))

    local task = setmetatable({
        pending = true,
        status = "pending",
        reason = nil,
        callbacks = {},
        player = player,
        progress = { phase = "searching", checked = 0, total = 0 },
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

    local automation_settings = Policy.GetAutomationSettings()
    ctx.search_radius = automation_settings.search_radius
    ctx.search_mode = automation_settings.search_mode
    ctx.ground_candidates = Finder.FindNearbyGroundItems(player, ctx.search_radius)
    ctx.container_candidates = Finder.FindNearbyContainers(player, ctx.search_radius)

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
    ctx.container_limit = automation_settings.max_containers == 0 and
        #ctx.container_candidates or
        math.min(#ctx.container_candidates, automation_settings.max_containers)
    task.progress.total = ctx.container_limit

    InstallInterruptionListeners(ctx)
    local controller = player.components.playercontroller
    if controller ~= nil and controller.placer_recipe ~= nil then
        controller:CancelPlacement()
    end
    if player.HUD ~= nil and player.HUD.IsCraftingOpen ~= nil and player.HUD:IsCraftingOpen() then
        player.HUD:CloseCrafting()
    end
    Notify(player, L("AUTO_CRAFT_STARTED", tostring(recipe.name)))
    Schedule(ctx, 0, function()
        -- Smart mode first tries visible ground/personal stock and then replans
        -- after each verified container. Thorough mode preserves the exhaustive
        -- behavior for players who prefer direct ingredients over speed.
        if ctx.search_mode == "smart" and PlanAfterVerification(ctx, false) then
            return
        end
        VerifyNextContainer(ctx)
    end)
    return task
end

return Coordinator
