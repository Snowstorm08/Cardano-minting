{ pkgs }:

let
  lib = pkgs.lib;

  # Helper: filter out internal keys
  validNames = attrs:
    lib.filter (n: !(n == "recurseForDerivations" || n == "meta"))
      (builtins.attrNames attrs);

in rec {

  /*
    dimension: name -> attrs -> function -> attrs
  */
  dimension = name: attrs: f:
    let
      mapped = builtins.mapAttrs (k: v:
        let result = f k v;
        in result // {
          recurseForDerivations = result.recurseForDerivations or true;
        }
      ) attrs;
    in
      mapped // {
        meta.dimension.name = name;
      };

  /*
    Collect all derivation paths in an attrset
  */
  derivationPaths =
    let
      go = path: attrs:
        builtins.concatMap (name:
          let
            value = attrs.${name};
            newPath = path ++ [ name ];
          in
            if lib.isDerivation value then
              [ (builtins.concatStringsSep "." newPath) ]
            else if builtins.isAttrs value then
              go newPath value
            else
              [ ]
        ) (validNames attrs);
    in
      go [ ];

  /*
    Aggregate derivations into a Hydra job
  */
  derivationAggregate = name: attrs:
    pkgs.releaseTools.aggregate {
      inherit name;
      constituents = derivationPaths attrs;
    };

  /*
    Platform filter based on meta.platforms
  */
  platformFilterGeneric = pkgs: system:
    let
      platform = pkgs.lib.systems.elaborate { inherit system; };
    in
      drv:
        if drv ? meta && drv.meta ? platforms then
          lib.any (lib.meta.platformMatch platform) drv.meta.platforms
        else
          true;

  /*
    Recursive filter that avoids diving into derivations
  */
  filterAttrsOnlyRecursive = pred: set:
    lib.listToAttrs (
      lib.concatMap (name:
        let value = set.${name};
        in
          if pred name value then [
            (lib.nameValuePair name (
              if builtins.isAttrs value && !lib.isDerivation value then
                filterAttrsOnlyRecursive pred value
              else
                value
            ))
          ] else [ ]
      ) (builtins.attrNames set)
    );

  /*
    Remove Hydra-problematic attributes
  */
  stripAttrsForHydra =
    filterAttrsOnlyRecursive (n: _: n != "recurseForDerivations" && n != "dimension");

  /*
    Keep only derivations or recursive sets
  */
  filterDerivations =
    filterAttrsOnlyRecursive (_: v:
      lib.isDerivation v || (v.recurseForDerivations or false)
    );

  /*
    Filter supported systems
  */
  filterSystems = systems:
    lib.filterAttrs (_: v: builtins.elem v systems) {
      linux = "x86_64-linux";
      darwin = "x86_64-darwin";
    };
}
