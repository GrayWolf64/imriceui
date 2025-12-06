--- All the things strongly related to GMod go here
-- TODO: Rename the dummy panel?
local ImRiceUI = ImRiceUI

local IsValid = IsValid
local SysTime = SysTime
local ScrW = ScrW
local ScrH = ScrH

local ImVector, ImVec2, ImVec4, ImVec1, ImRect = include("imriceui_internal.lua")

--- VGUIMousePressAllowed hook can only block mouse clicks to derma elements
-- and can't block mouse hovering
local GDummyPanel = GDummyPanel or nil

local function SetupDummyPanel()
    if IsValid(GDummyPanel) then
        GDummyPanel:Remove()
        GDummyPanel = nil
    end

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

    GDummyPanel.Paint = function(self, w, h) -- FIXME: block derma modal panels
        -- surface.SetDrawColor(0, 255, 0)
        -- surface.DrawOutlinedRect(0, 0, w, h, 4)
    end
end

local function AttachDummyPanel(pos, size)
    if not IsValid(GDummyPanel) then return end

    GDummyPanel:SetPos(pos.x, pos.y)
    GDummyPanel:SetSize(size.x, size.y)
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

local ImRiceUI_ImplGMOD_Data = ImRiceUI_ImplGMOD_Data or nil

local function ImRiceUI_ImplGMOD_Init()
    ImRiceUI_ImplGMOD_Data = {
        Time = 0
    }

    hook.Add("PostGamemodeLoaded", "ImGDummyWindow", function()
        SetupDummyPanel()
    end)
end

local function ImRiceUI_ImplGMOD_Shutdown()
    hook.Remove("PostGamemodeLoaded", "ImGDummyWindow")
end

local function ImRiceUI_ImplGMOD_NewFrame()
    local io = ImRiceUI:GetIO()
    local bd = ImRiceUI_ImplGMOD_Data

    io.DisplaySize = ImVec2(ScrW(), ScrH())

    local current_time = SysTime()
    io.DeltaTime = current_time - bd.Time
    bd.Time = current_time
end

return SetupDummyPanel, AttachDummyPanel, DetachDummyPanel, SetMouseCursor,
    ImRiceUI_ImplGMOD_Init, ImRiceUI_ImplGMOD_Shutdown, ImRiceUI_ImplGMOD_NewFrame