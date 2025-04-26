# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build/Test Commands
- `mix setup` - Install dependencies and compile
- `mix compile` - Compile the project
- `mix test` - Run all tests
- `mix test test/path/to/test_file.exs` - Run a specific test file
- `mix test test/path/to/test_file.exs:line_number` - Run a specific test
- `mix check` - Run all code quality checks
- `mix format` - Format code
- `mix credo` - Run code style checks
- `mix dialyzer` - Run static analysis

## Code Style Guidelines
- **Modules**: PascalCase, grouped by functionality in lib/prov_chain/
- **Functions/Variables**: snake_case
- **Imports**: Prefer explicit aliasing (e.g., `alias ProvChain.Module`)
- **Documentation**: Use @moduledoc and @doc with examples
- **Testing**: Use ExUnit with async: true when possible, describe/test blocks
- **Error handling**: Return {:ok, result} and {:error, reason} tuples
- **Formatting**: Follow Elixir standard formatting
- **Types**: Use type specs for public functions
- **Dependencies**: Organized by purpose in mix.exs