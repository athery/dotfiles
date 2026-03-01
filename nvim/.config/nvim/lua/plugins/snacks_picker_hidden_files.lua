return {
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      -- Ensure picker config table exists
      opts.picker = opts.picker or {}
      opts.picker.sources = opts.picker.sources or {}

      -- Extend the default "files" source configuration
      opts.picker.sources.files = vim.tbl_deep_extend("force", opts.picker.sources.files or {}, {
        hidden = true,   -- Include hidden files and directories (e.g. .config, .ssh)
        follow = true,   -- Follow symbolic links (useful when working with stow)
        ignored = false, -- Respect .gitignore (set to true to exclude ignored files)
      })

      return opts
    end,
  },
}
