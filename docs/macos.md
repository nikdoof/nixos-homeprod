# macOS Setup

Steps to set up a macOS workstation for working with this repository, including Nix
installation and LSP tooling for editor support.

## Installation

1. Install Nix using the [Determinate Nix Installer](https://determinate.systems/nix-installer/):
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
   ```
   This provides a deterministic Nix installation with automatic updates and a graceful
   uninstall path.

2. Restart your terminal, then install development tools:
   ```bash
   nix profile install nixpkgs#nixfmt-rfc-style
   nix profile install nixpkgs#statix
   nix profile install nixpkgs#deadnix
   nix profile install nixpkgs#nixd
   nix profile install nixpkgs#nil
   ```

3. (Optional) Install `agenix` for secret management:
   ```bash
   nix profile install nixpkgs#agenix
   ```

## Editor setup

### VS Code / VSCodium

Install the `jnoortheen.nix-ide` extension for Nix language support. The extension
auto-detects `nil` and `nixd` from PATH.

### Neovim

Use `nickel-nix` for tree-sitter parsing and `nil` or `nixd` as the LSP server. The
following plugins are recommended:

- `nickel-nix` (tree-sitter grammar)
- `neovim/nvim-lspconfig` (LSP client configuration)

### Zed

Nix language support is built-in. The LSP server must be on PATH:
```json
{
  "lsp": {
    "nil": {
      "binary": {
        "path": "nil"
      }
    }
  }
}
```

## First use

Clone the repository and verify the flake:

```bash
git clone https://github.com/nikdoof/nixos-homeprod.git
cd nixos-homeprod
nix flake check
```
