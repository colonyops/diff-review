-- Export module for generating markdown output from review comments
local M = {}

local comments = require("diff-review.comments")
local reviews = require("diff-review.reviews")

-- Export mode configuration
-- "comments": Comments with line numbers only
-- "full": Comments with code context
-- "diff": Full annotated diff
M.modes = {
	COMMENTS = "comments",
	FULL = "full",
	DIFF = "diff",
}

-- Format comment with line information
local function format_comment_line(comment)
	if comment.type == "range" then
		return string.format("- Lines %d-%d: %s", comment.line_range.start, comment.line_range["end"], comment.text)
	else
		return string.format("- Line %d: %s", comment.line, comment.text)
	end
end

-- Extract code lines from diff output for a specific line or range
local function get_code_context(file, start_line, end_line, context_lines)
	context_lines = context_lines or 2
	end_line = end_line or start_line

	-- Get diff output for the file
	local diff = require("diff-review.diff")
	local diff_output = diff.get_file_diff({ path = file })

	if not diff_output or diff_output == "" then
		return nil
	end

	-- Parse diff to extract code lines with line numbers
	local code_lines = {}
	local current_line = 0
	local in_hunk = false

	for line in diff_output:gmatch("[^\r\n]+") do
		-- Check for hunk header: @@ -start,count +start,count @@
		local new_start = line:match("^@@ %-(%d+),?%d* %+(%d+),?%d* @@")
		if new_start then
			current_line = tonumber(new_start) - 1
			in_hunk = true
		elseif in_hunk then
			-- Track line numbers based on diff format
			if line:sub(1, 1) == "+" then
				-- Added line
				current_line = current_line + 1
				table.insert(code_lines, { line_num = current_line, text = line:sub(2), type = "add" })
			elseif line:sub(1, 1) == "-" then
				-- Removed line (don't increment line number)
				-- Store but don't include in context extraction
			elseif line:sub(1, 1) == " " then
				-- Context line
				current_line = current_line + 1
				table.insert(code_lines, { line_num = current_line, text = line:sub(2), type = "context" })
			end
		end
	end

	-- Extract lines around the target range
	local start_extract = math.max(1, start_line - context_lines)
	local end_extract = end_line + context_lines

	local extracted = {}
	for _, code_line in ipairs(code_lines) do
		if code_line.line_num >= start_extract and code_line.line_num <= end_extract then
			table.insert(extracted, { line_num = code_line.line_num, text = code_line.text })
		end
	end

	return extracted
end

-- Format review metadata header
local function format_metadata_header()
	local review = reviews.get_current()
	if not review then
		return ""
	end

	local lines = {}
	local display_name = reviews.get_display_name(review)

	table.insert(lines, "## Review Comments")
	table.insert(lines, "")
	table.insert(lines, string.format("**Review:** %s", display_name))

	-- Add timestamp
	if review.last_accessed then
		local date = os.date("%Y-%m-%d %H:%M", review.last_accessed)
		table.insert(lines, string.format("**Date:** %s", date))
	end

	table.insert(lines, "")
	table.insert(lines, "---")
	table.insert(lines, "")

	return table.concat(lines, "\n")
end

-- Export Mode 1: Comments only with line numbers
function M.export_comments_only()
	local review = reviews.get_current()
	if not review then
		return nil, "No active review"
	end

	local all_comments = comments.get_all()
	if #all_comments == 0 then
		return nil, "No comments to export"
	end

	-- Group comments by file
	local by_file = {}
	for _, comment in ipairs(all_comments) do
		if not by_file[comment.file] then
			by_file[comment.file] = {}
		end
		table.insert(by_file[comment.file], comment)
	end

	-- Sort files alphabetically
	local files = {}
	for file, _ in pairs(by_file) do
		table.insert(files, file)
	end
	table.sort(files)

	-- Build markdown output with metadata header
	local lines = {}
	local header = format_metadata_header()
	for line in header:gmatch("[^\r\n]+") do
		table.insert(lines, line)
	end

	for _, file in ipairs(files) do
		table.insert(lines, string.format("**File:** %s", file))
		-- Sort comments by line number
		table.sort(by_file[file], function(a, b)
			return a.line < b.line
		end)
		for _, comment in ipairs(by_file[file]) do
			table.insert(lines, format_comment_line(comment))
		end
		table.insert(lines, "")
	end

	-- Add summary
	local total_comments = #all_comments
	local total_files = #files
	table.insert(lines, "---")
	table.insert(
		lines,
		string.format("Total: %d comment%s across %d file%s", total_comments, total_comments == 1 and "" or "s", total_files, total_files == 1 and "" or "s")
	)

	return table.concat(lines, "\n")
end

-- Export Mode 2: With code context
function M.export_full()
	local review = reviews.get_current()
	if not review then
		return nil, "No active review"
	end

	local all_comments = comments.get_all()
	if #all_comments == 0 then
		return nil, "No comments to export"
	end

	-- Group comments by file
	local by_file = {}
	for _, comment in ipairs(all_comments) do
		if not by_file[comment.file] then
			by_file[comment.file] = {}
		end
		table.insert(by_file[comment.file], comment)
	end

	-- Sort files alphabetically
	local files = {}
	for file, _ in pairs(by_file) do
		table.insert(files, file)
	end
	table.sort(files)

	-- Build markdown output with metadata header
	local lines = {}
	local header = format_metadata_header()
	for line in header:gmatch("[^\r\n]+") do
		table.insert(lines, line)
	end

	for _, file in ipairs(files) do
		table.insert(lines, string.format("**File:** %s", file))
		table.insert(lines, "")

		-- Sort comments by line number
		table.sort(by_file[file], function(a, b)
			return a.line < b.line
		end)

		for _, comment in ipairs(by_file[file]) do
			-- Add line reference
			local start_line, end_line
			if comment.type == "range" then
				start_line = comment.line_range.start
				end_line = comment.line_range["end"]
				table.insert(lines, string.format("Lines %d-%d:", start_line, end_line))
			else
				start_line = comment.line
				end_line = comment.line
				table.insert(lines, string.format("Line %d:", comment.line))
			end

			-- Add code context
			local context = get_code_context(file, start_line, end_line, 2)
			if context and #context > 0 then
				-- Determine file extension for syntax highlighting
				local ext = file:match("%.([^%.]+)$") or ""
				table.insert(lines, "```" .. ext)

				for _, code_line in ipairs(context) do
					table.insert(lines, string.format("%d: %s", code_line.line_num, code_line.text))
				end

				table.insert(lines, "```")
			else
				table.insert(lines, "```")
				table.insert(lines, "// Code context unavailable")
				table.insert(lines, "```")
			end
			table.insert(lines, "")

			-- Add comment text
			table.insert(lines, string.format("💬 %s", comment.text))
			table.insert(lines, "")
			table.insert(lines, "---")
			table.insert(lines, "")
		end
	end

	return table.concat(lines, "\n")
end

-- Export Mode 3: Annotated diff
function M.export_annotated_diff()
	local review = reviews.get_current()
	if not review then
		return nil, "No active review"
	end

	local all_comments = comments.get_all()
	if #all_comments == 0 then
		return nil, "No comments to export"
	end

	-- Group comments by file
	local comments_by_file = {}
	for _, comment in ipairs(all_comments) do
		if not comments_by_file[comment.file] then
			comments_by_file[comment.file] = {}
		end
		table.insert(comments_by_file[comment.file], comment)
	end

	-- Get all files with diffs
	local diff = require("diff-review.diff")
	local changed_files = diff.get_changed_files()

	-- Build annotated diff output with metadata header
	local output_lines = {}

	-- Add metadata header
	local display_name = reviews.get_display_name(review)
	table.insert(output_lines, string.format("# Review: %s", display_name))
	if review.last_accessed then
		local date = os.date("%Y-%m-%d %H:%M", review.last_accessed)
		table.insert(output_lines, string.format("# Date: %s", date))
	end
	table.insert(output_lines, string.format("# Comments: %d", #all_comments))
	table.insert(output_lines, "")

	for _, file_info in ipairs(changed_files) do
		local file = file_info.path
		local diff_output = diff.get_file_diff(file_info)

		if diff_output and diff_output ~= "" then
			-- Get comments for this file
			local file_comments = comments_by_file[file] or {}

			-- Sort comments by line number for insertion
			table.sort(file_comments, function(a, b)
				return a.line < b.line
			end)

			-- Parse diff and insert comments
			local current_line = 0
			local comment_idx = 1

			for line in diff_output:gmatch("[^\r\n]+") do
				-- Check for hunk header to track line numbers
				local new_start = line:match("^@@ %-(%d+),?%d* %+(%d+),?%d* @@")
				if new_start then
					current_line = tonumber(new_start) - 1
				elseif line:sub(1, 1) == "+" or line:sub(1, 1) == " " then
					-- Track line number for added or context lines
					current_line = current_line + 1
				end

				-- Add the diff line
				table.insert(output_lines, line)

				-- Check if we should insert a comment after this line
				while comment_idx <= #file_comments do
					local comment = file_comments[comment_idx]
					local comment_line = comment.type == "range" and comment.line_range.start or comment.line

					if current_line == comment_line then
						-- Insert comment as a special annotation line
						table.insert(output_lines, string.format("+    // 💬 %s", comment.text))
						comment_idx = comment_idx + 1
					else
						break
					end
				end
			end

			-- Add separator between files
			table.insert(output_lines, "")
		end
	end

	return table.concat(output_lines, "\n")
end

-- Main export function
function M.export(mode)
	mode = mode or M.modes.COMMENTS

	if mode == M.modes.COMMENTS then
		return M.export_comments_only()
	elseif mode == M.modes.FULL then
		return M.export_full()
	elseif mode == M.modes.DIFF then
		return M.export_annotated_diff()
	else
		return nil, string.format("Unknown export mode: %s", mode)
	end
end

-- Copy to clipboard
function M.copy_to_clipboard(content)
	if not content then
		return false, "No content to copy"
	end

	-- Try different clipboard commands
	local clip_cmd
	if vim.fn.has("clipboard") == 1 then
		-- Use Neovim's clipboard provider
		vim.fn.setreg("+", content)
		return true
	elseif vim.fn.executable("pbcopy") == 1 then
		-- macOS
		clip_cmd = "pbcopy"
	elseif vim.fn.executable("xclip") == 1 then
		-- Linux (X11)
		clip_cmd = "xclip -selection clipboard"
	elseif vim.fn.executable("wl-copy") == 1 then
		-- Linux (Wayland)
		clip_cmd = "wl-copy"
	else
		return false, "No clipboard utility available"
	end

	-- Write to clipboard using external command
	local handle = io.popen(clip_cmd, "w")
	if not handle then
		return false, "Failed to open clipboard command"
	end
	handle:write(content)
	handle:close()

	return true
end

return M
