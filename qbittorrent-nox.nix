{config, pkgs, lib, ...}:

with lib;

let
  cfg = config.services.qbittorrent-nox;
  settingsFormat = pkgs.formats.ini { };

  defaultConfig = {
    LegalNotice = {
      Accepted = true;
    };

    BitTorrent = {
      "Session\AddExtensionToIncompleteFiles" = true;
      "Session\AlternativeGlobalDLSpeedLimit" = 800;
      "Session\AlternativeGlobalUPSpeedLimit" = 200;
      "Session\BandwidthSchedulerEnabled" = true;
      "Session\DefaultSavePath" = if cfg.conf.savePath != null then cfg.conf.savePath else "";
      "Session\GlobalMaxRatio" = 2;
      "Session\GlobalMaxSeedingMinutes" = 1440;
      "Session\MaxConnections" = 100;
      "Session\Port" = cfg.port;
      "Session\Preallocation" = true;
      "Session\QueueingSystemEnabled" = false;
      "Session\UseAlternativeGlobalSpeedLimit" = true;
    };

    Network = {
      "PortForwardingEnabled" = false;
      "Proxy\OnlyForTorrents" = false;
      "Cookies" = "@Invalid()";
    };
    
    Preferences = {
      "Bittorrent\MaxRatio" = 2;
      "Connection\GlobalDLLimitAlt" = 500;
      "Connection\GlobalUPLimitAlt" = 100;
      "Connection\ResolvePeerCountries" = true;
      "Connection\alt_speeds_on" = false;
      "Downloads\SavePath" = if cfg.conf.savePath != null then cfg.conf.savePath else "";
      "Downloads\UseIncompleteExtension" = true;
      "General\Locale" = "ru";
      "Queueing\QueueingEnabled" = false;
      "Scheduler\Enabled" = true;
      "Scheduler\days" = "EveryDay";
      "Scheduler\end_time" = "@Variant(\0\0\0\xf\x1\xb7t\0)";
      "Scheduler\start_time" = "@Variant(\0\0\0\xf\x1\x80\x85\x80)";
      "WebUI\AlternativeUIEnabled" = false;
      "WebUI\AuthSubnetWhitelistEnabled" = false;
      "WebUI\BanDuration" = 3600;
      "WebUI\CSRFProtection" = true;
      "WebUI\ClickjackingProtection" = true;
      "WebUI\CustomHTTPHeadersEnabled" = false;
      "WebUI\HTTPS\Enabled" = false;
      "WebUI\HostHeaderValidation" = true;
      "WebUI\LocalHostAuth" = true;
      "WebUI\MaxAuthenticationFailCount" = 5;
      "WebUI\Port" = cfg.web.port;
      "WebUI\ReverseProxySupportEnabled" = true;
      "WebUI\SecureCookie" = true;
      "WebUI\SessionTimeout" = 3600;
      "WebUI\UseUPnP" = false;
    };
  };

  configFile = settingsFormat.generate "qBittorrent.conf" (defaultConfig);

in 
{
  options = {

    services.qbittorrent-nox = {

      enable = mkOption {
        type = types.bool;
        default = false;
        description = lib.mdDoc ''
          Start an qbittorrent-nox daemon for a user.
        '';
      };

      web = {
        port = mkOption {
          type = types.port;
          default = 8080;
          description = lib.mdDoc ''
            qbittorrent-nox web UI port.
          '';
        };
      };

      port = mkOption {
        type = types.port;
        default = 48197;
        description = lib.mdDoc ''
          qbittorrent-nox web UI port.
        '';
      };

      openFirewall = mkOption {
        default = false;
        type = types.bool;
        description = lib.mdDoc ''
          Whether to open the firewall for the ports in
          {option}`services.qbittorrent-nox.port`.
        '';
      };

      dataDir = mkOption {
        type = types.path;
        default = "/var/lib/qbittorrent-nox";
        description = lib.mdDoc ''
          The directory where qbittorrent-nox will create files.
        '';
      };

      user = mkOption {
        type = types.str;
        default = "qbittorrent";
        description = lib.mdDoc ''
          User account under which qbittorrent-nox runs.
        '';
      };

      group = mkOption {
        type = types.str;
        default = "qbittorrent";
        description = lib.mdDoc ''
          Group under which qbittorrent-nox runs.
        '';
      };

      package = mkPackageOption pkgs "qbittorrent-nox" { };
    };
  };

  config = mkIf cfg.enable {
    systemd = {
      services.qbittorrent-nox = {
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" "nss-lookup.target" ];
        wants = [ "network-online.target" ];
        description = "qBittorrent-nox service";
        documentation = [ "man:qbittorrent-nox(1)" ];
        
        serviceConfig = {
          ExecStart = ''
            ${cfg.package}/bin/qbittorrent-nox \
              --profile=${cfg.dataDir}
          '';
          Type = "exec";
          User = cfg.user;
          Group = cfg.group;
          UMask = "0002";
          PrivateTmp = "false";
          TimeoutStopSec = 1800;
        };
      };

      # tmpfiles = {
      #   rules = [
      #     "d '${cfg.dataDir}' 0770 ${cfg.user} ${cfg.group}"
      #     "d '${cfg.dataDir}/.config' 0770 ${cfg.user} ${cfg.group}"
      #     "d '${cfg.dataDir}/.config/qBittorrent' 0770 ${cfg.user} ${cfg.group}"
      #   ];
      # };
    };

    networking.firewall = mkMerge [
      (mkIf (cfg.openFirewall) {
        allowedTCPPorts = [ cfg.port cfg.webPort ];
        allowedUDPPorts = [ cfg.port ];
      })
    ];

    environment.systemPackages = [ cfg.package ];

    users = {
      users = mkIf (cfg.user == "qbittorrent") {
        qbittorrent = {
          group = cfg.group;
          uid = config.ids.uids.qbittorrent-nox;
          home = cfg.dataDir;
          description = "qbittorrent daemon user";
        };
      };

      groups = mkIf (cfg.group == "qbittorrent") {
        qbittorrent = {
          gid = config.ids.gids.qbittorrent-nox;
        };
      };
    };
  };

  # "${cfg.dataDir}/qBittorrent.conf".source = pkgs.writeText configFile;
}
