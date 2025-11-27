--- Some internal structures
-- I won't implement type checks, since I ensure that types are correct in internal usage,
-- and runtime type checking is very slow
local remove_at    = table.remove
local setmetatable = setmetatable
local next         = next
local isnumber     = isnumber

--- A compact ImVector clone, maybe
-- ImVector<>
local ImVector = {}
ImVector.__index = ImVector

function ImVector:push_back(value)
    self._top = self._top + 1
    self._items[self._top] = value
end

function ImVector:pop_back()
    if self._top == 0 then return nil end
    local value = self._items[self._top]
    self._items[self._top] = nil
    self._top = self._top - 1
    return value
end

function ImVector:clear()
    self._top = 0
end

function ImVector:clear_delete()
    for i = 1, self._top do
        self._items[i] = nil
    end
    self._top = 0
end

function ImVector:delete()

end

function ImVector:clear_destruct() self:clear_delete() end

function ImVector:size() return self._top end
function ImVector:empty() return self._top == 0 end

function ImVector:peek()
    if self._top == 0 then return nil end
    return self._items[self._top]
end

function ImVector:erase(i)
    if i < 1 or i > self._top then return nil end
    local removed = remove_at(self._items, i)
    self._top = self._top - 1
    return removed
end

function ImVector:at(i)
    if i < 1 or i > self._top then return nil end
    return self._items[i]
end

function ImVector:iter()
    local i = 0
    local n = self._top
    return function()
        i = i + 1
        if i <= n then
            return i, self._items[i]
        end
    end
end

local function _ImVector()
    return setmetatable({_items = {}, _top = 0}, ImVector)
end

--- ImVec2
local ImVec2 = {}
ImVec2.__index = ImVec2

local function _ImVec2(x, y)
    return setmetatable({
        x = x or 0,
        y = y or 0
    }, ImVec2)
end

function ImVec2:__add(other)
    return _ImVec2(self.x + other.x, self.y + other.y)
end

function ImVec2:__sub(other)
    return _ImVec2(self.x - other.x, self.y - other.y)
end

function ImVec2:__mul(other)
    if isnumber(self) then
        return _ImVec2(self * other.x, self * other.y)
    elseif isnumber(other) then
        return _ImVec2(self.x * other, self.y * other)
    else
        return _ImVec2(self.x * other.x, self.y * other.y)
    end
end

function ImVec2:__eq(other)
    return self.x == other.x and self.y == other.y
end

function ImVec2:delete()

end

--- struct IMGUI_API ImRect
local ImRect = {}
ImRect.__index = ImRect

function ImRect:delete()

end

function ImRect:contains(other)
    return other.Min.x >= self.Min.x and other.Max.x <= self.Max.x and
        other.Min.y >= self.Min.y and other.Max.y <= self.Max.y
end

function ImRect:contains_point(p)
    return p.x >= self.Min.x and p.x <= self.Max.x and
        p.y >= self.Min.y and p.y <= self.Max.y
end

function ImRect:overlaps(other)
    return self.Min.x <= other.Max.x and self.Max.x >= other.Min.x and
        self.Min.y <= other.Max.y and self.Max.y >= other.Min.y
end

function ImRect:GetCenter()
    return _ImVec2(
        (self.Min.x + self.Max.x) * 0.5,
        (self.Min.y + self.Max.y) * 0.5
    )
end

local function _ImRect(min, max)
    return setmetatable({
        Min = {x = min.x or 0, y = min.y or 0},
        Max = {x = max.x or 0, y = max.y or 0}
    }, ImRect)
end

return _ImVector, _ImVec2, _ImRect