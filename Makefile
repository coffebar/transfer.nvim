test:
	nvim --headless -u tests/minimal_init.lua -c 'PlenaryBustedDirectory tests' -c "qa!"
