local AceGUI = LibStub("AceGUI-3.0")

-- Lua APIs
local pairs = pairs
local assert = assert
local type = type

-- WoW APIs
local CreateFrame = CreateFrame
local UIParent = UIParent
local BackdropTemplateMixin = BackdropTemplateMixin

local Type = "SimpleIconButton"
local Version = 1

-- Callbacks --
local function onMouseDownButton(button)
	AceGUI:ClearFocus()
end

local function onMouseUpButton(button)
	button.obj:Fire("OnClickBody")
end

local function onShowButton(button)
	button.obj:Fire("OnShow")
end

local function onHideButton(button)
	button.obj:Fire("OnClose")
end

local function onEnterButton(button)
	button.obj:Fire("OnEnter")
end

local function onLeaveButton(button)
	button.obj:Fire("OnLeave")
end

-- Private Functions --
local function CreateContainer(self, frame)
	local content = CreateFrame("Frame", "ContainerFrame", frame)
	content:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	content.obj = self

	return content
end

local function CreateButton(self, container, width, height)
	local button = CreateFrame("Button", nil, self.content)
	button:SetPoint("CENTER")
	button:SetSize(width, height)
	button:RegisterForClicks("AnyDown", "AnyUp")
	button:SetHighlightTexture(130718)
	button:SetPushedTexture("Interface/Buttons/UI-Quickslot-Depress")
	button.obj = self
	self.button = button

	local texture = button:CreateTexture(nil, "BACKGROUND")
	texture:SetWidth(width)
	texture:SetHeight(height)
	texture:SetTexture(133939)
	texture:SetAllPoints(button)
	texture.obj = self
	self.texture = texture

	return button, texture
end

-- AceGUI functions --
local AceContainerSimpleIconButton = {}
function AceContainerSimpleIconButton:OnAcquire()
	self.frame:SetParent(UIParent)
	self.frame:SetFrameStrata("FULLSCREEN_DIALOG")
	self:ApplyStatus()
	self:Show()
end

function AceContainerSimpleIconButton:ApplyStatus()
	local status = self.status or self.localstatus
	local frame = self.frame
	self:SetWidth(status.width or 64)
	self:SetHeight(status.height or 64)
	if status.top and status.left then
		frame:SetPoint("TOP", UIParent,"BOTTOM", 0, status.top)
		frame:SetPoint("LEFT", UIParent,"LEFT", status.left, 0)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER")
	end
end

function AceContainerSimpleIconButton:Show()
	self.frame:Show()
end

function AceContainerSimpleIconButton:Hide()
	self.frame:Hide()
end

function AceContainerSimpleIconButton:OnRelease()
	self.status = nil
	for k in pairs(self.localstatus) do
		self.localstatus[k] = nil
	end
end

function AceContainerSimpleIconButton:SetStatusTable(status)
	assert(type(status) == "table")
	self.status = status
	self:ApplyStatus()
end

function AceContainerSimpleIconButton:OnWidthSet(width)
	local content = self.content
	local contentwidth = width
	if contentwidth < 0 then
		contentwidth = 0
	end
	content:SetWidth(contentwidth)
	content.width = contentwidth
end

function AceContainerSimpleIconButton:OnHeightSet(height)
	local content = self.content
	local contentheight = height
	if contentheight < 0 then
		contentheight = 0
	end
	content:SetHeight(contentheight)
	content.height = contentheight
end

-- Public Functions --
function AceContainerSimpleIconButton:SetSize(width, height)
	self:SetWidth(width)
	self:SetHeight(height)
end

function AceContainerSimpleIconButton:SetIsMovable(isMovable)
	if isMovable then
		self.frame:SetMovable(true)
		self.title:EnableMouse()
		self.title:SetScript("OnMouseDown", onMouseDownTitle)
		self.title:SetScript("OnMouseUp", onMouseUpTitle)
	end
end

function AceContainerSimpleIconButton:SetAlpha(alpha)
	self.frame:SetAlpha(alpha)
end

function AceContainerSimpleIconButton:IsMoving()
	return self._isMoving
end

function AceContainerSimpleIconButton:SetLabelFontSettings(path, size, flags)
	self.label:SetFont(path, size, flags)
end

function AceContainerSimpleIconButton:SetText(text)
	self.label:SetText(text)
end

-- Constructor --
local function Constructor()
	local self = AceContainerSimpleIconButton
	local width, height = 64, 64

	local frame = CreateFrame("Frame", Type, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	self.type = Type
	self.localstatus = {}
	self.frame = frame
	frame.obj = self

	-- Default Values
	frame:SetWidth(width)
	frame:SetHeight(height)
	frame:SetPoint("BOTTOMLEFT", UIParent, "CENTER", 0, 0)
	frame:SetFrameStrata("MEDIUM")
	frame:SetToplevel(true)

	-- Create Objects
	self.content = CreateContainer(self, frame)
	AceGUI:RegisterAsContainer(self)
	self:SetLayout("Fill")

	local button, texture = CreateButton(self, self.content, width, height)
	self.button = button
	self.texture = texture

	-- Callbacks
	button:SetScript("OnMouseDown", onMouseDownButton)
	button:SetScript("OnMouseUp", onMouseUpButton)
	button:SetScript("OnShow", onShowButton)
	button:SetScript("OnHide", onHideButton)
	button:SetScript("OnEnter", onEnterButton)
	button:SetScript("OnLeave", onLeaveButton)

	return self
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
