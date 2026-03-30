# Build

Build with Nix flakes:
- Install Nix with flakes:
  ```curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install```
- Build:
  ```nix build git@github.com:MaxCarroll0/nix-latex-template.git```
  (or just run `nix build` in the cloned repo)
