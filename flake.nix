{
  description = "qemu with Alexander Graf's 'hvf: Implement Apple Silicon Support' patches applied";

  inputs.utils.url = "github:numtide/flake-utils";

  # note: until https://github.com/NixOS/nix/issues/4423 is fixed, we need a separate qemuSrc repo since qemu uses submodules
  inputs.qemuSrc.url = "https://github.com/mstone/qemu-m1";
  inputs.qemuSrc.type = "git";
  inputs.qemuSrc.ref = "m1-test";
  inputs.qemuSrc.submodules = true;
  inputs.qemuSrc.flake = false;

  inputs.sigtool.url = "github:mstone/sigtool";
  inputs.sigtool.inputs.nixpkgs.follows = "nixpkgs";
  inputs.sigtool.inputs.utils.follows = "utils";

  outputs = { self, nixpkgs, utils, qemuSrc, sigtool }: let
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
          src = qemuSrc;
          patches = [(builtins.head (builtins.tail old.patches))];
          buildInputs = old.buildInputs ++ [ libtasn1 ];
          nativeBuildInputs = [ sigtool.defaultPackage.${prev.system} (python39.withPackages (ps: with ps; [sphinx sphinx_rtd_theme])) ] ++ (lib.drop 2 old.nativeBuildInputs);
        })).override { hostCpuOnly = true; };
        defaultPackage = qemu;
      };
    });
  };
}
