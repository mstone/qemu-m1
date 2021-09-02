{
  description = "qemu with Alexander Graf's 'hvf: Implement Apple Silicon Support' patches applied";

  inputs.utils.url = "github:numtide/flake-utils";

  # note: until https://github.com/NixOS/nix/issues/4423 is fixed, we need a separate qemuSrc repo since qemu uses submodules
  inputs.qemuSrc.url = "https://github.com/mstone/qemu-m1";
  inputs.qemuSrc.type = "git";
  inputs.qemuSrc.ref = "m1";
  inputs.qemuSrc.submodules = true;
  inputs.qemuSrc.flake = false;

  inputs.sigtoolSrc.url = "github:thefloweringash/sigtool?rev=db1f32bb7de43cee8801880fbb88be8764fe75bb";
  inputs.sigtoolSrc.flake = false;

  outputs = { self, nixpkgs, utils, qemuSrc, sigtoolSrc }: let
    name = "qemu";
    version = "6.1.0";
  in utils.lib.simpleFlake {
    inherit self nixpkgs name;
    systems = utils.lib.defaultSystems;
    overlay = (final: prev: {
      qemu = with final; rec {

        sigtool = (prev.darwin.sigtool.overrideAttrs (old: rec {
          src = sigtoolSrc;
          postInstall = null;
        }));

        qemu = (prev.qemu.overrideAttrs (old: rec {
          inherit version;
          src = qemuSrc;
          patches = [(builtins.head (builtins.tail old.patches))];
          buildInputs = old.buildInputs ++ [ libtasn1 ];
          nativeBuildInputs = [ sigtool (python39.withPackages (ps: with ps; [sphinx sphinx_rtd_theme])) ] ++ (lib.drop 2 old.nativeBuildInputs);
        })).override { hostCpuOnly = true; };

        defaultPackage = qemu;
      };
    });
  };
}
