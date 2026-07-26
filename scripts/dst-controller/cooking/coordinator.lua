-- Enhanced Controller - Search & Cook transaction coordinator

local G = require("dst-controller/global")
local Policy = require("dst-controller/crafting/policy")
local ContainerCache = require("dst-controller/crafting/container-cache")
local Finder = require("dst-controller/crafting/material-finder")
local Planner = require("dst-controller/cooking/planner")
local Helpers = require("dst-controller/utils/helpers")
local WorldAction = require("dst-controller/utils/world-action")
local L = require("dst-controller/localization").L
local cooking = require("cooking")

local Coordinator = {}
local active_tasks = {}

local function GetTime()
    return G.GetTime ~= nil and G.GetTime() or os.clock()
end

local function ProductName(prefab)
    local names = G.STRINGS and G.STRINGS.NAMES
    return names and names[string.upper(prefab or "")] or tostring(prefab)
end

local function Notify(player, message)
    local output = "[Enhanced Controller] " .. message
    Helpers.DebugPrint(message)
    local announcer = player and player.HUD and player.HUD.eventannouncer
    if announcer ~= nil and announcer.ShowNewAnnouncement ~= nil then
        announcer:ShowNewAnnouncement(output, { 1, 0.85, 0.35, 1 })
    end
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
    Coordinator.Interrupt(self.player, reason or L("AUTO_COOK_REASON_CANCELLED"))
end

function Task:GetProgress()
    return {
        phase = self.progress.phase,
        checked = self.progress.checked,
        total = self.progress.total,
    }
end

local function RemoveListener(ctx, listener)
    if listener ~= nil and listener.source ~= nil and
        listener.source.RemoveEventCallback ~= nil then
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
    for _, listener in ipairs(ctx.listeners) do
        RemoveListener(ctx, listener)
    end
    ctx.scheduled = {}
    ctx.listeners = {}

    if status == "success" then
        Notify(ctx.player, L("AUTO_COOK_COMPLETE", ProductName(ctx.request.product)))
    elseif status == "interrupted" then
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
        Notify(ctx.player, L("AUTO_COOK_INTERRUPTED",
            tostring(reason or L("AUTO_COOK_UNKNOWN_REASON"))))
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
        Interrupt(active_tasks[player.GUID], reason or L("AUTO_COOK_REASON_USER_ACTION"))
    end
end

function Coordinator.IsActive(player)
    return player ~= nil and active_tasks[player.GUID] ~= nil
end

function Coordinator.OnUserControl(player, control, down)
    if down and Coordinator.IsActive(player) then
        Coordinator.Interrupt(player, L("AUTO_COOK_REASON_USER_ACTION"))
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

local function WaitUntil(ctx, predicate, timeout, on_success, on_failure)
    local deadline = GetTime() + timeout
    local function Poll()
        local ok, result = pcall(predicate)
        if ok and result then
            on_success()
        elseif GetTime() >= deadline then
            if type(on_failure) == "function" then
                on_failure()
            else
                Interrupt(ctx, on_failure or L("AUTO_COOK_REASON_OPERATION_TIMEOUT"))
            end
        else
            Schedule(ctx, Policy.POLL_INTERVAL, Poll)
        end
    end
    Poll()
end

local function DoWorldAction(ctx, target, action)
    local ok = WorldAction.Do(ctx.player, target, action)
    if not ok then
        Interrupt(ctx, L("AUTO_COOK_REASON_GAME_STATE"))
        return false
    end
    return true
end

local function WaitForController(ctx, callback, failure_reason)
    local controller = ctx.player.components.playercontroller
    if controller ~= nil and not controller:IsBusy() then
        callback()
        return
    end
    WaitUntil(ctx, function()
        return controller ~= nil and not controller:IsBusy()
    end, Policy.ACTION_TIMEOUT, callback,
        failure_reason or L("AUTO_COOK_REASON_CONTAINER_BUSY"))
end

local function AddVerified(ctx, entity)
    if not ctx.verified_set[entity] then
        ctx.verified_set[entity] = true
        table.insert(ctx.verified, entity)
    end
end

local function IsReplicaBusy(replica)
    if replica == nil then
        return true
    elseif replica.IsBusy ~= nil then
        return replica:IsBusy()
    end
    local classified = replica.classified
    return classified ~= nil and classified.IsBusy ~= nil and
        classified:IsBusy() or false
end

local function PersonalInventoryBusy(ctx)
    return IsReplicaBusy(ctx.player.replica.inventory)
end

local function TryOpenStorage(ctx, entity, on_success, on_failure)
    if entity == nil or not entity:IsValid() or
        not Policy.IsStorageContainer(entity, ctx.player) then
        on_failure()
        return
    end

    local container = Policy.GetStorageContainer(entity, ctx.player)
    if Policy.IsStorageOpenedBy(entity, ctx.player) and container ~= nil then
        WaitUntil(ctx, function()
            return entity:IsValid() and not container:IsBusy()
        end, Policy.ACTION_TIMEOUT, function()
            ContainerCache.Snapshot(entity, ctx.player)
            AddVerified(ctx, entity)
            on_success()
        end, on_failure)
        return
    end

    if not Policy.CanOpenStorage(entity) then
        WaitUntil(ctx, function()
            return entity:IsValid() and Policy.CanOpenStorage(entity)
        end, Policy.ACTION_TIMEOUT, function()
            TryOpenStorage(ctx, entity, on_success, on_failure)
        end, on_failure)
        return
    end

    WaitForController(ctx, function()
        local previously_open = Policy.CaptureOpenContainers(ctx.player)
        if not DoWorldAction(ctx, entity, G.ACTIONS.RUMMAGE) then
            return
        end
        WaitUntil(ctx, function()
            container = Policy.GetStorageContainer(entity, ctx.player, previously_open)
            return entity:IsValid() and Policy.IsStorageOpenedBy(entity, ctx.player) and
                container ~= nil
        end, Policy.ACTION_TIMEOUT, function()
            WaitUntil(ctx, function()
                return entity:IsValid() and not container:IsBusy()
            end, Policy.ACTION_TIMEOUT, function()
                ContainerCache.Snapshot(entity, ctx.player)
                AddVerified(ctx, entity)
                on_success()
            end, on_failure)
        end, on_failure)
    end, on_failure)
end

local function OpenStorage(ctx, entity, callback)
    TryOpenStorage(ctx, entity, callback, function()
        Interrupt(ctx, L("AUTO_COOK_REASON_CONTAINER_OPEN_FAILED"))
    end)
end

local function DistanceSq(player, entity)
    if player.GetDistanceSqToInst ~= nil then
        return player:GetDistanceSqToInst(entity)
    end
    local px, _, pz = player.Transform:GetWorldPosition()
    local ex, _, ez = entity.Transform:GetWorldPosition()
    local dx, dz = px - ex, pz - ez
    return dx * dx + dz * dz
end

local function IsCookerAvailable(ctx, entity)
    if entity == nil or not entity:IsValid() or entity == ctx.player or
        not ctx.allowed_cookers[entity.prefab] or
        entity:HasTag("INLIMBO") or entity:HasTag("NOCLICK") or
        entity:HasTag("burnt") or entity:HasTag("donecooking") or
        not entity:HasTag("stewer") then
        return false
    end
    local container = entity.replica and entity.replica.container
    return container ~= nil and container:GetNumSlots() == 4 and
        container:CanBeOpened() and not container:IsReadOnlyContainer()
end

local function TryOpenCooker(ctx, entity, on_success, on_failure)
    if not IsCookerAvailable(ctx, entity) then
        on_failure()
        return
    end
    local container = entity.replica.container
    if container:IsOpenedBy(ctx.player) then
        WaitUntil(ctx, function()
            return IsCookerAvailable(ctx, entity) and not container:IsBusy()
        end, Policy.ACTION_TIMEOUT, on_success, on_failure)
        return
    end
    WaitForController(ctx, function()
        if not IsCookerAvailable(ctx, entity) or
            not DoWorldAction(ctx, entity, G.ACTIONS.RUMMAGE) then
            on_failure()
            return
        end
        WaitUntil(ctx, function()
            return IsCookerAvailable(ctx, entity) and
                container:IsOpenedBy(ctx.player)
        end, Policy.ACTION_TIMEOUT, function()
            WaitUntil(ctx, function()
                return IsCookerAvailable(ctx, entity) and not container:IsBusy()
            end, Policy.ACTION_TIMEOUT, on_success, on_failure)
        end, on_failure)
    end, on_failure)
end

local function CloseCooker(ctx, entity, callback)
    if entity == nil or not entity:IsValid() or
        not entity.replica.container:IsOpenedBy(ctx.player) then
        callback()
        return
    end
    if not DoWorldAction(ctx, entity, G.ACTIONS.RUMMAGE) then
        return
    end
    WaitUntil(ctx, function()
        return not entity:IsValid() or
            not entity.replica.container:IsOpenedBy(ctx.player)
    end, Policy.ACTION_TIMEOUT, callback, callback)
end

local BeginMaterialSearch

local function SelectCooker(ctx, index)
    local entity = ctx.cooker_candidates[index]
    if entity == nil then
        Interrupt(ctx, L("AUTO_COOK_REASON_NO_COOKER"))
        return
    end
    TryOpenCooker(ctx, entity, function()
        local container = entity.replica.container
        if container:IsEmpty() then
            ctx.cooker = entity
            ctx.task.progress.phase = "searching"
            BeginMaterialSearch(ctx)
        else
            CloseCooker(ctx, entity, function()
                SelectCooker(ctx, index + 1)
            end)
        end
    end, function()
        SelectCooker(ctx, index + 1)
    end)
end

local function AddCount(counts, prefab, amount)
    counts[prefab] = (counts[prefab] or 0) + amount
end

local function BuildAvailableCounts(ctx)
    local counts = Finder.GetPersonalCounts(ctx.player)
    for _, item in ipairs(ctx.ground_candidates) do
        if Policy.IsGroundCraftingItem(item, ctx.player) then
            AddCount(counts, item.prefab, Finder.GetStackCount(item))
        end
    end
    for _, entity in ipairs(ctx.verified) do
        local cached = ContainerCache.Get(entity)
        if entity:IsValid() and cached ~= nil then
            for prefab, amount in pairs(cached.items or {}) do
                AddCount(counts, prefab, amount)
            end
        end
    end
    return counts
end

local ExecuteIngredients

local function TryPlan(ctx, final_attempt)
    local plan = Planner.Find(
        ctx.request.product,
        ctx.request.recipes,
        BuildAvailableCounts(ctx),
        ctx.cooker.prefab,
        cooking.CalculateRecipe
    )
    if plan ~= nil then
        ctx.plan = plan
        ctx.needed_prefabs = {}
        for prefab in pairs(plan.required) do
            ctx.needed_prefabs[prefab] = true
        end
        ctx.task.progress.phase = "filling"
        ExecuteIngredients(ctx, 1)
        return true
    end
    if final_attempt then
        Interrupt(ctx, L("AUTO_COOK_REASON_INSUFFICIENT"))
    end
    return false
end

local function VerifyNextContainer(ctx)
    if ctx.next_container_index > ctx.container_limit then
        ctx.task.progress.phase = "planning"
        TryPlan(ctx, true)
        return
    end
    local entity = ctx.container_candidates[ctx.next_container_index]
    ctx.next_container_index = ctx.next_container_index + 1
    if entity == nil then
        ctx.task.progress.phase = "planning"
        TryPlan(ctx, true)
        return
    end
    TryOpenStorage(ctx, entity, function()
        ctx.task.progress.checked = ctx.task.progress.checked + 1
        if ctx.search_mode == "smart" and TryPlan(ctx, false) then
            return
        end
        VerifyNextContainer(ctx)
    end, function()
        ctx.task.progress.checked = ctx.task.progress.checked + 1
        VerifyNextContainer(ctx)
    end)
end

BeginMaterialSearch = function(ctx)
    if ctx.search_mode == "smart" and TryPlan(ctx, false) then
        return
    end
    VerifyNextContainer(ctx)
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
    local entity, record = FindOpenContainerRecord(ctx, prefab)
    if entity ~= nil then
        return entity, record
    end
    for _, candidate in ipairs(ctx.verified) do
        local cached = ContainerCache.Get(candidate)
        if candidate:IsValid() and cached ~= nil and
            (cached.items[prefab] or 0) > 0 then
            return candidate
        end
    end
end

local function FindGroundItem(ctx, prefab)
    for _, item in ipairs(ctx.ground_candidates) do
        if item.prefab == prefab and Policy.IsGroundCraftingItem(item, ctx.player) then
            return item
        end
    end
end

local function RecordExternalAcquisition(ctx, prefab)
    if Policy.ShouldReturnExternalRemainder(ctx.initial_owned, prefab) then
        ctx.return_prefabs[prefab] = true
    end
end

local function AcquireFromContainer(ctx, entity, record, prefab, callback)
    EnsureRoom(ctx, prefab, function()
        WaitUntil(ctx, function()
            return entity:IsValid() and not IsReplicaBusy(record.container) and
                not PersonalInventoryBusy(ctx)
        end, Policy.ACTION_TIMEOUT, function()
            local item = record.container:GetItemInSlot(record.slot)
            if item == nil or item.prefab ~= prefab then
                Interrupt(ctx, L("AUTO_CRAFT_REASON_SOURCE_CHANGED", prefab))
                return
            end
            local before = Finder.GetPersonalCount(ctx.player, prefab)
            record.container:MoveItemFromCountOfSlot(record.slot, ctx.player, 1)
            WaitUntil(ctx, function()
                return Finder.GetPersonalCount(ctx.player, prefab) > before
            end, Policy.ACTION_TIMEOUT, function()
                ContainerCache.Snapshot(entity, ctx.player)
                RecordExternalAcquisition(ctx, prefab)
                callback()
            end, L("AUTO_CRAFT_REASON_CONTAINER_TAKE_TIMEOUT"))
        end, L("AUTO_CRAFT_REASON_CONTAINER_TAKE_TIMEOUT"))
    end)
end

local function AcquireFromGround(ctx, item, prefab, callback)
    EnsureRoom(ctx, prefab, function()
        local before = Finder.GetPersonalCount(ctx.player, prefab)
        if not DoWorldAction(ctx, item, G.ACTIONS.PICKUP) then
            return
        end
        WaitUntil(ctx, function()
            return Finder.GetPersonalCount(ctx.player, prefab) > before or
                not item:IsValid()
        end, Policy.ACTION_TIMEOUT, function()
            if Finder.GetPersonalCount(ctx.player, prefab) <= before then
                Interrupt(ctx, L("AUTO_CRAFT_REASON_PICKUP_FAILED"))
                return
            end
            RecordExternalAcquisition(ctx, prefab)
            callback()
        end, L("AUTO_CRAFT_REASON_PICKUP_TIMEOUT"))
    end)
end

local function AcquireOne(ctx, prefab, callback)
    local entity, record = FindContainerRecord(ctx, prefab)
    if entity ~= nil and record ~= nil then
        AcquireFromContainer(ctx, entity, record, prefab, callback)
        return
    elseif entity ~= nil then
        OpenStorage(ctx, entity, function()
            local refreshed_entity, refreshed_record =
                FindOpenContainerRecord(ctx, prefab)
            if refreshed_entity == nil then
                Interrupt(ctx, L("AUTO_CRAFT_REASON_CACHE_STALE", prefab))
            else
                AcquireFromContainer(ctx, refreshed_entity, refreshed_record,
                    prefab, callback)
            end
        end)
        return
    end
    local item = FindGroundItem(ctx, prefab)
    if item ~= nil then
        AcquireFromGround(ctx, item, prefab, callback)
        return
    end
    Interrupt(ctx, L("AUTO_CRAFT_REASON_SOURCE_CHANGED", prefab))
end

local function SlotHasPrefab(container, slot, prefab)
    local item = container:GetItemInSlot(slot)
    return item ~= nil and item.prefab == prefab
end

local function FilledSlotsMatch(ctx, through_slot)
    if ctx.cooker == nil or not ctx.cooker:IsValid() then
        return false
    end
    local container = ctx.cooker.replica.container
    for slot = 1, through_slot do
        if not SlotHasPrefab(container, slot, ctx.plan.ingredients[slot]) then
            return false
        end
    end
    return true
end

local function EnsureCookerOpen(ctx, through_slot, callback)
    if not IsCookerAvailable(ctx, ctx.cooker) then
        Interrupt(ctx, L("AUTO_COOK_REASON_COOKER_UNAVAILABLE"))
        return
    end
    TryOpenCooker(ctx, ctx.cooker, function()
        if FilledSlotsMatch(ctx, through_slot) then
            callback()
        else
            Interrupt(ctx, L("AUTO_COOK_REASON_COOKER_CHANGED"))
        end
    end, function()
        Interrupt(ctx, L("AUTO_COOK_REASON_COOKER_OPEN_FAILED"))
    end)
end

local function FindPersonalRecord(player, prefab)
    local active_record = nil
    for _, record in ipairs(Finder.GetPersonalItems(player)) do
        if record.prefab == prefab and Policy.IsCraftingItem(record.item) then
            if not record.active then
                return record
            end
            active_record = record
        end
    end
    return active_record
end

local function MovePersonalToCooker(ctx, prefab, slot, callback)
    local record = FindPersonalRecord(ctx.player, prefab)
    if record == nil then
        AcquireOne(ctx, prefab, function()
            MovePersonalToCooker(ctx, prefab, slot, callback)
        end)
        return
    end

    EnsureCookerOpen(ctx, slot - 1, function()
        local container = ctx.cooker.replica.container
        WaitUntil(ctx, function()
            return not container:IsBusy() and not PersonalInventoryBusy(ctx)
        end, Policy.ACTION_TIMEOUT, function()
            local current = FindPersonalRecord(ctx.player, prefab)
            if current == nil or container:GetItemInSlot(slot) ~= nil or
                not container:CanTakeItemInSlot(current.item, slot) then
                Interrupt(ctx, L("AUTO_COOK_REASON_TRANSFER_FAILED"))
                return
            end
            if current.active then
                container:PutOneOfActiveItemInSlot(slot)
            else
                current.container:MoveItemFromCountOfSlot(
                    current.slot, ctx.cooker, 1)
            end
            WaitUntil(ctx, function()
                return ctx.cooker:IsValid() and
                    SlotHasPrefab(container, slot, prefab)
            end, Policy.ACTION_TIMEOUT, callback,
                L("AUTO_COOK_REASON_TRANSFER_FAILED"))
        end, L("AUTO_COOK_REASON_TRANSFER_FAILED"))
    end)
end

local ReturnExternalRemainders
local RestoreStaged

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
            Notify(ctx.player, L("AUTO_CRAFT_STAGED_ITEM_MISSING", item.prefab))
            Restore(index + 1)
            return
        end
        EnsureRoom(ctx, item.prefab, function()
            if not DoWorldAction(ctx, item, G.ACTIONS.PICKUP) then
                return
            end
            WaitUntil(ctx, function()
                return item.replica.inventoryitem:IsGrandOwner(ctx.player)
            end, Policy.ACTION_TIMEOUT, function()
                Restore(index + 1)
            end, L("AUTO_CRAFT_REASON_RESTORE_FAILED"))
        end, false)
    end
    Restore(1)
end

local function StartCooking(ctx)
    EnsureCookerOpen(ctx, 4, function()
        local container = ctx.cooker.replica.container
        local ingredients = {}
        for slot = 1, 4 do
            ingredients[slot] = container:GetItemInSlot(slot).prefab
        end
        local ok, product = pcall(cooking.CalculateRecipe,
            ctx.cooker.prefab, ingredients)
        if not ok or product ~= ctx.request.product then
            Interrupt(ctx, L("AUTO_COOK_REASON_RECIPE_MISMATCH"))
            return
        end

        local controller = ctx.player.components.playercontroller
        WaitUntil(ctx, function()
            return ctx.cooker:IsValid() and not container:IsBusy() and
                controller ~= nil and not controller:IsBusy() and
                not ctx.player:HasTag("busy")
        end, Policy.ACTION_TIMEOUT, function()
            local widget = container:GetWidget()
            local button = widget and widget.buttoninfo
            local valid = button ~= nil and button.fn ~= nil
            if valid and button.validfn ~= nil then
                local valid_ok, valid_result = pcall(button.validfn, ctx.cooker)
                valid = valid_ok and valid_result
            end
            if not valid then
                Interrupt(ctx, L("AUTO_COOK_REASON_START_FAILED"))
                return
            end
            ctx.task.progress.phase = "cooking"
            local invoked = pcall(button.fn, ctx.cooker, ctx.player)
            if not invoked then
                Interrupt(ctx, L("AUTO_COOK_REASON_START_FAILED"))
                return
            end
            WaitUntil(ctx, function()
                return not ctx.cooker:IsValid() or not container:CanBeOpened()
            end, Policy.ACTION_TIMEOUT, function()
                ReturnExternalRemainders(ctx, function()
                    RestoreStaged(ctx, function()
                        Complete(ctx, "success")
                    end)
                end)
            end, L("AUTO_COOK_REASON_START_FAILED"))
        end, L("AUTO_COOK_REASON_START_FAILED"))
    end)
end

ExecuteIngredients = function(ctx, index)
    local prefab = ctx.plan.ingredients[index]
    if prefab == nil then
        StartCooking(ctx)
        return
    end
    MovePersonalToCooker(ctx, prefab, index, function()
        ExecuteIngredients(ctx, index + 1)
    end)
end

local function InstallInterruptionListeners(ctx)
    local function OnInterrupted(_, data)
        Interrupt(ctx, data and data.reason or L("AUTO_COOK_REASON_GAME_STATE"))
    end
    Listen(ctx, ctx.player, "death", OnInterrupted)
    Listen(ctx, ctx.player, "onremove", OnInterrupted)
    Listen(ctx, ctx.player, "playerdeactivated", OnInterrupted)
    Listen(ctx, ctx.player, "actionfailed", OnInterrupted)
end

local function BuildCookerCandidates(ctx)
    local candidates = {}
    for _, entity in ipairs(Finder.FindNearbyEntities(
        ctx.player, ctx.search_radius)) do
        if IsCookerAvailable(ctx, entity) then
            table.insert(candidates, entity)
        end
    end
    table.sort(candidates, function(a, b)
        return DistanceSq(ctx.player, a) < DistanceSq(ctx.player, b)
    end)
    return candidates
end

function Coordinator.Start(player, request)
    if player == nil or not player:IsValid() or type(request) ~= "table" or
        type(request.product) ~= "string" or type(request.recipes) ~= "table" or
        type(request.cooker_prefabs) ~= "table" or
        player.replica == nil or player.replica.inventory == nil or
        player.components == nil or player.components.playercontroller == nil then
        return nil
    end
    if #request.recipes == 0 or #request.cooker_prefabs == 0 then
        Notify(player, L("AUTO_COOK_INTERRUPTED",
            L("AUTO_COOK_REASON_NO_DISCOVERED_RECIPE")))
        return nil
    end

    Coordinator.Interrupt(player, L("AUTO_COOK_REASON_REPLACED"))
    local ok, crafting_coordinator = pcall(
        require, "dst-controller/crafting/coordinator")
    if ok and crafting_coordinator ~= nil then
        crafting_coordinator.Interrupt(player, L("AUTO_CRAFT_REASON_REPLACED"))
    end

    local task = setmetatable({
        pending = true,
        status = "pending",
        reason = nil,
        callbacks = {},
        player = player,
        progress = { phase = "cooker", checked = 0, total = 0 },
    }, Task)
    local ctx = {
        player = player,
        request = request,
        task = task,
        scheduled = {},
        listeners = {},
        verified = {},
        verified_set = {},
        staged_items = {},
        return_prefabs = {},
        initial_owned = Finder.GetPersonalCounts(player),
        allowed_cookers = {},
        next_container_index = 1,
    }
    active_tasks[player.GUID] = ctx

    for _, prefab in ipairs(request.cooker_prefabs) do
        ctx.allowed_cookers[prefab] = true
    end
    local settings = Policy.GetAutomationSettings()
    ctx.search_radius = settings.search_radius
    ctx.search_mode = settings.search_mode
    ctx.ground_candidates = Finder.FindNearbyGroundItems(player, ctx.search_radius)
    ctx.container_candidates = Finder.FindNearbyContainers(player, ctx.search_radius)
    ctx.cooker_candidates = BuildCookerCandidates(ctx)

    local ingredient_prefabs = {}
    for _, ingredients in ipairs(request.recipes) do
        for _, prefab in ipairs(ingredients) do
            ingredient_prefabs[prefab] = true
        end
    end
    table.sort(ctx.container_candidates, function(a, b)
        local function Score(entity)
            local record = ContainerCache.Get(entity)
            if record == nil then
                return 0
            end
            local score = 1
            for prefab, amount in pairs(record.items or {}) do
                if ingredient_prefabs[prefab] then
                    score = score + amount
                end
            end
            return score
        end
        local a_score, b_score = Score(a), Score(b)
        if a_score == b_score then
            return DistanceSq(player, a) < DistanceSq(player, b)
        end
        return a_score > b_score
    end)
    ctx.container_limit = settings.max_containers == 0 and
        #ctx.container_candidates or
        math.min(#ctx.container_candidates, settings.max_containers)
    task.progress.total = ctx.container_limit

    InstallInterruptionListeners(ctx)
    Notify(player, L("AUTO_COOK_STARTED", ProductName(request.product)))
    Schedule(ctx, 0, function()
        SelectCooker(ctx, 1)
    end)
    return task
end

return Coordinator
