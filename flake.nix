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
        # Pin to Node.js 22 to match Salesforce CLI requirements (v2.114.1+ uses Node 22)
        nodejs = pkgs.nodejs_22;
        yarn = pkgs.yarn.override { inherit nodejs; };
      in
        pkgs.stdenv.mkDerivation {
          inherit version src;
          pname = name;
          nativeBuildInputs = [nodejs yarn pkgs.prefetch-yarn-deps pkgs.fixup-yarn-lock];
          phases = ["unpackPhase" "configurePhase" "buildPhase" "installPhase" "distPhase"];
          configurePhase = ''
            export HOME=$PWD/yarn_home
            yarn --offline config set yarn-offline-mirror ${offlineCache}
          '';
          buildPhase = ''
            export HOME=$PWD/yarn_home
            export SF_HIDE_RELEASE_NOTES=true
            fixup-yarn-lock ./yarn.lock
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
            yarn pack --offline --ignore-scripts --production=true --filename $out/tarballs/sf.tgz
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
        pkgs.mkShell {buildInputs = with pkgs; [nodejs_22 yarn];};
    });
}
