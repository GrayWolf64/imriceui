ImRiceUI = ImRiceUI or {}

local IsValid = IsValid

local remove_at = table.remove
local insert_at = table.insert

local ipairs = ipairs

local ScrW = ScrW
local ScrH = ScrH

local INF = math.huge

local GImRiceUI = nil

local ImDir_Left  = 0
local ImDir_Right = 1
local ImDir_Up    = 2
local ImDir_Down  = 3

--- font_data size range: 4~255
local IM_FONT_SIZE_MIN = 4
local IM_FONT_SIZE_MAX = 255

local ImResizeGripDef = {
    {CornerPos = {x = 1, y = 1}, InnerDir = {x = -1, y = -1}}, -- Bottom right grip
    {CornerPos = {x = 0, y = 1}, InnerDir = {x =  1, y = -1}} -- Bottom left
}

--- Notable: VGUIMousePressAllowed?
local GDummyPanel = GDummyPanel or nil

local function SetupDummyPanel()
    if IsValid(GDummyPanel) then return end

    GDummyPanel = vgui.Create("DFrame")

    GDummyPanel:SetSizable(false)
    GDummyPanel:SetTitle("")
    GDummyPanel:SetPaintShadow(false)
    GDummyPanel:ShowCloseButton(false)
    GDummyPanel:SetDrawOnTop(true)
    GDummyPanel:SetDraggable(false)
    GDummyPanel:SetMouseInputEnabled(false)
    GDummyPanel:SetKeyboardInputEnabled(false)

    GDummyPanel:SetVisible(false)

    GDummyPanel.Paint = function(self, w, h)
        -- surface.SetDrawColor(0, 255, 0)
        -- surface.DrawOutlinedRect(0, 0, w, h, 4)
    end
end

local function AttachDummyPanel(x, y, w, h)
    if not IsValid(GDummyPanel) then return end

    GDummyPanel:SetPos(x, y)
    GDummyPanel:SetSize(w, h)
    GDummyPanel:SetVisible(true)
    GDummyPanel:MakePopup()
    GDummyPanel:SetKeyboardInputEnabled(false)
end

local function DetachDummyPanel()
    if not IsValid(GDummyPanel) then return end

    GDummyPanel:SetVisible(false)
end

local function SetMouseCursor(cursor_str)
    if not IsValid(GDummyPanel) then return end

    GDummyPanel:SetCursor(cursor_str)
end

--- If lower, the window title cross or arrow will look awful
-- TODO: let client decide?
RunConsoleCommand("mat_antialias", "8")

local function ParseRGBA(str)
    local r, g, b, a = str:match("ImVec4%(([%d%.]+)f?, ([%d%.]+)f?, ([%d%.]+)f?, ([%d%.]+)f?%)")
    return {r = tonumber(r) * 255, g = tonumber(g) * 255, b = tonumber(b) * 255, a = tonumber(a) * 255}
end

--- Use FNV1a, as one ImGui FIXME suggested
-- TODO: fix other places where ids are treated as strings!!!
local str_byte, bit_bxor, bit_band = string.byte, bit.bxor, bit.band
local function ImHashStr(str)
    local FNV_OFFSET_BASIS = 0x811C9DC5
    local FNV_PRIME = 0x01000193

    local hash = FNV_OFFSET_BASIS

    local byte
    for i = 1, #str do
        byte = str_byte(str, i)
        hash = bit_bxor(hash, byte)
        hash = bit_band(hash * FNV_PRIME, 0xFFFFFFFF)
    end

    -- FIXME: is this possible?
    -- if hash == 0 then

    -- end

    return hash
end

local ImMin = math.min
local ImMax = math.max
local ImFloor = math.floor
local ImRound = math.Round
local function ImLerp(a, b, t) return a + (b - a) * t end
local function ImClamp(v, min, max) return ImMin(ImMax(v, min), max) end
local function ImTrunc(f) return ImFloor(f + 0.5) end

local ImNoColor, StyleColorsDark = include("imriceui_draw.lua")

local FontDataDefault = {
    font      = "Arial",
    size      = 13,
    weight    = 500,
    blursize  = 0,
    scanlines = 0,
    extended  = false,
    antialias = true,
    underline = false,
    italic    = false,
    strikeout = false,
    symbol    = false,
    rotary    = false,
    shadow    = false,
    additive  = false,
    outline   = false
}

local str_format = string.format
local function ImHashFontData(font_data)
    local str = str_format("%s%03d%04d%02d%02d%1d%1d%1d%1d%1d%1d%1d%1d%1d%1d",
        font_data.font       or FontDataDefault.font,
        font_data.size       or FontDataDefault.size,
        font_data.weight     or FontDataDefault.weight,
        font_data.blursize   or FontDataDefault.blursize,
        font_data.scanlines  or FontDataDefault.scanlines,
        (font_data.extended  or FontDataDefault.extended)  and 1 or 0,
        (font_data.antialias or FontDataDefault.antialias) and 1 or 0,
        (font_data.underline or FontDataDefault.underline) and 1 or 0,
        (font_data.italic    or FontDataDefault.italic)    and 1 or 0,
        (font_data.strikeout or FontDataDefault.strikeout) and 1 or 0,
        (font_data.symbol    or FontDataDefault.symbol)    and 1 or 0,
        (font_data.rotary    or FontDataDefault.rotary)    and 1 or 0,
        (font_data.shadow    or FontDataDefault.shadow)    and 1 or 0,
        (font_data.additive  or FontDataDefault.additive)  and 1 or 0,
        (font_data.outline   or FontDataDefault.outline)   and 1 or 0
    )

    return "ImFont" .. ImHashStr(str)
end

local pairs = pairs
local function FontCopy(font_data)
    local copy = {}
    for k, v in pairs(font_data) do
        copy[k] = v
    end
    return copy
end

--- Fonts created have a very long lifecycle, since can't be deleted
-- ImFont {name = , data = }
local ImFontAtlas = ImFontAtlas or {Fonts = {}}

--- Add or get a font, always take its return val as fontname to be used with surface.SetFont
-- ImFont* ImFontAtlas::AddFont
function ImFontAtlas:AddFont(font_data)
    local hash = ImHashFontData(font_data)
    if self.Fonts[hash] then return hash end

    self.Fonts[hash] = font_data
    surface.CreateFont(hash, font_data)

    return hash
end

--- void ImGui::UpdateCurrentFontSize
local function UpdateCurrentFontSize(restore_font_size_after_scaling)
    local final_size
    if restore_font_size_after_scaling > 0 then
        final_size = restore_font_size_after_scaling
    else
        final_size = 0
    end

    if final_size == 0 then
        final_size = GImRiceUI.FontSizeBase

        final_size = final_size * GImRiceUI.Style.FontScaleMain
    end

    -- Again, due to gmod font system limitation
    final_size = ImRound(final_size)
    final_size = ImClamp(final_size, IM_FONT_SIZE_MIN, IM_FONT_SIZE_MAX)

    GImRiceUI.FontSize = final_size

    local font_data_new = FontCopy(ImFontAtlas.Fonts[GImRiceUI.Font])

    font_data_new.size = final_size

    local font_new = ImFontAtlas:AddFont(font_data_new)
    GImRiceUI.Font = font_new
end

--- void ImGui::SetCurrentFont
local function SetCurrentFont(font_name, font_size_before_scaling, font_size_after_scaling)
    GImRiceUI.Font = font_name
    GImRiceUI.FontSizeBase = font_size_before_scaling
    UpdateCurrentFontSize(font_size_after_scaling) -- TODO: investigate
end

local function PushFont(font_name, font_size_base) -- FIXME: checks not implemented?
    if not font_name or font_name == "" then
        font_name = GImRiceUI.Font
    end

    insert_at(GImRiceUI.FontStack, {
        Font = font_name,
        FontSizeBeforeScaling = GImRiceUI.FontSizeBase,
        FontSizeAfterScaling = GImRiceUI.FontSize
    })

    if font_size_base == 0 then
        font_size_base = GImRiceUI.FontSizeBase
    end

    SetCurrentFont(font_name, font_size_base, 0)
end

local function PopFont()
    if #GImRiceUI.FontStack == 0 then return end

    local font_stack_data = GImRiceUI.FontStack[#GImRiceUI.FontStack]
    SetCurrentFont(font_stack_data.Font, font_stack_data.FontSizeBeforeScaling, font_stack_data.FontSizeAfterScaling)

    remove_at(GImRiceUI.FontStack)
end

local function GetDefaultFont() -- FIXME: fix impl
    return ImFontAtlas:AddFont({
        font = "ProggyCleanTT",
        size = 18
    })
end

--- void ImGui::UpdateFontsNewFrame
local function UpdateFontsNewFrame() -- TODO: investigate
    GImRiceUI.Font = GetDefaultFont()

    local font_stack_data  = {
        Font = GImRiceUI.Font,
        FontSizeBeforeScaling = GImRiceUI.Style.FontSizeBase,
        FontSizeAfterScaling = GImRiceUI.Style.FontSizeBase
    }

    SetCurrentFont(font_stack_data.Font, font_stack_data.FontSizeBeforeScaling, 0)

    insert_at(GImRiceUI.FontStack, font_stack_data)
end

--- void ImGui::UpdateFontsEndFrame
local function UpdateFontsEndFrame()
    PopFont()
end

local DefaultConfig = {
    WindowSize = {w = 500, h = 480},
    WindowPos = {x = 0, y = 0},

    WindowBorderWidth = 1,
}

--- Index starts from 1
local MouseButtonMap = {
    [1] = MOUSE_LEFT,
    [2] = MOUSE_RIGHT
}

--- struct ImGuiContext
local function CreateNewContext()
    GImRiceUI = {
        Style = {
            FramePadding = {x = 4, y = 3},

            WindowRounding = 0,

            Colors = StyleColorsDark,

            FontSizeBase = 18,
            FontScaleMain = 1,

            WindowMinSize = {w = 55, h = 55}
        },
        Config = DefaultConfig,
        Initialized = true,

        Windows = {}, -- Windows sorted in display order, back to front
        WindowsByID = {}, -- Map window's ID to window ref

        WindowsBorderHoverPadding = 0,

        CurrentWindowStack = {},
        CurrentWindow = nil,

        IO = {
            MousePos = {x = 0, y = 0},
            MouseX = gui.MouseX,
            MouseY = gui.MouseY,
            IsMouseDown = input.IsMouseDown,

            --- Just support 2 buttons now, L & R
            MouseDown             = {false, false},
            MouseClicked          = {false, false},
            MouseReleased         = {false, false},
            MouseDownDuration     = {-1, -1},
            MouseDownDurationPrev = {-1, -1},

            MouseClickedPos = {[1] = {}, [2] = {}}
        },

        MovingWindow = nil,
        ActiveIDClickOffset = {x = 0, y = 0},

        HoveredWindow = nil,

        ActiveID = 0, -- Active widget
        ActiveIDWindow = 0, -- Active window

        ActiveIDIsJustActivated = false,

        ActiveIDIsAlive = nil,

        DeactivatedItemData = {
            ID = 0,
            ElapseFrame = 0,
            HasBeenEditedBefore = false,
            IsAlive = false
        },

        HoveredID = 0,

        NavWindow = nil,

        FrameCount = 0,

        NextItemData = {

        },

        LastItemData = {
            ID = 0,
            ItemFlags = 0,
            StatusFlags = 0,

            Rect        = {min = {x = 0, y = 0}, max = {x = 0, y = 0}},
            NavRect     = {min = {x = 0, y = 0}, max = {x = 0, y = 0}},
            DisplayRect = {min = {x = 0, y = 0}, max = {x = 0, y = 0}},
            ClipRect    = {min = {x = 0, y = 0}, max = {x = 0, y = 0}},
            -- Shortcut = 
        },

        Font = nil, -- Currently bound *FontName* to be used with surface.SetFont
        FontSize = 18,
        FontSizeBase = 18,

        --- ImFontStackData
        FontStack = {}
    }

    hook.Add("PostGamemodeLoaded", "ImGDummyWindow", function()
        SetupDummyPanel()
    end)

    return GImRiceUI
end

local function CreateNewWindow(name)
    if not GImRiceUI then return end

    local window_id = ImHashStr(name)

    --- struct IMGUI_API ImGuiWindow
    local window = {
        ID = window_id,

        MoveID = 0,

        Name = name,
        Pos = {x = GImRiceUI.Config.WindowPos.x, y = GImRiceUI.Config.WindowPos.y},
        Size = {w = GImRiceUI.Config.WindowSize.w, h = GImRiceUI.Config.WindowSize.h}, -- Current size (==SizeFull or collapsed title bar size)
        SizeFull = {w = GImRiceUI.Config.WindowSize.w, h = GImRiceUI.Config.WindowSize.h},

        TitleBarHeight = 0,

        Active = false,

        Open = true,
        Collapsed = false,

        DrawList = {},

        IDStack = {},

        --- struct IMGUI_API ImGuiWindowTempData
        DC = {
            CursorPos         = {x = 0, y = 0},
            CursorPosPrevLine = {x = 0, y = 0},
            CursorStartPos    = {x = 0, y = 0},
            CursorMaxPos      = {x = 0, y = 0},
            IdealMaxPos       = {x = 0, y = 0},
            -- CurrLineSize   = 0,
            -- PrevLineSize   = 0,
        },

        LastFrameActive = -1
    }

    GImRiceUI.WindowsByID[window_id] = window

    insert_at(GImRiceUI.Windows, window)

    return window
end

--- void ImGui::KeepAliveID(ImGuiID id)
local function KeepAliveID(id)
    local g = GImRiceUI

    if g.ActiveID == id then
        g.ActiveIDIsAlive = id
    end

    if g.DeactivatedItemData.ID == id then
        g.DeactivatedItemData.IsAlive = true
    end
end

--- void ImGuiStyle::ScaleAllSizes
-- local function ScaleAllSizes(scale_factor)

-- end

--- ImGui::BringWindowToDisplayFront
local function BringWindowToDisplayFront(window)
    local current_front_window = GImRiceUI.Windows[#GImRiceUI.Windows]

    if current_front_window == window then return end

    for i, this_window in ipairs(GImRiceUI.Windows) do
        if this_window == window then
            remove_at(GImRiceUI.Windows, i)
            break
        end
    end

    insert_at(GImRiceUI.Windows, window)
end

--- void ImGui::SetNavWindow
local function SetNavWindow(window)
    if GImRiceUI.NavWindow ~= window then
        GImRiceUI.NavWindow = window
    end
end

--- void ImGui::FocusWindow
local function FocusWindow(window)
    if GImRiceUI.NavWindow ~= window then
        SetNavWindow(window)
    end

    if not window then return end

    BringWindowToDisplayFront(window)
end

--- void ImGui::SetFocusID

--- void ImGui::StopMouseMovingWindow()
local function StopMouseMovingWindow()
    GImRiceUI.MovingWindow = nil
end

--- void ImGui::SetActiveID
local function SetActiveID(id, window)
    local g = GImRiceUI

    if g.ActiveID ~= 0 then
        g.DeactivatedItemData.ID = g.ActiveID
        -- g.DeactivatedItemData.ElapseFrame =
        -- g.DeactivatedItemData.HasBeenEditedBefore =
        g.DeactivatedItemData.IsAlive = (g.ActiveIDIsAlive == g.ActiveID)

        if g.MovingWindow and (g.ActiveID == g.MovingWindow.MoveID) then
            print("SetActiveID() cancel MovingWindow")
            StopMouseMovingWindow()
        end
    end

    g.ActiveIDIsJustActivated = (g.ActiveID ~= id)

    g.ActiveID = id
    g.ActiveIDWindow = window

    if id ~= 0 then
        g.ActiveIDIsAlive = id
    end
end

local function ClearActiveID()
    SetActiveID(0, nil)
end

local function PushDrawCommand(draw_list, draw_call, ...)
    draw_list[#draw_list + 1] = {draw_call = draw_call, args = {...}}
end

local function AddRectFilled(draw_list, color, x, y, w, h)
    PushDrawCommand(draw_list, surface.SetDrawColor, color)
    PushDrawCommand(draw_list, surface.DrawRect, x, y, w, h)
end

local function AddRectOutline(draw_list, color, x, y, w, h, thickness)
    PushDrawCommand(draw_list, surface.SetDrawColor, color)
    PushDrawCommand(draw_list, surface.DrawOutlinedRect, x, y, w, h, thickness)
end

local function AddText(draw_list, text, font, x, y, color)
    PushDrawCommand(draw_list, surface.SetTextPos, x, y)
    PushDrawCommand(draw_list, surface.SetFont, font)
    PushDrawCommand(draw_list, surface.SetTextColor, color)
    PushDrawCommand(draw_list, surface.DrawText, text)
end

local function AddLine(draw_list, x1, y1, x2, y2, color)
    PushDrawCommand(draw_list, surface.SetDrawColor, color)
    PushDrawCommand(draw_list, surface.DrawLine, x1, y1, x2, y2)
end

local function AddTriangleFilled(draw_list, indices, color)
    PushDrawCommand(draw_list, surface.SetDrawColor, color)
    PushDrawCommand(draw_list, draw.NoTexture)
    PushDrawCommand(draw_list, surface.DrawPoly, indices)
end

local function RenderTextClipped(draw_list, text, font, x, y, color, w, h)
    surface.SetFont(font)
    local text_width, text_height = surface.GetTextSize(text)
    local need_clipping = text_width > w or text_height > h

    if need_clipping then
        PushDrawCommand(draw_list, render.SetScissorRect, x, y, x + w, y + h, true)
    end

    AddText(draw_list, text, font, x, y, color)

    if need_clipping then
        PushDrawCommand(draw_list, render.SetScissorRect, 0, 0, 0, 0, false)
    end
end

--- ImGui::RenderArrow
local function RenderArrow(draw_list, x, y, color, dir, scale)
    local h = GImRiceUI.FontSize
    local r = h * 0.40 * scale

    local center = {
        x = x + h * 0.5,
        y = y + h * 0.5 * scale
    }

    local a, b, c

    if dir == ImDir_Up or dir == ImDir_Down then
        if dir == ImDir_Up then r = -r end
        a = {x = center.x + r *  0.000, y = center.y + r *  0.750}
        b = {x = center.x + r * -0.866, y = center.y + r * -0.750}
        c = {x = center.x + r *  0.866, y = center.y + r * -0.750}
    elseif dir == ImDir_Left or dir == ImDir_Right then
        if dir == ImDir_Left then r = -r end
        a = {x = center.x + r *  0.750, y = center.y + r *  0.000}
        b = {x = center.x + r * -0.750, y = center.y + r *  0.866}
        c = {x = center.x + r * -0.750, y = center.y + r * -0.866}
    end

    AddTriangleFilled(draw_list, {a, b, c}, color)
end

local function PushID(str_id)
    local window = GImRiceUI.CurrentWindow
    if not window then return end
    insert_at(window.IDStack, str_id)
end

local function PopID()
    local window = GImRiceUI.CurrentWindow
    if not window then return end

    if #window.IDStack > 0 then
        remove_at(window.IDStack)
    end
end

local function GetID(str_id)
    local window = GImRiceUI.CurrentWindow
    if not window then return end

    local full_string = table.concat(window.IDStack, "#") .. "#" .. (str_id or "")

    return ImHashStr(full_string)
end

local function IsMouseHoveringRect(x, y, w, h)
    if GImRiceUI.IO.MousePos.x < x or
        GImRiceUI.IO.MousePos.y < y or
        GImRiceUI.IO.MousePos.x >= x + w or
        GImRiceUI.IO.MousePos.y >= y + h then

        return false
    end

    return true
end

--- bool ImGui::ItemHoverable
local function ItemHoverable(id, x, y, w, h)
    local window = GImRiceUI.CurrentWindow

    if GImRiceUI.HoveredWindow ~= window then
        return false
    end

    if not IsMouseHoveringRect(x, y, w, h) then
        return false
    end

    if GImRiceUI.HoveredID ~= 0 and GImRiceUI.HoveredID ~= id then
        return false
    end

    if id ~= 0 then
        GImRiceUI.HoveredID = id
    end

    return true
end

local function ButtonBehavior(button_id, x, y, w, h)
    if not GImRiceUI.CurrentWindow or not GImRiceUI.CurrentWindow.Open then
        return false, false, false
    end

    local io = GImRiceUI.IO
    local hovered = ItemHoverable(button_id, x, y, w, h)
    local pressed = false

    if hovered and io.MouseClicked[1] then
        pressed = true

        SetActiveID(button_id, GImRiceUI.CurrentWindow) -- FIXME: is this correct?
    end

    local held = false
    if GImRiceUI.ActiveID == button_id then
        if GImRiceUI.ActiveIDIsJustActivated then
            GImRiceUI.ActiveIDClickOffset.x = io.MousePos.x - x
            GImRiceUI.ActiveIDClickOffset.y = io.MousePos.y - y
        end

        if io.MouseDown[1] then
            held = true
        else
            ClearActiveID()
        end
    end

    return pressed, hovered, held
end

--- static inline ImVec2 CalcWindowMinSize
-- local function CalcWindowMinSize()

-- end

--- static ImVec2 CalcWindowSizeAfterConstraint
local function CalcWindowSizeAfterConstraint(window, size_desired)
    return {
        w = ImMax(size_desired.w, GImRiceUI.Style.WindowMinSize.w),
        h = ImMax(size_desired.h, GImRiceUI.Style.WindowMinSize.h)
    }
end

--- static void CalcResizePosSizeFromAnyCorner
local function CalcResizePosSizeFromAnyCorner(window, corner_target, corner_pos)
    local pos_min = {
        x = ImLerp(corner_target.x, window.Pos.x, corner_pos.x),
        y = ImLerp(corner_target.y, window.Pos.y, corner_pos.y)
    }
    local pos_max = {
        x = ImLerp(window.Pos.x + window.Size.w, corner_target.x, corner_pos.x),
        y = ImLerp(window.Pos.y + window.Size.h, corner_target.y, corner_pos.y)
    }
    local size_expected = {
        w = pos_max.x - pos_min.x,
        h = pos_max.y - pos_min.y
    }
    local size_constrained = CalcWindowSizeAfterConstraint(window, size_expected)

    local out_pos = {x = pos_min.x, y = pos_min.y}
    if corner_pos.x == 0 then
        out_pos.x = out_pos.x - (size_constrained.w - size_expected.w)
    end
    if corner_pos.y == 0 then
        out_pos.y = out_pos.y - (size_constrained.h - size_expected.h)
    end

    return out_pos, size_constrained
end

--- static int ImGui::UpdateWindowManualResize
local function UpdateWindowManualResize(window)
    local grip_draw_size = ImTrunc(ImMax(GImRiceUI.FontSize * 1.35, GImRiceUI.Style.WindowRounding + 1.0 + GImRiceUI.FontSize * 0.2))
    local grip_hover_inner_size = ImTrunc(grip_draw_size * 0.75)
    local grip_hover_outer_size = GImRiceUI.WindowsBorderHoverPadding + 1

    PushID("#RESIZE")

    local pos_target = {x = INF, y = INF}
    local size_target = {w = INF, h = INF}

    local resize_grip_colors = {}
    for i = 1, #ImResizeGripDef do
        local corner_pos = ImResizeGripDef[i].CornerPos
        local inner_dir = ImResizeGripDef[i].InnerDir

        local corner = {
            x = window.Pos.x + corner_pos.x * window.Size.w,
            y = window.Pos.y + corner_pos.y * window.Size.h
        }

        local resize_rect = {
            x = corner.x - inner_dir.x * grip_hover_outer_size,
            y = corner.y - inner_dir.y * grip_hover_outer_size,
            w = inner_dir.x * (grip_hover_inner_size + grip_hover_outer_size),
            h = inner_dir.y * (grip_hover_inner_size + grip_hover_outer_size)
        }

        if resize_rect.w < 0 then
            resize_rect.x = resize_rect.x + resize_rect.w
            resize_rect.w = -resize_rect.w
        end
        if resize_rect.h < 0 then
            resize_rect.y = resize_rect.y + resize_rect.h
            resize_rect.h = -resize_rect.h
        end

        local pressed, hovered, held = ButtonBehavior(GetID(i), resize_rect.x, resize_rect.y, resize_rect.w, resize_rect.h)

        if hovered or held then
            GImRiceUI.MovingWindow = nil
            if i == 1 then
                SetMouseCursor("sizenwse")
            elseif i == 2 then
                SetMouseCursor("sizenesw")
            end
        end

        if held then
            -- TODO: simplify, extract into funcs above
            local min_size = GImRiceUI.Style.WindowMinSize
            local max_size = {w = INF, h = INF}

            local clamp_rect = {
                Min = {x = window.Pos.x + min_size.w, y = window.Pos.y + min_size.h},
                Max = {x = window.Pos.x + max_size.w, y = window.Pos.y + max_size.h}
            } -- visibility rect?

            local clamp_min = {
                x = (corner_pos.x == 1.0) and clamp_rect.Min.x or -INF,
                y = (corner_pos.y == 1.0) and clamp_rect.Min.y or -INF
            }

            local clamp_max = {
                x = (corner_pos.x == 0.0) and clamp_rect.Max.x or INF,
                y = (corner_pos.y == 0.0) and clamp_rect.Max.y or INF
            }

            local corner_target = {
                x = GImRiceUI.IO.MousePos.x - GImRiceUI.ActiveIDClickOffset.x + ImLerp(inner_dir.x * grip_hover_outer_size, inner_dir.x * -grip_hover_inner_size, corner_pos.x),
                y = GImRiceUI.IO.MousePos.y - GImRiceUI.ActiveIDClickOffset.y + ImLerp(inner_dir.y * grip_hover_outer_size, inner_dir.y * -grip_hover_inner_size, corner_pos.y)
            }

            corner_target.x = ImClamp(corner_target.x, clamp_min.x, clamp_max.x)
            corner_target.y = ImClamp(corner_target.y, clamp_min.y, clamp_max.y)

            pos_target, size_target = CalcResizePosSizeFromAnyCorner(window, corner_target, corner_pos)
        end

        local grip_color = GImRiceUI.Style.Colors.ResizeGrip
        if i == 2 then
            grip_color = ImNoColor
        end
        if pressed or held then
            grip_color = GImRiceUI.Style.Colors.ResizeGripActive
        elseif hovered then
            grip_color = GImRiceUI.Style.Colors.ResizeGripHovered
        end
        resize_grip_colors[i] = grip_color
    end

    if size_target.w ~= INF and (window.Size.w ~= size_target.w or window.SizeFull.w ~= size_target.w) then
        window.Size.w = size_target.w
        window.SizeFull.w = size_target.w
    end

    if size_target.h ~= INF and (window.Size.h ~= size_target.h or window.SizeFull.h ~= size_target.h) then
        window.Size.h = size_target.h
        window.SizeFull.h = size_target.h
    end

    if pos_target.x ~= INF and window.Pos.x ~= ImFloor(pos_target.x) then
        window.Pos.x = ImFloor(pos_target.x)
    end

    if pos_target.y ~= INF and window.Pos.y ~= ImFloor(pos_target.y) then
        window.Pos.y = ImFloor(pos_target.y)
    end

    PopID()

    return resize_grip_colors
end

local function CloseButton(id, x, y, w, h)
    local window = GImRiceUI.CurrentWindow
    local pressed, hovered = ButtonBehavior(id, x, y, w, h)

    if hovered then
        AddRectFilled(window.DrawList, GImRiceUI.Style.Colors.ButtonHovered, x, y, w, h)
    end

    --- DrawLine draws lines of different thickness, why? Antialiasing
    -- AddText(window.DrawList, "X", "ImCloseButtonCross", x + w * 0.25, y, GImRiceUI.Style.Colors.Text)
    local center_x = x + w * 0.5 - 0.5
    local center_y = y + h * 0.5 - 0.5
    local cross_extent = w * 0.5 * 0.7071 - 1

    AddLine(window.DrawList, center_x - cross_extent, center_y - cross_extent,
            center_x + cross_extent, center_y + cross_extent,
            GImRiceUI.Style.Colors.Text)

    AddLine(window.DrawList, center_x + cross_extent, center_y - cross_extent,
            center_x - cross_extent, center_y + cross_extent,
            GImRiceUI.Style.Colors.Text)

    return pressed
end

local function CollapseButton(id, x, y, w, h)
    local window = GImRiceUI.CurrentWindow
    local pressed, hovered = ButtonBehavior(id, x, y, w, h)

    if hovered then
        AddRectFilled(window.DrawList, GImRiceUI.Style.Colors.ButtonHovered, x, y, w, h)
    end

    if window.Collapsed then
        RenderArrow(window.DrawList, x, y, GImRiceUI.Style.Colors.Text, ImDir_Right, 1)
    else
        RenderArrow(window.DrawList, x, y, GImRiceUI.Style.Colors.Text, ImDir_Down, 1)
    end

    return pressed
end

--- ImGui::RenderFrame, ImGui::RenderFrameBorder
-- local function RenderFrame(draw_list, x, y, w, h)

-- end

--- ImGui::RenderMouseCursor

--- ImGui::RenderWindowDecorations
local function RenderWindowDecorations(window, titlebar_is_highlight, resize_grip_colors, resize_grip_draw_size)
    local g = GImRiceUI

    local title_color
    if titlebar_is_highlight then
        title_color = g.Style.Colors.TitleBgActive
    else
        title_color = g.Style.Colors.TitleBg
    end

    local border_width = g.Config.WindowBorderWidth

    if window.Collapsed then
        AddRectFilled(window.DrawList, g.Style.Colors.TitleBgCollapsed,
            window.Pos.x + border_width, window.Pos.y + border_width,
            window.Size.w - 2 * border_width,
            window.TitleBarHeight - 2 * border_width)
        AddRectOutline(window.DrawList, g.Style.Colors.Border,
            window.Pos.x, window.Pos.y,
            window.Size.w, window.TitleBarHeight, border_width)
    else
        AddRectFilled(window.DrawList, title_color,
            window.Pos.x + border_width, window.Pos.y + border_width,
            window.Size.w - 2 * border_width,
            window.TitleBarHeight)
        -- Window background
        AddRectFilled(window.DrawList, g.Style.Colors.WindowBg,
            window.Pos.x + border_width, window.Pos.y + window.TitleBarHeight + border_width,
            window.Size.w - 2 * border_width, window.Size.h - window.TitleBarHeight - border_width)

        -- Resize grip(s)
        for i = 1, #ImResizeGripDef do
            local corner_pos = ImResizeGripDef[i].CornerPos
            local inner_dir = ImResizeGripDef[i].InnerDir

            local corner = {
                x = window.Pos.x + corner_pos.x * window.Size.w,
                y = window.Pos.y + corner_pos.y * window.Size.h
            }

            local padding = border_width * 1.3
            local grip_indices -- TODO: this is hard to maintain
            if inner_dir.x == -1 and inner_dir.y == -1 then
                grip_indices = {
                    {x = corner.x + padding * inner_dir.x, y = corner.y + padding * inner_dir.y}, -- Bottom-right corner
                    {x = corner.x - resize_grip_draw_size - padding, y = corner.y - padding}, -- Left
                    {x = corner.x + padding * inner_dir.x, y = corner.y - resize_grip_draw_size - padding} -- Up
                }
            elseif inner_dir.x  == 1 and inner_dir.y == -1 then
                grip_indices = {
                    {x = corner.x + padding * inner_dir.x, y = corner.y + padding * inner_dir.y}, -- Bottom-left corner
                    {x = corner.x + padding * inner_dir.x, y = corner.y - resize_grip_draw_size - padding}, -- Up
                    {x = corner.x + resize_grip_draw_size + padding, y = corner.y - padding} -- Right
                }
            end

            AddTriangleFilled(window.DrawList, grip_indices, resize_grip_colors[i])
        end

        -- RenderWindowOuterBorders?
        AddRectOutline(window.DrawList, g.Style.Colors.Border,
            window.Pos.x, window.Pos.y,
            window.Size.w, window.Size.h, border_width)
    end
end

--- ImGui::RenderWindowTitleBarContents
local function RenderWindowTitleBarContents(window)
    local g = GImRiceUI

    local pad_l = g.Style.FramePadding.x
    local pad_r = g.Style.FramePadding.x
    local button_size = g.FontSize

    local collapse_button_size = button_size -- TODO: impl has_close_button and etc. based
    local collapse_button_x = window.Pos.x + pad_l
    local collapse_button_y = window.Pos.y + g.Style.FramePadding.y

    local close_button_size = button_size
    local close_button_x = window.Pos.x + window.Size.w - button_size - pad_r
    local close_button_y = window.Pos.y + g.Style.FramePadding.y

    if CollapseButton(GetID("#COLLAPSE"), collapse_button_x, collapse_button_y, collapse_button_size, collapse_button_size) then
        window.Collapsed = not window.Collapsed
    end

    if CloseButton(GetID("#CLOSE"), close_button_x, close_button_y, close_button_size, close_button_size) then
        window.Open = false
    end

    -- Title text
    surface.SetFont(g.Font) -- TODO: layouting
    local _, text_h = surface.GetTextSize(window.Name)
    local text_clip_width = window.Size.w - window.TitleBarHeight - close_button_size - collapse_button_size
    RenderTextClipped(window.DrawList, window.Name, g.Font,
        window.Pos.x + window.TitleBarHeight, window.Pos.y + (window.TitleBarHeight - text_h) / 1.3,
        g.Style.Colors.Text,
        text_clip_width, window.Size.h)
end

local function Render()
    for _, window in ipairs(GImRiceUI.Windows) do
        if window and window.Open and window.DrawList then
            for _, cmd in ipairs(window.DrawList) do
                cmd.draw_call(unpack(cmd.args))
            end
        end
    end
end

--- void ImGui::StartMouseMovingWindow
local function StartMouseMovingWindow(window)
    FocusWindow(window)
    SetActiveID(window.MoveID, window)

    GImRiceUI.ActiveIDClickOffset = {
        x = GImRiceUI.IO.MouseClickedPos[1].x - window.Pos.x,
        y = GImRiceUI.IO.MouseClickedPos[1].y - window.Pos.y
    }

    GImRiceUI.MovingWindow = window
end

--- void ImGui::UpdateMouseMovingWindowNewFrame
local function UpdateMouseMovingWindowNewFrame()
    local window = GImRiceUI.MovingWindow

    if window then
        if GImRiceUI.IO.MouseDown[1] then
            window.Pos.x = GImRiceUI.IO.MousePos.x - GImRiceUI.ActiveIDClickOffset.x
            window.Pos.y = GImRiceUI.IO.MousePos.y - GImRiceUI.ActiveIDClickOffset.y

            FocusWindow(GImRiceUI.MovingWindow)
        else
            StopMouseMovingWindow()
            ClearActiveID()
        end
    -- else
    end
end

--- void ImGui::UpdateMouseMovingWindowEndFrame()
local function UpdateMouseMovingWindowEndFrame()
    if GImRiceUI.ActiveID ~= 0 or GImRiceUI.HoveredID ~= 0 then return end

    local hovered_window = GImRiceUI.HoveredWindow

    if GImRiceUI.IO.MouseClicked[1] then
        if hovered_window then
            StartMouseMovingWindow(hovered_window)
        else -- TODO: investigate elseif (hovered_window == nil and g.NavWindow == nil) 
            FocusWindow(nil)
            GImRiceUI.ActiveIDWindow = 0
        end
    end
end

--- ImGui::FindWindowByID
local function FindWindowByID(id)
    if not GImRiceUI then return end

    return GImRiceUI.WindowsByID[id]
end

--- ImGui::FindWindowByName
local function FindWindowByName(name)
    local id = ImHashStr(name)
    return FindWindowByID(id)
end

local function Begin(name)
    if name == nil or name == "" then return false end

    local window = FindWindowByName(name)
    local window_just_created = (window == nil)
    if window_just_created then
        window = CreateNewWindow(name)
    end

    local current_frame = GImRiceUI.FrameCount
    local first_begin_of_the_frame = (window.LastFrameActive ~= current_frame)
    local window_just_activated_by_user = (window.LastFrameActive < (current_frame - 1))

    if first_begin_of_the_frame then
        window.LastFrameActive = current_frame
    end

    local window_id = window.ID

    GImRiceUI.CurrentWindow = window

    for i = #window.IDStack, 1, -1 do
        window.IDStack[i] = nil
    end
    PushID(window_id)
    window.MoveID = GetID("#MOVE") -- TODO: investigate

    insert_at(GImRiceUI.CurrentWindowStack, window)

    window.Active = true

    window.TitleBarHeight = GImRiceUI.FontSize + GImRiceUI.Style.FramePadding.y * 2

    if window.Collapsed then
        window.Active = false

        window.Size.h = window.TitleBarHeight
    else
        window.Size.h = window.SizeFull.h
    end

    for i = #window.DrawList, 1, -1 do
        window.DrawList[i] = nil
    end

    local resize_grip_colors
    if not window.Collapsed then
        resize_grip_colors = UpdateWindowManualResize(window)
    end
    local resize_grip_draw_size = ImTrunc(ImMax(GImRiceUI.FontSize * 1.10, GImRiceUI.Style.WindowRounding + 1.0 + GImRiceUI.FontSize * 0.2));

    local title_bar_is_highlight = (GImRiceUI.NavWindow == window) -- TODO: proper cond, just simple highlight now

    RenderWindowDecorations(window, title_bar_is_highlight, resize_grip_colors, resize_grip_draw_size)

    RenderWindowTitleBarContents(window)

    return not window.Collapsed
end

local function End()
    local window = GImRiceUI.CurrentWindow
    if not window then return end

    PopID()
    remove_at(GImRiceUI.CurrentWindowStack)
    -- TODO: SetCurrentWindow
    GImRiceUI.CurrentWindow = GImRiceUI.CurrentWindowStack[#GImRiceUI.CurrentWindowStack]
end

--- FIXME: UpdateHoveredWindowAndCaptureFlags???
local function FindHoveredWindow()
    GImRiceUI.HoveredWindow = nil

    local x, y, w, h

    for i = #GImRiceUI.Windows, 1, -1 do
        local window = GImRiceUI.Windows[i]

        if window and window.Open then
            x, y, w, h = window.Pos.x, window.Pos.y, window.Size.w, window.Size.h

            local hit = IsMouseHoveringRect(x, y, w, h)

            if hit and GImRiceUI.HoveredWindow == nil then
                GImRiceUI.HoveredWindow = window

                break
            end
        end
    end

    --- Our window isn't actually a window. It doesn't "exist"
    -- need to block input to other game ui like Derma panels, and prevent render artifacts
    if GImRiceUI.HoveredWindow then
        AttachDummyPanel(0, 0, ScrW(), ScrH())
    else
        if x and y and w and h then
            AttachDummyPanel(x, y, w, h)
        else
            DetachDummyPanel()
        end
    end
end

--- ImGui::UpdateMouseInputs()
local function UpdateMouseInputs()
    local io = GImRiceUI.IO -- pointer to IO field

    io.MousePos.x = io.MouseX()
    io.MousePos.y = io.MouseY()
    GImRiceUI.FrameCount = GImRiceUI.FrameCount + 1

    for i = 1, #MouseButtonMap do
        local button_down = io.IsMouseDown(MouseButtonMap[i])

        io.MouseClicked[i] = button_down and (io.MouseDownDuration[i] < 0)

        if io.MouseClicked[i] then
            io.MouseClickedPos[i] = {x = io.MousePos.x, y = io.MousePos.y}
        end

        io.MouseReleased[i] = not button_down and (io.MouseDownDuration[i] >= 0)

        if button_down then
            if io.MouseDownDuration[i] < 0 then
                io.MouseDownDuration[i] = 0
            else
                io.MouseDownDuration[i] = io.MouseDownDuration[i] + 1
            end
        else
            io.MouseDownDuration[i] = -1.0
        end

        io.MouseDownDurationPrev[i] = io.MouseDownDuration[i]

        io.MouseDown[i] = button_down
    end
end

local function NewFrame()
    if not GImRiceUI or not GImRiceUI.Initialized then return end

    for i = #GImRiceUI.CurrentWindowStack, 1, -1 do
        GImRiceUI.CurrentWindowStack[i] = nil
    end
    GImRiceUI.CurrentWindow = nil

    UpdateFontsNewFrame()

    UpdateMouseInputs()

    GImRiceUI.HoveredID = 0
    GImRiceUI.HoveredWindow = nil

    -- if (g.ActiveId != 0 && g.ActiveIdIsAlive != g.ActiveId && g.ActiveIdPreviousFrame == g.ActiveId)
    -- {
    --     IMGUI_DEBUG_LOG_ACTIVEID("NewFrame(): ClearActiveID() because it isn't marked alive anymore!\n");
    --     ClearActiveID();
    -- }

    GImRiceUI.ActiveIDIsJustActivated = false

    FindHoveredWindow()

    UpdateMouseMovingWindowNewFrame()
end

--- TODO: FrameCountEnded
local function EndFrame()
    UpdateFontsEndFrame()

    UpdateMouseMovingWindowEndFrame()
end

--- void ImGui::Shutdown()

-- test here

CreateNewContext()

hook.Add("PostRender", "ImRiceUI", function()
    cam.Start2D()

    NewFrame()

    -- Temporary, internal function used
    -- UpdateCurrentFontSize(ImMax(10, math.abs(90 * math.sin(SysTime()))))

    Begin("Hello World!")
    End()

    Begin("ImRiceUI Demo")
    End()

    EndFrame()

    Render()

    cam.End2D()
end)