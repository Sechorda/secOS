--[[------------------------------------------------------------
                     Required libraries
------------------------------------------------------------]]--\n
local gears         = require("gears")
local awful         = require("awful")
                      require("awful.autofocus")
local wibox         = require("wibox")
local beautiful     = require("beautiful")
local naughty       = require("naughty")
local lain          = require("lain")
local freedesktop   = require("freedesktop")
local hotkeys_popup = require("awful.hotkeys_popup")
local mytable       = awful.util.table or gears.table -- 4.{0,1} compatibility
local switcher = require("awesome-switcher")
--[[------------------------------------------------------------
                       Error handling
------------------------------------------------------------]]--\n
-- Check if awesome encountered an error during startup
if awesome.startup_errors then
    naughty.notify {
        preset = naughty.config.presets.critical,
        title = "Oops, there were errors during startup!",
        text = awesome.startup_errors
    }
end
--[[------------------------------------------------------------
               Autostart processes / Startup scripts
------------------------------------------------------------]]--\n
-- This function will run once every time Awesome is started
local function run_once(cmd_arr)
    for _, cmd in ipairs(cmd_arr) do
        awful.spawn.with_shell(string.format("pgrep -u $USER -fx '%s' > /dev/null || (%s)", cmd, cmd))
    end
end

run_once({ "picom -b" }) -- comma-separated entries
--[[------------------------------------------------------------
                    Variable definitions
------------------------------------------------------------]]--\n
local modkey       = "Mod4"
local altkey       = "Mod1"
local terminal     = "kitty"
local editor       = os.getenv("EDITOR") or "vim"
local browser      = "Firefox"
local scrlocker    = "dm-tool switch-to-greeter"
-- Theme
beautiful.init(string.format("%s/.config/awesome/themes/holo/theme.lua", os.getenv("HOME"))) 


awful.util.terminal = terminal
awful.util.tagnames = { "Term", "Web", ".md", "Other" }
awful.layout.layouts = {
    awful.layout.suit.tile,
    awful.layout.suit.floating,
}

awful.util.taglist_buttons = mytable.join(
    awful.button({ }, 1, function(t) t:view_only() end),
    awful.button({ modkey }, 1, function(t)
        if client.focus then client.focus:move_to_tag(t) end
    end),
    awful.button({ }, 3, awful.tag.viewtoggle),
    awful.button({ modkey }, 3, function(t)
        if client.focus then client.focus:toggle_tag(t) end
    end),
    awful.button({ }, 4, function(t) awful.tag.viewnext(t.screen) end),
    awful.button({ }, 5, function(t) awful.tag.viewprev(t.screen) end)
)
--[[------------------------------------------------------------
                            Menu
------------------------------------------------------------]]--\n
-- WIP
--[[------------------------------------------------------------
                           Screen
------------------------------------------------------------]]--\n
-- Set wallpaper
gears.wallpaper.maximized(beautiful.wallpaper, screen.primary, true)

-- Create a wibox for each screen and add it
awful.screen.connect_for_each_screen(function(s) beautiful.at_screen_connect(s) end)
--[[------------------------------------------------------------
                        Key/Mouse bindings
------------------------------------------------------------]]--\n
globalkeys = mytable.join(
     -- Toggle window/tiling
     awful.key({ modkey }, "space", function()
        awful.layout.inc(1)
    end,
    {description = "toggle tiling and floating", group = "layout"}),
    -- Destroy all notifications
    awful.key({ "Control",           }, "space", function() naughty.destroy_all_notifications() end,
              {description = "destroy all notifications", group = "hotkeys"}),
              
    -- Take a screenshot
    awful.key({ altkey }, "p", function() os.execute("screenshot") end,
              {description = "take a screenshot", group = "hotkeys"}),

    -- Lock screen
    awful.key({ modkey }, "l", function () os.execute(scrlocker) end,
              {description = "lock screen", group = "hotkeys"}),

    -- Show help
    awful.key({ modkey,           }, "s",      hotkeys_popup.show_help,
              {description="show help", group="awesome"}),

    -- Tag browsing
    awful.key({ modkey,           }, "Left",   function () lain.util.tag_view_nonempty(-1) end,
              {description = "view previous non-empty", group = "tag"}),
    awful.key({ modkey,           }, "Right",  function () lain.util.tag_view_nonempty(1) end,
              {description = "view next non-empty", group = "tag"}),

    -- Window focusing with alt + arrow keys
    awful.key({ altkey }, "Left",
        function()
            awful.client.focus.global_bydirection("left")
            if client.focus then client.focus:raise() end
        end,
        {description = "focus left", group = "client"}),
    awful.key({ altkey }, "Right",
        function()
            awful.client.focus.global_bydirection("right")
            if client.focus then client.focus:raise() end
        end,
        {description = "focus right", group = "client"}),
    awful.key({ altkey }, "Up",
        function()
            awful.client.focus.global_bydirection("up")
            if client.focus then client.focus:raise() end
        end,
        {description = "focus up", group = "client"}),
    awful.key({ altkey }, "Down",
        function()
            awful.client.focus.global_bydirection("down")
            if client.focus then client.focus:raise() end
        end,
        {description = "focus down", group = "client"}),
    -- Window switcher: Activate Alt+Tab functionality to switch between windows
    awful.key({ "Mod1",           }, "Tab",
        function ()
            switcher.switch( 1, "Mod1", "Alt_L", "Shift", "Tab")
        end,
        {description = "window switcher", group = "client"}),

    -- Dynamic tagging
    awful.key({ modkey, "Shift" }, "n", function () lain.util.add_tag() end,
              {description = "add new tag", group = "tag"}),
    awful.key({ modkey, "Shift" }, "d", function () lain.util.delete_tag() end,
              {description = "delete tag", group = "tag"}),

    -- Standard program
    awful.key({ modkey,           }, "Return", function () awful.spawn(terminal) end,
              {description = "open a terminal", group = "launcher"}),
    awful.key({ modkey, "Shift"   }, "q", awesome.quit,
              {description = "quit awesome", group = "awesome"}),

    -- Copy primary to clipboard (terminals to gtk)
    awful.key({ modkey }, "c", function () awful.spawn.with_shell("xsel | xsel -i -b") end,
              {description = "copy terminal to gtk", group = "hotkeys"}),
    -- Copy clipboard to primary (gtk to terminals)
    awful.key({ modkey }, "v", function () awful.spawn.with_shell("xsel -b | xsel") end,
              {description = "copy gtk to terminal", group = "hotkeys"}),
    -- Prompt
    awful.key({ modkey }, "r", function () awful.spawn("rofi -show drun -config ~/.config/rofi/config.rasi -theme /home/mist/.config/ronema/ronema.rasi") end,
          {description = "open launcher", group = "launcher"})
)

clientkeys = mytable.join(
    awful.key({ modkey,           }, "f",
        function (c)
            c.fullscreen = not c.fullscreen
            c:raise()
        end,
        
        {description = "toggle fullscreen", group = "client"}),
    awful.key({ "Control"         }, "w",      function (c) c:kill()                         end,
              {description = "close", group = "client"})
)

-- Bind all key numbers to tags.
for i = 1, 6 do
    globalkeys = mytable.join(globalkeys,
        -- View tag only.
        awful.key({ modkey }, "#" .. i + 9,
                  function ()
                        local screen = awful.screen.focused()
                        local tag = screen.tags[i]
                        if tag then
                           tag:view_only()
                        end
                  end,
                  {description = "view tag #"..i, group = "tag"})
    )
end

clientbuttons = mytable.join(
    awful.button({ }, 1, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
    end),
    awful.button({ modkey }, 1, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
        awful.mouse.client.move(c)
    end),
    awful.button({ modkey }, 3, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
        awful.mouse.client.resize(c)
    end),
    -- right-click to move windows
    awful.button({ modkey }, 3, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
        awful.mouse.client.move(c)
    end)
)

-- Set keys
root.keys(globalkeys)

--[[------------------------------------------------------------
                            Rules
------------------------------------------------------------]]--
awful.rules.rules = {
    -- All clients will match this rule.
    { rule = { },
      properties = { border_width = beautiful.border_width,
                     border_color = beautiful.border_normal,
                     callback = awful.client.setslave,
                     focus = awful.client.focus.filter,
                     raise = true,
                     keys = clientkeys,
                     buttons = clientbuttons,
                     screen = awful.screen.preferred,
                     placement = awful.placement.no_overlap+awful.placement.no_offscreen,
     }
    },

    -- Add titlebars to normal clients and dialogs
    { rule_any = {type = { "dialog" }
      }, properties = { titlebars_enabled = true },
    },

    { rule = { instance = "kitty" },
    properties = { screen = 1, tag = "Term", border_width= 1} },

    { rule = { class = "firefox-esr" },
    properties = { screen = 1, tag = "Web"} },

    { rule = { class = "obsidian" },
    properties = { screen = 1, tag = ".md" } },

    { rule = { class = "calamares" },
    properties = { screen = 1, tag = "Other" } },

    { rule = { class = "spotify" },
    properties = { screen = 1, tag = "Other" } },
}
--[[------------------------------------------------------------
                           Layouts
------------------------------------------------------------]]--
-- Custom layout for Term tag
local term_layout = {}
term_layout.name = "term_layout"
local gap_size = 5 -- Adjust this value to increase or decrease the gap size

function term_layout.arrange(p)
    local area = p.workarea
    local n = #p.clients
    
    for i, c in ipairs(p.clients) do
        if i == 1 then
            -- First client takes up the left 30% vertically
            c:geometry({
                x = area.x + gap_size,
                y = area.y + gap_size,
                width = area.width * 0.3 - 2 * gap_size,
                height = area.height - 2 * gap_size
            })
        else
            -- Other clients share the right 70% horizontally
            local height = (area.height - (n * gap_size)) / (n - 1)
            c:geometry({
                x = area.x + area.width * 0.3 + gap_size,
                y = area.y + (i - 2) * (height + gap_size) + gap_size,
                width = area.width * 0.7 - 2 * gap_size,
                height = height
            })
        end
    end
end

-- Function to close all windows
local function close_all_clients()
    for _, c in ipairs(client.get()) do
        c:kill()
    end
end

-- Reset environment before starting applications (when using awesome-client 'awesome.restart()` in dev)
awesome.connect_signal("startup", function()
    -- Close all existing windows
    close_all_clients()
    
    -- Wait a brief moment before spawning new windows
    gears.timer.start_new(0.5, function()
        -- Spawn initial windows
        awful.spawn.with_shell("for i in {1..4}; do " .. terminal .. " & done")
        awful.spawn.with_shell("obsidian obsidian://vault/secos-vault")
        return false -- Don't repeat the timer
    end)
end)
--[[------------------------------------------------------------
                          Signals
------------------------------------------------------------]]--\n
-- Signal function to execute when a new client appears.
client.connect_signal("manage", function (c)
    if not c.size_hints.user_position
    and not c.size_hints.program_position then
        awful.placement.no_offscreen(c)
    end

    -- Switch to the tag of the new client
    if not awesome.startup then
        local target_tag = c.first_tag
        if target_tag then
            target_tag:view_only()
        end
    end
end)

-- Add a titlebar if titlebars_enabled is set to true in the rules.
client.connect_signal("request::titlebars", function(c)
    -- Custom
    if beautiful.titlebar_fun then
        beautiful.titlebar_fun(c)
        return
    end

    -- Default
    -- buttons for the titlebar
    local buttons = mytable.join(
        awful.button({ }, 1, function()
            c:emit_signal("request::activate", "titlebar", {raise = true})
            awful.mouse.client.move(c)
        end),
        awful.button({ }, 3, function()
            c:emit_signal("request::activate", "titlebar", {raise = true})
            awful.mouse.client.resize(c)
        end)
    )

    awful.titlebar(c, { size = 16 }) : setup {
        { -- Left
            awful.titlebar.widget.iconwidget(c),
            buttons = buttons,
            layout  = wibox.layout.fixed.horizontal
        },
        { -- Middle
            { -- Title
                align  = "center",
                widget = awful.titlebar.widget.titlewidget(c)
            },
            buttons = buttons,
            layout  = wibox.layout.flex.horizontal
        },
        { -- Right
            awful.titlebar.widget.ontopbutton    (c),
            awful.titlebar.widget.maximizedbutton(c),
            awful.titlebar.widget.closebutton    (c),
            layout = wibox.layout.fixed.horizontal()
        },
        layout = wibox.layout.align.horizontal
    }
end)

client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)

-- switch to parent after closing child window
local function backham()
    local s = awful.screen.focused()
    local c = awful.client.focus.history.get(s, 0)
    if c then
        client.focus = c
        c:raise()
    end
end

-- attach to minimized state
client.connect_signal("property::minimized", backham)
-- attach to closed state
client.connect_signal("unmanage", backham)
-- ensure there is always a selected client during tag switching or logins
tag.connect_signal("property::selected", backham)

-- Apply rounded corners to terminals
client.connect_signal("manage", function(c)
    if c.instance == "kitty" or c.class == "kitty" then
        c.shape = function(cr, w, h)
            gears.shape.rounded_rect(cr, w, h, 10)  -- using 10 as radius, adjust as needed
        end
    end
end)
