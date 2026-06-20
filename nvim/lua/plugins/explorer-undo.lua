-- Undo/redo for file operations (delete, rename) in the snacks explorer.
-- Deleted files are moved to a trash dir so they can be restored with u.
-- Redo is <C-r>. History is per-session (not persisted across restarts).

local history = {}
local redo_stack = {}
local trash_base = vim.fn.stdpath("data") .. "/explorer-trash"

local function unique_trash_path(orig)
  vim.fn.mkdir(trash_base, "p")
  local name = vim.fn.fnamemodify(orig, ":t")
  local dest = trash_base .. "/" .. name
  local i = 0
  while vim.fn.filereadable(dest) == 1 or vim.fn.isdirectory(dest) == 1 do
    i = i + 1
    dest = trash_base .. "/" .. i .. "_" .. name
  end
  return dest
end

local function mv(src, dst)
  local res = vim.system({ "mv", src, dst }):wait()
  return res.code == 0, res.stderr
end

local function push(op)
  table.insert(history, op)
  redo_stack = {}
end

return {
  "folke/snacks.nvim",
  opts = function(_, opts)
    opts.picker = opts.picker or {}
    opts.picker.actions = opts.picker.actions or {}

    opts.picker.actions.explorer_trash_delete = function(picker, item)
      if not item or not item.file then return end
      local path = item.file
      vim.ui.input(
        { prompt = "Delete '" .. vim.fn.fnamemodify(path, ":~:.") .. "'? [y/N] " },
        function(answer)
          if answer ~= "y" and answer ~= "Y" then return end
          local dest = unique_trash_path(path)
          local ok, err = mv(path, dest)
          if ok then
            push({ type = "delete", original = path, trash = dest })
            picker:refresh()
            vim.notify("Deleted (press u to undo)", vim.log.levels.INFO)
          else
            vim.notify("Delete failed: " .. (err or "unknown"), vim.log.levels.ERROR)
          end
        end
      )
    end

    opts.picker.actions.explorer_tracked_rename = function(picker, item)
      if not item or not item.file then return end
      local old_path = item.file
      local old_name = vim.fn.fnamemodify(old_path, ":t")
      local dir = vim.fn.fnamemodify(old_path, ":h")
      vim.ui.input({ prompt = "Rename: ", default = old_name }, function(new_name)
        if not new_name or new_name == "" or new_name == old_name then return end
        local new_path = dir .. "/" .. new_name
        local ok, err = mv(old_path, new_path)
        if ok then
          push({ type = "rename", old = old_path, new = new_path })
          picker:refresh()
        else
          vim.notify("Rename failed: " .. (err or "unknown"), vim.log.levels.ERROR)
        end
      end)
    end

    opts.picker.actions.explorer_undo = function(picker)
      local op = table.remove(history)
      if not op then
        vim.notify("Nothing to undo", vim.log.levels.INFO)
        return
      end
      local ok, err
      if op.type == "delete" then
        ok, err = mv(op.trash, op.original)
        if ok then
          table.insert(redo_stack, op)
          picker:refresh()
          vim.notify("Restored: " .. vim.fn.fnamemodify(op.original, ":t"), vim.log.levels.INFO)
        end
      elseif op.type == "rename" then
        ok, err = mv(op.new, op.old)
        if ok then
          table.insert(redo_stack, op)
          picker:refresh()
          vim.notify("Renamed back to: " .. vim.fn.fnamemodify(op.old, ":t"), vim.log.levels.INFO)
        end
      end
      if not ok then
        table.insert(history, op)
        vim.notify("Undo failed: " .. (err or "unknown"), vim.log.levels.ERROR)
      end
    end

    opts.picker.actions.explorer_redo = function(picker)
      local op = table.remove(redo_stack)
      if not op then
        vim.notify("Nothing to redo", vim.log.levels.INFO)
        return
      end
      local ok, err
      if op.type == "delete" then
        ok, err = mv(op.original, op.trash)
        if ok then
          table.insert(history, op)
          picker:refresh()
          vim.notify("Re-deleted: " .. vim.fn.fnamemodify(op.original, ":t"), vim.log.levels.INFO)
        end
      elseif op.type == "rename" then
        ok, err = mv(op.old, op.new)
        if ok then
          table.insert(history, op)
          picker:refresh()
          vim.notify("Re-renamed to: " .. vim.fn.fnamemodify(op.new, ":t"), vim.log.levels.INFO)
        end
      end
      if not ok then
        table.insert(redo_stack, op)
        vim.notify("Redo failed: " .. (err or "unknown"), vim.log.levels.ERROR)
      end
    end

    opts.picker.sources = opts.picker.sources or {}
    opts.picker.sources.explorer = vim.tbl_deep_extend("force", opts.picker.sources.explorer or {}, {
      win = {
        list = {
          keys = {
            ["d"] = "explorer_trash_delete",
            ["r"] = "explorer_tracked_rename",
            ["u"] = "explorer_undo",
            ["<C-r>"] = "explorer_redo",
          },
        },
      },
    })

    return opts
  end,
}
