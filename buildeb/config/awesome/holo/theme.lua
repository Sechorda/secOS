local gears = require("gears")
local lain  = require("lain")
local awful = require("awful")
local wibox = require("wibox")
local dpi   = require("beautiful.xresources").apply_dpi

local string, os = string, os
local my_table = awful.util.table or gears.table -- 4.{0,1} compatibility

local theme                                     = {}
theme.default_dir                               = require("awful.util").get_themes_dir() .. "default"
theme.icon_dir                                  = os.getenv("HOME") .. "/.config/awesome/themes/holo/icons"
theme.wallpaper                                 = os.getenv("HOME") .. "/.config/awesome/themes/holo/mist.jpg"
theme.font                                      = "Roboto Bold 10"
theme.taglist_font                              = "Roboto Condensed Regular 8"
theme.fg_normal                                 = "#FFFFFF"
theme.fg_focus                                  = "#0099CC"
theme.bg_focus                                  = "#303030"
theme.bg_normal                                 = "#242424"
theme.fg_urgent                                 = "#CC9393"
theme.bg_urgent                                 = "#006B8E"
theme.border_width                              = 0
theme.border_normal                             = "#252525"
theme.border_focus                              = "#0099CC"
theme.taglist_fg_focus                          = "#FFFFFF"
theme.tasklist_bg_normal                        = "#222222"
theme.tasklist_fg_focus                         = "#4CB7DB"
theme.tasklist_shape                            = gears.shape.circle
theme.tasklist_shape_border_width               = dpi(1)
theme.tasklist_shape_border_color               = theme.border_focus
theme.tasklist_spacing                          = dpi(4)
theme.tasklist_align                            = "center"
theme.tasklist_font                             = theme.font
theme.tasklist_disable_icon                     = false
theme.tasklist_icon_size                        = dpi(24)
theme.tasklist_plain_task_name                  = false
theme.tasklist_disable_icon                     = false
theme.tasklist_plain_task_name                  = false
theme.tasklist_multiple_instance_indicator      = "#0099CC"  -- Match your focus color
theme.menu_height                               = dpi(20)
theme.menu_width                                = dpi(160)
theme.menu_icon_size                            = dpi(32)
theme.awesome_icon                              = theme.icon_dir .. "/awesome_icon_white.png"
theme.awesome_icon_launcher                     = theme.icon_dir .. "/awesome_icon.png"
theme.taglist_squares_sel                       = theme.icon_dir .. "/square_sel.png"
theme.taglist_squares_unsel                     = theme.icon_dir .. "/square_unsel.png"
theme.spr_small                                 = theme.icon_dir .. "/spr_small.png"
theme.spr_very_small                            = theme.icon_dir .. "/spr_very_small.png"
theme.spr_right                                 = theme.icon_dir .. "/spr_right.png"
theme.spr_bottom_right                          = theme.icon_dir .. "/spr_bottom_right.png"
theme.spr_left                                  = theme.icon_dir .. "/spr_left.png"
theme.bar                                       = theme.icon_dir .. "/bar.png"
theme.bottom_bar                                = theme.icon_dir .. "/bottom_bar.png"
theme.mpdl                                      = theme.icon_dir .. "/mpd.png"
theme.mpd_on                                    = theme.icon_dir .. "/mpd_on.png"
theme.prev                                      = theme.icon_dir .. "/prev.png"
theme.nex                                       = theme.icon_dir .. "/next.png"
theme.stop                                      = theme.icon_dir .. "/stop.png"
theme.pause                                     = theme.icon_dir .. "/pause.png"
theme.play                                      = theme.icon_dir .. "/play.png"
theme.clock                                     = theme.icon_dir .. "/clock.png"
theme.calendar                                  = theme.icon_dir .. "/cal.png"
theme.cpu                                       = theme.icon_dir .. "/cpu.png"
theme.bat                                       = theme.icon_dir .. "/battery-icon.png"
theme.net_up                                    = theme.icon_dir .. "/net_up.png"
theme.net_down                                  = theme.icon_dir .. "/net_down.png"
theme.wifi_icon                                 = theme.icon_dir .. "/wifi-icon.svg"
theme.bluetooth_icon                            = theme.icon_dir .. "/bluetooth-icon.png"
theme.layout_tile                               = theme.icon_dir .. "/tile.png"
theme.layout_floating                           = theme.icon_dir .. "/floating.png"
theme.tasklist_plain_task_name                  = true
theme.tasklist_disable_icon                     = true
theme.useless_gap                               = dpi(4)
theme.titlebar_close_button_normal              = theme.icon_dir .. "/close-icon.svg"
theme.titlebar_close_button_focus               = theme.icon_dir .. "/close-icon.svg"
theme.titlebar_minimize_button_normal           = theme.icon_dir .. "/minimize-icon.svg"
theme.titlebar_minimize_button_focus            = theme.icon_dir .. "/minimize-icon.svg"
theme.titlebar_ontop_button_normal_inactive     = theme.icon_dir .. "/pin-icon.svg"
theme.titlebar_ontop_button_focus_inactive      = theme.icon_dir .. "/pin-icon.svg"
theme.titlebar_ontop_button_normal_active       = theme.icon_dir .. "/pin-icon.svg"
theme.titlebar_ontop_button_focus_active        = theme.icon_dir .. "/pin-icon.svg"
theme.titlebar_maximized_button_normal_inactive = theme.icon_dir .. "/maximize-icon.svg"
theme.titlebar_maximized_button_focus_inactive  = theme.icon_dir .. "/maximize-icon.svg"
theme.titlebar_maximized_button_normal_active   = theme.icon_dir .. "/maximize-icon.svg"
theme.titlebar_maximized_button_focus_active    = theme.icon_dir .. "/maximize-icon.svg"

theme.musicplr = string.format("%s -e ncmpcpp", awful.util.terminal)

local markup = lain.util.markup
local blue   = "#80CCE6"
local space3 = markup.font("Roboto 3", " ")

-- Clock
local mytextclock = wibox.widget.textclock(markup("#FFFFFF", space3 .. "%H:%M   " .. markup.font("Roboto 4", " ")))
mytextclock.font = theme.font
local clock_icon = wibox.widget.imagebox(theme.clock)
local clockbg = wibox.container.background(mytextclock, theme.bg_focus, gears.shape.rectangle)
local clockwidget = wibox.container.margin(clockbg, dpi(0), dpi(3), dpi(5), dpi(5))

-- Calendar
local mytextcalendar = wibox.widget.textclock(markup.fontfg(theme.font, "#FFFFFF", space3 .. "%d %b " .. markup.font("Roboto 5", " ")))
local calendar_icon = wibox.widget.imagebox(theme.calendar)
local calbg = wibox.container.background(mytextcalendar, theme.bg_focus, gears.shape.rectangle)
local calendarwidget = wibox.container.margin(calbg, dpi(0), dpi(0), dpi(5), dpi(5))
theme.cal = lain.widget.cal({
    attach_to = { mytextclock, mytextcalendar },
    notification_preset = {
        fg = "#FFFFFF",
        bg = theme.bg_normal,
        position = "bottom_right",
        font = "Monospace 10"
    }
})

local mpd_icon = awful.widget.launcher({ image = theme.mpdl, command = theme.musicplr })
local prev_icon = wibox.widget.imagebox(theme.prev)
local next_icon = wibox.widget.imagebox(theme.nex)
local stop_icon = wibox.widget.imagebox(theme.stop)
local pause_icon = wibox.widget.imagebox(theme.pause)
local play_pause_icon = wibox.widget.imagebox(theme.play)

-- New Playerctl widget
local playerctl = {}
playerctl.widget = wibox.widget {
    markup = "",
    align  = "center",
    valign = "center",
    widget = wibox.widget.textbox
}

-- Function to update player status
local function update_player_status()
    awful.spawn.easy_async("playerctl -p spotify status", function(stdout)
        local status = stdout:gsub("%s+", "")
        if status == "Playing" then
            play_pause_icon:set_image(theme.pause)
        else
            play_pause_icon:set_image(theme.play)
        end
    end)
    
    awful.spawn.easy_async("playerctl -p spotify metadata --format '{{ artist }} - {{ title }}'", function(stdout)
        if stdout ~= "" then
            playerctl.widget:set_markup(markup.font("Roboto 4", " ")
                          .. markup.font(theme.taglist_font,
                          " " .. stdout:gsub("\n", "") .. "  ")
                          .. markup.font("Roboto 5", " "))
        else
            playerctl.widget:set_markup("")
        end
    end)
end

-- Set up buttons for player controls
play_pause_icon:buttons(my_table.join(awful.button({}, 1,
function ()
    awful.spawn("playerctl -p spotify play-pause")
    gears.timer.delayed_call(update_player_status)
end)))

prev_icon:buttons(my_table.join(awful.button({}, 1,
function ()
    awful.spawn("playerctl -p spotify previous")
    gears.timer.delayed_call(update_player_status)
end)))

next_icon:buttons(my_table.join(awful.button({}, 1,
function ()
    awful.spawn("playerctl -p spotify next")
    gears.timer.delayed_call(update_player_status)
end)))

-- Update status every 2 seconds
gears.timer {
    timeout = 2,
    call_now = true,
    autostart = true,
    callback = update_player_status
}

local playerbg = wibox.container.background(playerctl.widget, theme.bg_focus, gears.shape.rectangle)
local playerwidget = wibox.container.margin(playerbg, dpi(0), dpi(0), dpi(5), dpi(5))

-- Battery
local bat_icon = wibox.widget.imagebox(theme.bat)
local bat = lain.widget.bat({
    settings = function()
        bat_header = ""
        bat_p      = bat_now.perc .. "%"
        if bat_now.ac_status == 1 then
            bat_p = bat_p
        end
        widget:set_markup(markup.font(theme.font, markup(blue, bat_header) .. bat_p))
    end
})
local batbg = wibox.container.background(bat.widget, theme.bg_focus, gears.shape.rectangle)
local batwidget = wibox.container.margin(batbg, dpi(0), dpi(0), dpi(5), dpi(5))

-- Modified Volume Control using MPD icon
local mpd_icon = wibox.widget {
    {
        widget = wibox.widget.imagebox,
        image = theme.mpdl,
        resize = true,
        id = "icon"
    },
    widget = wibox.container.background
}

-- Create horizontal volume slider
local volume_slider = wibox.widget {
    widget = wibox.widget.slider,
    bar_shape = gears.shape.rounded_rect,
    bar_height = dpi(2),
    bar_color = "#383838",
    handle_width = dpi(8),
    handle_shape = gears.shape.circle,
    handle_color = "#80CCE6",
    handle_border_width = 1,
    handle_border_color = "#80CCE6",
    minimum = 0,
    maximum = 100,
    value = 50
}

-- Add margins around the volume bar
local volume_with_margin = wibox.widget {
    volume_slider,
    margins = dpi(10),
    widget = wibox.container.margin
}

-- Create a larger area around the volume bar to prevent popup from disappearing
local volume_container = wibox.widget {
    volume_with_margin,
    forced_width = dpi(120),
    forced_height = dpi(30),
    bg = theme.bg_normal,
    shape = function(cr, width, height)
        gears.shape.rounded_rect(cr, width, height, dpi(6))
    end,
    widget = wibox.container.background
}

-- Create the volume popup
local volume_popup = awful.popup {
    widget = volume_container,
    visible = false,
    ontop = true,
    hide_on_right_click = false,
    bg = theme.bg_normal,
    border_width = dpi(1),
    border_color = theme.border_focus,
    shape = function(cr, width, height)
        gears.shape.rounded_rect(cr, width, height, dpi(6))
    end,
    minimum_width = dpi(120),
    maximum_width = dpi(120),
    minimum_height = dpi(30),
    maximum_height = dpi(30),
}

-- Update volume when slider changes
volume_slider:connect_signal("property::value", function()
    local volume_level = volume_slider.value
    awful.spawn.easy_async("amixer -D pulse sget Master", function(stdout)
        if not stdout:match("%[off%]") then  -- Only update if not muted
            awful.spawn.with_shell(string.format("amixer -D pulse sset Master %d%%", volume_level))
        end
    end)
end)

-- Set initial volume value
awful.spawn.easy_async("amixer -D pulse sget Master", function(stdout)
    if stdout then
        local volume = string.match(stdout, "(%d+)%%")
        volume_slider.value = tonumber(volume) or 50
    end
end)

-- Toggle mute only on icon click
mpd_icon:buttons(awful.util.table.join(
    awful.button({}, 1, function()
        awful.spawn.with_shell("amixer -D pulse set Master toggle")
        awful.spawn.easy_async("amixer -D pulse sget Master", function(stdout)
            if stdout:match("%[off%]") then
                mpd_icon:get_children_by_id("icon")[1]:set_image(theme.mpd_on)
            else
                mpd_icon:get_children_by_id("icon")[1]:set_image(theme.mpdl)
                -- Restore previous volume when unmuting
                volume_slider:emit_signal("property::value")
            end
        end)
    end)
))

-- Function to update popup position
local function show_volume_popup()
    local s = awful.screen.focused()
    local offset = dpi(10)  -- Distance from right edge

    volume_popup:move_next_to({
        x = s.geometry.width - volume_popup.width - offset,
        y = s.mywibox.height + dpi(45),
        width = 1,
        height = 1
    })
    volume_popup.visible = true
end

-- Variables to track hover state
local hover_timer = nil
local mouse_in_popup = false
local mouse_in_icon = false

-- Add hover behavior
mpd_icon:connect_signal("mouse::enter", function()
    if hover_timer then
        hover_timer:stop()
    end
    show_volume_popup()
    mouse_in_icon = true
end)

volume_popup:connect_signal("mouse::enter", function()
    if hover_timer then
        hover_timer:stop()
    end
    mouse_in_popup = true
end)

-- Function to handle mouse leave events
local function handle_mouse_leave()
    if hover_timer then
        hover_timer:stop()
    end
    
    hover_timer = gears.timer.start_new(0.5, function()
        if not mouse_in_icon and not mouse_in_popup then
            volume_popup.visible = false
        end
        hover_timer = nil
        return false
    end)
end

mpd_icon:connect_signal("mouse::leave", function()
    mouse_in_icon = false
    handle_mouse_leave()
end)

volume_popup:connect_signal("mouse::leave", function()
    mouse_in_popup = false
    handle_mouse_leave()
end)

-- CPU
local cpu_icon = wibox.widget.imagebox(theme.cpu)
local cpu = lain.widget.cpu({
    settings = function()
        widget:set_markup(space3 .. markup.font(theme.font, "CPU " .. cpu_now.usage
                          .. "% ") .. markup.font("Roboto 5", " "))
    end
})
local cpubg = wibox.container.background(cpu.widget, theme.bg_focus, gears.shape.rectangle)
local cpuwidget = wibox.container.margin(cpubg, dpi(0), dpi(0), dpi(5), dpi(5))

-- Net
local netdown_icon = wibox.widget.imagebox(theme.net_down)
local netup_icon = wibox.widget.imagebox(theme.net_up)
local net = lain.widget.net({
    settings = function()
        widget:set_markup(markup.font("Roboto 1", " ") .. markup.font(theme.font, net_now.received .. " - "
                          .. net_now.sent) .. markup.font("Roboto 2", " "))
    end
})
local netbg = wibox.container.background(net.widget, theme.bg_focus, gears.shape.rectangle)
local networkwidget = wibox.container.margin(netbg, dpi(0), dpi(0), dpi(5), dpi(5))

-- Rofi-network-manager
local rofi_net_widget = wibox.widget {
    {
        id = "icon",
        widget = wibox.widget.imagebox,
        image = theme.wifi_icon,
        resize = true,
        forced_width = dpi(24),
        forced_height = dpi(24),
    },
    layout = wibox.container.margin,
    left = dpi(3),
    right = dpi(3),
}

rofi_net_widget:connect_signal("button::press", function(_, _, _, button)
    if button == 1 then  -- left click
        awful.spawn("ronema")
    end
end)

-- Rofi-bluetooth-manager
local rofi_bluetooth_widget = wibox.widget {
    {
        id = "icon",
        widget = wibox.widget.imagebox,
        image = theme.bluetooth_icon,
        resize = true,
        forced_width = dpi(24),
        forced_height = dpi(24),
    },
    layout = wibox.container.margin,
    left = dpi(3),
    right = dpi(3),
}

rofi_bluetooth_widget:connect_signal("button::press", function(_, _, _, button)
    if button == 1 then  -- left click
        awful.spawn("roblma")
    end
end)

--tasklist

local function create_tasklist(s)
    -- Helper function to get grouped clients
    local function get_grouped_clients()
        local clients_by_class = {}
        for _, c in ipairs(client.get()) do
            if awful.widget.tasklist.filter.currenttags(c, s) then
                local class = c.class or '['..c.name..']'
                if not clients_by_class[class] then
                    clients_by_class[class] = {}
                end
                table.insert(clients_by_class[class], c)
            end
        end
        return clients_by_class
    end

    -- Create a table to store our widgets
    local widgets_table = {}
    
    -- Keep track of pending updates
    local pending_updates = {}
    
    -- Function to update background for a specific class
    local function update_class_backgrounds(class, skip_delay)
        if pending_updates[class] then
            return
        end
        
        pending_updates[class] = true
        
        local function do_update()
            pending_updates[class] = nil
            
            local clients_by_class = get_grouped_clients()
            local clients = clients_by_class[class]
            
            if clients then
                local is_stacked = #clients > 1
                for _, c in ipairs(clients) do
                    local widget = widgets_table[c]
                    if widget then
                        local bg_widget = widget:get_children_by_id('background_role')[1]
                        bg_widget.bg = is_stacked and "#004466" or "transparent"
                    end
                end
            end
        end

        if skip_delay then
            do_update()
        else
            gears.timer.delayed_call(do_update)
        end
    end

    -- Function to force update all widgets
    local function force_update_all_widgets()
        local clients_by_class = get_grouped_clients()
        
        -- Update backgrounds based on grouping
        for class, clients in pairs(clients_by_class) do
            local is_stacked = #clients > 1
            for _, c in ipairs(clients) do
                local widget = widgets_table[c]
                if widget then
                    local bg_widget = widget:get_children_by_id('background_role')[1]
                    bg_widget.bg = is_stacked and "#004466" or "transparent"
                end
            end
        end
    end

    local tasklist = awful.widget.tasklist {
        screen = s,
        filter = function(c, s)
            -- Only show one client per class
            local clients_by_class = get_grouped_clients()
            for class, clients in pairs(clients_by_class) do
                if clients[1] == c then
                    return true
                end
            end
            return false
        end,
        buttons = awful.util.table.join(
            awful.button({}, 1, function(c)
                local clients_by_class = get_grouped_clients()
                local class = c.class or '['..c.name..']'
                local clients = clients_by_class[class] or {}

                if #clients > 1 then
                    -- Create menu items for each window
                    local items = {}
                    for _, cl in ipairs(clients) do
                        table.insert(items, {
                            cl.name,
                            function()
                                if cl == client.focus then
                                    cl.minimized = true
                                else
                                    cl:emit_signal("request::activate", "tasklist", { raise = true })
                                end
                            end
                        })
                    end

                    -- Show menu
                    local m = awful.menu({
                        items = items,
                        theme = {
                            width = 300,
                            height = dpi(24),
                            border_width = dpi(2),
                            border_color = theme.border_focus,
                            fg_focus = theme.tasklist_fg_focus,
                            bg_focus = theme.bg_focus,
                            fg_normal = theme.fg_normal,
                            bg_normal = theme.bg_normal
                        }
                    })

                    local geo = mouse.current_widget_geometry
                    m:show({
                        coords = {
                            x = geo.x,
                            y = geo.y + geo.height + dpi(2)
                        }
                    })
                else
                    -- Single window behavior
                    if c == client.focus then
                        c.minimized = true
                    else
                        c:emit_signal("request::activate", "tasklist", { raise = true })
                    end
                end
            end),
            awful.button({}, 3, function(c)
                c:emit_signal("request::activate", "tasklist", { raise = true })
                awful.menu.client_list({ theme = { width = 250 } })
            end)
        ),
        layout = {
            spacing = theme.tasklist_spacing,
            layout = wibox.layout.flex.horizontal
        },
        widget_template = {
            {
                {
                    {
                        id = 'clienticon',
                        widget = awful.widget.clienticon,
                    },
                    halign = "center",
                    valign = "center",
                    widget = wibox.container.place,
                },
                margins = dpi(4),
                widget = wibox.container.margin,
            },
            id = 'background_role',
            forced_width = theme.tasklist_icon_size + dpi(12),
            forced_height = theme.tasklist_icon_size + dpi(12),
            shape = gears.shape.circle,
            shape_border_width = theme.tasklist_shape_border_width,
            shape_border_color = theme.tasklist_shape_border_color,
            widget = wibox.container.background,
            create_callback = function(self, c, index, objects)
                self:get_children_by_id('clienticon')[1].client = c
                widgets_table[c] = self
                
                -- Set background immediately if needed
                local class = c.class or '['..c.name..']'
                update_class_backgrounds(class, true)
            end,
            update_callback = function(self, c, index, objects)
                widgets_table[c] = self
                local class = c.class or '['..c.name..']'
                update_class_backgrounds(class)
            end,
        },
    }

    -- Set up signals for window events
    local function setup_signals()
        -- Window created
        client.connect_signal("manage", function(c)
            local class = c.class or '['..c.name..']'
            update_class_backgrounds(class, true)  -- Immediate update
        end)
        
        -- Window closed
        client.connect_signal("unmanage", function(c)
            local class = c.class or '['..c.name..']'
            widgets_table[c] = nil
            update_class_backgrounds(class)
        end)
        
        -- Window minimized/unminimized
        client.connect_signal("property::minimized", function(c)
            local class = c.class or '['..c.name..']'
            update_class_backgrounds(class)
        end)
        
        -- Window tagged/untagged
        client.connect_signal("tagged", function(c)
            local class = c.class or '['..c.name..']'
            update_class_backgrounds(class)
        end)
        client.connect_signal("untagged", function(c)
            local class = c.class or '['..c.name..']'
            update_class_backgrounds(class)
        end)
        
        -- Signal when a client's screen changes
        client.connect_signal("property::screen", function(c)
            local class = c.class or '['..c.name..']'
            update_class_backgrounds(class)
        end)
    end

    setup_signals()
    
    -- Initial update of all widgets
    gears.timer.delayed_call(force_update_all_widgets)
    
    return tasklist
end


-- Separators
local first = wibox.widget.textbox('<span font="Roboto 7"> </span>')
local spr_small = wibox.widget.imagebox(theme.spr_small)
local spr_very_small = wibox.widget.imagebox(theme.spr_very_small)
local spr_right = wibox.widget.imagebox(theme.spr_right)
local spr_bottom_right = wibox.widget.imagebox(theme.spr_bottom_right)
local spr_left = wibox.widget.imagebox(theme.spr_left)
local bar = wibox.widget.imagebox(theme.bar)
local bottom_bar = wibox.widget.imagebox(theme.bottom_bar)

-- White bullet separator
local white_bullet = wibox.widget.textbox('<span color="#FFFFFF" font="Roboto Bold 8"> • </span>')

local barcolor  = gears.color({
    type  = "linear",
    from  = { dpi(32), 0 },
    to    = { dpi(32), dpi(32) },
    stops = { {0, theme.bg_focus}, {0.25, "#505050"}, {1, theme.bg_focus} }
})

function theme.at_screen_connect(s)

    -- If wallpaper is a function, call it with the screen
    local wallpaper = theme.wallpaper
    if type(wallpaper) == "function" then
        wallpaper = wallpaper(s)
    end
    gears.wallpaper.maximized(wallpaper, s, true)

    -- Tags
    awful.tag(awful.util.tagnames, s, awful.layout.layouts[1])

    -- Create a promptbox for each screen
    s.mypromptbox = awful.widget.prompt()
    -- Create an imagebox widget which will contains an icon indicating which layout we're using.
    -- We need one layoutbox per screen.
    s.mylayoutbox = awful.widget.layoutbox(s)
    s.mylayoutbox:buttons(my_table.join(
                           awful.button({}, 1, function () awful.layout.inc( 1) end),
                           awful.button({}, 2, function () awful.layout.set( awful.layout.layouts[1] ) end),
                           awful.button({}, 3, function () awful.layout.inc(-1) end),
                           awful.button({}, 4, function () awful.layout.inc( 1) end),
                           awful.button({}, 5, function () awful.layout.inc(-1) end)))
    -- Create a taglist widget
    s.mytaglist = awful.widget.taglist(s, awful.widget.taglist.filter.all, awful.util.taglist_buttons, { bg_focus = barcolor })

    mytaglistcont = wibox.container.background(s.mytaglist, theme.bg_focus, gears.shape.rectangle)
    s.mytag = wibox.container.margin(mytaglistcont, dpi(0), dpi(0), dpi(5), dpi(5))

    -- Create tasklist 
    s.mytasklist = create_tasklist(s)

    -- Create the top wibox
    s.mywibox = awful.wibar({ position = "top", screen = s, height = dpi(32) })

    -- Add widgets to the wibox
    s.mywibox:setup {
        layout = wibox.layout.align.horizontal,
        { -- Left widgets
            layout = wibox.layout.fixed.horizontal,
            first,
            s.mytag,
            spr_small,
            s.mylayoutbox,
            spr_small,
            s.mypromptbox,
        },
        { -- Middle widget (tasklist wrapped in a constraint container)
            {
                s.mytasklist,
                halign = "center",
                widget = wibox.container.place,
            },
            width = dpi(300),  -- Adjust this value to control how much space the tasklist can use
            strategy = "max",
            widget = wibox.container.constraint,
        }, -- Middle widget
        { -- Right widgets
            layout = wibox.layout.fixed.horizontal,
            wibox.widget.systray(),
            rofi_bluetooth_widget,
            white_bullet,
            rofi_net_widget,
            bar,
            prev_icon,
            next_icon,
            play_pause_icon,
            bar,
            mpd_icon,
            bar,
            spr_very_small,
            spr_left,
        },
    }

    -- Create the bottom wibox
    s.mybottomwibox = awful.wibar({ position = "bottom", screen = s, border_width = dpi(0), height = dpi(32) })

    -- Add widgets to the bottom wibox
    s.mybottomwibox:setup {
        layout = wibox.layout.align.horizontal,
        { -- Left widgets
            layout = wibox.layout.fixed.horizontal,
            mylauncher,
        },
        nil, -- Middle widget (removed tasklist)
        { -- Right widgets
            layout = wibox.layout.fixed.horizontal,
            spr_bottom_right,
            netdown_icon,
            networkwidget,
            netup_icon,
            bottom_bar,
            cpu_icon,
            cpuwidget,
            bottom_bar,
            bat_icon,
            batwidget,
            bottom_bar,
            calendar_icon,
            calendarwidget,
            bottom_bar,
            clock_icon,
            clockwidget,
        },
    }
end

return theme