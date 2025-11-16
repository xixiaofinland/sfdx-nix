{
  description = "Nix flake that provides sfdx.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
      };

      sfPackage = let
        name = "salesforce-cli";
        version = "2.113.2";
        src = pkgs.fetchFromGitHub {
          owner = "salesforcecli";
          repo = "cli";
          rev = version;
          hash = "sha256-dT0XOfIYkKy4Rteg42/2ioI8AcdCLzF+6ZkUbnXtV0I=";
        };
        lib = pkgs.lib;
        offlineCache = pkgs.fetchYarnDeps {
          yarnLock = "${src}/yarn.lock";
          hash = "sha256-C81c31WVnNoX9AEN2fTZlbfUq46Yp/U6Bk4SmMhkAz4=";
        };
      in
        pkgs.stdenv.mkDerivation {
          inherit version src;
          pname = name;
          nativeBuildInputs = [
  pkgs.nodejs_20
  pkgs.yarn
  pkgs.prefetch-yarn-deps
  pkgs.fixup-yarn-lock
];
          phases = ["unpackPhase" "configurePhase" "buildPhase" "installPhase" "distPhase"];

configurePhase = ''
  export PATH="${pkgs.nodejs_20}/bin:${pkgs.yarn}/bin:$PATH"
  export HOME=$PWD/yarn_home
  yarn --offline config set yarn-offline-mirror ${offlineCache}
'';

buildPhase = ''
  export PATH="${pkgs.nodejs_20}/bin:${pkgs.yarn}/bin:$PATH"
  export HOME=$PWD/yarn_home
  export SF_HIDE_RELEASE_NOTES=true
  chmod -R +rw $PWD/scripts
  yarn --offline install --ignore-scripts
  chmod -R +rw $PWD/node_modules
  patchShebangs --build node_modules
  yarn --offline --production=true run build
'';

          installPhase = ''
            mkdir $out
            mv node_modules $out/
            mv dist $out/
            mkdir -p $out/bin
            mv bin/run.js $out/bin/sf
            # necessary for some runtime configuration
            cp ./package.json $out
            patchShebangs $out
          '';

          distPhase = ''
            mkdir -p $out/tarballs/
            yarn pack --offline --ignore-scripts --production=true --filename $out/tarballs/sf/.tgz
          '';
        };
    in {
      packages = rec {
        sf = sfPackage;
        default = sf;
      };
      apps = rec {
        sf = flake-utils.lib.mkApp {
          drv = self.packages.${system}.sf;
          exePath = "/bin/sf";
        };
        default = sf;
      };
      formatter = pkgs.alejandra;
      devShells.default =
        pkgs.mkShell {buildInputs = with pkgs; [nodejs yarn];};
    });
}
