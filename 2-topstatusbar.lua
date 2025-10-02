--[[
This patch adds a top status bar. It is based on the revised patch in https://github.com/issues/mentioned?issue=joshuacant%7CKOReader.patches%7C1
]]--
local TextWidget = require("ui/widget/textwidget")
local CenterContainer = require("ui/widget/container/centercontainer")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local BD = require("ui/bidi")
local Size = require("ui/size")
local Geom = require("ui/geometry")
local Device = require("device")
local Font = require("ui/font")
local logger = require("logger")
local util = require("util")
local datetime = require("datetime")
local NetworkMgr = require("ui/network/manager")
local Screen = Device.screen
local _ = require("gettext")
local T = require("ffi/util").template
local ReaderView = require("apps/reader/modules/readerview")
local ReaderView_paintTo_orig = ReaderView.paintTo

local header_settings = G_reader_settings:readSetting("footer")
local screen_width = Screen:getWidth()

-- Configurations for left, center, right
local left_config = {
	time = true,
	book_author = false,
	book_title = false,
	wifi = false,
	battery = false
}
local center_config = {
	time = false,
	book_author = true,
	book_title = true,
	wifi = false,
	battery = false
}
local right_config = {
	time = false,
	book_author = false,
	book_title = false,
	wifi = true,
	battery = true
}

-- Configure formatting options for header here, if desired
local header_font_face = "ffont" -- this is the same font the footer uses
local header_font_size = header_settings.text_font_size or 14 -- Will use your footer setting if available
local header_font_bold = header_settings.text_font_bold or false -- Will use your footer setting if available
local header_top_padding = Size.padding.small -- replace small with default or large for more space at the top
local header_use_book_margins = true -- Use same margins as book for header
local header_margin = Size.padding.large -- Use this instead, if book margins is set to false

-- Minimum spacing between sections (in pixels)
local min_section_spacing = 20

local all_separators = {
    bar     = "|",
    bullet  = "•",
    dot     = "·",
    em_dash = "—",
    en_dash = "-",
}

local separator = all_separators.bullet

ReaderView.paintTo = function(self, bb, x, y)
    ReaderView_paintTo_orig(self, bb, x, y)
    if self.render_mode ~= nil then return end -- Show only for epub-likes and never on pdf-likes

    -- Infos for whole book:
    local pageno = self.state.page or 1 -- Current page
    local pages = self.ui.doc_settings.data.doc_pages or 1
    local book_title = self.ui.doc_props.display_title or ""
    -- MODIFIED to make spacing tighter, like the footer
    local page_progress = ("%d/%d"):format(pageno, pages)
    local percentage = (pageno / pages) * 100

    -- Author(s):
    local book_author = self.ui.doc_props.authors
    if book_author and book_author:find("\n") then -- Show first author if multiple authors
        book_author =  T(_("%1 et al."), util.splitToArray(book_author, "\n")[1] .. ",")
    end

    -- Clock:
    local time = datetime.secondsToHour(os.time(), G_reader_settings:isTrue("twelve_hour_clock"))

    -- Battery:
    local battery_string = ""
    local powerd = Device.powerd
    if powerd and powerd.getCapacity then
        local batt_lvl = powerd:getCapacity()
        if batt_lvl and batt_lvl >= 0 then
            local batt_symbol = powerd:getBatterySymbol(powerd:isCharged(), powerd:isCharging(), batt_lvl)
            battery_string = string.format("%s%d%%", batt_symbol, batt_lvl)
            if powerd.isCharging and powerd:isCharging() then
                battery_string = "+" .. battery_string
            end
        end
    end

    -- set the wifi string
    local wifi = ""
    if NetworkMgr:isWifiOn() then
        wifi = ""
    else
        wifi = ""
    end

    local function getHeaderText(header_config, header_separator)
        local header = ""
        if header_config.time then
            header = string.format("%s", time)
        end
        if header_config.book_author then
            if header ~= "" then
                header = header .. string.format(" %s ", header_separator)
            end
        	header = header .. string.format("%s", book_author)
        end
        if header_config.book_title then
            if header ~= "" then
                header = header .. string.format(" %s ", header_separator)
            end
        	header = header .. string.format("%s", book_title)
        end
        if header_config.wifi then
            if header ~= "" then
                header = header .. string.format(" %s ", header_separator)
            end
            header = header .. string.format("%s", wifi)
        end
        if header_config.battery then
            if header ~= "" then
                header = header .. string.format(" %s ", header_separator)
            end
            header = header .. string.format("%s", battery_string)
        end
        return header
    end

    local left_header = getHeaderText(left_config, separator)
    local center_header = getHeaderText(center_config, separator)
    local right_header = getHeaderText(right_config, separator)

    -- Calculate margins
    local margins = 0
    local left_margin = header_margin
    local right_margin = header_margin
    if header_use_book_margins then -- Set width % based on R + L margins
        left_margin = self.document:getPageMargins().left or header_margin
        right_margin = self.document:getPageMargins().right or header_margin
    end
    margins = left_margin + right_margin
    local avail_width = Screen:getWidth() - margins -- deduct margins from width

    -- Step 1: Calculate actual width needed for left and right sections
    local function getTextWidth(text)
        if text == nil or text == "" then
            return 0
        end
        local text_widget = TextWidget:new{
            text = text:gsub(" ", "\u{00A0}"), -- no-break-space
            face = Font:getFace(header_font_face, header_font_size),
            bold = header_font_bold,
            padding = 0,
        }
        local width = text_widget:getSize().w
        text_widget:free()
        return width
    end

    local left_width = getTextWidth(left_header)
    local right_width = getTextWidth(right_header)
    
    -- Step 2: Calculate available space for center section
    local total_spacing = min_section_spacing * 2 -- Space on both sides of center
    local center_available_width = avail_width - left_width - right_width - total_spacing
    
    -- Step 3: Create fitted text for center section with maximum available space
    local function getFittedText(text, max_width)
        if text == nil or text == "" then
            return ""
        end
        local text_widget = TextWidget:new{
            text = text:gsub(" ", "\u{00A0}"), -- no-break-space
            max_width = max_width,
            face = Font:getFace(header_font_face, header_font_size),
            bold = header_font_bold,
            padding = 0,
        }
        local fitted_text, add_ellipsis = text_widget:getFittedText()
        text_widget:free()
        if add_ellipsis then
            fitted_text = fitted_text .. "…"
        end
        return BD.auto(fitted_text)
    end

    -- Only truncate center if absolutely necessary
    local center_header_text = getFittedText(center_header, math.max(100, center_available_width))
    
    -- Create text widgets
    local left_text_widget = TextWidget:new {
        text = BD.auto(left_header),
        face = Font:getFace(header_font_face, header_font_size),
        bold = header_font_bold,
        padding = 0,
    }
    local center_text_widget = TextWidget:new {
        text = center_header_text,
        face = Font:getFace(header_font_face, header_font_size),
        bold = header_font_bold,
        padding = 0,
    }
    local right_text_widget = TextWidget:new {
        text = BD.auto(right_header),
        face = Font:getFace(header_font_face, header_font_size),
        bold = header_font_bold,
        padding = 0,
    }
    
    -- Step 4: Calculate final spacing - distribute remaining space evenly
    local actual_left_width = left_text_widget:getSize().w
    local actual_center_width = center_text_widget:getSize().w
    local actual_right_width = right_text_widget:getSize().w
    local total_text_width = actual_left_width + actual_center_width + actual_right_width
    local remaining_space = avail_width - total_text_width
    
    -- Ensure minimum spacing, but use more if available
    local space_between = math.max(min_section_spacing, remaining_space / 2)
    
    local header = CenterContainer:new {
        dimen = Geom:new{ w = Screen:getWidth(), h = math.max(left_text_widget:getSize().h, center_text_widget:getSize().h, right_text_widget:getSize().h) },
        VerticalGroup:new {
            VerticalSpan:new { width = header_top_padding },
            HorizontalGroup:new {
                HorizontalSpan:new { width = left_margin },
                left_text_widget,
                HorizontalSpan:new { width = space_between },
                center_text_widget,
                HorizontalSpan:new { width = space_between },
                right_text_widget,
                HorizontalSpan:new { width = right_margin },
            },
        },
    }
    header:paintTo(bb, x, y)
end
