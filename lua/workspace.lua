local M = {}

M.root = vim.fn.expand("~/dev")

local function tmux_session_name(path)
    -- Must match workspaceup(): session="$(basename "$workdir" | tr '.' '_')"
    local base = vim.fn.fnamemodify(vim.fs.normalize(vim.fn.fnamemodify(path, ":p")), ":t")
    return (base:gsub("%.", "_"))
end

local function tmux_session_exists(session)
    local result = vim.system({
        "tmux",
        "has-session",
        "-t",
        session,
    }, {text = true}):wait()
    return result.code == 0
end

local function git_worktrees(repo)
    local result = vim.system({"git","-C",repo, "worktree","list", "--porcelain"},{text = true,}):wait()
    if result.code ~= 0 then
        return {}
    end
    local worktrees = {}
    local current

    for line in result.stdout:gmatch("[^\r\n]+") do
        local path = line:match("^worktree (.+)$")
        if path then
            current = {
                path = path,
                branch = nil,
            }
        table.insert(worktrees,current)
        elseif current then
            local branch = line:match("^branch refs/heads/(.+)$")
            if branch then
                current.branch = branch
            end
        end
    end
    return worktrees
end

local function git_branch(dir)
    local result = vim.system(
        { "git", "-C", dir, "branch", "--show-current" },
        { text = true }
    ):wait()
    if result.code ~= 0 then
        return nil
    end
    local branch = (result.stdout or ""):gsub("%s+$", "")
    if branch == "" then
        return nil
    end
    return branch
end

local function discover()
    local items = {}

    for _, project_dir in ipairs(vim.fn.glob(M.root .. "/*", false, true)) do
        if vim.fn.isdirectory(project_dir) == 1 then
            local project = vim.fn.fnamemodify(project_dir, ":t")
            local project_session = tmux_session_name(project_dir)

            -- Project itself: `workspaceup` roots a tmux session here.
            table.insert(items, {
                kind = "project",
                text = project,
                file = project_dir,
                branch = git_branch(project_dir),
                session = project_session,
                session_exists = tmux_session_exists(project_session),
            })

            local default = project_dir .. "/default"

            -- `default` is our filesystem convention for the
            -- checkout from which we query the repository
            if vim.fn.isdirectory(default) == 1 then
                local worktrees = git_worktrees(default)

                if #worktrees == 0 then
                    -- Not a git repo (yet) or no linked worktrees:
                    -- fall back to the directories on disk.
                    table.insert(items, {
                        kind = "workspace",
                        text = project .. "-default",
                        file = default,
                        branch = git_branch(default),
                        session = tmux_session_name(default),
                        session_exists = tmux_session_exists(tmux_session_name(default)),
                    })
                    for _, wt_dir in ipairs(vim.fn.glob(project_dir .. "/worktrees/*", false, true)) do
                        if vim.fn.isdirectory(wt_dir) == 1 then
                            local wt_name = vim.fn.fnamemodify(wt_dir, ":t")
                            local session = tmux_session_name(wt_dir)
                            table.insert(items, {
                                kind = "workspace",
                                text = project .. "-" .. wt_name,
                                file = wt_dir,
                                branch = git_branch(wt_dir),
                                session = session,
                                session_exists = tmux_session_exists(session),
                            })
                        end
                    end
                else
                    for _, wt in ipairs(worktrees) do
                        local worktree_name = vim.fn.fnamemodify(wt.path, ":t")
                        local session = tmux_session_name(wt.path)

                        table.insert(items, {
                            kind = "workspace",
                            text = project .. "-" .. worktree_name,
                            file = wt.path,
                            branch = wt.branch,
                            session = session,
                            session_exists = tmux_session_exists(session),
                        })
                    end
                end
            end
        end
    end

    table.sort(items, function(a, b)
        return a.text < b.text
    end)

    return items
end

function M.switch()
    local items = discover()

    if #items == 0 then
        vim.notify(
            "No projects or workspaces found under " .. M.root,
            vim.log.levels.WARN
        )
        return
    end

    Snacks.picker.pick({
        title = "Switch workspace",
        items = items,
        format = function(item, _picker)
            local session_marker = item.session_exists and "●" or "○"
            local kind_hl = item.kind == "project" and "SnacksPickerDirectory" or "SnacksPickerLabel"
            local chunks = {
                {
                    session_marker .. " " .. item.text,
                    kind_hl,
                },
                {
                    item.branch and ("  " .. item.branch) or "",
                    "SnacksPickerComment",
                },
            }
            if item.kind == "project" then
                table.insert(chunks, { "  project", "SnacksPickerComment" })
            end
            return chunks
        end,

        confirm = function(picker, item)
            picker:close()

            if not item then
                return
            end

            -- Delegate to the existing Bash function: it creates the
            -- tmux session (nvim/git/shell/opencode windows) if needed,
            -- then switches (inside tmux) or attaches (outside tmux).
            local result = vim.system({
                "bash",
                "-ic",
                "workspaceup " .. vim.fn.shellescape(item.file),
            }, {
                text = true,
            }):wait()

            if result.code ~= 0 then
                vim.notify(
                    "Failed to switch workspace\n" ..
                    (result.stderr ~= "" and result.stderr or result.stdout or ""),
                    vim.log.levels.ERROR
                )
            end
        end
    })
end

return M

