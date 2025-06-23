vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = { "*.c", "*.cpp", "*.h", "*.hpp" },
    callback = function()
        require("autobear").check_and_generate()
    end,
})
