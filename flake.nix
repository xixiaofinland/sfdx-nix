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
      pkgs = import nixpkgs {inherit system;};
      nodejs = pkgs.nodejs_22;
      yarn = pkgs.yarn.override {inherit nodejs;};
    in {
      packages = rec {
        sf = pkgs.stdenv.mkDerivation rec {
          pname = "salesforce-cli";
          version = "2.113.2";
          
          src = pkgs.fetchFromGitHub {
            owner = "salesforcecli";
            repo = "cli";
            rev = version;
            hash = "sha256-dT0XOfIYkKy4Rteg42/2ioI8AcdCLzF+6ZkUbnXtV0I=";
          };

          offlineCache = pkgs.fetchYarnDeps {
            yarnLock = "${src}/yarn.lock";
            hash = "sha256-C81c31WVnNoX9AEN2fTZlbfUq46Yp/U6Bk4SmMhkAz4=";
          };
nativeBuildInputs = [
            nodejs
            yarn
            pkgs.prefetch-yarn-deps
            pkgs.fixup-yarn-lock
          ];

          configurePhase = ''
            runHook preConfigure
            export HOME=$TMPDIR
            yarn config --offline set yarn-offline-mirror ${offlineCache}
            runHook postConfigure
          '';

          buildPhase = ''
            runHook preBuild
            export HOME=$TMPDIR
            export SF_HIDE_RELEASE_NOTES=true
            
            # Fix yarn.lock to work with offline cache
            ${pkgs.fixup-yarn-lock}/bin/fixup-yarn-lock yarn.lock
            
            yarn install --offline --ignore-scripts --ignore-engines
            patchShebangs --build node_modules
            yarn build --offline
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            mkdir -p $out/{bin,lib}
            
            # Move core files to lib directory
            mv node_modules dist package.json $out/lib/
            
            # Create wrapper script
            cat > $out/bin/sf <<'EOF'
            #!/bin/sh
            exec ${nodejs}/bin/node $out/lib/bin/run.js "$@"
            EOF
            chmod +x $out/bin/sf
            
            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "Salesforce CLI";
            homepage = "https://developer.salesforce.com/tools/salesforcecli";
            license = licenses.bsd3;
            maintainers = [];
            platforms = platforms.unix;
          };
        };
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

      devShells.default = pkgs.mkShell {
        buildInputs = [nodejs yarn];
        shellHook = ''
          echo "Salesforce CLI development environment"
          echo "Node.js: $(node --version)"
          echo "Yarn: $(yarn --version)"
        '';
      };
    });
}
}
