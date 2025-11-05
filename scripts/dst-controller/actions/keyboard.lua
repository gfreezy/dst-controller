-- Keyboard Actions - 键盘输入动作
-- 支持单个按键或组合键（用+分隔）

local G = require("dst-controller/global")

-- 键盘按键映射表（DST KEY_ 常量）
-- 注意：只包含DST constants.lua中实际定义的按键
local KEY_MAP = {
    -- 字母键
    a = G.KEY_A, b = G.KEY_B, c = G.KEY_C, d = G.KEY_D, e = G.KEY_E,
    f = G.KEY_F, g = G.KEY_G, h = G.KEY_H, i = G.KEY_I, j = G.KEY_J,
    k = G.KEY_K, l = G.KEY_L, m = G.KEY_M, n = G.KEY_N, o = G.KEY_O,
    p = G.KEY_P, q = G.KEY_Q, r = G.KEY_R, s = G.KEY_S, t = G.KEY_T,
    u = G.KEY_U, v = G.KEY_V, w = G.KEY_W, x = G.KEY_X, y = G.KEY_Y,
    z = G.KEY_Z,

    -- 数字键
    ["0"] = G.KEY_0, ["1"] = G.KEY_1, ["2"] = G.KEY_2, ["3"] = G.KEY_3,
    ["4"] = G.KEY_4, ["5"] = G.KEY_5, ["6"] = G.KEY_6, ["7"] = G.KEY_7,
    ["8"] = G.KEY_8, ["9"] = G.KEY_9,

    -- 功能键
    f1 = G.KEY_F1, f2 = G.KEY_F2, f3 = G.KEY_F3, f4 = G.KEY_F4,
    f5 = G.KEY_F5, f6 = G.KEY_F6, f7 = G.KEY_F7, f8 = G.KEY_F8,
    f9 = G.KEY_F9, f10 = G.KEY_F10, f11 = G.KEY_F11, f12 = G.KEY_F12,

    -- 修饰键
    ctrl = G.KEY_CTRL, lctrl = G.KEY_LCTRL, rctrl = G.KEY_RCTRL,
    shift = G.KEY_SHIFT, lshift = G.KEY_LSHIFT, rshift = G.KEY_RSHIFT,
    alt = G.KEY_ALT, lalt = G.KEY_LALT, ralt = G.KEY_RALT,

    -- 特殊键
    space = G.KEY_SPACE,
    enter = G.KEY_ENTER,
    escape = G.KEY_ESCAPE,
    tab = G.KEY_TAB,
    backspace = G.KEY_BACKSPACE,
    delete = G.KEY_DELETE,
    insert = G.KEY_INSERT,
    home = G.KEY_HOME,
    ["end"] = G.KEY_END,
    pageup = G.KEY_PAGEUP,
    pagedown = G.KEY_PAGEDOWN,

    -- 方向键
    up = G.KEY_UP,
    down = G.KEY_DOWN,
    left = G.KEY_LEFT,
    right = G.KEY_RIGHT,

    -- 符号键（只包含DST中定义的）
    minus = G.KEY_MINUS,              -- -
    equals = G.KEY_EQUALS,            -- =
    leftbracket = G.KEY_LEFTBRACKET,  -- [
    rightbracket = G.KEY_RIGHTBRACKET,-- ]
    backslash = G.KEY_BACKSLASH,      -- \
    semicolon = G.KEY_SEMICOLON,      -- ;
    period = G.KEY_PERIOD,            -- .
    slash = G.KEY_SLASH,              -- /
    tilde = G.KEY_TILDE,              -- `
    -- 注意：DST未定义 KEY_COMMA 和 KEY_APOSTROPHE
}

-- 解析键盘组合键字符串
-- 例如: "ctrl+shift+s" -> {KEY_CTRL, KEY_SHIFT, KEY_S}
local function ParseKeyCombo(key_string)
    if not key_string or key_string == "" then
        return {}
    end

    local keys = {}
    local parts = {}

    -- 分割字符串（按+分隔）
    for part in string.gmatch(key_string, "[^+]+") do
        local trimmed = part:match("^%s*(.-)%s*$"):lower()  -- 去除空格并转小写
        table.insert(parts, trimmed)
    end

    -- 转换为KEY常量
    for _, key_name in ipairs(parts) do
        local key_code = KEY_MAP[key_name]
        if key_code then
            table.insert(keys, key_code)
        else
            print("[KeyboardAction] Warning: Unknown key '" .. key_name .. "'")
        end
    end

    return keys
end

-- 当前模拟按下的按键状态（用于 IsKeyDown hook）
local simulated_keys_down = {}

-- Hook TheInput:IsKeyDown to simulate key states
local original_IsKeyDown = nil
local function InstallIsKeyDownHook()
    if original_IsKeyDown then
        return  -- Already hooked
    end

    original_IsKeyDown = G.TheInput.IsKeyDown
    G.TheInput.IsKeyDown = function(self, key)
        -- Check if this key is being simulated
        if simulated_keys_down[key] then
            return true
        end
        -- Otherwise use original method
        return original_IsKeyDown(self, key)
    end

    print("[KeyboardAction] IsKeyDown hook installed")
end

-- 触发键盘按键
-- 通过调用 TheInput:OnRawKey 和 hook IsKeyDown 来模拟键盘输入
-- down: true=按下, false=释放, nil=按下后自动释放
local function TriggerKey(player, key_string, down)
    if not player or not player:IsValid() then
        return
    end

    local keys = ParseKeyCombo(key_string)
    if #keys == 0 then
        print("[KeyboardAction] No valid keys to trigger")
        return
    end

    -- Ensure hook is installed
    InstallIsKeyDownHook()

    -- Handle different down modes
    if down == nil then
        -- Mode 1: Press and release (default)
        -- Press all keys
        for _, key in ipairs(keys) do
            simulated_keys_down[key] = true
            G.TheInput:OnRawKey(key, true)
        end

        -- Schedule release after a short delay (1 frame)
        player:DoTaskInTime(0, function()
            for _, key in ipairs(keys) do
                simulated_keys_down[key] = nil
                G.TheInput:OnRawKey(key, false)
            end
        end)
    elseif down then
        -- Mode 2: Press only (hold)
        for _, key in ipairs(keys) do
            simulated_keys_down[key] = true
            G.TheInput:OnRawKey(key, true)
        end
    else
        -- Mode 3: Release only
        for _, key in ipairs(keys) do
            simulated_keys_down[key] = nil
            G.TheInput:OnRawKey(key, false)
        end
    end

    print("[KeyboardAction] Triggered keys:", key_string, "down:", down)
end

return {
    -- 触发键盘按键
    -- 通过调用 TheInput:OnRawKey 和 hook IsKeyDown 来模拟键盘输入
    --
    -- 参数1 (player): 玩家对象
    -- 参数2 (key_string): 键盘按键字符串（单个或组合键，用+分隔）
    --   例如: "space", "ctrl+s", "shift+tab", "f5", "ctrl+shift+s"
    -- 参数3 (down, 可选): 按键状态
    --   - nil 或不提供: 按下后自动释放（默认）
    --   - true: 仅按下，不释放
    --   - false: 仅释放
    --
    -- 实现原理:
    --   1. Hook TheInput:IsKeyDown() 来模拟按键状态（让组合键检测生效）
    --   2. 调用 TheInput:OnRawKey() 来触发键盘事件（触发游戏逻辑）
    --
    -- 使用示例:
    --   ACTIONS.trigger_key(player, "space")           -- 按下空格键
    --   ACTIONS.trigger_key(player, "ctrl+s")          -- 按下ctrl+s后自动释放
    --   ACTIONS.trigger_key(player, "shift", true)   -- 按下shift不释放
    --   ACTIONS.trigger_key(player, "shift", false)  -- 释放shift
    trigger_key = TriggerKey
}
