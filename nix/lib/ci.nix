{ pkgs }:

let
  inherit (pkgs) lib;

  ignoredAttrs = [ "recurseForDerivations" "meta" "dimension" ];

  /*
    Check whether an attribute name should be exposed.
  */
  isValidName = name:
    !(builtins.elem name ignoredAttrs);

  /*
    Recursively walk an attribute set.
  */
  recurseAttrs = f: path: attrs:
    builtins.concatMap (
      name:
        f path name attrs.${name}
    ) (builtins.filter isValidName (builtins.attrNames attrs));

in
rec {

  /*
    dimension :: String -> AttrSet -> (String -> Any -> AttrSet) -> AttrSet

    Applies a function across an attrset while automatically enabling
    recurseForDerivations.
  */
  dimension = name: attrs: f:
    let
      mapped = builtins.mapAttrs (
        key: value:
          let
            result = f key value;
          in
            result
            // {
              recurseForDerivations =
                result.recurseForDerivations or true;
            }
      ) attrs;
    in
      mapped
      // {
        meta.dimension.name = name;
      };

  /*
    derivationPaths :: AttrSet -> [ String ]

    Collect all derivation paths recursively.
  */
  derivationPaths =
    let
      collect = path: attrs:
        recurseAttrs (
          currentPath: name: value:
            let
              nextPath = currentPath ++ [ name ];
            in
              if lib.isDerivation value then
                [ (lib.concatStringsSep "." nextPath) ]
              else if builtins.isAttrs value then
                collect nextPath value
              else
                [ ]
        ) path attrs;
    in
      collect [ ];

}
