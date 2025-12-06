local surface = surface
local render  = render
local draw    = draw

--- If lower, the window title cross or arrow will look awful
-- TODO: let client decide?
RunConsoleCommand("mat_antialias", "8")

local ImVector, ImVec2, ImVec4, ImVec1, ImRect = include("imriceui_internal.lua")

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

local function AddDrawCmd(draw_list, draw_call, ...)
    draw_list.CmdBuffer[#draw_list.CmdBuffer + 1] = {draw_call = draw_call, args = {...}}
end

local function AddRectFilled(draw_list, color, p_min, p_max)
    AddDrawCmd(draw_list, surface.SetDrawColor, color)
    AddDrawCmd(draw_list, surface.DrawRect, p_min.x, p_min.y, p_max.x - p_min.x, p_max.y - p_min.y)
end

local function AddRectOutline(draw_list, color, p_min, p_max, thickness)
    AddDrawCmd(draw_list, surface.SetDrawColor, color)
    AddDrawCmd(draw_list, surface.DrawOutlinedRect, p_min.x, p_min.y, p_max.x - p_min.x, p_max.y - p_min.y, thickness)
end

local function AddText(draw_list, text, font, pos, color)
    AddDrawCmd(draw_list, surface.SetTextPos, pos.x, pos.y)
    AddDrawCmd(draw_list, surface.SetFont, font)
    AddDrawCmd(draw_list, surface.SetTextColor, color)
    AddDrawCmd(draw_list, surface.DrawText, text)
end

local function AddLine(draw_list, p1, p2, color)
    AddDrawCmd(draw_list, surface.SetDrawColor, color)
    AddDrawCmd(draw_list, surface.DrawLine, p1.x, p1.y, p2.x, p2.y)
end

--- Points must be in clockwise order
local function AddTriangleFilled(draw_list, indices, color)
    AddDrawCmd(draw_list, surface.SetDrawColor, color)
    AddDrawCmd(draw_list, draw.NoTexture)
    AddDrawCmd(draw_list, surface.DrawPoly, indices)
end

local function RenderTextClipped(draw_list, text, font, pos, color, w, h)
    surface.SetFont(font)
    local text_width, text_height = surface.GetTextSize(text)
    local need_clipping = text_width > w or text_height > h

    if need_clipping then
        AddDrawCmd(draw_list, render.SetScissorRect, pos.x, pos.y, pos.x + w, pos.y + h, true)
    end

    AddText(draw_list, text, font, pos, color)

    if need_clipping then
        AddDrawCmd(draw_list, render.SetScissorRect, 0, 0, 0, 0, false)
    end
end

local function PushClipRect(draw_list, cr_min, cr_max, intersect_with_current_clip_rect)
    local cr = ImVec4(cr_min.x, cr_min.y, cr_max.x, cr_max.y)

    if intersect_with_current_clip_rect then
        local current = draw_list._CmdHeader.ClipRect

        if cr.x < current.x then cr.x = current.x end
        if cr.y < current.y then cr.y = current.y end
        if cr.z > current.z then cr.z = current.z end
        if cr.w > current.w then cr.w = current.w end
    end

    cr.z = math.max(cr.x, cr.z)
    cr.w = math.max(cr.y, cr.w)

    table.insert(draw_list._ClipRectStack, cr)
    draw_list._CmdHeader.ClipRect = cr
    -- _OnChangedClipRect()
end

return ImNoColor, StyleColorsDark,
    AddDrawCmd, AddRectFilled, AddRectOutline, AddText, AddLine,
    AddTriangleFilled, RenderTextClipped