package.loaded["dst-controller/locations/protocol"] = nil
local Protocol = require("dst-controller/locations/protocol")

local name = "基地;东门=入口%3B\n二层"
local query = Protocol.EncodeQueryPlayer("A1B2", "KU_test;=", name)
assert(query:find("[玩家位置]", 1, true), "protocol should remain visibly identifiable")
assert(query:find("查询玩家", 1, true), "query type should remain human-readable")
assert(query:find("%3B", 1, true), "reserved semicolons should be escaped")
assert(query:find("%3D", 1, true), "reserved equals signs should be escaped")
assert(query:find("%25", 1, true), "literal percent signs should be escaped")

local decoded_query = assert(Protocol.Decode(query))
assert(decoded_query.kind == "query_player")
assert(decoded_query.request_id == "A1B2")
assert(decoded_query.target_userid == "KU_test;=")
assert(decoded_query.target_name == name, "escaped UTF-8 values should round-trip")

local all = assert(Protocol.Decode(Protocol.EncodeQueryAll("ALL-1")))
assert(all.kind == "query_all" and all.request_id == "ALL-1")

local position_message = Protocol.EncodePosition(
    "A1B2", "Master;One", "地表=森林", 123.44, -456.76)
local position = assert(Protocol.Decode(position_message))
assert(position.kind == "position")
assert(position.shard_id == "Master;One")
assert(position.world_type == "地表=森林")
assert(position.x == 123.4 and position.z == -456.8)

assert(Protocol.Decode("普通聊天") == nil)
assert(Protocol.Decode("[玩家位置];类型=位置回复;编号=A;分片=M;区域=地表;X=坏;Z=2") == nil)
assert(Protocol.Decode("[玩家位置];类型=查询全部;编号=A;编号=B") == nil)
