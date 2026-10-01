# Module INVITE uniquement. Non importe par la configuration homelab.
# Active in test mode; see docs/PRIVACY_GATEWAY_VALIDATION.md for evidence.
{ config, lib, pkgs, ... }:
let
  n = import ../../lib/netv-network.nix;
  cfg = config.homelab.privacyGateway;
  endpoint = if cfg.endpointIPv4 == null then "0.0.0.0" else cfg.endpointIPv4;
  peerKey = if cfg.peerPublicKey == null then "" else cfg.peerPublicKey;
  interface = "wg-mullvad";
in
{
  options.homelab.privacyGateway = {
    enable = lib.mkEnableOption "the isolated guest privacy gateway";
    guestConfirmed = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Explicit confirmation that this module targets a dedicated VM, never the homelab host.";
    };
    endpointIPv4 = lib.mkOption {
      type = lib.types.nullOr (lib.types.strMatching "[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+");
      default = null;
      description = "Numeric Endpoint IPv4 from the owner's Mullvad profile; no DNS bootstrap outside VPN.";
    };
    endpointPort = lib.mkOption {
      type = lib.types.port;
      default = 51820;
    };
    peerPublicKey = lib.mkOption {
      type = lib.types.nullOr (lib.types.strMatching "[A-Za-z0-9+/]{43}=");
      default = null;
      description = "Mullvad SERVER public key. Never the private key.";
    };
    addresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Assigned WireGuard addresses, including prefix lengths, from the owner's profile.";
    };
    privateKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/privacy-gateway-secrets/mullvad-private-key";
      description = "Runtime root-owned 0600 file containing only the private key; never a Nix path literal.";
    };
    underlayInterface = lib.mkOption {
      type = lib.types.strMatching "[A-Za-z0-9_-]+";
      default = "eth0";
      description = "Guest uplink name, to be verified against the VM hardware configuration.";
    };
    mtu = lib.mkOption {
      type = lib.types.ints.between 1280 1420;
      default = 1420;
      description = "Mullvad underlay MTU; 1420 fits Tailscale encrypted packets over the verified 1500-byte guest uplink. Tailscale itself stays at 1280.";
    };
    bootstrapSSHAddress = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional QEMU user-network host address for loopback-only SSH bootstrap.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.guestConfirmed && config.networking.hostName == "privacy-gateway" && !config.boot.isContainer;
        message = "Privacy gateway must run in the explicitly confirmed dedicated privacy-gateway VM, never on homelab.";
      }
      {
        assertion = cfg.endpointIPv4 != null && cfg.peerPublicKey != null && cfg.addresses != [ ];
        message = "Provide the public Endpoint, server PublicKey and assigned Address metadata before building the gateway.";
      }
      {
        assertion = lib.hasPrefix "/var/lib/privacy-gateway-secrets/" cfg.privateKeyFile;
        message = "The private key must remain a runtime secret outside the Nix store.";
      }
      {
        assertion = !(config.virtualisation.docker.enable or false);
        message = "This VM is a dedicated network appliance, not an application Docker host.";
      }
    ];

    networking.hostName = "privacy-gateway";
    networking.useDHCP = false;
    networking.useNetworkd = true;
    networking.nameservers = [ "127.0.0.1" ];
    networking.resolvconf.enable = false;
    services.resolved.enable = false;
    # With both resolver managers disabled, nameservers alone does not create
    # this file. Tailscale's exit-node DNS proxy reads it directly.
    environment.etc."resolv.conf".text = "nameserver 127.0.0.1\n";
    systemd.network.enable = true;
    systemd.network.networks."10-underlay" = {
      matchConfig.Name = cfg.underlayInterface;
      matchConfig.MACAddress = "52:54:00:24:02:02";
      address = [ "${n.underlayGuest}/30" ];
      networkConfig = { DHCP = "no"; IPv6AcceptRA = false; LinkLocalAddressing = "no"; Gateway = n.underlayHost; };
    };
    systemd.network.networks."20-netv" = {
      matchConfig.MACAddress = "52:54:00:24:00:02";
      address = [ "${n.egressGuest}/28" ];
      networkConfig = { DHCP = "no"; IPv6AcceptRA = false; LinkLocalAddressing = "no"; };
    };

    # Native nft policy only: avoid implicit firewall/Tailscale chains changing
    # the forwarding contract. Forwarded Internet is NATed solely into Mullvad.
    networking.firewall.enable = false;
    networking.nftables.enable = true;
    networking.nftables.tables."privacy-gateway" = {
      family = "inet";
      content = ''
        chain input {
          type filter hook input priority filter; policy drop;
          ct state invalid drop
          iifname "lo" accept
          ct state established,related accept
          iifname "${cfg.underlayInterface}" udp sport 67 udp dport 68 accept
          ${lib.optionalString (cfg.bootstrapSSHAddress != null) ''iifname "${cfg.underlayInterface}" ip saddr ${cfg.bootstrapSSHAddress} tcp dport 22 accept''}
          iifname "${interface}" udp dport 41641 accept
          iifname "tailscale0" udp dport 53 accept
          iifname "tailscale0" tcp dport { 22, 53, 443 } accept
          iifname "tailscale0" meta l4proto { icmp, ipv6-icmp } accept
          iifname "apps0" ip saddr ${n.app} udp dport 53 accept
          iifname "apps0" ip saddr ${n.app} tcp dport 53 accept
        }
        chain output {
          type filter hook output priority filter; policy drop;
          oifname "lo" accept
          oifname "tailscale0" ct state established,related accept
          oifname "apps0" ip daddr ${n.app} ct state established,related accept
          # No generic established exception on underlay: a prior connection
          # must not become an accidental fallback if the tunnel disappears.
          oifname "${cfg.underlayInterface}" ip daddr ${endpoint} udp dport ${toString cfg.endpointPort} accept
          oifname "${cfg.underlayInterface}" udp sport 68 udp dport 67 accept
          ${lib.optionalString (cfg.bootstrapSSHAddress != null) ''oifname "${cfg.underlayInterface}" ip daddr ${cfg.bootstrapSSHAddress} tcp sport 22 ct state established accept''}
          oifname "${interface}" accept
        }
        chain forward {
          type filter hook forward priority filter; policy drop;
          ct state invalid drop
          iifname "apps0" ip saddr != ${n.app} drop
          iifname "apps0" ip daddr { 0.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 127.0.0.0/8, 169.254.0.0/16, 172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/4, 240.0.0.0/4 } drop
          iifname "apps0" oifname "${interface}" ip saddr ${n.app} accept
          iifname "${interface}" oifname "apps0" ip daddr ${n.app} ct state established,related accept
          # No routing into LAN, another tailnet node or non-public addresses.
          iifname "tailscale0" ip daddr { 0.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 127.0.0.0/8, 169.254.0.0/16, 172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/4, 240.0.0.0/4 } drop
          iifname "tailscale0" ip6 daddr { ::/128, ::1/128, fc00::/7, fe80::/10, ff00::/8 } drop
          iifname "tailscale0" oifname "${interface}" accept
          iifname "${interface}" oifname "tailscale0" ct state established,related accept
        }
        chain postrouting {
          type nat hook postrouting priority srcnat; policy accept;
          iifname "tailscale0" oifname "${interface}" masquerade
          iifname "apps0" oifname "${interface}" ip saddr ${n.app} masquerade
        }
      '';
    };
    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
      "net.ipv4.conf.all.rp_filter" = 0;
      "net.ipv4.conf.default.rp_filter" = 0;
      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.default.accept_redirects" = 0;
      "net.ipv6.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.all.send_redirects" = 0;
    };
    networking.wg-quick.interfaces.${interface} = {
      address = cfg.addresses;
      privateKeyFile = cfg.privateKeyFile;
      mtu = cfg.mtu;
      # Explicit priorities: wg-quick's automatic rule numbering depends on
      # whether tailscaled starts before it. Never let outer Tailscale traffic
      # escape via its marked main-table rule ahead of the Mullvad policy.
      table = "51820";
      # NixOS wraps postUp in a script: wg-quick does not substitute %i inside it.
      postUp = [ "${pkgs.wireguard-tools}/bin/wg set ${interface} fwmark 51820" ] ++
        lib.concatMap (route: [
          "${pkgs.iproute2}/bin/ip ${route.family} rule add priority 5000 to ${route.peerRange} lookup 52"
          "${pkgs.iproute2}/bin/ip ${route.family} rule add priority 5010 lookup main suppress_prefixlength 0"
          "${pkgs.iproute2}/bin/ip ${route.family} rule add priority 5020 not fwmark 51820 lookup 51820"
        ]) [
          { family = "-4"; peerRange = "100.64.0.0/10"; }
          { family = "-6"; peerRange = "fd7a:115c:a1e0::/48"; }
        ];
      preDown = lib.concatMap (route: [
        "${pkgs.iproute2}/bin/ip ${route.family} rule del priority 5000 to ${route.peerRange} lookup 52"
        "${pkgs.iproute2}/bin/ip ${route.family} rule del priority 5010 lookup main suppress_prefixlength 0"
        "${pkgs.iproute2}/bin/ip ${route.family} rule del priority 5020 not fwmark 51820 lookup 51820"
      ]) [
        { family = "-4"; peerRange = "100.64.0.0/10"; }
        { family = "-6"; peerRange = "fd7a:115c:a1e0::/48"; }
      ];
      # Keep the system resolver on AdGuard, not DNS from the imported profile.
      dns = [ ];
      peers = [ {
        publicKey = peerKey;
        endpoint = "${endpoint}:${toString cfg.endpointPort}";
        allowedIPs = [ "0.0.0.0/0" "::/0" ];
        persistentKeepalive = 25;
      } ];
    };
    systemd.services."wg-quick-${interface}" = {
      requires = [ "nftables.service" ];
      after = [ "nftables.service" ];
      preStart = ''
        # Check metadata only. Never print or parse the secret into a log.
        test -f ${lib.escapeShellArg cfg.privateKeyFile}
        test "$(${pkgs.coreutils}/bin/stat -c '%u:%a' ${lib.escapeShellArg cfg.privateKeyFile})" = "0:600"
      '';
      serviceConfig.Restart = "on-failure";
      serviceConfig.RestartSec = "15s";
    };
    systemd.tmpfiles.rules = [ "d /var/lib/privacy-gateway-secrets 0700 root root -" ];

    services.adguardhome = {
      enable = true;
      openFirewall = false;
      allowDHCP = false;
      host = "127.0.0.1";
      port = 3000;
      mutableSettings = false;
      settings = {
        # The UI stays loopback-only until authenticated private HTTPS is set
        # up; no users/password hashes are stored in the public configuration.
        dns = {
          bind_hosts = [ "0.0.0.0" "::" ];
          port = 53;
          upstream_dns = [ "10.64.0.1" ];
          bootstrap_dns = [ "10.64.0.1" ];
          fallback_dns = [ ];
          use_private_ptr_resolvers = false;
          ratelimit = 50;
          refuse_any = true;
          cache_size = 4194304;
        };
        dhcp.enabled = false;
        querylog = { enabled = false; file_enabled = false; };
        statistics.enabled = false;
        filtering = { protection_enabled = true; filtering_enabled = true; };
        # Start without an unreviewed remote blocklist: add one explicitly
        # after successful routing/IPTV validation and document exceptions.
        filters = [ ];
      };
    };
    systemd.services.adguardhome = {
      requires = [ "nftables.service" ];
      after = [ "nftables.service" ];
    };

    services.tailscale = {
      enable = true;
      openFirewall = false;
      useRoutingFeatures = "server";
      # No auto-registration secret in the derivation. Registration is a
      # separate operator step; Serve and exit approval are also explicit.
      extraSetFlags = [ "--accept-dns=false" "--accept-routes=false" "--netfilter-mode=off" "--advertise-exit-node" ];
    };
    systemd.services.tailscaled = {
      requires = [ "nftables.service" ];
      after = [ "nftables.service" ];
    };
    services.openssh = {
      enable = true;
      openFirewall = false;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        AllowTcpForwarding = "no";
        AllowAgentForwarding = false;
        X11Forwarding = false;
      };
    };
    # Provision administrator keys/accounts in the guest hardware/profile
    # module. No fallback password, autologin or root SSH is introduced here.
    services.journald.extraConfig = ''
      SystemMaxUse=128M
      RuntimeMaxUse=32M
      MaxRetentionSec=7day
    '';
    environment.systemPackages = [ pkgs.wireguard-tools pkgs.nftables pkgs.iproute2 pkgs.dig ];
  };
}
