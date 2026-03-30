{
  description = "(lua)LaTeX Build Template";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };
  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      document_name = "document_name"; # Set name here
      document_date = "2026-03-29"; # Set date here. Set to empty string to automatically use last commit date
      tex =
        pkgs:
        pkgs.texlive.combine {
          inherit (pkgs.texlive)
            scheme-basic
            latex-bin
            latexmk
            # Add TeX packages here
            lipsum
            ;
        };

      forEachSystem =
        f:
        nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (system: f nixpkgs.legacyPackages.${system});
    in
    {
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
            mkdir -p .cache/texmf-var
            env TEXMFHOME=.cache TEXMFVAR=.cache/texmf-var \
              SOURCE_DATE_EPOCH=${
                if document_date == "" then toString self.lastModified else "$(date -d ${document_date} +%s)"
              } \
              latexmk -interaction=nonstopmode -pdf -lualatex \
              -pretex="\pdfvariable suppressoptionalinfo 512\relax" \
              -usepretex ${document_name}$.tex
          '';
          installPhase = ''
            mkdir -p $out
            cp ${document_name}.pdf $out/
          '';
        };

        default = document;
      });
    };
}
