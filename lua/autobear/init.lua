local uv = vim.loop
local util = require("lspconfig.util")
local M = {}

-- Check if a file exists (sync)
local function file_exists(path)
    local stat = uv.fs_stat(path)
    return stat and stat.type == "file"
end

-- Get file modification time (epoch seconds)
local function get_mtime(path)
    local stat = uv.fs_stat(path)
    if stat then
        return stat.mtime.sec
    end
    return nil
end

-- Find project root by searching for either compile_commands.json or Makefile upwards from given path
local function find_project_root(startpath)
    -- root_pattern returns a function that searches upward for these files
    local root_finder = util.root_pattern("compile_commands.json", "Makefile")
    return root_finder(startpath)
end

-- Run 'bear -- make' asynchronously
local function run_bear_make(cwd)
    vim.notify("Generating compile_commands.json using Bear...", vim.log.levels.INFO)
    local Job = require("plenary.job")

    Job:new({
        command = "bear",
        args = { "--", "make" },
        cwd = cwd,
        on_exit = function(j, return_val)
            if return_val == 0 then
                vim.schedule(function()
                    vim.notify("compile_commands.json generated successfully.", vim.log.levels.INFO)
                    vim.cmd("write")
                end)
            else
                vim.schedule(function()
                    vim.notify("Bear failed: " .. table.concat(j:stderr_result(), "\n"), vim.log.levels.ERROR)
                end)
            end
        end,
    }):start()
end

function M.check_and_generate()
    local ft = vim.bo.filetype
    if ft ~= "c" and ft ~= "cpp" and ft ~= "objc" and ft ~= "objcpp" then
        return
    end

    -- Get the absolute path of current buffer's directory
    local buf_path = vim.api.nvim_buf_get_name(0)
    local buf_dir = vim.fn.fnamemodify(buf_path, ":p:h")

    -- Find root directory containing either compile_commands.json or Makefile
    local root = find_project_root(buf_dir)
    if not root then
        -- No Makefile or compile_commands.json found in any parent directory
        return
    end

    local cc_path = root .. "/compile_commands.json"
    local makefile_path = root .. "/Makefile"

    -- Check if Makefile exists at root (should be, since root was found with it)
    if not file_exists(makefile_path) then
        return
    end

    local cc_exists = file_exists(cc_path)

    local makefile_mtime = get_mtime(makefile_path)
    local cc_mtime = get_mtime(cc_path)

    -- Regenerate compile_commands.json if:
    -- - it doesn't exist, OR
    -- - Makefile is newer than compile_commands.json
    if (not cc_exists) or (makefile_mtime and cc_mtime and makefile_mtime > cc_mtime) then
        run_bear_make(root)
    end
end

return M
