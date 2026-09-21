{ pkgs, pkgs-r, ... }:
{
  environment.systemPackages = with pkgs; [
    age
    ffmpeg
    gnucash
    quarto
    # R / data science — pinned via nixpkgs-r input (flake.nix), bumped only
    # on request from `just update` since these often rebuild from source
    (pkgs-r.rWrapper.override {
      packages = with pkgs-r.rPackages; [
        # document rendering
        rmarkdown knitr
        # core data wrangling & viz
        tidyverse ggplot2 dplyr tidyr readr lubridate stringr purrr
        data_table
        # EDA & cleaning
        janitor skimr broom here fs
        # visualization extensions
        patchwork ggthemes ggridges GGally corrplot viridis
        # tables
        kableExtra modelsummary stargazer
        # stats & ML
        caret forecast zoo xts
        tidymodels xgboost lightgbm glmnet
        # econometrics
        car lme4 sandwich lmtest fixest quantreg moments urca vars
        # quant finance
        quantmod TTR PerformanceAnalytics tidyquant tseries rugarch
        PortfolioAnalytics RQuantLib copula rmgarch slider
        # misc utils
        plotly DT scales
        # I/O & web
        writexl openxlsx httr vctrs
        # interactive & data
        shiny
      ];
    })
    pkgs-r.rstudio
    (texlive.combine {
      inherit (texlive)
        scheme-medium
        framed
        titling
        enumitem
        parskip
        preprint
        titlesec
        # bibliography
        biblatex biber csquotes
        # cross-references
        cleveref
        # math & science
        siunitx mathtools thmtools
        # tables
        multirow
        # code & algorithms
        minted algorithm2e
        # document structure
        appendix glossaries todonotes pdfpages
        # boxes & text
        tcolorbox soul;
    })
    pandoc
  ];
}
