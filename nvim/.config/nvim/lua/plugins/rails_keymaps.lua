-- ~/.config/nvim/lua/plugins/rails_keymaps.lua
return {
  {
    "tpope/vim-rails",
    keys = {
      { "<leader>a", "<cmd>AV<cr>", desc = "Rails: alternate vsplit" },
      { "<leader>A", "<cmd>A<cr>",  desc = "Rails: alternate" },
    },
  },
}
