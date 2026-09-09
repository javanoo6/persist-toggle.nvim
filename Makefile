.PHONY: test unit e2e

test: unit e2e

unit:
	nvim --clean --headless -u tests/minimal_init.lua -S tests/persist_toggle_spec.lua

e2e:
	rm -rf .test-tmp
	mkdir -p .test-tmp
	PERSIST_TOGGLE_E2E_PATH="$$(pwd)/.test-tmp/e2e.json" \
		nvim --clean --headless -u tests/minimal_init.lua -S tests/e2e_write.lua
	PERSIST_TOGGLE_E2E_PATH="$$(pwd)/.test-tmp/e2e.json" \
		nvim --clean --headless -u tests/minimal_init.lua -S tests/e2e_read.lua
	rm -rf .test-tmp
