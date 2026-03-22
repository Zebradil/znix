local map = vim.keymap.set

-- Buffer navigation
map("n", "]b", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "[b", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
map("n", "<Leader>bd", "<cmd>bdelete<cr>", { desc = "Close buffer" })

-- Base64 encode/decode (visual mode)
map(
  "v",
  "<Leader>64e",
  "y"
    .. ":let was_paste=&paste<CR>"
    .. ":set paste<CR>"
    .. ":let @b=system('base64 --wrap=0', @\")<CR>"
    .. 'gv"bP'
    .. ":if !was_paste|set nopaste|endif<CR><esc>",
  { desc = "Base64 encode" }
)
map(
  "v",
  "<Leader>64d",
  "y"
    .. ":let was_paste=&paste<CR>"
    .. ":set paste<CR>"
    .. ":let @b=system('base64 --decode --wrap=0', @\")<CR>"
    .. 'gv"bP'
    .. ":if !was_paste|set nopaste|endif<CR><esc>",
  { desc = "Base64 decode" }
)

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })

-- Window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Move to lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Move to upper window" })
map("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })

-- Save / quit
map("n", "<Leader>w", "<cmd>w<cr>", { desc = "Save file" })
map("n", "<Leader>q", "<cmd>q<cr>", { desc = "Quit" })

-- Diagnostic navigation
map("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
map("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
map("n", "<Leader>ld", vim.diagnostic.open_float, { desc = "Line diagnostics" })
map("n", "<Leader>lq", vim.diagnostic.setloclist, { desc = "Diagnostics to loclist" })
