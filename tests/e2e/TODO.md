# E2E Tests TODO

## Tests That Need to Be Implemented

### Comment Persistence (3 tests)
- Save and reload comments for a review
- Handle saving with no comments
- Handle comments with special characters (quotes, newlines)

### Review Switching (2 tests)
- Preserve comments when switching between reviews
- Handle switching to uncommitted review

### Export Workflow (3 tests)
- Export comments in markdown format
- Handle export with no comments
- Export comments grouped by file

### Reset Workflow (2 tests)
- Clear all comments and delete persistence
- Allow starting fresh after reset

### Comment CRUD Operations (4 tests)
- Add, get, update, and delete comments
- Get comments for a specific file
- Get comments at a specific line
- Calculate comment statistics

**Total: 14 tests**

---

## Problems That Need to Be Fixed

### 1. Persistence Directory Can't Be Mocked
**Problem:** Tests use the real filesystem (~/.local/share/nvim/diff-review/), so persistence files from previous runs pollute test state.

**Solution:** Add a way to override the storage directory
```lua
-- Option A: Add to persistence.lua
function M.set_storage_dir(path)
  storage_dir_override = path
end

-- Option B: Check environment variable
local storage_dir = os.getenv("DIFF_REVIEW_TEST_DIR") or get_default_storage_dir()
```

### 2. Can't Delete Persistence Files
**Problem:** `persistence.auto_save({})` does NOT delete the file, so you can't clear persisted data.

**Solution:** Add a delete function or fix auto_save
```lua
-- Option A: Add explicit delete
function M.delete(review_id)
  local filepath = get_filepath(review_id)
  vim.fn.delete(filepath)
end

-- Option B: Fix auto_save to delete when empty
function M.auto_save(comments, context_id)
  if #comments == 0 then
    M.delete(context_id)  -- Delete instead of skipping
    return
  end
  M.save(comments, context_id)
end
```

### 3. Export Has a Table Comparison Bug
**Problem:** `export.lua` line ~176 tries to compare tables in table.sort()

**Solution:** Fix the sort comparator
```lua
-- Find the sort call in export.lua and fix it
table.sort(comments, function(a, b)
  if a.file ~= b.file then
    return a.file < b.file
  end
  return a.line < b.line
end)
```

### 4. reviews.set_current() Auto-Loads from Disk
**Problem:** Calling `set_current()` automatically loads persisted comments, interfering with tests that want a clean slate.

**Solution:** Add a way to disable auto-load in tests
```lua
-- Option A: Add flag parameter
function M.set_current(review, skip_load)
  -- ...
  if not skip_load then
    local loaded = persistence.auto_load(review.id)
    -- ...
  end
end

-- Option B: Add test mode flag to persistence module
persistence.test_mode = true  -- Disables auto-load
```

---

## Implementation Order

1. **Fix persistence directory mocking** (enables 11 tests)
   - Add `set_storage_dir()` or env var support
   - Update tests to use temp directories

2. **Add persistence.delete()** (enables 2 reset tests)
   - Simple function to remove files

3. **Fix export.lua sort bug** (enables 3 export tests)
   - One-line fix to comparator

4. **Optional: Add skip_load flag** (makes tests cleaner)
   - Not strictly necessary if we have directory mocking
