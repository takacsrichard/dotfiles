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
        default = "Brave";
        engines = {
          "Brave" = {
            urls = [{
              template = "https://search.brave.com/search";
              params = [{ name = "q"; value = "{searchTerms}"; }];
            }];
            iconURL = "https://brave.com/static-assets/images/brave-favicon.png";
            definedAliases = [ "@brave" ];
          };
        };
      };
      settings = {
        "browser.startup.page"                                           = 3;
        "browser.newtabpage.activity-stream.feeds.topsites"             = false;
        "browser.newtabpage.activity-stream.newtabWallpapers.wallpaper" = "light-panda";
        "accessibility.typeaheadfind.flashBar"                          = 0;
        "toolkit.legacyUserProfileCustomizations.stylesheets"           = true;
      };
      extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
        ublock-origin
        bitwarden
        absolute-enable-right-click
        vimium
        # linkclump is not in NUR — install it manually from addons.mozilla.org
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
