vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = { "*.c", "*.cpp", "*.h", "*.hpp" },
    callback = function()
        vim.defer_fn(function()
            require("autobear").check_and_generate()
        end, 150) -- delay to prevent fullscreen message on startup
    end,
})
