local helpers = require("lain.helpers")
local wibox   = require("wibox")
local string  = string

-- Network infos
-- lain.widget.net

local function factory(args)
    args             = args or {}

    local net        = { widget = args.widget or wibox.widget.textbox(), devices = {} }
    local timeout    = args.timeout or 2
    local units      = args.units or 1024 -- KB
    local format     = args.format or "%.1f"
    local settings   = args.settings or function() end

    -- Compatibility with old API where iface was a string corresponding to 1 interface
    net.iface = (args.iface and (type(args.iface) == "string" and {args.iface}) or
                (type(args.iface) == "table" and args.iface)) or {}

    function net.get_devices()
        net.iface = {} -- reset at every call
        helpers.line_callback("ip link", function(line)
            net.iface[#net.iface + 1] = not string.match(line, "LOOPBACK") and string.match(line, "(%w+): <") or nil
        end)
    end

    if #net.iface == 0 then net.get_devices() end

    function net.update()
        -- These are the totals over all specified interfaces
        net_now = {
            devices  = {},
            -- Bytes since last iteration
            sent     = 0,
            received = 0
        }

        for _, dev in ipairs(net.iface) do
            local dev_now    = {}
            local dev_before = net.devices[dev] or { last_t = 0, last_r = 0 }
            local now_t      = tonumber(helpers.first_line(string.format("/sys/class/net/%s/statistics/tx_bytes", dev)) or 0)
            local now_r      = tonumber(helpers.first_line(string.format("/sys/class/net/%s/statistics/rx_bytes", dev)) or 0)

            dev_now.sent     = (now_t - dev_before.last_t) / timeout / units
            dev_now.received = (now_r - dev_before.last_r) / timeout / units

            net_now.sent     = net_now.sent + dev_now.sent
            net_now.received = net_now.received + dev_now.received

            dev_now.sent     = string.format(format, dev_now.sent)
            dev_now.received = string.format(format, dev_now.received)

            dev_now.last_t   = now_t
            dev_now.last_r   = now_r

            net.devices[dev] = dev_now

            net_now.devices[dev] = dev_now
        end

        net_now.sent = string.format(format, net_now.sent)
        net_now.received = string.format(format, net_now.received)

        widget = net.widget
        settings()
    end

    helpers.newtimer("network", timeout, net.update)

    return net
end

return factory