{ pkgs, pkgs-r, ... }:
let
  # Shared by rWrapper and rstudioWrapper below. RStudio internally overrides
  # R_LIBS_SITE, so plain `rstudio` cannot see rWrapper's packages and will
  # prompt to install them into ~/R instead — rstudioWrapper works around that.
  # NOTE: MASS survival rpart nnet cluster boot mgcv nlme lattice Matrix foreign
  # KernSmooth class spatial codetools come free via the wrappers'
  # `recommendedPackages`, so they are deliberately not listed here.
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

    # data import — course handouts ship .xlsx and Stata/SPSS files
    readxl haven
    # machine learning beyond the boosted trees above
    randomForest ranger e1071 rpart_plot pROC ROCR
    # econometrics: panel data, IV, structural breaks, regression tables
    plm AER ivreg estimatr dynlm strucchange texreg nortest
    # modern tidy time series alongside forecast/zoo/xts
    tsibble fable feasts
    # quant finance: GARCH variants, Rmetrics stack, derivatives, heuristics
    fGarch timeSeries fPortfolio derivmkts NMOF FinTS
    # portfolio optimisation solvers
    CVXR quadprog ROI nloptr
    # missing data and descriptive statistics
    mice naniar psych Hmisc
    # inference helpers
    emmeans multcomp performance
    # visualisation staples assumed by most ggplot2 material
    ggrepel gridExtra cowplot RColorBrewer
    # reporting: books, dashboards, journal templates
    # NOTE: gt/gtsummary omitted — they pull r-V8, which fails to build in this
    # nixpkgs pin (ICU ABI mismatch: undefined symbol _ZN6icu_78...). Publication
    # tables are covered by modelsummary/kableExtra/stargazer above.
    bookdown flexdashboard rticles tinytex
    # databases
    DBI RSQLite dbplyr
    # workflow / compiled-code deps that many packages assume present
    devtools remotes renv conflicted tictoc furrr Rcpp RcppArmadillo
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
