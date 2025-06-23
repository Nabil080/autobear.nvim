local M = {}

-- Default user-configurable options
local opts = {
    build_command = { "bear", "--", "make", "re" }, -- command to generate target_file
    check_file = "Makefile",                        -- file to check for changes (optional)
    target_file = "compile_commands.json",          -- file to generate and compare against
    extensions = { "c", "cpp", "objc", "objcpp" },  -- supported filetypes
}

-- Setup function to override defaults
function M.setup(user_opts)
    user_opts = user_opts or {}
    for key, value in pairs(user_opts) do
        opts[key] = value
    end
end

local uv = vim.loop
local Job = require("plenary.job")

-- Check if a given path points to an existing file
local function file_exists(path)
    local stat = uv.fs_stat(path)
    return stat and stat.type == "file"
end

-- Get the modification time (epoch seconds) of a file
local function get_mtime(path)
    local stat = uv.fs_stat(path)
    if stat then
        return stat.mtime.sec
    end
    return nil
end

-- Run the user-defined build command asynchronously
local function run_build_command(cwd)
    vim.notify("Generating " .. opts.target_file .. " using build command...", vim.log.levels.INFO)

    Job:new({
        command = opts.build_command[1],
        args = vim.list_slice(opts.build_command, 2),
        cwd = cwd,
        on_exit = function(job, return_val)
            vim.schedule(function()
                if return_val == 0 then
                    vim.notify(opts.target_file .. " generated successfully.", vim.log.levels.INFO)
                    -- Restart LSP to pick up new compile_commands.json
                    vim.cmd("LspRestart")
                else
                    local err = table.concat(job:stderr_result(), "\n")
                    vim.notify("Build command failed:\n" .. err, vim.log.levels.ERROR)
                end
            end)
        end,
    }):start()
end

-- Helper: check if filetype is in the allowed extensions list
local function is_supported_filetype(ft)
    for _, ext in ipairs(opts.extensions) do
        if ft == ext then
            return true
        end
    end
    return false
end

-- Main function: checks file timestamps and triggers build command if needed
function M.check_and_generate()
    -- Only run for supported filetypes
    local ft = vim.bo.filetype
    if not is_supported_filetype(ft) then
        return
    end

    -- Get directory of current buffer
    local buf_path = vim.api.nvim_buf_get_name(0)
    local buf_dir = vim.fn.fnamemodify(buf_path, ":p:h")

    -- Find project root by searching for check_file or target_file upwards
    local util = require("lspconfig.util")
    local root_finder = util.root_pattern(opts.check_file or opts.target_file, opts.target_file)
    local root = root_finder(buf_dir)
    if not root then
        return
    end

    -- Construct absolute paths for target_file and optional check_file
    local target_path = root .. "/" .. opts.target_file
    local check_path = opts.check_file and (root .. "/" .. opts.check_file) or nil

    -- Check existence of target and check files
    local target_exists = file_exists(target_path)
    local check_exists = check_path and file_exists(check_path)

    local should_run_build = false

    -- Decide if build command should run:
    -- 1. If target file missing → run build
    -- 2. If check file exists and is newer than target → run build
    if not target_exists then
        should_run_build = true
    elseif check_exists then
        local target_mtime = get_mtime(target_path)
        local check_mtime = get_mtime(check_path)
        if check_mtime and target_mtime and check_mtime > target_mtime then
            should_run_build = true
        end
    end

    -- Run build if conditions met
    if should_run_build then
        run_build_command(root)
    end
end

-- Exposing extensions for autostart script
M.extensions = opts.extensions

return M
