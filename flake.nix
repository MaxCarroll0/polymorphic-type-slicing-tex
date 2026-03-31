{
  description = "Polymorphic Type Slicing Dissertation";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };
  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      document_name = "PolymorphicTypeSlicing"; # Set name here
      document_date = ""; # Set date here. Set to empty string to automatically use last commit date
      tex =
        pkgs:
        pkgs.texlive.withPackages (
          ps: with ps; [
            scheme-basic
            latex-bin
            latexmk
            # Add extra TeX packages here
            lipsum
          ]
        );

      forEachSystem =
        f:
        nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (system: f nixpkgs.legacyPackages.${system});
    in
    {
      # Dev Shell
      devShells = forEachSystem (pkgs: {
        default = pkgs.mkShell {
          # require TexLive with required packages
          packages = [
            ((tex pkgs).withPackages (
              ps: with ps; [
                digestif
                dvisvgm
              ]
            ))
          ];
        };
      });

      # Build via Latexmk
      packages = forEachSystem (pkgs: rec {
        document = pkgs.stdenvNoCC.mkDerivation rec {
          name = document_name;
          src = self;
          buildInputs = [
            pkgs.coreutils
            (tex pkgs)
          ];
          phases = [
            "unpackPhase"
            "buildPhase"
            "installPhase"
          ];
          buildPhase = ''
            export PATH="${pkgs.lib.makeBinPath buildInputs}";
            export TEXMFVAR=$(mktemp -d);
            export SOURCE_DATE_EPOCH=${
              if document_date == "" then toString self.lastModified else "$(date -d ${document_date} +%s)"
            };
            latexmk -interaction=nonstopmode -pdf -lualatex \
            -pretex="\pdfvariable suppressoptionalinfo 512\relax" \
            -usepretex ${document_name}.tex
          '';
          installPhase = ''
            mkdir -p $out
            cp ${document_name}.pdf $out/
            cp ${document_name}.log $out/
          '';
        };

        default = document;
      });
    };
}
