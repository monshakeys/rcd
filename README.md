# RCD - Rapid (Repositories) Change Directory

A high-performance tool for quickly switching between Git projects under multiple repository roots, rewritten in Rust to fully replicate the functionality of the shell script version.

## Features

- 🔍 **fzf Integration**: Supports fzf interactive menu with tree preview, auto-fallback to built-in menu when fzf is unavailable
- 🎯 **Fuzzy Search**: Supports Levenshtein distance tolerance search with 3-character tolerance
- 📁 **Smart Caching**: 4-hour JSON cache mechanism to avoid repeated filesystem scanning
- ⚙️ **Directory Management**: Easy management of project root directories with dynamic add/remove support
- 🚀 **Concurrent Scanning**: Multi-threaded scanning for improved performance

## Installation

### Homebrew (Recommended)

```bash
brew install monshakeys/tap/rcd
```

### Alternative Methods

- Download the latest binary from the [releases page](https://github.com/monshakeys/rcd/releases) and place it in your `$PATH`.
- Or these methods:

```bash
# clone
git clone git@github.com:monshakeys/rcd.git
cd rcd

# for dev
cargo build
./target/debug/lscmd

# for prod
cargo build --locked --release
./target/release/lscmd

# run without building executable
cargo run              # debug mode
cargo run --release    # release mode

# install to path
cargo install --path .
```

## Usage

```bash
# Search for project and output path
rcd myproject

# Launch interactive mode (fzf menu + tree preview)
rcd

# List all project names and short paths
rcd -l

# Show help message (including dynamic root directory list)
rcd -h

# Clear cache and force rebuild
rcd -c

# Add project root directory to scan
rcd --add /path/to/your/project

# Interactively remove project root directory
rcd --remove
```

## Output Example

## Project Structure

```
rcd/
``
