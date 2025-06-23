local function get_patterns_from_extensions(extensions)
    local patterns = {}
    for _, ext in ipairs(extensions) do
        table.insert(patterns, "*." .. ext)
    end
    return patterns
end

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = get_patterns_from_extensions(require("autobear").extensions or { "c", "cpp", "h", "hpp" }),
    callback = function()
        -- Use defer_fn to avoid fullscreen messages on startup
        vim.defer_fn(function()
            require("autobear").check_and_generate()
        end, 150)
    end,
})
