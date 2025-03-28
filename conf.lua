---@diagnostic disable: duplicate-set-field
function lovr.conf(t)
    t.modules.headset = false

    t.window.fullscreentype = "desktop" -- Choose between "desktop" fullscreen or "exclusive" fullscreen mode (string)
    t.window.x = nil                  -- The x-coordinate of the window's position in the specified display (number)
    t.window.y = nil                  -- The y-coordinate of the window's position in the specified display (number)
    t.window.minwidth = 1             -- Minimum window width if the window is resizable (number)
    t.window.minheight = 1            -- Minimum window height if the window is resizable (number)
    t.window.display = 1              -- Index of the monitor to show the window in (number)
    t.window.centered = true          -- Align window on the center of the monitor (boolean)
    t.window.topmost = false          -- Show window on top (boolean)
    t.window.borderless = false       -- Remove all border visuals from the window (boolean)
    t.window.resizable = true         -- Let the window be user-resizable (boolean)
    t.window.opacity = 1              -- Window opacity value (number)
    -- t.window.width = 600
    -- t.window.height = 600

    ---@diagnostic disable-next-line: lowercase-global
    conf = t.window
end
