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

        qemuUnsigned = (prev.qemu.overrideAttrs (old: rec {
          inherit version;
          src = qemuSrc;
          patches = [(builtins.head (builtins.tail old.patches))];
          buildInputs = old.buildInputs ++ [ libtasn1 ];
          nativeBuildInputs = [ (python39.withPackages (ps: with ps; [sphinx sphinx_rtd_theme])) ] ++ (lib.drop 2 old.nativeBuildInputs);
        })).override { hostCpuOnly = true; };

        qemu = stdenv.mkDerivation {
          pname = name;
          inherit version;
          buildInputs = [ qemuUnsigned sigtool darwin.cctools ];
          phases = [ "installPhase" ];
          installPhase = ''
            set -euo pipefail
            mkdir -p $out/bin
            ln -sf ${qemuUnsigned}/share $out/share
            ln -sf ${qemuUnsigned}/include $out/include
            f="$out/bin/qemu-system-${stdenv.targetPlatform.qemuArch}";
            i="${qemuUnsigned}/bin/qemu-system-${stdenv.targetPlatform.qemuArch}-unsigned";
            cp $i $f;
            local sigsize;
            local -a allocate_archs;
            while read -r arch sigsize; do
              sigsize=$(( ((sigsize + 15) / 16) * 16 + 1024 ));
              allocate_archs+=(-a "$arch" "$sigsize");
            done < <(${sigtool}/bin/sigtool -f "$f" size);
            ${darwin.cctools}/bin/${darwin.cctools.targetPrefix}codesign_allocate -i "$f" "''${allocate_archs[@]}" -o "$f.tmp";
            ${sigtool}/bin/sigtool -i qemu-system-aarch64 -f "$f.tmp" -e ${./accel/hvf/entitlements.plist} inject;
            mv "$f.tmp" "$f";
          '';
        };

        defaultPackage = qemu;
      };
    });
  };
}
