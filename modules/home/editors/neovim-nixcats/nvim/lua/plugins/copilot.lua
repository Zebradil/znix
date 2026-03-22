if not nixCats("copilot") then return end

require("copilot").setup({
  suggestion = {
    enabled = true,
    auto_trigger = false,
    keymap = {
      accept = "<M-l>",
      accept_word = false,
      accept_line = false,
      next = "<M-]>",
      prev = "<M-[>",
      dismiss = "<C-]>",
    },
  },
  panel = { enabled = false },
  filetypes = {
    yaml = true,
    markdown = true,
    gitcommit = true,
    ["*"] = true,
  },
})

require("CopilotChat").setup({
  window = {
    layout = "float",
    width = 0.8,
    height = 0.8,
    border = "rounded",
  },
  show_help = true,
  question_header = "  User ",
  answer_header = "  Copilot ",
})

local map = vim.keymap.set
map("n", "<Leader>cc", "<cmd>CopilotChatToggle<cr>", { desc = "Copilot Chat Toggle" })
map("v", "<Leader>ce", "<cmd>CopilotChatExplain<cr>", { desc = "Copilot Explain" })
map("v", "<Leader>cf", "<cmd>CopilotChatFix<cr>", { desc = "Copilot Fix" })
map("v", "<Leader>cr", "<cmd>CopilotChatReview<cr>", { desc = "Copilot Review" })
map("v", "<Leader>cd", "<cmd>CopilotChatDocs<cr>", { desc = "Copilot Docs" })
map("n", "<Leader>cp", function()
  local actions = require("CopilotChat.actions")
  require("CopilotChat.integrations.snacks").pick(actions.prompt_actions())
end, { desc = "Copilot Prompt actions" })
