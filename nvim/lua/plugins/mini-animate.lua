return {
  -- 1. Disable the old repository reference
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
