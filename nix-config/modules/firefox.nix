{ config, pkgs, ... }:
{
  programs.firefox = {
    enable = true;
    configPath = "${config.xdg.configHome}/mozilla/firefox";
    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      OverrideFirstRunPage = "";
      OverridePostUpdatePage = "";
      PasswordManagerEnabled = false;
      DisableFormHistory = true;
      AutofillCreditCardEnabled = false;
      AutofillAddressEnabled = false;
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
      };
    };
    profiles.default = {
      search = {
        force = true;
        default = "google";
      };
      settings = {
        "browser.startup.page"                                           = 3;
        "browser.newtabpage.activity-stream.feeds.topsites"             = false;
        "browser.newtabpage.activity-stream.newtabWallpapers.wallpaper" = "light-panda";
        "accessibility.typeaheadfind.flashBar"                          = 0;
        "toolkit.legacyUserProfileCustomizations.stylesheets"           = true;

        "browser.newtab.preload"                                  = false;
        "browser.sessionstore.interval"                           = 600000;
        "dom.ipc.processCount"                                    = 2;
        "dom.ipc.processCount.webIsolated"                        = 2;
        "dom.timeout.defer_during_load"                           = true;
        "dom.timeout.background_budget_regeneration_rate"         = 1000;
        "dom.timeout.background_throttling_max_budget"            = 10;
        "dom.timeout.budget_throttling_max_delay"                 = 60000;
      };
      extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
        ublock-origin
        bitwarden
        absolute-enable-right-click
        vimium
      ];
      userContent = ''
        @-moz-document url("about:newtab"), url("about:home") {
          body, #newtab-window {
            background-color: #000000 !important;
            background-image: none !important;
          }
        }
      '';
    };
  };
}
