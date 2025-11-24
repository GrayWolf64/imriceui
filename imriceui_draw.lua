local function ParseImGuiCol(str)
    local r, g, b, a = str:match("ImVec4%(([%d%.]+)f?, ([%d%.]+)f?, ([%d%.]+)f?, ([%d%.]+)f?%)")
    return {r = tonumber(r) * 255, g = tonumber(g) * 255, b = tonumber(b) * 255, a = tonumber(a) * 255}
end

local ImNoColor = {r = 0, g = 0, b = 0, a = 0}

--- ImGui::StyleColorsDark
local StyleColorsDark = {
    Text              = ParseImGuiCol("ImVec4(1.00f, 1.00f, 1.00f, 1.00f)"),
    WindowBg          = ParseImGuiCol("ImVec4(0.06f, 0.06f, 0.06f, 0.94f)"),
    Border            = ParseImGuiCol("ImVec4(0.43f, 0.43f, 0.50f, 0.50f)"),
    BorderShadow      = ParseImGuiCol("ImVec4(0.00f, 0.00f, 0.00f, 0.00f)"),
    TitleBg           = ParseImGuiCol("ImVec4(0.04f, 0.04f, 0.04f, 1.00f)"),
    TitleBgActive     = ParseImGuiCol("ImVec4(0.16f, 0.29f, 0.48f, 1.00f)"),
    TitleBgCollapsed  = ParseImGuiCol("ImVec4(0.00f, 0.00f, 0.00f, 0.51f)"),
    MenuBarBg         = ParseImGuiCol("ImVec4(0.14f, 0.14f, 0.14f, 1.00f)"),
    Button            = ParseImGuiCol("ImVec4(0.26f, 0.59f, 0.98f, 0.40f)"),
    ButtonHovered     = ParseImGuiCol("ImVec4(0.26f, 0.59f, 0.98f, 1.00f)"),
    ButtonActive      = ParseImGuiCol("ImVec4(0.06f, 0.53f, 0.98f, 1.00f)"),
    ResizeGrip        = ParseImGuiCol("ImVec4(0.26f, 0.59f, 0.98f, 0.20f)"),
    ResizeGripHovered = ParseImGuiCol("ImVec4(0.26f, 0.59f, 0.98f, 0.67f)"),
    ResizeGripActive  = ParseImGuiCol("ImVec4(0.26f, 0.59f, 0.98f, 0.95f)")
}

return ImNoColor, StyleColorsDark