.PHONY: test test-setup

PLENARY_DIR ?= /tmp/plenary.nvim

test-setup:
	@if [ ! -d $(PLENARY_DIR) ]; then \
		echo "Installing plenary.nvim to $(PLENARY_DIR)..."; \
		git clone https://github.com/nvim-lua/plenary.nvim $(PLENARY_DIR); \
	fi

test: test-setup
	@echo "Running tests..."
	PLENARY_DIR=$(PLENARY_DIR) nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"

test-file: test-setup
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make test-file FILE=tests/config_spec.lua"; \
		exit 1; \
	fi
	@echo "Running $(FILE)..."
	PLENARY_DIR=$(PLENARY_DIR) nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "PlenaryBustedFile $(FILE)"

clean-test:
	rm -rf $(PLENARY_DIR)
