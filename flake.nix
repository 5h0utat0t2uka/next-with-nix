{
  description = "Next.js 16 + Node 24 + OSV-Scanner + Biome";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    git-hooks.url = "github:cachix/git-hooks.nix";
  };

  outputs = { self, nixpkgs, flake-utils, git-hooks, ... }:

  flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system; };

      # commit 時のフック（--writeオプションあり）
      preCommit = git-hooks.lib.${system}.run {
        src = ./.;
        hooks = {
          biome = {
            enable = true;
            name = "biome";
            entry = "${pkgs.biome}/bin/biome check --write --no-errors-on-unmatched";
            files = "\\.(js|ts|jsx|tsx|json|css|md)$";
          };
        };
      };
      preCommitCheck = git-hooks.lib.${system}.run {
        src = ./.;
        hooks = {
          biome = {
            enable = true;
            name = "biome";
            entry = "${pkgs.biome}/bin/biome check --no-errors-on-unmatched";
            files = "\\.(js|ts|jsx|tsx|json|css|md)$";
          };
        };
      };
    in
    {
      checks = {
        pre-commit = preCommitCheck;
      };

      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          nodejs_24
          pnpm
          ni
          git
          biome
          infisical
          osv-scanner
        ];

        shellHook = ''
          ${preCommit.shellHook}
          echo "node: $(node -v)"
          echo "pnpm: $(pnpm -v)"
        '';
      };
    }
  );
}
