---------------------------------------------------------------------------
--  Super Mario World (U) Utility Script for Lsnes - rr2 version
--  http://tasvideos.org/Lsnes.html
--  
--  Author: Rodrigo A. do Amaral (Amaraticando)
--  Git repository: https://github.com/rodamaral/smw-tas
---------------------------------------------------------------------------

--#############################################################################
-- CONFIG:

-- Comparison script (experimental)
-- put the path between double brackets, e.g. [[C:\folder1\folder2\file.lua]] or simply put nil without "quote marks"
local GHOST_FILENAME = nil

-- Hotkeys  (look at the manual to see all the valid keynames)
-- make sure that the hotkeys below don't conflict with previous bindings
local HOTKEY_INCREASE_OPACITY = "equals"  -- to increase the opacity of the text: the '='/'+' key 
local HOTKEY_DECREASE_OPACITY = "minus"   -- to decrease the opacity of the text: the '_'/'-' key

-- Display
local display_movie_info = true
local display_misc_info = true
local show_player_info = true
local show_player_hitbox = true
local show_interaction_points = false  -- can be changed by right-clicking on player
local show_sprite_info = true
local show_sprite_hitbox = true  -- you still have to select the sprite with the mouse
local show_all_sprite_info = false  -- things like sprite status and stun timer when they are in their 'default' state
local show_level_info = true
local show_pit = false  -- only works in horizontal levels for now
local show_yoshi_info = true
local show_counters_info = true
local show_controller_input = true

-- Cheats
local ALLOW_CHEATS = true -- better turn off while recording a TAS

-- Font settings
local USE_CUSTOM_FONTS = true
local LSNES_FONT_HEIGHT = 16
local LSNES_FONT_WIDTH = 8
local CUSTOM_FONTS = {
    default = { file = nil, height = LSNES_FONT_HEIGHT, width = LSNES_FONT_WIDTH }, -- this is lsnes default font
    
    snes9xlua =       { file = "data\\snes9xlua.font",        height = 16, width = 10 },
    snes9xluaclever = { file = "data\\snes9xluaclever.font",  height = 16, width = 08 }, -- quite pixelated
    snes9xluasmall =  { file = "data\\snes9xluasmall.font",   height = 09, width = 05 },
    snes9xtext =      { file = "data\\snes9xtext.font",       height = 11, width = 08 },
    verysmall =       { file = "data\\verysmall.font",        height = 08, width = 04 }, -- broken, unless for numerals
}

-- Lateral gaps (initial values)
local Left_gap = 150
local Right_gap = LSNES_FONT_WIDTH*17  -- 17 maximum chars of the Level info
local Top_gap = LSNES_FONT_HEIGHT
local Bottom_gap = LSNES_FONT_HEIGHT

-- Colours (text)
local text_color = 0x00ffffff
local background_color = 0x90000000
local outline_color = 0x40000000
local joystick_input_color = 0x00ffff00
local joystick_input_bg = 0xd0ffffff
local lag_color = 0x00ff0000
local REC_color = 0x00ff0000
local REC_bg = 0x900000ff
local rerecord_color = 0x00a9a9a9

-- Colours (hitbox and related text)
local mario_color = 0x00ff0000
local mario_bg = -1
local mario_bg_mounted = -1
local interaction_color = 0x00ffffff
local interaction_bg = 0xe0000000
local interaction_color_without_hitbox = 0

local SPRITES_COLOR = {0x00ff00, 0x0000ff, 0xffff00, 0xff8000, 0xff00ff, 0xb00040}
local SPRITES_BG = 0xb00000b0
local sprites_interaction_color = 0x00ffff00  -- unused yet

local YOSHI_COLOR = 0x0000ffff
local YOSHI_BG = 0xb000ffff
local YOSHI_BG_MOUNTED = -1
local TONGUE_BG = 0xa0ff0000
local extended_sprites = 0x00ffffff  -- unused yet

local cape_color = 0x00ffd700
local cape_bg = 0xc0ffd700
local cape_block = 0x00ff0000

local block_color = 0x0000008b
local block_bg = 0xa022cc88

-- END OF CONFIG < < < < < < <
--#############################################################################
-- INITIAL STATEMENTS:

-- Script verifies whether the emulator is indeed Lsnes - rr2 version
if not movie.lagcount then
    function on_paint()
        gui.text(1, 01, "This script is supposed to be run on Lsnes - rr2 version.", text_color, background_color)
        gui.text(1, 17, "Your version seems to be different.", text_color, background_color)
        gui.text(1, 33, "Download the correct script at:", text_color, background_color)
        gui.text(1, 49, "https://github.com/rodamaral/smw-tas", text_color, background_color)
    end
    gui.repaint()
end

--print(@@LUA_SCRIPT_FILENAME@@))  -- rr1 version can't understand this syntax
print("This script is supposed to be run on Lsnes - rr2 version.")

local draw_font = {}
for key, value in pairs(CUSTOM_FONTS) do
    draw_font[key] = gui.font.load(value.file) or gui.text
end

--#############################################################################
-- GAME AND SNES SPECIFIC MACROS:

local NTSC_FRAMERATE = 10738636/178683

local SMW = {
    -- Game Modes
    game_mode_overworld = 0x0e,
    game_mode_level = 0x14,
    
    sprite_max = 12,
}

WRAM = {
    game_mode = 0x0100,
    real_frame = 0x0013,
    effective_frame = 0x0014,
    timer_frame_counter = 0x0f30,
    RNG = 0x148d,
    current_level = 0x00fe,  -- plus 1
    sprite_memory_header = 0x1692,
    lock_animation_flag = 0x009d, -- Most codes will still run if this is set, but almost nothing will move or animate.
    level_mode_settings = 0x1925,
    
    -- cheats
    frozen = 0x13fb,
    level_paused = 0x13d4,
    level_index = 0x13bf,
    room_index = 0x00ce,
    level_flag_table = 0x1ea2,
    level_exit_type = 0x0dd5,
    midway_point = 0x13ce,
    
    -- Camera
    camera_x = 0x001a,
    camera_y = 0x001c,
    screens_number = 0x005d,
    hscreen_number = 0x005e,
    vscreen_number = 0x005f,
    vertical_scroll = 0x1412,  -- #$00 = Disable; #$01 = Enable; #$02 = Enable if flying/climbing/etc.
    
    -- Sprites
    sprite_status = 0x14c8,
    sprite_throw = 0x1504, --
    chuckHP = 0x1528, --
    sprite_stun = 0x1540,
    sprite_contact_mario = 0x154c,
    spriteContactSprite = 0x1564, --
    spriteContactoObject = 0x15dc,  --
    sprite_number = 0x009e,
    sprite_x_high = 0x14e0,
    sprite_x_low = 0x00e4,
    sprite_y_high = 0x14d4,
    sprite_y_low = 0x00d8,
    sprite_x_sub = 0x14f8,
    sprite_y_sub = 0x14ec,
    sprite_x_speed = 0x00b6,
    sprite_y_speed = 0x00aa,
    sprite_direction = 0x157c,
    sprite_x_offscreen = 0x15a0, 
    sprite_y_offscreen = 0x186c,
    sprite_miscellaneous = 0x160e,
    sprite_miscellaneous2 = 0x163e,
    sprite_4_tweaker = 0x167a,
    sprite_tongue_length = 0x151c,
    sprite_tongue_timer = 0x1558,
    sprite_tongue_wait = 0x14a3,
    sprite_yoshi_squatting = 0x18af,
    sprite_buoyancy = 0x190e,
    reznor_killed_flag = 0x151c,
    
    -- Player
    x = 0x0094,
    y = 0x0096,
    previous_x = 0x00d1,
    previous_y = 0x00d3,
    x_sub = 0x13da,
    y_sub = 0x13dc,
    x_speed = 0x007b,
    x_subspeed = 0x007a,
    y_speed = 0x007d,
    direction = 0x0076,
    is_ducking = 0x0073,
    p_meter = 0x13e4,
    take_off = 0x149f,
    powerup = 0x0019,
    cape_spin = 0x14a6,
    cape_fall = 0x14a5,
    cape_interaction = 0x13e8,
    flight_animation = 0x1407,
    diving_status = 0x1409,
    player_in_air = 0x0071,
    climbing_status = 0x0074,
    spinjump_flag = 0x140d,
    player_blocked_status = 0x0077, 
    player_item = 0x0dc2, --hex
    cape_x = 0x13e9,
    cape_y = 0x13eb,
    on_ground = 0x13ef,
    on_ground_delay = 0x008d,
    on_air = 0x0072,
    can_jump_from_water = 0x13fa,
    carrying_item = 0x148f,
    mario_score = 0x0f34,
    player_looking_up = 0x13de,
    
    -- Yoshi
    yoshi_riding_flag = 0x187a,  -- #$00 = No, #$01 = Yes, #$02 = Yes, and turning around.
    yoshi_tongue_height = 0x188b,
    
    -- Timer
    --keep_mode_active = 0x0db1,
    score_incrementing = 0x13d6,
    end_level_timer = 0x1493,
    multicoin_block_timer = 0x186b, 
    gray_pow_timer = 0x14ae,
    blue_pow_timer = 0x14ad,
    dircoin_timer = 0x190c,
    pballoon_timer = 0x1891,
    star_timer = 0x1490,
    animation_timer = 0x1496,--
    invisibility_timer = 0x1497,
    fireflower_timer = 0x149b,
    yoshi_timer = 0x18e8,
    swallow_timer = 0x18ac,
    lakitu_timer = 0x18e0,
}

local ROM = {
    xoffbase = 0x01b56c,
    yoffbase = 0x01b5e4,
    xradbase = 0x01b5a8,
    yradbase = 0x01b620,
}

local HITBOX_SPRITE = {
    [0x00] = { left = 0, right = 16, up = 3, down = 15},
    [0x01] = { left = 0, right = 16, up = 3, down = 26},
    [0x02] = { left = 14, right = 34, up = -2, down = 18},
    [0x03] = { left = 18, right = 30, up = 8, down = 18},
    [0x04] = { left = -2, right = 50, up = -2, down = 14},
    [0x05] = { left = -2, right = 82, up = -2, down = 14},
    [0x06] = { left = -1, right = 17, up = 2, down = 28},
    [0x07] = { left = 6, right = 50, up = 8, down = 58},
    [0x08] = { left = -10, right = 26, up = -2, down = 16},
    [0x09] = { left = 2, right = 14, up = 19, down = 33}, -- Yoshi, default = { left = -4, right = 20, up = 8, down = 40}
    [0x0a] = { left = 1, right = 6, up = 7, down = 11},
    [0x0b] = { left = 4, right = 11, up = 6, down = 11},
    [0x0c] = { left = -1, right = 16, up = -2, down = 22},
    [0x0d] = { left = -2, right = 17, up = -4, down = 14},
    [0x0e] = { left = 4, right = 28, up = 6, down = 28},
    [0x0f] = { left = 0, right = 40, up = -2, down = 18},
    [0x10] = { left = -2, right = 17, up = -2, down = 32},
    [0x11] = { left = -26, right = 42, up = -24, down = 42},
    [0x12] = { left = -6, right = 6, up = 16, down = 70},
    [0x13] = { left = -6, right = 6, up = 16, down = 134},
    [0x14] = { left = 2, right = 30, up = 2, down = 16},
    [0x15] = { left = -2, right = 17, up = -2, down = 14},
    [0x16] = { left = -6, right = 22, up = -12, down = 14},
    [0x17] = { left = 0, right = 16, up = 8, down = 79},
    [0x18] = { left = 0, right = 16, up = 19, down = 79},
    [0x19] = { left = 0, right = 16, up = 35, down = 79},
    [0x1a] = { left = 0, right = 16, up = 51, down = 79},
    [0x1b] = { left = 0, right = 16, up = 67, down = 79},
    [0x1c] = { left = -2, right = 12, up = 10, down = 60},
    [0x1d] = { left = 0, right = 32, up = -3, down = 26},
    [0x1e] = { left = 4, right = 12, up = 13, down = 21},  -- Goal tape, default = { left = -34, right = 18, up = -8, down = 26
    [0x1f] = { left = -18, right = 34, up = -4, down = 16},
    [0x20] = { left = -6, right = 6, up = -24, down = 2},
    [0x21] = { left = -6, right = 6, up = 16, down = 42},
    [0x22] = { left = -2, right = 18, up = 0, down = 18},
    [0x23] = { left = -10, right = 26, up = -24, down = 10},
    [0x24] = { left = -14, right = 46, up = 32, down = 90},
    [0x25] = { left = -16, right = 48, up = 4, down = 26},
    [0x26] = { left = -2, right = 34, up = 88, down = 98},
    [0x27] = { left = -6, right = 22, up = -4, down = 22},
    [0x28] = { left = -16, right = 16, up = -24, down = 18},
    [0x29] = { left = -18, right = 18, up = -4, down = 25},
    [0x2a] = { left = 0, right = 16, up = -8, down = 13},
    [0x2b] = { left = -2, right = 18, up = 2, down = 80},
    [0x2c] = { left = -10, right = 10, up = -8, down = 10},
    [0x2d] = { left = 2, right = 14, up = 4, down = 10},
    [0x2e] = { left = 0, right = 32, up = -2, down = 34},
    [0x2f] = { left = 0, right = 32, up = -2, down = 32},
    [0x30] = { left = 6, right = 26, up = -14, down = 16},
    [0x31] = { left = -2, right = 50, up = -2, down = 18},
    [0x32] = { left = -2, right = 50, up = -2, down = 18},
    [0x33] = { left = -2, right = 66, up = -2, down = 18},
    [0x34] = { left = -6, right = 6, up = -4, down = 6},
    [0x35] = { left = 1, right = 23, up = 0, down = 34},
    [0x36] = { left = 6, right = 62, up = 8, down = 56},
    [0x37] = { left = -2, right = 17, up = -8, down = 14},
    [0x38] = { left = 6, right = 42, up = 16, down = 58},
    [0x39] = { left = 2, right = 14, up = 3, down = 15},
    [0x3a] = { left = -10, right = 26, up = 16, down = 34},
    [0x3b] = { left = -2, right = 18, up = 0, down = 15},
    [0x3c] = { left = 10, right = 17, up = 10, down = 18},
    [0x3d] = { left = 10, right = 17, up = 21, down = 43},
    [0x3e] = { left = 14, right = 272, up = 18, down = 36},
    [0x3f] = { left = 6, right = 18, up = 8, down = 34}
}

-- Creates a set from a list
local function make_set(list)
    local set = {}
    for _, l in ipairs(list) do set[l] = true end
    return set
end

-- from sprite number, returns oscillation flag
-- A sprite must be here iff it processes interaction with player every frame AND this bit is not working in the sprite_4_tweaker WRAM(0x167a)
local OSCILLATION_SPRITES = make_set{0x0e, 0x21, 0x29, 0x35, 0x54, 0x74, 0x75, 0x76, 0x77, 0x78, 0x81, 0x83, 0x87}

-- Sprites that have a custom hitbox drawing
local ABNORMAL_HITBOX_SPRITES = make_set{0x63}

--#############################################################################
-- SCRIPT UTILITIES:
-- Variables used in various functions
local Previous_lag_count = nil
local Is_lagged = nil
local Borders

-- x can also be "left", "left-border", "middle", "right" and "right_border"
-- y can also be "top", "top-border", "middle", "bottom" and "bottom-border"
local function text_position(x, y, text, font)
    -- Calculates the correct FONT, FONT_HEIGHT and FONT_WIDTH
    local font_height
    local font_width
    if not CUSTOM_FONTS[font] then font = "default" end
    font_height = CUSTOM_FONTS[font].height or LSNES_FONT_HEIGHT
    font_width = CUSTOM_FONTS[font].width or LSNES_FONT_WIDTH
    
    -- Calculates the actual text string
    local formatted_text
    if type(text) ~= "table" then
        formatted_text = text
    elseif not text[2] then
        formatted_text = text[1]
    else
        formatted_text = string.format(unpack(text))
    end
    
    local text_length = string.len(formatted_text)*font_width
    
    -- calculates suitable x
    if x == "left" then x = 0
    elseif x == "left-border" then x = -Borders.left
    elseif x == "right" then x = screen_width - text_length
    elseif x == "right-border" then x = screen_width + Borders.right - text_length
    elseif x == "middle" then x = (screen_width - text_length)/2
    end
    
    if x < -Borders.left then x = -Borders.left end
    local x_final = x + text_length
    if x_final > screen_width + Borders.right then
        x = screen_width + Borders.right - text_length
    end
    
    -- calculates suitable y
    if y == "top" then y = 0
    elseif y == "top-border" then y = -Borders.top
    elseif y == "bottom" then y = screen_height - font_height
    elseif y == "bottom-border" then y = screen_height + Borders.bottom - font_height
    elseif y == "middle" then y = (screen_height - font_height)/2
    end
    
    if y < -Borders.top then y = -Borders.top end
    local y_final = y + font_height
    if y_final > screen_height + Borders.bottom then
        y = screen_height + Borders.bottom - font_height
    end
    
    return x, y, formatted_text
end

-- Draws the text formatted in a given position within the screen space
-- the optional arguments [...] are text color, background color and the on-screen flag
local function draw_text(x, y, text, ...)
    local x_pos, y_pos, formatted_text = text_position(x, y, text)
    
    gui.text(x_pos, y_pos, formatted_text, ...)
    
    return x_pos, y_pos
end

-- acts like draw_text, but with custom font
local function custom_text(x, y, text, font_name, ...)
    if not USE_CUSTOM_FONTS then draw_text(x, y, text, ...) return end
    
    if font_name == "default" then draw_text(x, y, text, ...); return end
    
    local x_pos, y_pos, formatted_text = text_position(x, y, text, font_name)
    
    -- draws the text
    local color1, color2, color3 = ...
    color2 = -1                 -- lsnes overlaps the backgrounds boundaries and they look like a grid
    if not color3 then color3 = outline_color end
    draw_font[font_name](x_pos + Borders.left, y_pos + Borders.top, formatted_text, color1, color2, color3) -- drawing is glitched if coordinates are before the borders
    
    return x_pos, y_pos
end

-- Prints the elements of a table in the console (DEBUG)
local function print_table(data)
    data = ((type(data) == "table") and data) or {data}
    
    for key, value in pairs(data) do
        if type(key) == "table" then
            print_table(value)
            print("...")
        else
            print(key, value)
        end
    end
end

-- Checks whether 'data' is a table and then prints it in (x,y)
local function draw_table(x, y, data, ...)
    local data = ((type(data) == "table") and data) or {data}
    local index = 0
    
    for key, value in ipairs(data) do
        if value ~= "" and value ~= nil then
            index = index + 1
            draw_text(x, y + (LSNES_FONT_HEIGHT * index), value, ...)
        end
    end
end

-- Returns frames-time conversion
local function frame_time(frame)
    if not NTSC_FRAMERATE then error("NTSC_FRAMERATE undefined."); return end
    
    local total_seconds = frame/NTSC_FRAMERATE
    local hours, minutes, seconds = bit.multidiv(total_seconds, 3600, 60)
    local miliseconds = 1000* (total_seconds%1)
    
    if hours == 0 then hours = "" else hours = string.format("%d:", hours) end
    local str = string.format("%s%.2d:%.2d.%.3d", hours, minutes, seconds, miliseconds)
    return str
end

-- Changes transparency of a color: result is opaque original * transparency level (0.0 to 1.0). Acts like gui.opacity() in Snex9s.
local function change_transparency(color, transparency)
    if type(color) ~= "number" then
        color = gui.color(color)
    end
    if transparency > 1 then transparency = 1 end
    if transparency < 0 then transparency = 0 end
    
    local a = bit.lrshift(color, 24)
    local rgb = color - bit.lshift(a, 24)
    local new_a = 0x100 - math.floor((transparency * (0x100 - a)))
    local new_color = bit.lshift(new_a, 24) + rgb
    
    return new_color
end

-- draw a pixel given (x,y) with SNES' pixel sizes
local function draw_pixel(x, y, ...)
    gui.pixel(2*x, 2*y, ...)
    gui.pixel(2*x + 1, 2*y, ...)
    gui.pixel(2*x, 2*y + 1, ...)
    gui.pixel(2*x + 1, 2*y + 1, ...)
end

-- draws a line given (x,y) and (x',y') with SNES' pixel sizes
local function draw_line(x1, y1, x2, y2, ...)
    gui.line(2*x1, 2*y1, 2*x2, 2*y2, ...)
    gui.line(2*x1 + 1, 2*y1, 2*x2 + 1, 2*y2, ...)
    gui.line(2*x1, 2*y1 + 1, 2*x2, 2*y2 + 1, ...)
    gui.line(2*x1 + 1, 2*y1 + 1, 2*x2 + 1, 2*y2 + 1, ...)
end

-- draws a box given (x,y) and (x',y') with SNES' pixel sizes
local function draw_box(x1, y1, x2, y2, ...)
    if x2 < x1 then
        x1, x2 = x2, x1
    end
    if y2 < y1 then
        y1, y2 = y2, y1
    end
    
    local x = 2*x1
    local y = 2*y1
    local w = (2 * (x2 - x1)) + 2  -- adds thickness
    local h = (2 * (y2 - y1)) + 2  -- adds thickness
    
    gui.rectangle(x, y, w, h, ...)
end

-- Like draw_box, but with a different color in the right and bottom
local function draw_box2(x1, y1, x2, y2, ...)
    if x2 < x1 then
        x1, x2 = x2, x1
    end
    if y2 < y1 then
        y1, y2 = y2, y1
    end
    
    local x = 2*x1
    local y = 2*y1
    local w = (2 * (x2 - x1)) + 2  -- adds thickness
    local h = (2 * (y2 - y1)) + 2  -- adds thickness
    
    gui.box(x, y, w, h, ...)
end

-- mouse (x, y)
local Mouse_x, Mouse_y = 0, 0
local function read_mouse()
    Mouse_x = user_input.mouse_x.value
    Mouse_y = user_input.mouse_y.value
    local left_click = user_input.mouse_left.value
    local right_click = user_input.mouse_right.value
    
    return Mouse_x, Mouse_y, left_click, right_click
end

-- Uses hotkeys to change the opacity of the gui functions
-- Left click = more transparency
-- Right click = less transparency
local function change_background_opacity()
    if not user_input then return end
    if not user_input[HOTKEY_INCREASE_OPACITY] then error(HOTKEY_INCREASE_OPACITY, ": Wrong hotkey for \"HOTKEY_INCREASE_OPACITY\"."); return end
    if not user_input[HOTKEY_DECREASE_OPACITY] then error(HOTKEY_DECREASE_OPACITY, ": Wrong hotkey for \"HOTKEY_DECREASE_OPACITY\"."); return end
    
    local increase_key = user_input[HOTKEY_INCREASE_OPACITY].value
    local increase_key = user_input[HOTKEY_INCREASE_OPACITY].value
    local decrease_key = user_input[HOTKEY_DECREASE_OPACITY].value
    
    if increase_key  == 1 then
        if text_color > 0x04000000 then text_color = text_color - 0x04000000
        else
            if background_color > 0x04000000 then background_color = background_color - 0x04000000 end
        end
    end
    
    if decrease_key == 1 then
        if  background_color < 0xfc000000 then background_color = background_color + 0x04000000
        else
            if text_color < 0xfc000000 then text_color = text_color + 0x04000000 end
        end
    end
    
end

-- Gets input of the 1st controller / Might be deprecated someday...
local Joypad = {}
local function get_joypad()
    Joypad["B"] = input.get2(1, 0, 0)
    Joypad["Y"] = input.get2(1, 0, 1)
    Joypad["select"] = input.get2(1, 0, 2)
    Joypad["start"] = input.get2(1, 0, 3)
    Joypad["up"] = input.get2(1, 0, 4)
    Joypad["down"] = input.get2(1, 0, 5)
    Joypad["left"] = input.get2(1, 0, 6)
    Joypad["right"] = input.get2(1, 0, 7)
    Joypad["A"] = input.get2(1, 0, 8)
    Joypad["X"] = input.get2(1, 0, 9)
    Joypad["L"] = input.get2(1, 0, 10)
    Joypad["R"] = input.get2(1, 0, 11)
end

-- Displays input of the 1st controller
-- Beware that this will fail if there's more than 1 controller in the movie
local Current_movie
local function display_input()
    -- Font
    local font = "default"
    
    -- Avoids loading the movie every frame in readonly mode
    if not movie.readonly() or not Current_movie then
        Current_movie = movie.copy_movie()
    end
    
    -- Accounts for discarded input between frames
    local current_subframe = movie.current_first_subframe()
    local y_current_input = (screen_height - CUSTOM_FONTS[font].height)/2
    local past_inputs = math.floor(y_current_input/CUSTOM_FONTS[font].height)
    local movie_size = movie.get_size() - 1
    local sequence = "BYsS^v<>AXLR"
    local x_input = -string.len(sequence)*CUSTOM_FONTS[font].width - 2
    local remove_num = 8
    
    -- DEBUG
    --local current_input = movie.get_frame(Current_movie, movie_size):serialize()
    --gui.text(200, 200, string.format("%d %d %s", current_subframe, movie_size, current_input))
    
    -- Calculate the extreme-left position to display the frames and the rectangles
    local frame_length = string.len(movie.currentframe() + 1 + past_inputs)*CUSTOM_FONTS[font].width
    local rectangle_x = x_input - frame_length - 2
    if Left_gap ~= -rectangle_x + 1 then  -- increases left gap if needed
        Left_gap = -rectangle_x + 1
    end
    
    for i = past_inputs, -past_inputs, -1 do
        if current_subframe - i > movie_size then break end
        
        if current_subframe - i >= 0 then
            local current_input = movie.get_frame(Current_movie, current_subframe - i)
            local input_line = current_input:serialize()
            local str = string.sub(input_line, remove_num) -- remove the "FR X Y|" from input
            
            str = string.gsub(str, "%p", "\032") -- ' '
            str = string.gsub(str, "u", "\094")  -- '^'
            str = string.gsub(str, "d", "v")     -- 'v'
            str = string.gsub(str, "l", "\060")  -- '<'
            str = string.gsub(str, "r", "\062")  -- '>'
            
            local joystick_input_color = joystick_input_color
            local joystick_input_bg = joystick_input_bg
            if string.sub(input_line, 1, 1) ~= "F" then  -- an ignored subframe
                joystick_input_bg = change_transparency(joystick_input_color, 0.4)
                joystick_input_color = lag_color
            end
            
            local frame_to_display = movie.currentframe() + 1 - i
            
            custom_text(x_input - frame_length - 2, y_current_input - i*CUSTOM_FONTS[font].height, frame_to_display, font, text_color, -1)
            custom_text(x_input, y_current_input - i*CUSTOM_FONTS[font].height, sequence, font, joystick_input_bg)
            custom_text(x_input, y_current_input - i*CUSTOM_FONTS[font].height, str, font, joystick_input_color)
        end
        
    end
    
    draw_box(rectangle_x/2, (y_current_input - past_inputs*CUSTOM_FONTS[font].height)/2, -1, (y_current_input + (past_inputs + 1)*CUSTOM_FONTS[font].height)/2, 1, 0x40ffffff)
    draw_box(rectangle_x/2, y_current_input/2, -1, (y_current_input + CUSTOM_FONTS[font].height)/2, 1, 0x40ff0000)
    
end

--#############################################################################
-- SMW FUNCTIONS:

local Real_frame, Previous_real_frame, Effective_frame, Game_mode, Level_index, Room_index, Level_flag, Current_level, Is_paused, Lock_animation_flag
local function scan_smw()
    Previous_real_frame = Real_frame or memory.readbyte("WRAM", WRAM.real_frame)
    Real_frame = memory.readbyte("WRAM", WRAM.real_frame)
    Effective_frame = memory.readbyte("WRAM", WRAM.effective_frame)
    Game_mode = memory.readbyte("WRAM", WRAM.game_mode)
    Level_index = memory.readbyte("WRAM", WRAM.level_index)
    Level_flag = memory.readbyte("WRAM", WRAM.level_flag_table + Level_index)
    Is_paused = memory.readbyte("WRAM", WRAM.level_paused) == 1
    Lock_animation_flag = memory.readbyte("WRAM", WRAM.lock_animation_flag)
    Room_index = bit.lshift(memory.readbyte("WRAM", WRAM.room_index), 16) + bit.lshift(memory.readbyte("WRAM", WRAM.room_index + 1), 8) + memory.readbyte("WRAM", WRAM.room_index + 2)
end

-- Converts the in-game (x, y) to SNES-screen coordinates
local function screen_coordinates(x, y, camera_x, camera_y)
    local x_screen = (x - camera_x)
    local y_screen = (y - camera_y) - 1
    
    return x_screen, y_screen
end

-- Converts lsnes-screen coordinates to in-game (x, y)
local function game_coordinates(x_lsnes, y_lsnes, camera_x, camera_y)
    local x_game = (x_lsnes/2) + camera_x
    local y_game = (y_lsnes/2 + 1) + camera_y
    
    return x_game, y_game
end

-- Creates lateral gaps
local function create_gaps()
    gui.left_gap(Left_gap)  -- for input display
    gui.right_gap(Right_gap)
    gui.top_gap(Top_gap)
    gui.bottom_gap(Bottom_gap)
end

-- Returns the final dimensions of the borders
-- It's the maximum value between the gaps (created by the script) and pads (created via lsnes UI/settings)
local function get_border_values()
    local left_padding = settings.get("left-border")
    local right_padding = settings.get("right-border")
    local top_padding = settings.get("top-border")
    local bottom_padding = settings.get("bottom-border")
    
    local left_border = math.max(left_padding, Left_gap)
    local right_border = math.max(right_padding, Right_gap)
    local top_border = math.max(top_padding, Top_gap)
    local bottom_border = math.max(bottom_padding, Bottom_gap)
    
    local border = {["left"] = left_border,
                    ["right"] = right_border,
                    ["top"] = top_border,
                    ["bottom"] = bottom_border
    }
    
    return border
end

-- Returns the extreme values that Mario needs to have in order to NOT touch a solid rectangular object
-- todo: implement this feature for moving sprites that doesn't appear only for each 16 pixels interval
local function display_boundaries(x_game, y_game, width, height, camera_x, camera_y, font)
    if not font then error("Undefined font"); return end
    
    local left = width*math.floor(x_game/width)
    local top = height*math.floor(y_game/height)
    left, top = screen_coordinates(left, top, camera_x, camera_y)
    local right = left + width - 1
    local bottom = top + height - 1
    
    
    -- Reads WRAM values of the player
    local on_yoshi = memory.readbyte("WRAM", WRAM.yoshi_riding_flag) ~= 0
    local is_ducking = memory.readbyte("WRAM", WRAM.is_ducking)
    local powerup = memory.readbyte("WRAM", WRAM.powerup)
    local is_small = is_ducking ~= 0 or powerup == 0
    
    
    -- Left
    local left_x = 2*left - 6*CUSTOM_FONTS[font].width - 2
    local left_y = 2*top + height - CUSTOM_FONTS[font].height/2
    local left_text = string.format("%4d.0", width*math.floor(x_game/width) - 13)
    custom_text(left_x, left_y, left_text, font, color_text, color_background, outline_color)
    
    
    -- Right
    local right_x = 2*(left + width)
    local right_y = left_y
    local right_text = string.format("%d.f", width*math.floor(x_game/width) + 12)
    custom_text(right_x, right_y, right_text, font, color_text, color_background, outline_color)
    
    
    -- Top
    local value = (on_yoshi and y_game - 16) or y_game
    
    local top_text = string.format("%d.0", width*math.floor(value/width) - 32)
    local top_x = (4*left + 32 - CUSTOM_FONTS[font].width*string.len(top_text))/2
    local top_y = 2*top - CUSTOM_FONTS[font].height
    custom_text(top_x, top_y, top_text, font, color_text, color_background, outline_color)
    
    
    -- Bottom
    value = height*math.floor(y_game/height)
    if not is_small and not on_yoshi then
        value = value + 0x07
    elseif is_small and on_yoshi then
        value = value - 4
    else
        value = value - 1  -- the other 2 cases are equal
    end
    
    local bottom_text = string.format("%d.f", value)
    local bottom_x = (4*left + 2*width - CUSTOM_FONTS[font].width*string.len(bottom_text))/2
    local bottom_y = 2*top + 2*height
    custom_text(bottom_x, bottom_y, bottom_text, font, color_text, color_background, outline_color)
    
    return
end

-- draws the boundaries of a block
local Show_block = false
local Block_x , Block_y = 0, 0
local function draw_block(x, y, camera_x, camera_y)
    if not (x and y) then return end
    
    -- Custom Font
    local font = "snes9xluasmall"
    
    local x_game, y_game
    if Show_block then
        x_game, y_game = Block_x, Block_y
    else
        x_game, y_game = game_coordinates(x, y, camera_x, camera_y)
        Block_x, Block_y = x_game, y_game
        return
    end
    
    local color_text = change_transparency(text_color, 0.8)
    local color_background = change_transparency(background_color, 0.5)
    
    local left = 16*math.floor(x_game/16)
    local top = 16*math.floor(y_game/16)
    left, top = screen_coordinates(left, top, camera_x, camera_y)
    local right = left + 15
    local bottom = top + 15
    
    -- Returns if block is way too outside the screen
    if 2*left < 16 - Borders.left then return end
    if 2*top  < 16 - Borders.top  then return end
    if 2*right  > screen_width  + Borders.right  - 16 then return end
    if 2*bottom > screen_height + Borders.bottom - 16 then return end
    
    -- Drawings
    draw_box(left, top, right, bottom, 2, block_color, block_bg)  -- the block itself
    display_boundaries(x_game, y_game, 16, 16, camera_x, camera_y, font)  -- the text around it
    
end

-- erases block drawing
local function clear_block_drawing()
    if not user_input.mouse_left then return end
    if user_input.mouse_left.value == 0 then return end
    
    Show_block = not Show_block
end

-- uses the mouse to select an object
local function select_object(mouse_x, mouse_y, camera_x, camera_y)
    local x_game, y_game = game_coordinates(mouse_x, mouse_y, camera_x, camera_y)
    local obj_id
    
    for id = 0, SMW.sprite_max - 1 do
        local sprite_status = memory.readbyte("WRAM", WRAM.sprite_status + id)
        if sprite_status ~= 0 then
            local x_sprite = bit.lshift(memory.readbyte("WRAM", WRAM.sprite_x_high + id), 8) + memory.readbyte("WRAM", WRAM.sprite_x_low + id)
            local y_sprite = bit.lshift(memory.readbyte("WRAM", WRAM.sprite_y_high + id), 8) + memory.readbyte("WRAM", WRAM.sprite_y_low + id)
            
            if x_sprite >= x_game - 16 and x_sprite <= x_game and y_sprite >= y_game - 24 and y_sprite <= y_game then
                obj_id = id
                break
            end
        end
    end
    
    -- selects Mario
    if not obj_id then
        local x_player = memory.readsword("WRAM", WRAM.x)
        local y_player = memory.readsword("WRAM", WRAM.y)
        
        if x_player >= x_game - 16 and x_player <= x_game and y_player >= y_game - 24 and y_player <= y_game then
            obj_id = SMW.sprite_max
        end
    end
    
    if not obj_id then return end
    
    draw_text("middle", "middle", {"#%d(%4d, %3d)", obj_id, x_game, y_game}, text_color, background_color)
    return obj_id, x_game, y_game
end

local function show_hitbox(sprite_table, sprite_id)
    if not sprite_table[sprite_id] then error("Error", sprite_id, type(sprite_id)); return end
    
    if sprite_table[sprite_id] == "none" then sprite_table[sprite_id] = "sprite"; return end
    --if sprite_table[sprite_id] == "sprite" then sprite_table[sprite_id] = "block"; return end
    --if sprite_table[sprite_id] == "block" then sprite_table[sprite_id] = "both"; return end
    --if sprite_table[sprite_id] == "both" then sprite_table[sprite_id] = "none"; return end
    if sprite_table[sprite_id] == "sprite" then sprite_table[sprite_id] = "none"; return end
end

local function sprite_click()
    if user_input.mouse_right.value == 0 then return end
    if not Sprite_paint then return end
    
    local camera_x = memory.readsword("WRAM", WRAM.camera_x)
    local camera_y = memory.readsword("WRAM", WRAM.camera_y)
    local id = select_object(Mouse_x, Mouse_y, camera_x, camera_y)
    
    if id and id >= 0 and id <= SMW.sprite_max - 1 then
        id = tostring(id)
        show_hitbox(Sprite_paint, id)
    end
end

local function on_player_click()
    if user_input.mouse_right.value == 0 then return end
    
    local camera_x = memory.readsword("WRAM", WRAM.camera_x)
    local camera_y = memory.readsword("WRAM", WRAM.camera_y)
    local id = select_object(Mouse_x, Mouse_y, camera_x, camera_y)
    
    if id == SMW.sprite_max then
        
        if show_player_hitbox and show_interaction_points then
            show_interaction_points = false
            show_player_hitbox = false
        elseif show_player_hitbox then
            show_interaction_points = true
            show_player_hitbox = false
        elseif show_interaction_points then
            show_player_hitbox = true
        else
            show_player_hitbox = true
        end
        
    end
end

local function show_movie_info(not_synth)
    local emu_frame = movie.currentframe() + 1
    if not not_synth then emu_frame = emu_frame - 1 end  -- if current frame is not the result of a frame advance
    
    local emu_maxframe = movie.framecount() + 1
    local emu_rerecord = movie.rerecords()
    local is_recording = not movie.readonly()
    local pos
    
    local movie_info = string.format("Movie %d/%d", emu_frame, emu_maxframe)
    draw_text("left", -LSNES_FONT_HEIGHT, {movie_info}, text_color, background_color)
    
    pos = string.len(movie_info)*LSNES_FONT_WIDTH
    local rr_info = string.format("|%d ", emu_rerecord)
    draw_text(pos, -LSNES_FONT_HEIGHT, {rr_info}, rerecord_color, background_color)
    
    local lag_count = movie.lagcount()
    pos = pos + string.len(rr_info)*LSNES_FONT_WIDTH
    draw_text(pos, -LSNES_FONT_HEIGHT, {lag_count}, lag_color, background_color)
    
    if is_recording then
        draw_text("right", "bottom", "REC ", REC_color, REC_bg)
    else
        local str = frame_time(movie.currentframe())
        draw_text("right", "bottom", str, text_color, background_color)
    end
    
    if Is_lagged then
        gui.textHV(screen_width/2 - 3*LSNES_FONT_WIDTH, 2*LSNES_FONT_HEIGHT, "Lag", lag_color, 0xa0000000)
    end
end

local function show_misc_info()
    -- Font
    local font = "default"
    
    -- Display
    local color = text_color
    local color_bg = -1
    local RNG = memory.readbyte("WRAM", WRAM.RNG)
    local main_info = string.format("Frame(%02x, %02x) RNG(%04x) Mode(%02x)",
                                    Real_frame, Effective_frame, RNG, Game_mode)
    ;
    
    custom_text("right-border", - CUSTOM_FONTS[font]["height"], main_info, font, color, color_bg)
    
end

local function read_screens()
	local screens_number = memory.readbyte("WRAM", WRAM.screens_number)
    local vscreen_number = memory.readbyte("WRAM", WRAM.vscreen_number)
    local hscreen_number = memory.readbyte("WRAM", WRAM.hscreen_number) - 1
    local vscreen_current = memory.readsbyte("WRAM", WRAM.y + 1)
    local hscreen_current = memory.readsbyte("WRAM", WRAM.x + 1)
    local level_mode_settings = memory.readbyte("WRAM", WRAM.level_mode_settings)
    --local b1, b2, b3, b4, b5, b6, b7, b8 = bit.multidiv(level_mode_settings, 128, 64, 32, 16, 8, 4, 2)
    --draw_text("middle", "middle", {"%x: %x%x%x%x%x%x%x%x", level_mode_settings, b1, b2, b3, b4, b5, b6, b7, b8}, text_color, background_color)
    
    local level_type
    if (level_mode_settings ~= 0) and (level_mode_settings == 0x3 or level_mode_settings == 0x4 or level_mode_settings == 0x7
        or level_mode_settings == 0x8 or level_mode_settings == 0xa or level_mode_settings == 0xd) then
            level_type = "Vertical"
        ;
    else
        level_type = "Horizontal"
    end
    
    return level_type, screens_number, hscreen_current, hscreen_number, vscreen_current, vscreen_number
end

local function level()
    -- Font
    local font = "default"
    
    local sprite_memory_header = memory.readbyte("WRAM", WRAM.sprite_memory_header)
    local sprite_buoyancy = memory.readbyte("WRAM", WRAM.sprite_buoyancy)/0x40
    local color = text_color
    local color_bg = -1
    
    if sprite_buoyancy == 0 then sprite_buoyancy = "" else
        sprite_buoyancy = string.format(" %.2x", sprite_buoyancy)
        color = REC_color
    end
    
    local lm_level_number = Level_index
    if Level_index > 0x24 then lm_level_number = Level_index + 0xdc end  -- converts the level number to the Lunar Magic number; should not be used outside here
    
    -- Number of screens within the level
    local level_type, screens_number, hscreen_current, hscreen_number, vscreen_current, vscreen_number = read_screens()  -- new
    
    custom_text("right-border", 0, {"%.1sLevel(%.2x, %.2x)%s", level_type, lm_level_number, sprite_memory_header, sprite_buoyancy},
                    font, color, color_bg, outline_color)
	;
    
    custom_text("right-border", CUSTOM_FONTS[font].height, "Screens:", font, text_color, background_color, outline_color)
    
    custom_text("right-border", 2*CUSTOM_FONTS[font].height, {"%d: (%d/%d, %d/%d)", screens_number, hscreen_current, hscreen_number,
                vscreen_current, vscreen_number}, font, text_color, background_color, outline_color)
    ;
    
	-- Time frame counter of the clock
	timer_frame_counter = memory.readbyte("WRAM", WRAM.timer_frame_counter)
	custom_text(322, 30, {"%.2d", timer_frame_counter}, "snes9xlua", text_color, background_color, outline_color)
    
end


-- Creates lines showing where the real pit of death is
-- One line is for sprites and another is for Mario or Mario/Yoshi (different spot)
local function draw_pit()
    local camera_y = memory.readsword("WRAM", WRAM.camera_y)
    local camera_x = memory.readsword("WRAM", WRAM.camera_x)
    local _, y_screen = screen_coordinates(0, 432, camera_x, camera_y)
    local on_yoshi = memory.readbyte("WRAM", WRAM.yoshi_riding_flag) ~= 0
    local y_inc = 0x0b
    if not on_yoshi then y_inc = y_inc + 5 end
    
    draw_line(0, y_screen, screen_width/2, y_screen, "green")
    draw_line(0, y_screen + y_inc, screen_width/2, y_screen + y_inc, "blue")
end

local function player()
    -- Font
    local font = "default"
    
    -- Reads WRAM
    local x = memory.readsword("WRAM", WRAM.x)
    local y = memory.readsword("WRAM", WRAM.y)
    local previous_x = memory.readsword("WRAM", WRAM.previous_x)
    local previous_y = memory.readsword("WRAM", WRAM.previous_y)
    local x_sub = memory.readbyte("WRAM", WRAM.x_sub)
    local y_sub = memory.readbyte("WRAM", WRAM.y_sub)
    local x_speed = memory.readsbyte("WRAM", WRAM.x_speed)
    local x_subspeed = memory.readbyte("WRAM", WRAM.x_subspeed)
    local y_speed = memory.readsbyte("WRAM", WRAM.y_speed)
    local p_meter = memory.readbyte("WRAM", WRAM.p_meter)
    local take_off = memory.readbyte("WRAM", WRAM.take_off)
    local powerup = memory.readbyte("WRAM", WRAM.powerup)
    local direction = memory.readbyte("WRAM", WRAM.direction)
    local cape_spin = memory.readbyte("WRAM", WRAM.cape_spin)
    local cape_fall = memory.readbyte("WRAM", WRAM.cape_fall)
    local flight_animation = memory.readbyte("WRAM", WRAM.flight_animation)
    local diving_status = memory.readsbyte("WRAM", WRAM.diving_status)
    local player_in_air = memory.readbyte("WRAM", WRAM.player_in_air)
    local player_blocked_status = memory.readbyte("WRAM", WRAM.player_blocked_status)
    local player_item = memory.readbyte("WRAM", WRAM.player_item)
    local is_ducking = memory.readbyte("WRAM", WRAM.is_ducking)
    local on_ground = memory.readbyte("WRAM", WRAM.on_ground)
    local spinjump_flag = memory.readbyte("WRAM", WRAM.spinjump_flag)
    local can_jump_from_water = memory.readbyte("WRAM", WRAM.can_jump_from_water)
    local carrying_item = memory.readbyte("WRAM", WRAM.carrying_item)
    local yoshi_riding_flag = memory.readbyte("WRAM", WRAM.yoshi_riding_flag)
    local camera_x = memory.readsword("WRAM", WRAM.camera_x)
    local camera_y = memory.readsword("WRAM", WRAM.camera_y)
    
    -- Transformations
    if direction == 0 then direction = "<-" else direction = "->" end
    
    local spin_direction = (Effective_frame)%8
    if spin_direction < 4 then
        spin_direction = spin_direction + 1
    else
        spin_direction = 3 - spin_direction
    end
    
    local is_caped = powerup == 0x2
    local is_spinning = cape_spin ~= 0 or spinjump_flag ~= 0
    
    -- Blocked status
    local blocked_status = {}
    if bit.test(player_blocked_status, 0) then table.insert(blocked_status, "R") else table.insert(blocked_status, " ") end
    if bit.test(player_blocked_status, 1) then table.insert(blocked_status, "L") else table.insert(blocked_status, " ") end
    if bit.test(player_blocked_status, 2) then table.insert(blocked_status, "D") else table.insert(blocked_status, " ") end
    if bit.test(player_blocked_status, 3) then table.insert(blocked_status, "U") else table.insert(blocked_status, " ") end
    if bit.test(player_blocked_status, 4) then table.insert(blocked_status, "M") else table.insert(blocked_status, " ") end
    local block_str = "Block: " .. table.concat(blocked_status)
    
    -- Display info
    local i = 0
    local delta_x = CUSTOM_FONTS[font].width
    local delta_y = CUSTOM_FONTS[font].height
    local table_y = 64
    custom_text(0, table_y + i*delta_y, {"Meter (%03d, %02d) %s", p_meter, take_off, direction},
    font, text_color, background_color, outline_color)
    custom_text(18*delta_x, table_y + i*delta_y, {" %+d", spin_direction},
    font, (is_spinning and text_color) or 0x00a0a0a0, background_color, outline_color)
    i = i + 1
    
    custom_text(0, table_y + i*delta_y, {"Pos (%+d.%1x, %+d.%1x)", x, x_sub/16, y, y_sub/16},
    font, text_color, background_color, outline_color)
    i = i + 1
    
    custom_text(0, table_y + i*delta_y, {"Speed (%+d(%d), %+d)", x_speed, x_subspeed/16, y_speed},
    font, text_color, background_color, outline_color)
    i = i + 1
    
    if is_caped then
        custom_text(0, table_y + i*delta_y, {"Cape (%.2d, %.2d)/(%d, %d)", cape_spin, cape_fall, flight_animation, diving_status},
        font, cape_color, background_color, outline_color)
        i = i + 1
    end
    
    custom_text(7*delta_x, table_y + i*delta_y, "RLDUM", font, 0x00a0a0a0, -1, outline_color)
    custom_text(0, table_y + i*delta_y, block_str,      font, text_color, background_color, outline_color)
    i = i + 1
    
    custom_text(0, table_y + i*delta_y, {"Camera (%d, %d)", camera_x, camera_y}, font, text_color, background_color, outline_color)
    
    
    -- draw block
    draw_block(Mouse_x, Mouse_y, camera_x, camera_y)
    
    -- change hitbox of sprites
    if Mouse_x and Mouse_y then select_object(Mouse_x, Mouse_y, camera_x, camera_y) end
    
    -- shows hitbox and interaction points for player
    if not (show_player_hitbox or show_interaction_points) then return end
    
    --------------------
    -- displays player's hitbox
    local function player_hitbox(x, y)
        
        local x_screen, y_screen = screen_coordinates(x, y, camera_x, camera_y)
        local yoshi_hitbox = nil
        local is_small = is_ducking ~= 0 or powerup == 0
        local on_yoshi =  yoshi_riding_flag ~= 0
        
        local x_points = {
            center = 0x8,
            left_side = 0x2 + 1,
            left_foot = 0x5,
            right_side = 0xe - 1,
            right_foot = 0xb
        }
        local y_points = {}
        
        if is_small and not on_yoshi then
            y_points = {
                head = 0x10,
                center = 0x18,
                shoulder = 0x16,
                side = 0x1a,
                foot = 0x20,
                sprite = 0x18
            }
        elseif not is_small and not on_yoshi then
            y_points = {
                head = 0x08,
                center = 0x12,
                shoulder = 0x0f,
                side = 0x1a,
                foot = 0x20,
                sprite = 0x0a
            }
        elseif is_small and on_yoshi then
            y_points = {
                head = 0x13,
                center = 0x1d,
                shoulder = 0x19,
                side = 0x28,
                foot = 0x30,
                sprite = 0x28,
                sprite_up = 0x1c
            }
        else
            y_points = {
                head = 0x10,
                center = 0x1a,
                shoulder = 0x16,
                side = 0x28,
                foot = 0x30,
                sprite = 0x28,
                sprite_up = 0x14
            }
        end
        
        draw_box(x_screen + x_points.left_side, y_screen + y_points.head, x_screen + x_points.right_side, y_screen + y_points.foot,
                2, interaction_bg, interaction_bg)  -- background for block interaction
        ;
        
        if show_player_hitbox then
            
            -- Collision with sprites
            local mario_color = (not on_yoshi and mario_color) or mario_color
            local mario_bg = (not on_yoshi and mario_bg) or mario_bg_mounted
            
            if y_points.sprite_up then
                draw_box(x_screen + x_points.left_side  + 1, y_screen + y_points.sprite_up - 2,
                         x_screen + x_points.right_side - 1, y_screen + y_points.foot, 2, mario_color, mario_bg)
                ;
                
            else
                draw_box(x_screen + x_points.left_side  + 1, y_screen + y_points.sprite - 2,
                         x_screen + x_points.right_side - 1, y_screen + y_points.foot, 2, mario_color, mario_bg)
                ;
                
            end
            
        end
        
        -- interaction points (collision with blocks)
        if show_interaction_points then
            
            local color = interaction_color
            
            if not show_player_hitbox then
                draw_box(x_screen + x_points.left_side , y_screen + y_points.head,
                         x_screen + x_points.right_side, y_screen + y_points.foot, 2, interaction_color_without_hitbox, -1)
            end
            
            --draw_pixel(x_screen, y_screen, color) -- debug (useful to see when Mario or sprites die in the pit)
            draw_line(x_screen + x_points.left_side, y_screen + y_points.side, x_screen + x_points.left_foot, y_screen + y_points.side, color)  -- left side
            draw_line(x_screen + x_points.right_side, y_screen + y_points.side, x_screen + x_points.right_foot, y_screen + y_points.side, color)  -- right side
            draw_line(x_screen + x_points.left_foot, y_screen + y_points.foot - 2, x_screen + x_points.left_foot, y_screen + y_points.foot, color)  -- left foot bottom
            draw_line(x_screen + x_points.right_foot, y_screen + y_points.foot - 2, x_screen + x_points.right_foot, y_screen + y_points.foot, color)  -- right foot bottom
            draw_line(x_screen + x_points.left_side, y_screen + y_points.shoulder, x_screen + x_points.left_side + 2, y_screen + y_points.shoulder, color)  -- head left point
            draw_line(x_screen + x_points.right_side - 2, y_screen + y_points.shoulder, x_screen + x_points.right_side, y_screen + y_points.shoulder, color)  -- head right point
            draw_line(x_screen + x_points.center, y_screen + y_points.head, x_screen + x_points.center, y_screen + y_points.head + 2, color)  -- head point
            draw_line(x_screen + x_points.center - 1, y_screen + y_points.center, x_screen + x_points.center + 1, y_screen + y_points.center, color)  -- center point
            draw_line(x_screen + x_points.center, y_screen + y_points.center - 1, x_screen + x_points.center, y_screen + y_points.center + 1, color)  -- center point
        end
        
        return x_points, y_points
    end
    --------------------
    -- displays the hitbox of the cape while spinning
    local function cape_hitbox()
        local cape_interaction = memory.readbyte("WRAM", WRAM.cape_interaction)
        if cape_interaction == 0 then return end
        
        local cape_x = memory.readword("WRAM", WRAM.cape_x)
        local cape_y = memory.readword("WRAM", WRAM.cape_y)
        
        local cape_x_screen, cape_y_screen = screen_coordinates(cape_x, cape_y, camera_x, camera_y)
        local cape_left = 0
        local cape_right = 0x10
        local cape_up = 0x02
        local cape_down = 0x10
        local cape_middle = 0x08
        local block_interaction_cape = (x > cape_x and cape_left + 2) or cape_right - 2
        local active_frame = Real_frame%2 == 1
        
        if active_frame then bg_color = cape_bg else bg_color = -1 end
        draw_box(cape_x_screen + cape_left, cape_y_screen + cape_up, cape_x_screen + cape_right, cape_y_screen + cape_down, 2, cape_color, bg_color)
        
        if active_frame then
            draw_pixel(cape_x_screen + block_interaction_cape, cape_y_screen + cape_middle, cape_block)
        else
			draw_pixel(cape_x_screen + block_interaction_cape, cape_y_screen + cape_middle, text_color)
		end
		
    end
    
	--------------------
    cape_hitbox()
    player_hitbox(x, y)
	player_hitbox(math.floor((256*x + x_sub + 16*x_speed)/256), math.floor((256*y + y_sub + 16*y_speed)/256)) -- Shows where Mario is expected to be in the next frame
    
end

-- Returns the id of Yoshi; if more than one, the lowest sprite slot
local function get_yoshi_id()
    for i = 0, SMW.sprite_max - 1 do
        id = memory.readbyte("WRAM", WRAM.sprite_number + i)
        status = memory.readbyte("WRAM", WRAM.sprite_status + i)
        if id == 0x35 and status ~= 0 then return i end
    end
    
    return nil
end

local function sprites()
    local camera_x = memory.readsword("WRAM", WRAM.camera_x)
    local camera_y = memory.readsword("WRAM", WRAM.camera_y)
    local yoshi_riding_flag = memory.readbyte("WRAM", WRAM.yoshi_riding_flag)
    local counter = 0
    local table_position = 80
    
    for id = 0, SMW.sprite_max - 1 do
        local sprite_status = memory.readbyte("WRAM", WRAM.sprite_status + id)
        if sprite_status ~= 0 then
            local x = bit.lshift(memory.readbyte("WRAM", WRAM.sprite_x_high + id), 8) + memory.readbyte("WRAM", WRAM.sprite_x_low + id)
            local y = bit.lshift(memory.readbyte("WRAM", WRAM.sprite_y_high + id), 8) + memory.readbyte("WRAM", WRAM.sprite_y_low + id)
            local x_sub = memory.readbyte("WRAM", WRAM.sprite_x_sub + id)
            local y_sub = memory.readbyte("WRAM", WRAM.sprite_y_sub + id)
            local number = memory.readbyte("WRAM", WRAM.sprite_number + id)
            local stun = memory.readbyte("WRAM", WRAM.sprite_stun + id)
            local x_speed = memory.readsbyte("WRAM", WRAM.sprite_x_speed + id)
            local y_speed = memory.readsbyte("WRAM", WRAM.sprite_y_speed + id)
            local contact_mario = memory.readbyte("WRAM", WRAM.sprite_contact_mario + id)
            local x_offscreen = memory.readsbyte("WRAM", WRAM.sprite_x_offscreen + id)
            local y_offscreen = memory.readsbyte("WRAM", WRAM.sprite_y_offscreen + id)
            
            local special = ""
            if show_all_sprite_info or ((sprite_status ~= 0x8 and sprite_status ~= 0x9 and sprite_status ~= 0xa and sprite_status ~= 0xb) or stun ~= 0) then
                special = string.format("(%d %d) ", sprite_status, stun)
            end
            
            -- Let x and y be signed
            if x >= 32768 then x = x - 65535 end
            if y >= 32768 then y = y - 65535 end
            
            -- Prints those info in the sprite-table and display hitboxes
            local draw_str = string.format("#%02d %02x %s%d.%1x(%+.2d) %d.%1x(%+.2d)",
                                            id, number, special, x, x_sub/16, x_speed, y, y_sub/16, y_speed)
            ;
            
            -----------------
            -- displays sprite hitbox
            
            local x_screen, y_screen = screen_coordinates(x, y, camera_x, camera_y)
            
            local boxid = bit.band(memory.readbyte("WRAM", 0x1662 + id), 0x3f)  -- This is the type of box of the sprite
            local x_left = HITBOX_SPRITE[boxid].left
            local x_right = HITBOX_SPRITE[boxid].right
            local y_up = HITBOX_SPRITE[boxid].up
            local y_down = HITBOX_SPRITE[boxid].down
            
            -- Format: dpmksPiS. This 'm' bit seems odd, since it has false negatives
            local oscillation_flag = bit.test(memory.readbyte("WRAM", WRAM.sprite_4_tweaker + id), 5) or OSCILLATION_SPRITES[number]
            --local normal_interaction = bit.testn(memory.readbyte("WRAM", WRAM.sprite_4_tweaker + id), 7) -- test
            --local weird_sprite = bit.binary_st_u8le(memory.readbyte("WRAM", WRAM.sprite_4_tweaker + id))
            
            -- calculates the correct color to use, according to id
            local info_color
            local color_background
            if number == 0x35 then
                info_color = YOSHI_COLOR
                color_background = YOSHI_BG
            else
                info_color = SPRITES_COLOR[id%(#SPRITES_COLOR) + 1]
                color_background = SPRITES_BG
            end
            
            
            if (not oscillation_flag) and (Real_frame - id)%2 == 1 then color_background = -1 end     -- due to sprite oscillation every other frame
                                                                                            -- notice that some sprites interact with Mario every frame
            ;
            
            ------------------
            -- SPRITES' HITBOX
            if not Sprite_paint then
                Sprite_paint = {}
                for key = 0, SMW.sprite_max - 1 do
                    Sprite_paint[tostring(key)] = "sprite"
                end
            end
            
            --print(id, ABNORMAL_HITBOX_SPRITES[id])--test
            if show_sprite_hitbox and Sprite_paint[tostring(id)] ~= "none" and not ABNORMAL_HITBOX_SPRITES[number] then
                if id ~= get_yoshi_id() or yoshi_riding_flag == 0 then
                    
                    
                    --if 
                        --draw_pixel(x_screen, y_screen, "white") -- debug (useful to see when sprite dies in the pit)
                    --end
                    
                    draw_box2(x_screen + x_left, y_screen + y_up, x_screen + x_right, y_screen + y_down,
                              2, info_color, info_color, color_background)
                    ;
                    
                    if y_middle and sprite_status ~= 0x0b then
                        for key, value in ipairs(y_middle) do
                            draw_line(x_screen + x_left, y_screen + value, x_screen + x_right, y_screen + value, info_color)
                        end
                    end
                else
                    draw_box(x_screen + x_left - 2, y_screen + y_up - 9,
                             x_screen + x_right + 2, y_screen + y_down - 8, 2, YOSHI_COLOR, YOSHI_BG_MOUNTED)
                    ;
                end
            end
            --END OF SPRITES' HITBOX
            ------------------------
            
            
            -------------------
            -- SPECIAL SPRITES:
            
            --[[
            PROBLEMATIC ONES
                29	Koopa Kid
                54  Revolving door for climbing net, wrong hitbox area, not urgent
                5a  Turn block bridge, horizontal, hitbox only applies to central block and wrongly
                6b	Wall springboard (left wall), wrong area
                6c	Wall springboard (right wall), hitbox misplaced, wrong area
                86	Wiggler, the second part of the sprite, that hurts Mario even if he's on Yoshi, doesn't appear
                89	Layer 3 Smash, hitbox of generator outside
                9e	Ball 'n' Chain, hitbox only applies to central block, rotating ball
                a3	Rotating gray platform, wrong hitbox, rotating plataforms
            ]]
            
            --[[
            if number == 0x5f then  -- Swinging brown platform (fix it)
                local plataform_x = -memory.readsbyte("WRAM", 0x1523)
                local plataform_y = -memory.readsbyte("WRAM", 0x0036)
                
                custom_text(2*(x_screen + x_left + x_right - 16), 2*(y_screen + y_up - 26), {"%4d, %4d", plataform_x, plataform_y},
                    "snes9xtext", info_color, color_bg, "black")
                ;
                
                draw_box2(x_screen + x_left + plataform_x/2, y_screen + y_up + plataform_y/2, x_screen + x_right + plataform_x/2, y_screen + y_down + plataform_y/2,
                          2, info_color, info_color, color_background)
                ;
                
                
            end
            --]]
            
            if number == 0x62 or number == 0x63 then  -- Brown line-guided platform & Brown/checkered line-guided platform
                    x_screen = x_screen - 24
                    y_screen = y_screen - 8
                    --y_down = y_down -- todo: investigate why the actual base is pixel below when Mario is small
                    
                    draw_box2(x_screen + x_left, y_screen + y_up, x_screen + x_right, y_screen + y_down,
                              2, info_color, info_color, color_background)
                    ;
            end
            
            if number == 0x7b then  -- Goal Tape
            
                draw_line(x_screen + x_left, 0, x_screen + x_left, 448, info_color)
                draw_text(2*x_screen - 4, 224, {"Mario = %4d.0", x - 8}, info_color, color_bg)
            
            elseif number == 0xa9 then  -- Reznor
            
                local font = "snes9xluaclever"
                local reznor
                local color
                for index = 0, SMW.sprite_max - 1 do
                    reznor = memory.readbyte("WRAM", WRAM.reznor_killed_flag + index)
                    if index >= 4 and index <= 7 then
                        color = REC_color
                    else
                        color = color_weak
                    end
                    custom_text(3*CUSTOM_FONTS[font].width*index, "bottom-border", {"%.2x", reznor}, font, color, -1, background_color)
                end
            
            end
            -- END OF SPECIAL SPRITES
            -------------------------
            
            -- Prints those informations next to the sprite
            if contact_mario == 0 then contact_mario = "" end
            
            if x_offscreen ~= 0 or y_offscreen ~= 0 or (id == get_yoshi_id() and yoshi_riding_flag ~= 0) then  -- more transparency if sprite is offscreen or it's Yoshi under Mario
                info_color = change_transparency(info_color, 0.7)
                color_bg = change_transparency(background_color, 0.2)
            else
                color_bg = background_color
            end
            
            --[[ Debug
            custom_text(2*(x_screen + x_left + x_right - 32), 2*(y_screen + y_up - 10) - 16,
                       {"%.2x: %.2d, %.2d ; %.2d, %.2d; %s", boxid, x_left, x_right, y_up, y_down, oscillation_flag},
                        "snes9xtext", info_color, color_bg, "black")
            ;
            --]]
            
            local sprite_middle = x_screen + (x_left + x_right)/2
            custom_text(2*(sprite_middle - 6), 2*(y_screen + y_up - 10), {"#%.2d %s", id, contact_mario},
                                "snes9xtext", info_color, color_bg, "black")
            ;
            
            
            -----------------
            
            draw_text("right-border", table_position + counter*LSNES_FONT_HEIGHT, draw_str, info_color, background_color)
            
            counter = counter + 1
        end
    
    end
    
    draw_text("right-border", table_position - LSNES_FONT_HEIGHT, {"spr:%.2d", counter}, 0x00a9a9a9, background_color)
end

local function yoshi()
    local yoshi_id = get_yoshi_id()
    if yoshi_id ~= nil then
        local eat_id = memory.readbyte("WRAM", WRAM.sprite_miscellaneous + yoshi_id)
        local eat_type = memory.readbyte("WRAM", WRAM.sprite_number + eat_id)
        local tongue_len = memory.readbyte("WRAM", WRAM.sprite_tongue_length + yoshi_id)
        local tongue_timer = memory.readbyte("WRAM", WRAM.sprite_tongue_timer + yoshi_id)
        local tongue_wait = memory.readbyte("WRAM", WRAM.sprite_tongue_wait)
        
        eat_type = eat_id == 0xff and "-" or string.format("%02x", eat_type)
        eat_id = eat_id == 0xff and "-" or string.format("#%02d", eat_id)
        
        -- mixes tongue_wait with tongue_timer
        if tongue_timer == 0 and tongue_wait ~= 0 then
            tongue_timer_string = string.format("%02d", tongue_wait)
        elseif tongue_timer ~= 0 and tongue_wait == 0 then
            tongue_timer_string = string.format("%02d", tongue_timer)
        elseif tongue_timer ~= 0 and tongue_wait ~= 0 then
            tongue_timer_string = string.format("%02d, %02d !!!", tongue_wait, tongue_timer)  -- expected to never occur
        else
            tongue_timer_string = "00"
        end
        
        draw_text(0, 11*LSNES_FONT_HEIGHT, {"Yoshi (%0s, %0s, %02d, %s)", eat_id, eat_type, tongue_len, tongue_timer_string}, YOSHI_COLOR, background_color)
        
        -- more WRAM values
        local yoshi_x = bit.lshift(memory.readbyte("WRAM", WRAM.sprite_x_high + yoshi_id), 8) + memory.readbyte("WRAM", WRAM.sprite_x_low + yoshi_id)
        local yoshi_y = bit.lshift(memory.readbyte("WRAM", WRAM.sprite_y_high + yoshi_id), 8) + memory.readbyte("WRAM", WRAM.sprite_y_low + yoshi_id)
        local camera_x = memory.readsword("WRAM", WRAM.camera_x)
        local camera_y = memory.readsword("WRAM", WRAM.camera_y)
        local mount_invisibility = memory.readbyte("WRAM", WRAM.sprite_miscellaneous2 + yoshi_id)
        
        local x_screen, y_screen = screen_coordinates(yoshi_x, yoshi_y, camera_x, camera_y)
        
        if mount_invisibility ~= 0 then
            custom_text(2*x_screen + 8, 2*y_screen - 24, mount_invisibility, "snes9xtext", YOSHI_COLOR, background_color, outline_color)
        end
        
        -- tongue hitbox point
        if tongue_timer ~= 0 or tongue_wait ~= 0 or tongue_len ~= 0 then
            
            local yoshi_x = bit.lshift(memory.readbyte("WRAM", WRAM.sprite_x_high + yoshi_id), 8) + memory.readbyte("WRAM", WRAM.sprite_x_low + yoshi_id)
            local yoshi_y = bit.lshift(memory.readbyte("WRAM", WRAM.sprite_y_high + yoshi_id), 8) + memory.readbyte("WRAM", WRAM.sprite_y_low + yoshi_id)
            local camera_x = memory.readsword("WRAM", WRAM.camera_x)
            local camera_y = memory.readsword("WRAM", WRAM.camera_y)
            local yoshi_direction = memory.readbyte("WRAM", WRAM.sprite_direction + yoshi_id)
            local tongue_direction = (1 - 2*yoshi_direction)
            local tongue_high = memory.readsbyte("WRAM", WRAM.yoshi_tongue_height) ~= 0x0a
            
            local x_inc = (yoshi_direction ~= 0 and -0x0f) or 0x1f
            if tongue_high then x_inc = x_inc - 0x05*tongue_direction end
            local y_inc = (tongue_high and 0xe) or 0x19
            local x_screen, y_screen = screen_coordinates(yoshi_x, yoshi_y, camera_x, camera_y)
            local x_tongue, y_tongue = x_screen + x_inc + tongue_len*tongue_direction, y_screen + y_inc
            
            -- the drawing
            draw_box(x_tongue - 5*tongue_direction, y_tongue - 4, x_tongue - tongue_direction, y_tongue + 4, 2, TONGUE_BG, TONGUE_BG)
            if tongue_wait <= 0x9 then
                draw_line(x_tongue - 5*tongue_direction, y_tongue, x_tongue - tongue_direction, y_tongue, YOSHI_COLOR)
            end
            
        end
        
    end
end

local function show_counters()
    -- Font
    local font = "default"--"snes9xtext"--
    local height = CUSTOM_FONTS[font].height
    local text_counter = 0
    
    local multicoin_block_timer = memory.readbyte("WRAM", WRAM.multicoin_block_timer)
    local gray_pow_timer = memory.readbyte("WRAM", WRAM.gray_pow_timer)
    local blue_pow_timer = memory.readbyte("WRAM", WRAM.blue_pow_timer)
    local dircoin_timer = memory.readbyte("WRAM", WRAM.dircoin_timer)
    local pballoon_timer = memory.readbyte("WRAM", WRAM.pballoon_timer)
    local star_timer = memory.readbyte("WRAM", WRAM.star_timer)
    local invisibility_timer = memory.readbyte("WRAM", WRAM.invisibility_timer)
    local animation_timer = memory.readbyte("WRAM", WRAM.animation_timer)
    local fireflower_timer = memory.readbyte("WRAM", WRAM.fireflower_timer)
    local yoshi_timer = memory.readbyte("WRAM", WRAM.yoshi_timer)
    local swallow_timer = memory.readbyte("WRAM", WRAM.swallow_timer)
    local lakitu_timer = memory.readbyte("WRAM", WRAM.lakitu_timer)
    
    local display_counter = function(label, value, default, mult, frame, color)
        if value == default then return end
        text_counter = text_counter + 1
        local color = color or text_color
        
        custom_text(0, 196 + (text_counter * height), {"%s: %d", label, (value * mult) - frame}, font, color, background_color, outline_color)
    end
    
    display_counter("Multi Coin", multicoin_block_timer, 0, 1, 0)
    display_counter("Pow", gray_pow_timer, 0, 4, Effective_frame % 4, 0x007e7e7e)
    display_counter("Pow", blue_pow_timer, 0, 4, Effective_frame % 4, 0x000000ff)
    display_counter("Dir Coin", dircoin_timer, 0, 4, Real_frame % 4, 0x00a52a2a)
    display_counter("P-Balloon", pballoon_timer, 0, 4, Real_frame % 4)
    display_counter("Star", star_timer, 0, 4, (Effective_frame - 3) % 4, 0x00ffff00)
    display_counter("Invibility", invisibility_timer, 0, 1, 0)
    display_counter("Fireflower", fireflower_timer, 0, 1, 0, 0x00ffa500)
    display_counter("Yoshi", yoshi_timer, 0, 1, 0, YOSHI_COLOR)
    display_counter("Swallow", swallow_timer, 0, 4, (Effective_frame - 1) % 4, YOSHI_COLOR)
    display_counter("Lakitu", lakitu_timer, 0, 4, Effective_frame % 4)
    
    if Lock_animation_flag ~= 0 then display_counter("Animation", animation_timer, 0, 1, 0) end  -- shows when player is getting hurt or dying
    
    local score_incrementing = memory.readbyte("WRAM", WRAM.score_incrementing)
    local end_level_timer = memory.readbyte("WRAM", WRAM.end_level_timer)
    
    display_counter("End Level", end_level_timer, 0, 2, (Real_frame - 1) % 2)
    display_counter("Score Incrementing", score_incrementing, 0x50, 1, 0)
end

--#############################################################################
-- CHEATS

local Cheat_flag = false
local function is_cheat_active()
    if Cheat_flag then gui.textHV(screen_width/2 - 3*LSNES_FONT_WIDTH, 0, "Cheat", lag_color, 0xa0000000) end
    Cheat_flag = false
end

-- allows start + select + X to activate the normal exit
--        start + select + A to activate the secret exit 
--        start + select + B to exit the level without activating any exits
local on_exit_mode = false
local force_secret_exit = false
local function beat_level()
    if Is_paused and Joypad["select"] == 1 and (Joypad["X"] == 1 or Joypad["A"] == 1 or Joypad["B"] == 1) then
        memory.writebyte("WRAM", WRAM.level_flag_table + Level_index, bit.bor(Level_flag, 0x80))
        
        force_secret_exit = Joypad["A"] == 1
        if Joypad["B"] == 0 then
            memory.writebyte("WRAM", WRAM.midway_point, 1)
        else
            memory.writebyte("WRAM", WRAM.midway_point, 0)
        end
        
        on_exit_mode = true
    end
    
end

local function activate_next_level()
    if not on_exit_mode then return end
    
    if memory.readbyte("WRAM", WRAM.level_exit_type) == 0x80 and memory.readbyte("WRAM", WRAM.midway_point) == 1 then
        if force_secret_exit then
            memory.writebyte("WRAM", WRAM.level_exit_type, 0x2)
        else
            memory.writebyte("WRAM", WRAM.level_exit_type, 1)
        end
        
        on_exit_mode = false
        Cheat_flag = true
    end
    
end

-- This function forces the score to a given value
-- Change _set_score to true and press L+R+A
local _set_score = false
local function set_score()
    if (Joypad["L"] == 1 and Joypad["R"] == 1 and Joypad["A"] == 1) then _set_score = true end
    if not _set_score then return end
    
    local desired_score = 11450 -- set score here WITH the last digit 0
    draw_text(24, 144, {"Set score to %d", desired_score}, text_color, background_color)
    print("Script edited score")
    
    desired_score = desired_score/10
    score0 = desired_score%0x100 -- low
    score1 = ((desired_score - score0)/0x100)%0x100
    score2 = (desired_score - score1*0x100 - score0)/0x100%0x1000000
    
    memory.writebyte("WRAM", WRAM.mario_score, score0)
    memory.writebyte("WRAM", WRAM.mario_score + 1, score1)
    memory.writebyte("WRAM", WRAM.mario_score + 2, score2)
    
    --memory.writebyte("WRAM", 0x7e0dbf, 0) -- number of coins
    
    _set_score = false
    
    Cheat_flag = true
end

-- This function forces Mario's position to a given value
-- Change _force_pos to true and press L+R+up to activate and L+R+down to turn it off.
local _force_pos = false
local Y_cheat = nil
local function force_pos()
    if (Joypad["L"] == 1 and Joypad["R"] == 1 and Joypad["up"] == 1) then _force_pos = true end
    if (Joypad["L"] == 1 and Joypad["R"] == 1 and Joypad["down"] == 1) then _force_pos = false; Y_cheat = nil; end
    if not _force_pos then return end
    
    local Y_cheat = Y_cheat or memory.readsword("WRAM", WRAM.y)
    
    if Joypad["down"] == 1 then Y_cheat = Y_cheat + 1 end
    if Joypad["up"] == 1 then Y_cheat = Y_cheat - 1 end
    
    memory.writeword("WRAM", WRAM.y, Y_cheat)
    memory.writebyte("WRAM", WRAM.y_sub, 0)
    memory.writebyte("WRAM", WRAM.y_speed, 0)
    
    Cheat_flag = true
end

--#############################################################################
-- COMPARISON SCRIPT (EXPERIMENTAL)--

local Show_comparison  = nil
if type(GHOST_FILENAME) == "string" then
    Show_comparison = io.open(GHOST_FILENAME)
end

if Show_comparison then
    dofile(GHOST_FILENAME)
    print("Loaded comparison script.")
    ghostfile = ghost_dumps[1]
    ghost_room_table = read_ghost_rooms(ghostfile)
end

-- END OF THE COMPARISON SCRIPT (EXPERIMENTAL)--

--#############################################################################
-- MAIN --

gui.subframe_update(false)

function on_frame_emulated()
    Is_lagged = memory.get_lag_flag()
end

user_input = {}
function on_input(subframe)
    user_input = input.raw()
    
    read_mouse()
    get_joypad()  -- to be deprecated?
    
    input.keyhook("mouse_right", true) -- calls on_keyhook when right-click changes
    input.keyhook("mouse_left", true) -- calls on_keyhook when left-click changes
    
    change_background_opacity()
    if ALLOW_CHEATS then
        beat_level()
        activate_next_level()
        set_score()
        force_pos()
    end
end

function on_keyhook(key, inner_table)
    if key == "mouse_right" then
        sprite_click()
        on_player_click()
    end
    
    if key == "mouse_left" then
        clear_block_drawing()
    end
end

-- Loading a state
function on_pre_load()
    Current_movie = movie.copy_movie()
end

function on_post_load()
    Current_movie = movie.copy_movie()
end

function on_paint(not_synth)
    screen_width, screen_height = gui.resolution()
    create_gaps()
    Borders = get_border_values()
    
    scan_smw()
    if Game_mode == SMW.game_mode_level then  -- in level functions
        if show_sprite_info then sprites() end
        if show_level_info then level() end
        if show_pit then draw_pit() end
        if show_player_info then player() end
        if show_yoshi_info then yoshi() end
        if show_counters_info then show_counters() end
    end
    
    if display_movie_info then show_movie_info(not_synth) end
    if display_misc_info then show_misc_info() end
    if show_controller_input then display_input() end
    
    is_cheat_active()
    
    -- Comparison script (needs external file to work)
    if Show_comparison then
        comparison(not_synth)
    end
end

gui.repaint()
