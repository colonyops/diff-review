-- Fuzzy finder integration for switching between active reviews
-- Supports Snacks.nvim (primary) and Telescope (fallback)
local M = {}

local config = require("diff-review.config")
local reviews = require("diff-review.reviews")
local comments = require("diff-review.comments")

-- Format timestamp as "X hours/days ago"
local function format_time_ago(timestamp)
	local now = os.time()
	local diff = now - timestamp
	local minutes = math.floor(diff / 60)
	local hours = math.floor(diff / 3600)
	local days = math.floor(diff / 86400)

	if minutes < 60 then
		return string.format("%d min%s ago", minutes, minutes == 1 and "" or "s")
	elseif hours < 24 then
		return string.format("%d hour%s ago", hours, hours == 1 and "" or "s")
	else
		return string.format("%d day%s ago", days, days == 1 and "" or "s")
	end
end

-- Get comment count for a review
local function get_comment_count(review)
	local loaded_comments = require("diff-review.persistence").auto_load(review.id)
	if loaded_comments then
		return #loaded_comments
	end
	return 0
end

-- Format review entry for display
local function format_review(review)
	local display_name = reviews.get_display_name(review)
	local comment_count = get_comment_count(review)
	local time_ago = format_time_ago(review.last_accessed)

	-- Format: "display_name    X comments    time_ago"
	return string.format("%-40s %2d comments    %s", display_name, comment_count, time_ago)
end

-- Check if Snacks.nvim is available
local function has_snacks()
	local ok, snacks = pcall(require, "snacks")
	return ok and snacks.picker
end

-- Check if Telescope is available
local function has_telescope()
	return pcall(require, "telescope")
end

-- Open picker with Snacks.nvim
local function snacks_picker()
	local review_list = reviews.list()

	if #review_list == 0 then
		vim.notify("No active reviews", vim.log.levels.INFO)
		return true
	end

	-- Build display items
	local items = {}
	for _, review in ipairs(review_list) do
		table.insert(items, format_review(review))
	end

	-- Use vim.ui.select (enhanced by Snacks.nvim if available)
	vim.ui.select(items, {
		prompt = "Select Review:",
		format_item = function(item)
			return item
		end,
	}, function(choice, idx)
		if choice and idx then
			local review = review_list[idx]
			require("diff-review.layout").open(
				review.type,
				review.base,
				review.head,
				review.pr_number
			)
		end
	end)

	return true
end

-- Open picker with Telescope
local function telescope_picker()
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	local review_list = reviews.list()

	if #review_list == 0 then
		vim.notify("No active reviews", vim.log.levels.INFO)
		return
	end

	-- Build entries for picker
	local results = {}
	for _, review in ipairs(review_list) do
		table.insert(results, {
			display = format_review(review),
			ordinal = reviews.get_display_name(review), -- For fuzzy matching
			review = review,
		})
	end

	pickers
		.new({}, {
			prompt_title = "Reviews (" .. #review_list .. " active)",
			finder = finders.new_table({
				results = results,
				entry_maker = function(entry)
					return {
						value = entry.review,
						display = entry.display,
						ordinal = entry.ordinal,
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			attach_mappings = function(prompt_bufnr, map)
				-- Default action: switch to review
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					local review = selection.value

					-- Switch to selected review
					require("diff-review.layout").open(review.type, review.base, review.head, review.pr_number)
				end)

				-- Ctrl-d: delete review
				map("i", "<C-d>", function()
					local selection = action_state.get_selected_entry()
					local review = selection.value

					actions.close(prompt_bufnr)

					-- Confirm deletion
					vim.ui.select({ "Yes", "No" }, {
						prompt = string.format("Delete review '%s'?", reviews.get_display_name(review)),
					}, function(choice)
						if choice == "Yes" then
							reviews.delete(review.id)
							vim.notify("Review deleted", vim.log.levels.INFO)
							-- Reopen picker
							telescope_picker()
						end
					end)
				end)

				-- Ctrl-e: export comments (TODO: implement when export module is ready)
				-- map("i", "<C-e>", function()
				-- 	local selection = action_state.get_selected_entry()
				-- 	local review = selection.value
				--
				-- 	actions.close(prompt_bufnr)
				--
				-- 	-- Load review and export comments
				-- 	reviews.set_current(review)
				-- 	require("diff-review.export").export("comments")
				-- end)

				return true
			end,
		})
		:find()
end

-- Main picker function - auto-detect available picker
function M.show()
	local picker_preference = config.get().picker or "snacks"

	-- Try preferred picker first
	if picker_preference == "snacks" then
		if snacks_picker() then
			return
		end
		-- Fall through to telescope if snacks failed
	elseif picker_preference == "telescope" then
		if has_telescope() then
			telescope_picker()
			return
		end
		-- Fall through to snacks if telescope not available
	end

	-- Fallback logic
	if has_snacks() and snacks_picker() then
		return
	elseif has_telescope() then
		telescope_picker()
	else
		vim.notify(
			"No picker available. Install Snacks.nvim or Telescope.nvim",
			vim.log.levels.ERROR
		)
	end
end

return M
