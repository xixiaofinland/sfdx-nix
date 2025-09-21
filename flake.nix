{
  description = "Nix flake that provides Salesforce CLI (sf)";

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

      salesforce-cli = pkgs.stdenv.mkDerivation rec {
        pname = "salesforce-cli";
        version = "2.108.2";
        
        src = pkgs.fetchFromGitHub {
          owner = "salesforcecli";
          repo = "cli";
          rev = version;
          hash = "sha256-EhuBSlSUo11QmDmTdcc7V2rVUHgVjsuoxxYt96jGqCI=";
        };

        offlineCache = pkgs.fetchYarnDeps {
          yarnLock = "${src}/yarn.lock";
          hash = "sha256-jgpNG1F4ZsB9oK3jBq6yFDBKpUmnScCVFzLp2lysMHE=";
        };

        nativeBuildInputs = with pkgs; [
          nodejs 
          yarn 
          prefetch-yarn-deps 
          fixup-yarn-lock
        ];

        configurePhase = ''
          runHook preConfigure
          export HOME=$TMPDIR/yarn_home
          yarn --offline config set yarn-offline-mirror ${offlineCache}
          runHook postConfigure
        '';

        buildPhase = ''
          runHook preBuild
          export HOME=$TMPDIR/yarn_home
          export SF_HIDE_RELEASE_NOTES=true
          
          fixup-yarn-lock ./yarn.lock
          yarn --offline install --ignore-scripts --frozen-lockfile
          patchShebangs --build node_modules scripts
          yarn --offline run build
          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          mkdir -p $out/lib/salesforce-cli $out/bin
          
          cp -r node_modules dist package.json $out/lib/salesforce-cli/
          
          # Create wrapper script
          cat > $out/bin/sf << EOF
          #!/bin/sh
          exec ${pkgs.nodejs}/bin/node $out/lib/salesforce-cli/bin/run.js "\$@"
          EOF
          chmod +x $out/bin/sf
          runHook postInstall
        '';

        meta = with pkgs.lib; {
          description = "Salesforce CLI";
          homepage = "https://github.com/salesforcecli/cli";
          license = licenses.bsd3;
          maintainers = [];
          platforms = platforms.all;
        };
      };
    in {
      packages = {
        default = salesforce-cli;
        sf = salesforce-cli;
        salesforce-cli = salesforce-cli;
      };
      
      apps = {
        default = flake-utils.lib.mkApp {
          drv = salesforce-cli;
          exePath = "/bin/sf";
        };
        sf = flake-utils.lib.mkApp {
          drv = salesforce-cli;
          exePath = "/bin/sf";
        };
      };
      
      formatter = pkgs.alejandra;
      
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [nodejs yarn];
        packages = [salesforce-cli];
      };
    });
}
