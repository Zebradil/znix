if not nixCats("custom") then
  return
end

-- Custom tree-sitter parsers from zebradil
-- These plugins are on the runtimepath and register parsers/queries with nvim-treesitter.

-- tree-sitter-test_highlights: activate with :set filetype=test_highlights
-- tree-sitter-ytt_annotation: ytt annotation syntax
-- tree-sitter-queries: provides yaml-lang module

-- The plugins self-register when required; packadd ensures they are loaded.
vim.cmd("packadd tree-sitter-test_highlights")
vim.cmd("packadd tree-sitter-ytt_annotation")
vim.cmd("packadd tree-sitter-queries")
