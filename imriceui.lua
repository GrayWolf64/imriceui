--- ImGui for Garry's Mod written in pure Lua
--
ImRiceUI = ImRiceUI or {}

local ipairs = ipairs
local assert = assert

local ScrW = ScrW
local ScrH = ScrH

local SysTime = SysTime

local GetMouseX = gui.MouseX
local GetMouseY = gui.MouseY

local INF = math.huge

local GImRiceUI = nil

local ImDir_Left  = 0
local ImDir_Right = 1
local ImDir_Up    = 2
local ImDir_Down  = 3

--- font_data size range: 4~255
local IM_FONT_SIZE_MIN = 4
local IM_FONT_SIZE_MAX = 255

local ImVector, ImVec2, ImVec4, ImVec1, ImRect = include("imriceui_internal.lua")

local ImResizeGripDef = {
    {CornerPos = ImVec2(1, 1), InnerDir = ImVec2(-1, -1)}, -- Bottom right grip
    {CornerPos = ImVec2(0, 1), InnerDir = ImVec2( 1, -1)} -- Bottom left
}

local SetupDummyPanel, AttachDummyPanel, DetachDummyPanel, SetMouseCursor,
    ImRiceUI_ImplGMOD_Init, ImRiceUI_ImplGMOD_Shutdown, ImRiceUI_ImplGMOD_NewFrame = include("imriceui_impl_gmod.lua")

--- Use FNV1a, as one ImGui FIXME suggested
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

    assert(hash ~= 0, "ImHash = 0!")

    return hash
end

local ImMin = math.min
local ImMax = math.max
local ImFloor = math.floor
local ImRound = math.Round
local function ImLerp(a, b, t) return a + (b - a) * t end
local function ImClamp(v, min, max) return ImMin(ImMax(v, min), max) end
local function ImTrunc(f) return ImFloor(f + 0.5) end

local ImNoColor, StyleColorsDark,
    AddDrawCmd, AddRectFilled, AddRectOutline, AddText, AddLine,
    AddTriangleFilled, RenderTextClipped = include("imriceui_draw.lua")

--- ImGui::RenderArrow
local function RenderArrow(draw_list, pos, color, dir, scale)
    local h = GImRiceUI.FontSize
    local r = h * 0.40 * scale

    center = pos + ImVec2(h * 0.50, h * 0.50 * scale)

    local a, b, c

    if dir == ImDir_Up or dir == ImDir_Down then
        if dir == ImDir_Up then r = -r end
        a = ImVec2( 0.000,  0.750) * r
        b = ImVec2(-0.866, -0.750) * r
        c = ImVec2( 0.866, -0.750) * r
    elseif dir == ImDir_Left or dir == ImDir_Right then
        if dir == ImDir_Left then r = -r end
        a = ImVec2( 0.750,  0.000) * r
        b = ImVec2(-0.750,  0.866) * r
        c = ImVec2(-0.750, -0.866) * r
    end

    AddTriangleFilled(draw_list, {center + a, center + b, center + c}, color)
end

local FontDataDefault, FontCopy = include("imriceui_h.lua")

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
    local g = GImRiceUI

    local final_size
    if restore_font_size_after_scaling > 0 then
        final_size = restore_font_size_after_scaling
    else
        final_size = 0
    end

    if final_size == 0 then
        final_size = g.FontSizeBase

        final_size = final_size * g.Style.FontScaleMain
    end

    -- Again, due to gmod font system limitation
    final_size = ImRound(final_size)
    final_size = ImClamp(final_size, IM_FONT_SIZE_MIN, IM_FONT_SIZE_MAX)

    g.FontSize = final_size

    local font_data_new = FontCopy(ImFontAtlas.Fonts[g.Font])

    font_data_new.size = final_size

    local font_new = ImFontAtlas:AddFont(font_data_new)
    g.Font = font_new
end

--- void ImGui::SetCurrentFont
local function SetCurrentFont(font_name, font_size_before_scaling, font_size_after_scaling)
    local g = GImRiceUI

    g.Font = font_name
    g.FontSizeBase = font_size_before_scaling
    UpdateCurrentFontSize(font_size_after_scaling) -- TODO: investigate
end

local function PushFont(font_name, font_size_base) -- FIXME: checks not implemented?
    local g = GImRiceUI

    if not font_name or font_name == "" then
        font_name = g.Font
    end

    g.FontStack:push_back({
        Font = font_name,
        FontSizeBeforeScaling = g.FontSizeBase,
        FontSizeAfterScaling = g.FontSize
    })

    if font_size_base == 0 then
        font_size_base = g.FontSizeBase
    end

    SetCurrentFont(font_name, font_size_base, 0)
end

local function PopFont()
    local g = GImRiceUI

    if g.FontStack:size() == 0 then return end

    local font_stack_data = g.FontStack:peek()
    SetCurrentFont(font_stack_data.Font, font_stack_data.FontSizeBeforeScaling, font_stack_data.FontSizeAfterScaling)

    g.FontStack:pop_back()
end

local function GetDefaultFont() -- FIXME: fix impl
    return ImFontAtlas:AddFont({
        font = "ProggyCleanTT",
        size = 18
    })
end

--- void ImGui::UpdateFontsNewFrame
local function UpdateFontsNewFrame() -- TODO: investigate
    local g = GImRiceUI

    g.Font = GetDefaultFont()

    local font_stack_data  = {
        Font = g.Font,
        FontSizeBeforeScaling = g.Style.FontSizeBase,
        FontSizeAfterScaling = g.Style.FontSizeBase
    }

    SetCurrentFont(font_stack_data.Font, font_stack_data.FontSizeBeforeScaling, 0)

    g.FontStack:push_back(font_stack_data)
end

--- void ImGui::UpdateFontsEndFrame
local function UpdateFontsEndFrame()
    PopFont()
end

local DefaultConfig = {
    WindowSize = {w = 500, h = 480},
    WindowPos = {x = 60, y = 60}
}

--- Index starts from 1
local MouseButtonMap = {
    [1] = MOUSE_LEFT,
    [2] = MOUSE_RIGHT
}

--- struct ImGuiContext
-- ImGuiContext::ImGuiContext(ImFontAtlas* shared_font_atlas)
local function CreateContext()
    GImRiceUI = {
        Style = {
            FramePadding = ImVec2(4, 3),

            WindowRounding = 0,

            Colors = StyleColorsDark,

            FontSizeBase = 18,
            FontScaleMain = 1,

            WindowMinSize = ImVec2(60, 60),

            FrameBorderSize = 1,
            ItemSpacing = ImVec2(8, 4)
        },

        Config = DefaultConfig,
        Initialized = true,

        Windows = ImVector(), -- Windows sorted in display order, back to front
        WindowsByID = {}, -- Map window's ID to window ref

        WindowsBorderHoverPadding = 0,

        CurrentWindowStack = ImVector(),
        CurrentWindow = nil,

        IO = { -- TODO: make IO independent?
            MousePos = ImVec2(),
            IsMouseDown = input.IsMouseDown,

            --- Just support 2 buttons now, L & R
            MouseDown             = {false, false},
            MouseClicked          = {false, false},
            MouseReleased         = {false, false},
            MouseDownDuration     = {-1, -1},
            MouseDownDurationPrev = {-1, -1},

            MouseDownOwned = {nil, nil},

            MouseClickedTime = {nil, nil},
            MouseReleasedTime = {nil, nil},

            MouseClickedPos = {ImVec2(), ImVec2()},

            WantCaptureMouse = nil,
            -- WantCaptureKeyboard = nil,
            -- WantTextInput = nil,

            DeltaTime = 1 / 60,
            Framerate = 0
        },

        MovingWindow = nil,
        ActiveIDClickOffset = ImVec2(),

        HoveredWindow = nil,

        ActiveID = 0, -- Active widget
        ActiveIDWindow = nil, -- Active window

        ActiveIDIsJustActivated = false,

        ActiveIDIsAlive = nil,

        ActiveIDPreviousFrame = 0,

        DeactivatedItemData = {
            ID = 0,
            ElapseFrame = 0,
            HasBeenEditedBefore = false,
            IsAlive = false
        },

        HoveredID = 0,

        NavWindow = nil,

        FrameCount = 0,

        FrameCountEnded = -1,
        FrameCountRendered = -1,

        Time = 0,

        NextItemData = {

        },

        LastItemData = {
            ID = 0,
            ItemFlags = 0,
            StatusFlags = 0,

            Rect        = ImRect(),
            NavRect     = ImRect(),
            DisplayRect = ImRect(),
            ClipRect    = ImRect()
            -- Shortcut = 
        },

        Font = nil, -- Currently bound *FontName* to be used with surface.SetFont
        FontSize = 18,
        FontSizeBase = 18,

        --- Contains ImFontStackData
        FontStack = ImVector(),

        -- StackSizesInBeginForCurrentWindow = nil,

        --- Misc
        FramerateSecPerFrame = {}, -- size = 60
        FramerateSecPerFrameIdx = 0,
        FramerateSecPerFrameCount = 0,
        FramerateSecPerFrameAccum = 0,

        WantCaptureMouseNextFrame = -1,
        -- WantCaptureKeyboardNextFrame = -1,
        -- WantTextInputNextFrame = -1
    }

    for i = 0, 59 do GImRiceUI.FramerateSecPerFrame[i] = 0 end

    return GImRiceUI
end

--- void ImGui::DestroyContext
-- local function DestroyContext()

-- end

local function CreateNewWindow(name)
    local g = GImRiceUI

    if not g then return end

    local window_id = ImHashStr(name)

    --- struct IMGUI_API ImGuiWindow
    local window = {
        ID = window_id,

        MoveID = 0,

        Name = name,
        Pos = ImVec2(g.Config.WindowPos.x, g.Config.WindowPos.y),
        Size = ImVec2(g.Config.WindowSize.w, g.Config.WindowSize.h), -- Current size (==SizeFull or collapsed title bar size)
        SizeFull = ImVec2(g.Config.WindowSize.w, g.Config.WindowSize.h),

        TitleBarHeight = 0,

        Active = false,
        WasActive = false,

        Collapsed = false,

        SkipItems = false,

        SkipRefresh = false,

        Hidden = false,

        HiddenFramesCanSkipItems = 0,
        HiddenFramesCannotSkipItems = 0,
        HiddenFramesForRenderOnly = 0,

        HasCloseButton = true,

        --- struct ImDrawList
        DrawList = {
            CmdBuffer = {},

            _CmdHeader = {},
            _ClipRectStack = {}
        },

        IDStack = ImVector(),

        --- struct IMGUI_API ImGuiWindowTempData
        DC = {
            CursorPos         = ImVec2(),
            CursorPosPrevLine = ImVec2(),
            CursorStartPos    = ImVec2(),
            CursorMaxPos      = ImVec2(),
            IdealMaxPos       = ImVec2(),
            CurrLineSize      = ImVec2(),
            PrevLineSize      = ImVec2(),

            CurrLineTextBaseOffset = 0,
            PrevLineTextBaseOffset = 0,

            IsSameLine = false,
            IsSetPos = false,

            Indent                  = ImVec1(),
            ColumnsOffset           = ImVec1(),
            GroupOffset             = ImVec1(),
            CursorStartPosLossyness = ImVec1()
        },

        ClipRect = ImRect(),

        LastFrameActive = -1
    }

    g.WindowsByID[window_id] = window

    g.Windows:push_back(window)

    return window
end

local function TitleBarRect(window) -- TODO: as a method?
    return ImRect(window.Pos, ImVec2(window.Pos.x + window.SizeFull.x, window.Pos.y + window.TitleBarHeight))
end

--- TODO: fix drawlist
--- void ImGui::PushClipRect

--- void ImGui::PopClipRect

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

--- bool ImGui::ItemAdd
local function ItemAdd(bb, id, nav_bb_arg, extra_flags)
    local g = GImRiceUI
    local window = g.CurrentWindow

    g.LastItemData.ID = id
    g.LastItemData.Rect = bb

    if nav_bb_arg then
        g.LastItemData.NavRect = nav_bb_arg
    else
        g.LastItemData.NavRect = bb
    end

    -- g.LastItemData.ItemFlags = g.CurrentItemFlags | g.NextItemData.ItemFlags | extra_flags;
    -- g.LastItemData.StatusFlags = ImGuiItemStatusFlags_None;

    if id ~= 0 then
        KeepAliveID(id)
    end

    -- g.NextItemData.HasFlags = ImGuiNextItemDataFlags_None;
    -- g.NextItemData.ItemFlags = ImGuiItemFlags_None;

    -- local is_rect_visible = Overlaps(bb, window.ClipRect)
end

local function ItemSize(size, text_baseline_y)
    local g = GImRiceUI
    local window = g.CurrentWindow

    if window.SkipItems then return end

    local offset_to_match_baseline_y
    if text_baseline_y >= 0 then
        offset_to_match_baseline_y = ImMax(0, window.DC.CurrLineTextBaseOffset - text_baseline_y)
    else
        offset_to_match_baseline_y = 0
    end

    local line_y1
    if window.DC.IsSameLine then
        line_y1 = window.DC.CursorPosPrevLine.y
    else
        line_y1 = window.DC.CursorPos.y
    end

    local line_height = ImMax(window.DC.CurrLineSize.y, window.DC.CursorPos.y - line_y1 + size.y + offset_to_match_baseline_y)

    window.DC.CursorPosPrevLine.x = window.DC.CursorPos.x + size.x
    window.DC.CursorPosPrevLine.y = line_y1
    window.DC.CursorPos.x = ImTrunc(window.Pos.x + window.DC.Indent.x + window.DC.ColumnsOffset.x)
    window.DC.CursorPos.y = ImTrunc(line_y1 + line_height + g.Style.ItemSpacing.y)
    window.DC.CursorMaxPos.x = ImMax(window.DC.CursorMaxPos.x, window.DC.CursorPosPrevLine.x)
    window.DC.CursorMaxPos.y = ImMax(window.DC.CursorMaxPos.y, window.DC.CursorPos.y - g.Style.ItemSpacing.y)

    window.DC.PrevLineSize.y = line_height
    window.DC.CurrLineSize.y = 0
    window.DC.PrevLineTextBaseOffset = ImMax(window.DC.CurrLineTextBaseOffset, text_baseline_y)
    window.DC.CurrLineTextBaseOffset = 0
    window.DC.IsSetPos = false
    window.DC.IsSameLine = false

    --- Horizontal layout mode
    -- if (window->DC.LayoutType == ImGuiLayoutType_Horizontal)
    -- SameLine();
end

--- void ImGuiStyle::ScaleAllSizes
-- local function ScaleAllSizes(scale_factor)

-- end

--- void ImGui::BringWindowToDisplayFront(ImGuiWindow* window)
local function BringWindowToDisplayFront(window)
    local g = GImRiceUI

    local current_front_window = g.Windows:peek()

    if current_front_window == window then return end

    for i, this_window in g.Windows:iter() do
        if this_window == window then
            g.Windows:erase(i)
            break
        end
    end

    g.Windows:push_back(window)
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

local function PushID(str_id)
    local window = GImRiceUI.CurrentWindow
    if not window then return end

    window.IDStack:push_back(str_id)
end

local function PopID()
    local window = GImRiceUI.CurrentWindow
    if not window then return end

    window.IDStack:pop_back()
end

local table_concat = table.concat
local function GetID(str_id)
    local window = GImRiceUI.CurrentWindow
    if not window then return end

    local full_string = table_concat(window.IDStack._items, "#") .. "#" .. (str_id or "") -- FIXME: no _items

    return ImHashStr(full_string)
end

local function IsMouseHoveringRect(r_min, r_max)
    local rect_clipped = ImRect(r_min, r_max)

    return rect_clipped:contains_point(GImRiceUI.IO.MousePos)
end

--- void ImGui::SetHoveredID
local function SetHoveredID(id)
    local g = GImRiceUI

    g.HoveredID = id
end

--- bool ImGui::ItemHoverable
local function ItemHoverable(id, bb)
    local g = GImRiceUI

    local window = g.CurrentWindow

    if g.HoveredWindow ~= window then
        return false
    end

    if not IsMouseHoveringRect(bb.Min, bb.Max) then
        return false
    end

    if g.HoveredID ~= 0 and g.HoveredID ~= id then
        return false
    end

    if id ~= 0 then
        SetHoveredID(id)
    end

    return true
end

--- bool ImGui::IsMouseDown
local function IsMouseDown(button)
    local g = GImRiceUI

    return g.IO.MouseDown[button]
end

--- bool ImGui::IsMouseClicked
local function IsMouseClicked(button)
    local g = GImRiceUI

    if not g.IO.MouseDown[button] then
        return false
    end

    local t = g.IO.MouseDownDuration[button]
    if t < 0 then
        return false
    end

    local pressed = (t == 0)
    if not pressed then
        return false
    end

    return true
end

local function ButtonBehavior(button_id, bb) -- TODO: Move to separate file!
    local g = GImRiceUI

    local io = g.IO
    local hovered = ItemHoverable(button_id, bb)

    local pressed = false
    if hovered then
        if IsMouseClicked(1) then
            pressed = true

            SetActiveID(button_id, g.CurrentWindow) -- FIXME: is this correct?
        end
    end

    local held = false
    if g.ActiveID == button_id then
        if g.ActiveIDIsJustActivated then
            g.ActiveIDClickOffset = io.MousePos - bb.Min
        end

        if IsMouseDown(1) then
            held = true
        else
            ClearActiveID()
        end
    end

    return pressed, hovered, held
end

--- static bool IsWindowActiveAndVisible
local function IsWindowActiveAndVisible(window)
    return window.Active and not window.Hidden
end

--- static inline ImVec2 CalcWindowMinSize
-- local function CalcWindowMinSize()

-- end

--- static ImVec2 CalcWindowSizeAfterConstraint
local function CalcWindowSizeAfterConstraint(window, size_desired) -- TODO: finish
    return ImVec2(
        ImMax(size_desired.x, GImRiceUI.Style.WindowMinSize.x),
        ImMax(size_desired.y, GImRiceUI.Style.WindowMinSize.y)
    )
end

--- static void CalcResizePosSizeFromAnyCorner
local function CalcResizePosSizeFromAnyCorner(window, corner_target, corner_pos)
    local pos_min = ImVec2(
        ImLerp(corner_target.x, window.Pos.x, corner_pos.x),
        ImLerp(corner_target.y, window.Pos.y, corner_pos.y)
    )
    local pos_max = ImVec2(
        ImLerp(window.Pos.x + window.Size.x, corner_target.x, corner_pos.x),
        ImLerp(window.Pos.y + window.Size.y, corner_target.y, corner_pos.y)
    )
    local size_expected = pos_max - pos_min

    local size_constrained = CalcWindowSizeAfterConstraint(window, size_expected)

    local out_pos = ImVec2(pos_min.x, pos_min.y)

    if corner_pos.x == 0 then
        out_pos.x = out_pos.x - (size_constrained.x - size_expected.x)
    end
    if corner_pos.y == 0 then
        out_pos.y = out_pos.y - (size_constrained.y - size_expected.y)
    end

    return out_pos, size_constrained
end

--- static int ImGui::UpdateWindowManualResize
local function UpdateWindowManualResize(window, resize_grip_colors)
    local g = GImRiceUI

    if window.WasActive == false then return end

    local grip_draw_size = ImTrunc(ImMax(g.FontSize * 1.35, g.Style.WindowRounding + 1.0 + g.FontSize * 0.2))
    local grip_hover_inner_size = ImTrunc(grip_draw_size * 0.75)
    local grip_hover_outer_size = g.WindowsBorderHoverPadding + 1

    PushID("#RESIZE")

    local pos_target = ImVec2(INF, INF)
    local size_target = ImVec2(INF, INF)

    local min_size = g.Style.WindowMinSize
    local max_size = {x = INF, y = INF}

    local clamp_rect = ImRect(window.Pos + min_size, window.Pos + max_size) -- visibility rect?

    for i = 1, #ImResizeGripDef do
        local corner_pos = ImResizeGripDef[i].CornerPos
        local inner_dir = ImResizeGripDef[i].InnerDir

        local corner = ImVec2(window.Pos.x + corner_pos.x * window.Size.x, window.Pos.y + corner_pos.y * window.Size.y)

        local resize_rect = ImRect(corner - inner_dir * grip_hover_outer_size, corner + inner_dir * grip_hover_inner_size)

        if resize_rect.Min.x > resize_rect.Max.x then resize_rect.Min.x, resize_rect.Max.x = resize_rect.Max.x, resize_rect.Min.x end
        if resize_rect.Min.y > resize_rect.Max.y then resize_rect.Min.y, resize_rect.Max.y = resize_rect.Max.y, resize_rect.Min.y end

        local resize_grip_id = GetID(i)

        ItemAdd(resize_rect, resize_grip_id)
        local pressed, hovered, held = ButtonBehavior(resize_grip_id, resize_rect)

        if hovered or held then
            g.MovingWindow = nil
            if i == 1 then
                SetMouseCursor("sizenwse")
            elseif i == 2 then
                SetMouseCursor("sizenesw")
            end
        end

        if held then
            local clamp_min = ImVec2((corner_pos.x == 1.0) and clamp_rect.Min.x or -INF, (corner_pos.y == 1.0) and clamp_rect.Min.y or -INF)
            local clamp_max = ImVec2((corner_pos.x == 0.0) and clamp_rect.Max.x or INF, (corner_pos.y == 0.0) and clamp_rect.Max.y or INF)

            local corner_target = ImVec2(
                g.IO.MousePos.x - g.ActiveIDClickOffset.x + ImLerp(inner_dir.x * grip_hover_outer_size, inner_dir.x * -grip_hover_inner_size, corner_pos.x),
                g.IO.MousePos.y - g.ActiveIDClickOffset.y + ImLerp(inner_dir.y * grip_hover_outer_size, inner_dir.y * -grip_hover_inner_size, corner_pos.y)
            )

            corner_target.x = ImClamp(corner_target.x, clamp_min.x, clamp_max.x)
            corner_target.y = ImClamp(corner_target.y, clamp_min.y, clamp_max.y)

            pos_target, size_target = CalcResizePosSizeFromAnyCorner(window, corner_target, corner_pos)
        end

        local grip_color = g.Style.Colors.ResizeGrip
        if i == 2 then
            grip_color = ImNoColor
        end
        if pressed or held then
            grip_color = g.Style.Colors.ResizeGripActive
        elseif hovered then
            grip_color = g.Style.Colors.ResizeGripHovered
        end
        resize_grip_colors[i] = grip_color
    end

    if size_target.x ~= INF and (window.Size.x ~= size_target.x or window.SizeFull.x ~= size_target.x) then
        window.Size.x = size_target.x
        window.SizeFull.x = size_target.x
    end

    if size_target.y ~= INF and (window.Size.y ~= size_target.y or window.SizeFull.y ~= size_target.y) then
        window.Size.y = size_target.y
        window.SizeFull.y = size_target.y
    end

    if pos_target.x ~= INF and window.Pos.x ~= ImFloor(pos_target.x) then
        window.Pos.x = ImFloor(pos_target.x)
    end

    if pos_target.y ~= INF and window.Pos.y ~= ImFloor(pos_target.y) then
        window.Pos.y = ImFloor(pos_target.y)
    end

    PopID()
end

local function CloseButton(id, pos)
    local g = GImRiceUI
    local window = g.CurrentWindow

    local bb = ImRect(pos, pos + ImVec2(g.FontSize, g.FontSize))

    local is_clipped = not ItemAdd(bb, id)

    local pressed, hovered = ButtonBehavior(id, bb)

    if hovered then
        AddRectFilled(window.DrawList, g.Style.Colors.ButtonHovered, bb.Min, bb.Max)
    end

    --- DrawLine draws lines of different thickness, why? Antialiasing
    -- AddText(window.DrawList, "X", "ImCloseButtonCross", x + w * 0.25, y, g.Style.Colors.Text)
    local cross_center = bb:GetCenter() - ImVec2(0.5, 0.5)
    local cross_extent = g.FontSize * 0.5 * 0.7071 - 1

    AddLine(window.DrawList, cross_center + ImVec2(cross_extent, cross_extent), cross_center + ImVec2(-cross_extent, -cross_extent), g.Style.Colors.Text)
    AddLine(window.DrawList, cross_center + ImVec2(cross_extent, -cross_extent), cross_center + ImVec2(-cross_extent, cross_extent), g.Style.Colors.Text)

    return pressed
end

local function CollapseButton(id, pos)
    local g = GImRiceUI
    local window = g.CurrentWindow

    local bb = ImRect(pos, pos + ImVec2(g.FontSize, g.FontSize))

    local is_clipped = not ItemAdd(bb, id)

    local pressed, hovered = ButtonBehavior(id, bb)

    if hovered then
        AddRectFilled(window.DrawList, g.Style.Colors.ButtonHovered, bb.Min, bb.Max)
    end

    if window.Collapsed then
        RenderArrow(window.DrawList, bb.Min, g.Style.Colors.Text, ImDir_Right, 1)
    else
        RenderArrow(window.DrawList, bb.Min, g.Style.Colors.Text, ImDir_Down, 1)
    end

    return pressed
end

--- ImGui::RenderMouseCursor

--- ImGui::RenderFrame
local function RenderFrame(p_min, p_max, fill_col, borders, rounding) -- TODO: implement rounding
    local g = GImRiceUI
    local window = g.CurrentWindow

    AddRectFilled(window.DrawList, fill_col, p_min, p_max, rounding)

    local border_size = g.Style.FrameBorderSize
    if borders and border_size > 0 then
        AddRectOutline(window.DrawList, g.Style.Colors.BorderShadow, p_min + ImVec2(1, 1), p_max + ImVec2(1, 1), border_size)
        AddRectOutline(window.DrawList, g.Style.Colors.Border, p_min, p_max, border_size)
    end
end

--- ImGui::RenderWindowDecorations
local function RenderWindowDecorations(window, title_bar_rect, titlebar_is_highlight, resize_grip_colors, resize_grip_draw_size)
    local g = GImRiceUI

    local title_color
    if titlebar_is_highlight then
        title_color = g.Style.Colors.TitleBgActive
    else
        title_color = g.Style.Colors.TitleBg
    end

    local border_width = g.Style.FrameBorderSize

    if window.Collapsed then
        RenderFrame(title_bar_rect.Min, title_bar_rect.Max, g.Style.Colors.TitleBgCollapsed, true)
    else
        -- Title bar
        AddRectFilled(window.DrawList, title_color,
            title_bar_rect.Min, title_bar_rect.Max)
        -- Window background
        AddRectFilled(window.DrawList, g.Style.Colors.WindowBg,
            window.Pos + ImVec2(0, window.TitleBarHeight), window.Pos + window.Size)

        -- Resize grip(s)
        for i = 1, #ImResizeGripDef do
            local corner_pos = ImResizeGripDef[i].CornerPos
            local inner_dir = ImResizeGripDef[i].InnerDir

            local corner = window.Pos + corner_pos * window.Size

            local padding = border_width * 1.3
            local grip_indices -- TODO: this is hard to maintain
            if inner_dir.x == -1 and inner_dir.y == -1 then
                grip_indices = {
                    corner + padding * inner_dir, -- Bottom-right corner
                    ImVec2(corner.x - resize_grip_draw_size - padding, corner.y - padding), -- Left
                    ImVec2(corner.x + padding * inner_dir.x, corner.y - resize_grip_draw_size - padding) -- Up
                }
            elseif inner_dir.x  == 1 and inner_dir.y == -1 then
                grip_indices = {
                    corner + padding * inner_dir, -- Bottom-left corner
                    ImVec2(corner.x + padding * inner_dir.x, corner.y - resize_grip_draw_size - padding), -- Up
                    ImVec2(corner.x + resize_grip_draw_size + padding, corner.y - padding) -- Right
                }
            end

            AddTriangleFilled(window.DrawList, grip_indices, resize_grip_colors[i] or ImNoColor)
        end

        -- RenderWindowOuterBorders?
        AddRectOutline(window.DrawList, g.Style.Colors.Border,
            window.Pos, window.Pos + window.Size, border_width)
    end
end

--- ImGui::RenderWindowTitleBarContents
local function RenderWindowTitleBarContents(window, p_open)
    local g = GImRiceUI

    local pad_l = g.Style.FramePadding.x
    local pad_r = g.Style.FramePadding.x
    local button_size = g.FontSize

    local collapse_button_size = button_size -- TODO: impl has_close_button and etc. based
    local collapse_button_pos = ImVec2(window.Pos.x + pad_l, window.Pos.y + g.Style.FramePadding.y)

    local close_button_size = button_size
    local close_button_pos = ImVec2(window.Pos.x + window.Size.x - button_size - pad_r, window.Pos.y + g.Style.FramePadding.y)

    if CollapseButton(GetID("#COLLAPSE"), collapse_button_pos) then
        window.Collapsed = not window.Collapsed
    end

    if CloseButton(GetID("#CLOSE"), close_button_pos) then
        p_open[1] = false
        window.Hidden = true -- TODO: temporary hidden set
    end

    -- Title text
    surface.SetFont(g.Font) -- TODO: layouting
    local _, text_h = surface.GetTextSize(window.Name)
    local text_clip_width = window.Size.x - window.TitleBarHeight - close_button_size - collapse_button_size
    RenderTextClipped(window.DrawList, window.Name, g.Font,
        ImVec2(window.Pos.x + window.TitleBarHeight, window.Pos.y + (window.TitleBarHeight - text_h) / 1.3),
        g.Style.Colors.Text,
        text_clip_width, window.Size.y)
end

local unpack = unpack
local function Render()
    for _, window in GImRiceUI.Windows:iter() do
        if window and IsWindowActiveAndVisible(window) and window.DrawList then
            for _, cmd in ipairs(window.DrawList.CmdBuffer) do
                cmd.draw_call(unpack(cmd.args))
            end
        end
    end
end

--- static void SetCurrentWindow
local function SetCurrentWindow(window)
    local g = GImRiceUI
    g.CurrentWindow = window

    if window then
        local backup_skip_items = window.SkipItems
        window.SkipItems = false

        UpdateCurrentFontSize(0)

        window.SkipItems = backup_skip_items
    end
end

--- void ImGui::SetWindowPos
local function SetWindowPos(window, pos)
    local old_pos = window.Pos:copy()

    window.Pos.x = ImTrunc(pos.x)
    window.Pos.y = ImTrunc(pos.y)

    local offset = window.Pos - old_pos

    if offset.x == 0 and offset.y == 0 then return end

    -- window->DC.CursorPos += offset;
    -- window->DC.CursorMaxPos += offset;
    -- window->DC.IdealMaxPos += offset;
    -- window->DC.CursorStartPos += offset;
end

--- void ImGui::StartMouseMovingWindow
local function StartMouseMovingWindow(window)
    local g = GImRiceUI

    FocusWindow(window)
    SetActiveID(window.MoveID, window)

    g.ActiveIDClickOffset = g.IO.MouseClickedPos[1] - window.Pos

    g.MovingWindow = window
end

--- void ImGui::UpdateMouseMovingWindowNewFrame
local function UpdateMouseMovingWindowNewFrame()
    local g = GImRiceUI
    local window = g.MovingWindow

    if window then
        KeepAliveID(g.ActiveID)

        if g.IO.MouseDown[1] then
            SetWindowPos(window, g.IO.MousePos - g.ActiveIDClickOffset)

            FocusWindow(g.MovingWindow)
        else
            StopMouseMovingWindow()
            ClearActiveID()
        end
    else
        if (g.ActiveIDWindow and g.ActiveIDWindow.MoveID == g.ActiveID) then
            KeepAliveID(g.ActiveID)

            if g.IO.MouseDown[1] then
                ClearActiveID()
            end
        end
    end
end

--- void ImGui::UpdateMouseMovingWindowEndFrame()
local function UpdateMouseMovingWindowEndFrame()
    local g = GImRiceUI

    if g.ActiveID ~= 0 or g.HoveredID ~= 0 then return end

    local hovered_window = g.HoveredWindow

    if g.IO.MouseClicked[1] then
        if hovered_window then
            StartMouseMovingWindow(hovered_window)
        else -- TODO: investigate elseif (hovered_window == nil and g.NavWindow == nil) 
            FocusWindow(nil)
            g.ActiveIDWindow = nil
        end
    end
end

--- ImGui::FindWindowByID
local function FindWindowByID(id)
    local g = GImRiceUI

    if not g then return end

    return g.WindowsByID[id]
end

--- ImGui::FindWindowByName
local function FindWindowByName(name)
    local id = ImHashStr(name)
    return FindWindowByID(id)
end

-- `p_open` will be set to false when the close button is pressed.
local function Begin(name, p_open)
    local g = GImRiceUI

    if name == nil or name == "" then return false end
    -- IM_ASSERT(g.FrameCountEnded != g.FrameCount)

    local window = FindWindowByName(name)
    local window_just_created = (window == nil)
    if window_just_created then
        window = CreateNewWindow(name)
    end

    local current_frame = g.FrameCount
    local first_begin_of_the_frame = (window.LastFrameActive ~= current_frame)
    local window_just_activated_by_user = (window.LastFrameActive < (current_frame - 1))

    if first_begin_of_the_frame and not window.SkipRefresh then
        window.Active = true
        window.HasCloseButton = (p_open[1] ~= nil)
        window.ClipRect = ImVec4(-INF, -INF, INF, INF)

        window.LastFrameActive = current_frame
    end

    local window_id = window.ID

    g.CurrentWindow = window

    window.IDStack:clear_delete()

    PushID(window_id)
    window.MoveID = GetID("#MOVE") -- TODO: investigate

    g.CurrentWindowStack:push_back(window)

    window.TitleBarHeight = g.FontSize + g.Style.FramePadding.y * 2

    if window.Collapsed then
        window.Size.y = window.TitleBarHeight
    else
        window.Size.y = window.SizeFull.y
    end

    for i = #window.DrawList.CmdBuffer, 1, -1 do
        window.DrawList.CmdBuffer[i] = nil
    end

    local resize_grip_colors = {}
    if not window.Collapsed then
        UpdateWindowManualResize(window, resize_grip_colors)
    end
    local resize_grip_draw_size = ImTrunc(ImMax(g.FontSize * 1.10, g.Style.WindowRounding + 1.0 + g.FontSize * 0.2));

    local title_bar_rect = TitleBarRect(window)

    local title_bar_is_highlight = (g.NavWindow == window) -- TODO: proper cond, just simple highlight now

    RenderWindowDecorations(window, title_bar_rect, title_bar_is_highlight, resize_grip_colors, resize_grip_draw_size)

    RenderWindowTitleBarContents(window, p_open)

    return not window.Collapsed
end

local function End()
    local g = GImRiceUI

    local window = g.CurrentWindow
    if not window then return end

    PopID()
    g.CurrentWindowStack:pop_back()

    SetCurrentWindow(g.CurrentWindowStack:peek())
end

local function FindHoveredWindowEx()
    local g = GImRiceUI

    g.HoveredWindow = nil

    for i = g.Windows:size(), 1, -1 do
        local window = g.Windows:at(i)

        if not window or ((not window.WasActive) or window.Hidden) then continue end

        local hit = IsMouseHoveringRect(window.Pos, window.Pos + window.Size)

        if hit and g.HoveredWindow == nil then
            g.HoveredWindow = window

            break
        end
    end
end

--- void ImGui::UpdateHoveredWindowAndCaptureFlags
local function UpdateHoveredWindowAndCaptureFlags()
    local g = GImRiceUI
    local io = g.IO

    FindHoveredWindowEx()

    local mouse_earliest_down = -1
    local mouse_any_down = false

    for i = 1, #MouseButtonMap do
        if io.MouseClicked[i] then
            io.MouseDownOwned[i] = (g.HoveredWindow ~= nil)
        end

        mouse_any_down = mouse_any_down or io.MouseDown[i]
        if (io.MouseDown[i] or io.MouseReleased[i]) then
            if (mouse_earliest_down == -1 or (io.MouseClickedTime[i] < io.MouseClickedTime[mouse_earliest_down])) then
                mouse_earliest_down = i
            end
        end
    end

    local mouse_avail = (mouse_earliest_down == -1) or io.MouseDownOwned[mouse_earliest_down]

    if (g.WantCaptureMouseNextFrame ~= -1) then
        io.WantCaptureMouse = (g.WantCaptureMouseNextFrame ~= 0)
    else
        io.WantCaptureMouse = (mouse_avail and (g.HoveredWindow ~= nil or mouse_any_down)) -- or has_open_popup
    end

    --- Our window isn't actually a window. It doesn't "exist"
    -- need to block input to other game ui like Derma panels
    if io.WantCaptureMouse then
        AttachDummyPanel({x = 0, y = 0}, io.DisplaySize)
    else
        DetachDummyPanel()
    end
end

--- ImGui::UpdateMouseInputs()
local function UpdateMouseInputs()
    local g = GImRiceUI
    local io = g.IO

    io.MousePos.x = GetMouseX()
    io.MousePos.y = GetMouseY()

    for i = 1, #MouseButtonMap do
        local button_down = io.IsMouseDown(MouseButtonMap[i])

        io.MouseClicked[i] = button_down and (io.MouseDownDuration[i] < 0)
        io.MouseReleased[i] = not button_down and (io.MouseDownDuration[i] >= 0)

        if io.MouseClicked[i] then
            io.MouseClickedTime[i] = g.Time
            io.MouseClickedPos[i] = ImVec2(io.MousePos.x, io.MousePos.y)
        end

        if io.MouseReleased[i] then
            io.MouseReleasedTime[i] = g.Time
        end

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
    local g = GImRiceUI

    g.Time = g.Time + g.IO.DeltaTime

    if not g or not g.Initialized then return end

    g.FrameCount = g.FrameCount + 1

    -- FIXME: are lines below correct and necessary
    g.FramerateSecPerFrameAccum = g.FramerateSecPerFrameAccum + (g.IO.DeltaTime - g.FramerateSecPerFrame[g.FramerateSecPerFrameIdx])
    g.FramerateSecPerFrame[g.FramerateSecPerFrameIdx] = g.IO.DeltaTime
    g.FramerateSecPerFrameIdx = (g.FramerateSecPerFrameIdx + 1) % 60
    g.FramerateSecPerFrameCount = ImMin(g.FramerateSecPerFrameCount + 1, 60)
    if g.FramerateSecPerFrameAccum > 0 then
        g.IO.Framerate = (1.0 / (g.FramerateSecPerFrameAccum / g.FramerateSecPerFrameCount))
    else
        g.IO.Framerate = INF
    end

    g.CurrentWindowStack:clear_delete()

    g.CurrentWindow = nil

    UpdateFontsNewFrame()

    g.HoveredID = 0
    g.HoveredWindow = nil

    if (g.ActiveID ~= 0 and g.ActiveIDIsAlive ~= g.ActiveID and g.ActiveIDPreviousFrame == g.ActiveID) then
        print("NewFrame(): ClearActiveID() because it isn't marked alive anymore!")

        ClearActiveID()
    end

    g.ActiveIDPreviousFrame = g.ActiveID
    g.ActiveIDIsAlive = 0
    g.ActiveIDIsJustActivated = false

    UpdateMouseInputs()

    for _, window in g.Windows:iter() do
        window.WasActive = window.Active
        window.Active = false
    end

    UpdateHoveredWindowAndCaptureFlags()

    UpdateMouseMovingWindowNewFrame()
end

local function EndFrame()
    local g = GImRiceUI

    if g.FrameCountEnded == g.FrameCount then return end

    g.FrameCountEnded = g.FrameCount
    UpdateFontsEndFrame()

    UpdateMouseMovingWindowEndFrame()
end

--- Exposure, have to be careful with this
--
function ImRiceUI:GetIO() return GImRiceUI.IO end

--- void ImGui::Shutdown()

--- TEST HERE:

ImRiceUI_ImplGMOD_Init()

CreateContext()

hook.Add("PostRender", "ImRiceUI", function()
    cam.Start2D()

    ImRiceUI_ImplGMOD_NewFrame()

    NewFrame()

    -- Temporary, internal function used
    UpdateCurrentFontSize(ImMax(15, math.abs(90 * math.sin(SysTime()))))

    local window1_open = {true}
    Begin("Hello World!", window1_open)
    End()

    local window2_open = {true}
    Begin("ImRiceUI Demo", window2_open)
    End()

    EndFrame()

    Render()

    -- Temporary
    local g = GImRiceUI
    draw.DrawText(
        str_format(
            "ActiveID: %s\nActiveIDWindow: %s\nHoveredWindow: %s\nActiveIDIsAlive: %s\nActiveIDPreviousFrame: %s\n\nMem: %dkb\nFramerate: %d\n\n io.WantCaptureMouse: %s",
            g.ActiveID,
            g.ActiveIDWindow and g.ActiveIDWindow.ID or nil,
            g.HoveredWindow and g.HoveredWindow.ID or nil,
            g.ActiveIDIsAlive,
            g.ActiveIDPreviousFrame,
            ImRound(collectgarbage("count")),
            g.IO.Framerate,
            g.IO.WantCaptureMouse
        ), "CloseCaption_Bold", 0, 0, color_white
    )

    cam.End2D()
end)