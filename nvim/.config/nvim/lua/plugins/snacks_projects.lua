return {
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      opts.picker = opts.picker or {}
      opts.picker.sources = opts.picker.sources or {}
      opts.picker.sources.projects = vim.tbl_deep_extend("force", opts.picker.sources.projects or {}, {
        -- IMPORTANT: projects a un confirm "spécial", mieux en fonction
        confirm = function(picker, item)
          -- "cd" vers le projet choisi
          picker:action("cd")

          -- Optionnel: ouvrir l'explorer juste après
          -- picker:action("picker_explorer")

          picker:close()
        end,

        -- on choisira ensuite true/false
        -- recent = false,
      })
      return opts
    end,
  },
}
