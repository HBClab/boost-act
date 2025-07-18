{
  description = "A Nix-flake-based Python and R development environment";

  inputs.nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1.*.tar.gz";

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forEachSupportedSystem = f: nixpkgs.lib.genAttrs supportedSystems (system: f {
        pkgs = import nixpkgs { inherit system; };
      });

      version = "3.13";
    in
    {
      devShells = forEachSupportedSystem ({ pkgs }:
        let
          concatMajorMinor = v:
            pkgs.lib.pipe v [
              pkgs.lib.versions.splitVersion
              (pkgs.lib.sublist 0 2)
              pkgs.lib.concatStrings
            ];

          python = pkgs."python${concatMajorMinor version}";

          rWithPackages = pkgs.rWrapper.override {
            packages = with pkgs.rPackages; [
              optparse
            ];
          };
        in
        {
          default = pkgs.mkShellNoCC {
            venvDir = ".venv";

            postShellHook = ''
              venvVersionWarn() {
                local venvVersion
                venvVersion="$("$venvDir/bin/python" -c 'import platform; print(platform.python_version())')"
                [[ "$venvVersion" == "${python.version}" ]] && return
                cat <<EOF
Warning: Python version mismatch: [$venvVersion (venv)] != [${python.version}]
         Delete '$venvDir' and reload to rebuild for version ${python.version}
EOF
              }

              venvVersionWarn
            '';

            packages = [
              python.pkgs.venvShellHook
              python.pkgs.pip

              # Python: Data manipulation
              python.pkgs.pandas
              python.pkgs.numpy

              # Python: Visualization
              python.pkgs.matplotlib
              python.pkgs.seaborn
              python.pkgs.plotly

              # Python: API requests
              python.pkgs.requests
              python.pkgs.httpx

              # Python: Interactive tools
              python.pkgs.jupyterlab
              python.pkgs.ipython

              # Python: Scientific & config
              python.pkgs.scipy
              python.pkgs.pyyaml

              # R
              rWithPackages

              # General tools
              pkgs.git
            ];
          };
        });
    };
}

