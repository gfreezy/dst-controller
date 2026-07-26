-- Enhanced Controller - Human-readable player location chat protocol

local Protocol = {}

Protocol.PREFIX = "[玩家位置]"

local TYPE_QUERY_ALL = "查询全部"
local TYPE_QUERY_PLAYER = "查询玩家"
local TYPE_POSITION = "位置回复"

local function EncodeValue(value)
    return tostring(value or ""):gsub("[%%;=\r\n]", function(char)
        return string.format("%%%02X", string.byte(char))
    end)
end

local function DecodeValue(value)
    return value:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end)
end

local function Build(fields)
    local parts = { Protocol.PREFIX }
    for _, field in ipairs(fields) do
        parts[#parts + 1] = field[1] .. "=" .. EncodeValue(field[2])
    end
    return table.concat(parts, ";")
end

local function ParseFields(message)
    if type(message) ~= "string" or
        message:sub(1, #Protocol.PREFIX) ~= Protocol.PREFIX then
        return nil
    end

    local fields = {}
    local index = 0
    for segment in (message .. ";"):gmatch("(.-);") do
        index = index + 1
        if index == 1 then
            if segment ~= Protocol.PREFIX then
                return nil
            end
        else
            local separator = segment:find("=", 1, true)
            if separator == nil or separator == 1 then
                return nil
            end
            local key = segment:sub(1, separator - 1)
            if fields[key] ~= nil then
                return nil
            end
            fields[key] = DecodeValue(segment:sub(separator + 1))
        end
    end
    return fields
end

local function ValidId(value)
    return type(value) == "string" and value ~= "" and #value <= 64
end

function Protocol.EncodeQueryAll(request_id)
    return Build({
        { "类型", TYPE_QUERY_ALL },
        { "编号", request_id },
    })
end

function Protocol.EncodeQueryPlayer(request_id, target_userid, target_name)
    return Build({
        { "类型", TYPE_QUERY_PLAYER },
        { "编号", request_id },
        { "玩家", target_name or target_userid },
        { "用户", target_userid },
    })
end

function Protocol.EncodePosition(request_id, shard_id, world_type, x, z)
    return Build({
        { "类型", TYPE_POSITION },
        { "编号", request_id },
        { "分片", shard_id },
        { "区域", world_type },
        { "X", string.format("%.1f", x) },
        { "Z", string.format("%.1f", z) },
    })
end

function Protocol.Decode(message)
    local fields = ParseFields(message)
    if fields == nil or not ValidId(fields["编号"]) then
        return nil
    end

    local message_type = fields["类型"]
    if message_type == TYPE_QUERY_ALL then
        return {
            kind = "query_all",
            request_id = fields["编号"],
        }
    elseif message_type == TYPE_QUERY_PLAYER then
        if not ValidId(fields["用户"]) then
            return nil
        end
        return {
            kind = "query_player",
            request_id = fields["编号"],
            target_userid = fields["用户"],
            target_name = fields["玩家"] or fields["用户"],
        }
    elseif message_type == TYPE_POSITION then
        local x = tonumber(fields["X"])
        local z = tonumber(fields["Z"])
        if not ValidId(fields["分片"]) or
            type(fields["区域"]) ~= "string" or fields["区域"] == "" or
            x == nil or z == nil or x ~= x or z ~= z or
            math.abs(x) > 100000 or math.abs(z) > 100000 then
            return nil
        end
        return {
            kind = "position",
            request_id = fields["编号"],
            shard_id = fields["分片"],
            world_type = fields["区域"],
            x = x,
            z = z,
        }
    end
    return nil
end

Protocol.EncodeValue = EncodeValue
Protocol.DecodeValue = DecodeValue

return Protocol
