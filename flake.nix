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
            lipsum

            amsmath
            amsfonts
            amscls
            mathtools

            semantic
            stmaryrd

            xcolor
            soul

            hyperref
            cleveref
            biblatex
            biber

            booktabs
            arydshln

            graphics
            caption

            tikz-cd
            pgf
            tcolorbox
            tikzfill
            environ
            etoolbox
            pdfcol
            listings

            fancyhdr

            ulem
            marginnote
            dutchcal
            fontspec
            lualatex-math
            unicode-data

            texcount

            polytable

            standalone
            preview
            luatex85
            adjustbox
            collectbox
            varwidth

            koma-script
            dvisvgm
          ]
        );

      forEachSystem =
        f:
        nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (system: f nixpkgs.legacyPackages.${system});

      stripMarginsLua    = ./scripts/strip-margins.lua;
      expandMathLua      = ./scripts/expand-math.lua;
      inferenceArrowsLua = ./scripts/inference-arrows.lua;
      extractFiguresLua  = ./scripts/extract-figures.lua;
      theoremExtractLua  = ./scripts/theorem-extract.lua;
      theoremSpliceLua   = ./scripts/theorem-splice.lua;

      # Source files whose figures we extract — same list the build-doc
      # app enumerates. Each entry is the .tex basename without extension.
      figureScanFiles = [
        "intro" "ui" "background" "core-calculus" "synthesis" "analysis"
        "marking" "algorithms" "complexity" "comparisons" "conclusions"
        "appendix-context-classification" "appendix-bounded-syn-slices"
      ];

      mkFigures = pkgs:
        pkgs.stdenvNoCC.mkDerivation {
          name = "${document_name}-figures";
          src = self;
          nativeBuildInputs = [
            pkgs.coreutils (tex pkgs) pkgs.poppler_utils pkgs.lua5_4
          ];
          phases = [ "unpackPhase" "buildPhase" "installPhase" ];
          buildPhase = ''
            export TEXMFVAR=$(mktemp -d)
            mkdir -p out/Figures out/stub
            # Mirror every source file into stub/; extract-figures.lua then
            # overwrites the ones that contain \begin{figure}…\end{figure}.
            for tex in *.tex; do
              [ -f "$tex" ] && cp "$tex" out/stub/
            done
            for base in ${pkgs.lib.escapeShellArgs figureScanFiles}; do
              [ -f "$base.tex" ] || continue
              figdir=$(mktemp -d)
              SRC_FILE="$base.tex" SRC_DIR="$PWD" FIGDIR="$figdir" \
              BASE="$base" FIG_OUT="$PWD/out/Figures" \
              STUB_FILE="$PWD/out/stub/$base.tex" \
                lua ${extractFiguresLua} > /dev/null || true
            done
          '';
          installPhase = ''
            mkdir -p $out
            cp -a out/Figures $out/
            cp -a out/stub    $out/
          '';
        };

      mkPandocDoc =
        pkgs:
        {
          format,
          ext,
          mode,                # txt | md | org | html — drives Lua filter behaviour
          pandocArgs ? "",
          stripMargins ? false,
        }:
        let figures = mkFigures pkgs;
        in pkgs.stdenvNoCC.mkDerivation {
          name = "${document_name}-${ext}${if stripMargins then "-no-marginpars" else ""}";
          src = self;
          nativeBuildInputs = [ pkgs.pandoc pkgs.coreutils ];
          phases = [ "unpackPhase" "buildPhase" "installPhase" ];
          buildPhase = ''
            # Overlay the figure-stubbed .tex files. The stubs replace each
            # figure body with \includegraphics{Figures/<base>-fig<N>.svg},
            # which pandoc converts into the format's image reference
            # (`![](…)` for gfm, `[[file:…]]` for org, `<img …>` for html).
            cp -f ${figures}/stub/*.tex .
            ln -sfn ${figures}/Figures Figures
            pandoc -f latex -t ${format} ${pandocArgs} \
              --metadata=slice-text-mode=${mode} \
              --metadata=slice-strip-margins=${if stripMargins then "true" else "false"} \
              --lua-filter=${stripMarginsLua} \
              --lua-filter=${inferenceArrowsLua} \
              --lua-filter=${expandMathLua} \
              ${document_name}.tex -o ${document_name}.${ext} 2>pandoc.log || true
            if [ ! -s ${document_name}.${ext} ]; then
              echo "pandoc produced no output; see pandoc.log" >&2
              cat pandoc.log >&2 || true
              exit 1
            fi
          '';
          installPhase = ''
            mkdir -p $out
            cp ${document_name}.${ext} $out/
            cp -aL Figures $out/Figures
          '';
        };

    in
    {
      devShells = forEachSystem (pkgs: {
        default = pkgs.mkShell {
          packages = [
            ((tex pkgs).withPackages (
              ps: with ps; [
                digestif
                dvisvgm
              ]
            ))
            pkgs.pandoc
          ];
        };
      });

      packages = forEachSystem (pkgs:
        let
          pdf = pkgs.stdenvNoCC.mkDerivation {
            name = document_name;
            src = self;
            nativeBuildInputs = [ pkgs.coreutils (tex pkgs) ];
            phases = [ "unpackPhase" "buildPhase" "installPhase" ];
            buildPhase = ''
              export TEXMFVAR=$(mktemp -d);
              export SOURCE_DATE_EPOCH=${
                if document_date == "" then toString self.lastModified else "$(date -d ${document_date} +%s)"
              };
              texcount -inc -sum=1,1,1,1,0,0,0 -0 ${document_name}.tex > wordcount.aux || echo "0" > wordcount.aux
              latexmk -interaction=nonstopmode -pdf -lualatex \
                -pretex="\pdfvariable suppressoptionalinfo 512\relax" \
                -usepretex ${document_name}.tex
            '';
            installPhase = ''
              mkdir -p $out
              cp ${document_name}.pdf $out/
            '';
          };
          mk = mkPandocDoc pkgs;
          html_args = "--mathml --standalone --metadata title=${document_name}";
          txt   = mk { format = "plain"; ext = "txt"; mode = "txt"; };
          org   = mk { format = "org";   ext = "org"; mode = "org"; };
          md    = mk { format = "gfm";   ext = "md";  mode = "md";  };
          html  = mk { format = "html";  ext = "html"; mode = "html"; pandocArgs = html_args; };

          txt-no-marginpars  = mk { format = "plain"; ext = "txt";  mode = "txt"; stripMargins = true; };
          org-no-marginpars  = mk { format = "org";   ext = "org";  mode = "org"; stripMargins = true; };
          md-no-marginpars   = mk { format = "gfm";   ext = "md";   mode = "md";  stripMargins = true; };
          html-no-marginpars = mk { format = "html";  ext = "html"; mode = "html"; pandocArgs = html_args; stripMargins = true; };

          allOf = label: extras: pkgs.symlinkJoin {
            name = "${document_name}-${label}";
            paths = [ pdf ] ++ extras;
          };
        in {
          default = pdf;
          pdf     = pdf;

          inherit txt org md html;
          inherit txt-no-marginpars org-no-marginpars md-no-marginpars html-no-marginpars;

          all              = allOf "all"              [ txt org md html ];
          all-no-marginpars = allOf "all-no-marginpars" [ txt-no-marginpars org-no-marginpars md-no-marginpars html-no-marginpars ];
        }
      );

      apps = forEachSystem (pkgs:
        let
          buildScript = pkgs.writeShellApplication {
            name = "build-doc";
            runtimeInputs = [ (tex pkgs) pkgs.pandoc pkgs.coreutils pkgs.gnused pkgs.poppler_utils pkgs.lua5_4 ];
            text = ''
              declare -A SEC
              SEC[FRONTMATTER]="cover-page.tex,abstract.tex"
              SEC[1]="intro.tex"
              SEC[2]="ui.tex"
              SEC[3]="background.tex"
              SEC[4]="core-calculus.tex"
              SEC[5]="synthesis.tex"
              SEC[6]="analysis.tex"
              SEC[7]="marking.tex"
              SEC[8]="algorithms.tex"
              SEC[9]="complexity.tex"
              SEC[10]="comparisons.tex"
              SEC[11]="conclusions.tex"
              SEC[BIB]="__BIB__"
              SEC[A]="appendix-marked-classification.tex"
              SEC[B]="appendix-bounded-syn-slices.tex"
              ALL_IDS=(FRONTMATTER 1 2 3 4 5 6 7 8 9 10 11 BIB A B)

              normalise_ids() {
                local out=()
                for id in "$@"; do
                  if [ "$id" = "0" ]; then out+=("FRONTMATTER"); else out+=("$id"); fi
                done
                printf '%s\n' "''${out[@]}"
              }

              targets=()
              clean=false
              include_csv=""
              exclude_csv=""
              do_figures=true
              theorems_mode=""
              stub_figures_in_plain=true
              while [ $# -gt 0 ]; do
                case "$1" in
                  --txt)  targets+=("txt") ; shift ;;
                  --org)  targets+=("org") ; shift ;;
                  --md)   targets+=("md")  ; shift ;;
                  --html) targets+=("html"); shift ;;
                  --all)  targets=("txt" "org" "md" "html") ; shift ;;
                  --everything)
                    targets=("txt" "org" "md" "html")
                    theorems_mode="all"
                    do_figures=true
                    shift ;;
                  --theorems)
                    if [ $# -ge 2 ] && [[ "$2" =~ ^(all|important|counterexamples)$ ]]; then
                      theorems_mode="$2"; shift 2
                    else
                      theorems_mode="all"; shift
                    fi ;;
                  --theorems=*)
                    theorems_mode="''${1#--theorems=}"; shift ;;
                  --no-marginpars|--clean) clean=true ; shift ;;
                  --figures)   do_figures=true  ; shift ;;
                  --nofigures) do_figures=false; stub_figures_in_plain=false ; shift ;;
                  --include) include_csv="$2" ; shift 2 ;;
                  --include=*) include_csv="''${1#--include=}" ; shift ;;
                  --exclude) exclude_csv="$2" ; shift 2 ;;
                  --exclude=*) exclude_csv="''${1#--exclude=}" ; shift ;;
                  *) echo "Unknown argument: $1" >&2; exit 1 ;;
                esac
              done

              if [ -n "$theorems_mode" ] \
                 && [ "$theorems_mode" != "all" ] \
                 && [ "$theorems_mode" != "important" ] \
                 && [ "$theorems_mode" != "counterexamples" ]; then
                echo "Invalid --theorems mode: '$theorems_mode' (expected all|important|counterexamples)" >&2
                exit 1
              fi

              if [ -n "$include_csv" ]; then
                IFS=',' read -ra wanted <<< "$include_csv"
                mapfile -t wanted < <(normalise_ids "''${wanted[@]}")
              else
                wanted=("''${ALL_IDS[@]}")
              fi
              if [ -n "$exclude_csv" ]; then
                IFS=',' read -ra unwanted <<< "$exclude_csv"
                mapfile -t unwanted < <(normalise_ids "''${unwanted[@]}")
                filtered=()
                for id in "''${wanted[@]}"; do
                  skip=false
                  for u in "''${unwanted[@]}"; do
                    if [ "$id" = "$u" ]; then skip=true; break; fi
                  done
                  $skip || filtered+=("$id")
                done
                wanted=("''${filtered[@]}")
              fi

              filter_applied=false
              if [ -n "$include_csv" ] || [ -n "$exclude_csv" ]; then
                filter_applied=true
              fi

              if $filter_applied; then
                work=$(mktemp -d)
                cp -a ./. "$work/"
                find "$work" -name '.#*' -delete 2>/dev/null || true
                chmod -R u+w "$work"
                main="$work/${document_name}.tex"
                body=""
                for id in "''${wanted[@]}"; do
                  entry="''${SEC[$id]:-}"
                  if [ -z "$entry" ]; then echo "Unknown section ID: $id" >&2; exit 1; fi
                  if [ "$entry" = "__BIB__" ]; then
                    body="$body"$'\n'"\\printbibliography"
                  else
                    IFS=',' read -ra files <<< "$entry"
                    for f in "''${files[@]}"; do
                      body="$body"$'\n'"\\input{$f}"
                    done
                  fi
                done
                # Switch numbering to A, B, ... before the first appendix file.
                if printf '%s\n' "''${wanted[@]}" | grep -qE '^(A|B)$'; then
                  body=$(printf '%s\n' "$body" | sed '0,/\\input{appendix-/{s/\\input{appendix-/\\appendix\n\\input{appendix-/}')
                fi
                cat > "$main" <<EOF
              \documentclass[12pt]{article}
              \input{preamble.tex}
              \begin{document}
              $body
              \end{document}
              EOF
                src="$work"
              else
                src="."
              fi

              OUT_ROOT="./${document_name}"
              rm -rf "$OUT_ROOT"
              mkdir -p "$OUT_ROOT"
              if $clean; then
                fmt_outdir="$OUT_ROOT/no-marginpars"
                mkdir -p "$fmt_outdir"
              else
                fmt_outdir="$OUT_ROOT"
              fi

              has_plain=false
              for t in "''${targets[@]:-}"; do
                case "$t" in txt|org|md) has_plain=true ;; esac
              done
              stub_src=""
              if $has_plain && $stub_figures_in_plain; then
                do_figures=true
              fi

              echo "Building PDF…"
              if $filter_applied; then
                ( cd "$src" && \
                  TEXMFVAR=$(mktemp -d) \
                  latexmk -interaction=nonstopmode -pdf -lualatex \
                    -pretex="\\pdfvariable suppressoptionalinfo 512\\relax" \
                    -usepretex ${document_name}.tex )
                cp "$src/${document_name}.pdf" "$OUT_ROOT/${document_name}.pdf"
              else
                tmp_pdf=$(mktemp -d)/pdf
                nix build .#pdf -o "$tmp_pdf"
                cp "$tmp_pdf/${document_name}.pdf" "$OUT_ROOT/${document_name}.pdf"
                rm -f "$tmp_pdf"
              fi
              echo "  → $OUT_ROOT/${document_name}.pdf"

              if $do_figures; then
                FIG_OUT="$OUT_ROOT/Figures"
                echo "Extracting figures → $FIG_OUT/"
                mkdir -p "$FIG_OUT"
                figdir=$(mktemp -d)
                scan_files=()
                for id in "''${wanted[@]}"; do
                  entry="''${SEC[$id]:-}"
                  [ -z "$entry" ] && continue
                  [ "$entry" = "__BIB__" ] && continue
                  IFS=',' read -ra files <<< "$entry"
                  for f in "''${files[@]}"; do scan_files+=("$f"); done
                done

                if $has_plain && $stub_figures_in_plain; then
                  stub_src=$(mktemp -d)
                  cp -a "$src"/. "$stub_src/"
                  find "$stub_src" -name '.#*' -delete 2>/dev/null || true
                  chmod -R u+w "$stub_src" 2>/dev/null || true
                fi

                for f in "''${scan_files[@]}"; do
                  base="''${f%.tex}"
                  stub_target=""
                  if [ -n "$stub_src" ]; then
                    stub_target="$stub_src/$f"
                  fi
                  SRC_FILE="$src/$f" SRC_DIR="$src" FIGDIR="$figdir" \
                  BASE="$base" FIG_OUT="$FIG_OUT" STUB_FILE="$stub_target" \
                    lua ${extractFiguresLua}
                  echo "  $base: figures found in source"
                done
                rm -rf "$figdir"
              fi

              for t in "''${targets[@]:-}"; do
                [ -z "$t" ] && continue
                case "$t" in
                  txt)  fmt="plain"; ext="txt"; extra=() ;;
                  org)  fmt="org";   ext="org"; extra=() ;;
                  md)   fmt="gfm";   ext="md";  extra=() ;;
                  html) fmt="html";  ext="html"; extra=("--mathml" "--standalone" "--metadata" "title=${document_name}") ;;
                esac
                target_dir="$fmt_outdir"
                manual_pandoc=$filter_applied
                pandoc_src="$src"
                case "$t" in
                  txt|org|md)
                    if [ -n "$stub_src" ]; then
                      pandoc_src="$stub_src"; manual_pandoc=true
                    fi ;;
                esac
                if $manual_pandoc; then
                  echo "Building $t (filtered)…"
                  # Match the nix-build pipeline exactly: always run all three
                  # filters, in the same order, with the same metadata flags.
                  args=(
                    "--metadata=slice-text-mode=$t"
                    "--metadata=slice-strip-margins=$($clean && echo true || echo false)"
                    "--lua-filter=${stripMarginsLua}"
                    "--lua-filter=${inferenceArrowsLua}"
                    "--lua-filter=${expandMathLua}"
                  )
                  ( cd "$pandoc_src" && pandoc -f latex -t "$fmt" "''${extra[@]}" "''${args[@]}" ${document_name}.tex -o "${document_name}.$ext" ) || true
                  cp "$pandoc_src/${document_name}.$ext" "$target_dir/" || true
                else
                  tmp_out=$(mktemp -d)/fmt
                  if $clean; then
                    nix build ".#$t-no-marginpars" -o "$tmp_out"
                  else
                    nix build ".#$t" -o "$tmp_out"
                  fi
                  cp "$tmp_out/${document_name}.$ext" "$target_dir/"
                  rm -f "$tmp_out"
                fi
                echo "  → $target_dir/${document_name}.$ext"
              done

              if [ -n "$theorems_mode" ]; then
                echo "Building theorem reference (mode=$theorems_mode)…"

                # Need a writable copy: theorem-reference.tex must not land in the source tree.
                if [ "$src" = "." ]; then
                  work_ref=$(mktemp -d)
                  cp -a ./. "$work_ref/"
                  find "$work_ref" -name '.#*' -delete 2>/dev/null || true
                  chmod -R u+w "$work_ref"
                  src="$work_ref"
                fi

                declare -A SEC_NAME
                SEC_NAME[FRONTMATTER]="Frontmatter"
                SEC_NAME[1]="Introduction"
                SEC_NAME[2]="Explanation by Example"
                SEC_NAME[3]="Background"
                SEC_NAME[4]="The Core Calculus"
                SEC_NAME[5]="Synthesis Slices"
                SEC_NAME[6]="Analysis Slices"
                SEC_NAME[7]="Error Marking & Type Error Debugging"
                SEC_NAME[8]="Algorithms"
                SEC_NAME[9]="Complexity of Minimum-Size Slicing"
                SEC_NAME[10]="Relation to Other Forms of Slicing"
                SEC_NAME[11]="Conclusions"
                SEC_NAME[A]="Appendix A: Marked Context Classification"
                SEC_NAME[B]="Appendix B: Bounded Synthesis Slices"

                ref_inputs=""
                for id in "''${wanted[@]}"; do
                  entry="''${SEC[$id]:-}"
                  [ -z "$entry" ] && continue
                  [ "$entry" = "__BIB__" ] && continue
                  sname="''${SEC_NAME[$id]:-Section $id}"
                  IFS=',' read -ra files <<< "$entry"
                  for f in "''${files[@]}"; do
                    ref_inputs+="$id|$f|$sname"$'\n'
                  done
                done

                gen_body=$(mktemp)
                ref_input_file=$(mktemp)
                printf '%s' "$ref_inputs" > "$ref_input_file"
                THM_MODE="$theorems_mode" SRC_DIR="$src" REF_INPUTS="$ref_input_file" \
                  lua ${theoremExtractLua} "$gen_body"

                ref_tex="$src/theorem-reference.tex"
                lua ${theoremSpliceLua} \
                    "$src/theorem-reference-template.tex" "$gen_body" "$theorems_mode" "$ref_tex"
                rm -f "$gen_body" "$ref_input_file"

                ref_outdir="$OUT_ROOT/Reference"
                mkdir -p "$ref_outdir"
                if $clean; then
                  ref_fmt_outdir="$ref_outdir/no-marginpars"
                  mkdir -p "$ref_fmt_outdir"
                else
                  ref_fmt_outdir="$ref_outdir"
                fi
                ( cd "$src" && \
                  TEXMFVAR=$(mktemp -d) \
                  latexmk -interaction=nonstopmode -pdf -lualatex \
                    -pretex="\\pdfvariable suppressoptionalinfo 512\\relax" \
                    -usepretex theorem-reference.tex ) || true
                if [ -s "$src/theorem-reference.pdf" ]; then
                  cp "$src/theorem-reference.pdf" "$ref_outdir/theorem-reference.pdf"
                  echo "  → $ref_outdir/theorem-reference.pdf"
                else
                  echo "  (skipped reference PDF: latexmk failed; see theorem-reference.log)"
                fi

                for t in "''${targets[@]:-}"; do
                  [ -z "$t" ] && continue
                  case "$t" in
                    txt)  fmt="plain"; ext="txt"; extra=() ;;
                    org)  fmt="org";   ext="org"; extra=() ;;
                    md)   fmt="gfm";   ext="md";  extra=() ;;
                    html) fmt="html";  ext="html"; extra=("--mathml" "--standalone" "--metadata" "title=theorem-reference") ;;
                  esac
                  args=(
                    "--metadata=slice-text-mode=$t"
                    "--metadata=slice-strip-margins=$($clean && echo true || echo false)"
                    "--lua-filter=${stripMarginsLua}"
                    "--lua-filter=${inferenceArrowsLua}"
                    "--lua-filter=${expandMathLua}"
                  )
                  ( cd "$src" && pandoc -f latex -t "$fmt" "''${extra[@]}" "''${args[@]}" theorem-reference.tex -o "theorem-reference.$ext" ) || true
                  cp "$src/theorem-reference.$ext" "$ref_fmt_outdir/" 2>/dev/null || true
                  echo "  → $ref_fmt_outdir/theorem-reference.$ext"
                done
              fi

            '';
          };
        in {
          build = {
            type = "app";
            program = "${buildScript}/bin/build-doc";
          };
          default = self.apps.${pkgs.system}.build;
        }
      );
    };
}
