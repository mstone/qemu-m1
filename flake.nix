{
  description = "qemu with Alexander Graf's 'hvf: Implement Apple Silicon Support' patches applied";

  inputs.utils.url = "github:numtide/flake-utils";

  inputs.sigtool.url = "github:mstone/sigtool";
  inputs.sigtool.inputs.nixpkgs.follows = "nixpkgs";
  inputs.sigtool.inputs.utils.follows = "utils";

  outputs = { self, nixpkgs, utils, sigtool }: let
    name = "qemu";
    version = "6.1.0";
  in utils.lib.simpleFlake {
    inherit self nixpkgs name;
    systems = utils.lib.defaultSystems;
    preOverlays = [ (final: prev: {
      sigtool = sigtool;
    })];
    overlay = (final: prev: {
      qemu = with final; rec {
        qemu = (prev.qemu.overrideAttrs (old: rec {
          inherit version;
          src = self;
          patches = [(builtins.head (builtins.tail old.patches))];
          buildInputs = old.buildInputs ++ [ libtasn1 ];
          nativeBuildInputs = [ sigtool.defaultPackage.${prev.system} (python39.withPackages (ps: with ps; [sphinx sphinx_rtd_theme])) ] ++ (lib.drop 2 old.nativeBuildInputs);
          darwinDontCodeSign = true;
          dontStrip = true;
        })).override { hostCpuOnly = true; };
        defaultPackage = qemu;
      };
    });
  };
}
