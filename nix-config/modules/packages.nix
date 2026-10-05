{ pkgs, pkgs-r, ... }:
let
  # Shared by rWrapper and rstudioWrapper below. RStudio internally overrides
  # R_LIBS_SITE, so plain `rstudio` cannot see rWrapper's packages and will
  # prompt to install them into ~/R instead — rstudioWrapper works around that.
  rPkgs = with pkgs-r.rPackages; [
    rmarkdown knitr
    tidyverse ggplot2 dplyr tidyr readr lubridate stringr purrr
    data_table
    janitor skimr broom here fs
    patchwork ggthemes ggridges GGally corrplot viridis
    kableExtra modelsummary stargazer
    caret forecast zoo xts
    tidymodels xgboost lightgbm glmnet
    car lme4 sandwich lmtest fixest quantreg moments urca vars
    quantmod TTR PerformanceAnalytics tidyquant tseries rugarch
    PortfolioAnalytics RQuantLib copula rmgarch slider
    plotly DT scales
    writexl openxlsx httr vctrs
    shiny
    base64enc digest evaluate glue highr htmltools jsonlite magrittr mime stringi xfun yaml
  ];
in
{
  environment.systemPackages = with pkgs; [
    age
    ffmpeg
    gnucash
    quarto
    # R / data science — pinned via nixpkgs-r input (flake.nix), bumped only
    # on request from `just update` since these often rebuild from source
    (pkgs-r.rWrapper.override { packages = rPkgs; })
    (pkgs-r.rstudioWrapper.override { packages = rPkgs; })
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
