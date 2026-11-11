-- Shared test helpers. Run tests from the repo root, e.g. luajit tests/value_test.lua
local T = {}

-- Load addon files into a fresh namespace, the way the game does.
function T.load(files)
    local ns = {}
    for _, f in ipairs(files) do
        assert(loadfile(f))("WiseEconomicDecisions", ns)
    end
    return ns
end

local function deepEqual(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do
        if not deepEqual(v, b[k]) then return false end
    end
    for k, v in pairs(b) do
        if not deepEqual(a[k], v) then return false end
    end
    return true
end

local function show(v)
    if type(v) ~= "table" then return tostring(v) end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(x, y) return tostring(x) < tostring(y) end)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. "=" .. show(v[k]) end
    return "{" .. table.concat(parts, ", ") .. "}"
end

function T.eq(name, got, want)
    if deepEqual(got, want) then
        print("PASS " .. name)
    else
        print("FAIL " .. name .. ": got " .. show(got) .. " want " .. show(want))
        os.exit(1)
    end
end

-- Item record with sensible defaults (see the plan's "Item record" shape).
function T.item(o)
    local item = {
        itemID = 1, count = 1, maxStack = 1, vendor = 0, family = 0,
        classID = 15, subclassID = 0, bound = false, isQuest = false,
        name = "Item", quality = 1, icon = 0,
    }
    for k, v in pairs(o or {}) do item[k] = v end
    return item
end

return T
