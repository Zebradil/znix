vim.on_key(nil, vim.api.nvim_get_namespaces()["auto_hlsearch"])

-- This will run last in the setup process.
-- This is just pure lua so anything that doesn't
-- fit in the normal config locations above can go here
