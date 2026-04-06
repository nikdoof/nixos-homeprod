# macOS Setup

Steps to set up a macOS workstation for working with this repository, including Nix
installation and LSP tooling for editor support.

## Installation

- Install Deterministic Nix from <https://nix.deterministic.systems/> and follow the
  instructions to set it up.
- Run `nix profile add github:/nix-community/nixd` to install the `nixd` LSP server.
- Run `nix profile add github:oxalica/nil` to install the `nil` LSP client.
- Restart your terminal and editor.
