-- Single source of truth for mini.animate.
-- To disable animations entirely (e.g. over a very slow link), set
-- `enabled = false` on the nvim-mini spec below.
return {
  -- 1. Disable the old repository reference (LazyVim still points here)
  {
    "echasnovski/mini.animate",
    enabled = false,
  },

  -- 2. Import and configure the updated repository reference
  {
    "nvim-mini/mini.animate",
    event = "VeryLazy",
    opts = function()
      -- Don't animate when scrolling with the mouse
      local animate = require("mini.animate")
      return {
        resize = {
          timing = animate.gen_timing.linear({ duration = 100, unit = "total" }),
        },
        scroll = {
          timing = animate.gen_timing.linear({ duration = 150, unit = "total" }),
        },
      }
    end,
  },
}
