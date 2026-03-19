{ lib
, haskell-nix
, gitignore-nix
, sources
, compiler-nix-name
, libsodium-vrf
, source-repo-override
}:

let
  # --- Helpers ---------------------------------------------------------------

  # Extract index-state from cabal.project
  parseIndexState = content:
    let
      matches =
        map (line: builtins.match "^index-state: *(.*)" line)
          (lib.splitString "\n" content);

      filtered = lib.filter (x: x != null) matches;
    in
      lib.head (filtered ++ [ null ]);

  # --- Values ----------------------------------------------------------------

  cabalProjectContent = builtins.readFile ../../../cabal.project;

  index-state = parseIndexState cabalProjectContent;

  project = import ./haskell.nix {
    inherit
      lib
      haskell-nix
      compiler-nix-name
      gitignore-nix
      libsodium-vrf
      source-repo-override;
  };

  packages = project.hsPkgs;

  projectPackages =
    haskell-nix.haskellLib.selectProjectPackages packages;

in rec {
  inherit
    index-state
    project
    packages
    projectPackages;
}
