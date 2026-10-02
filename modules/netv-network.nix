{ config, lib, pkgs, ... }:
let
  n = import ../lib/netv-network.nix;
  appSet = "{ " + lib.concatStringsSep ", " (map (app: app.address) n.vpnApps) + " }";
in
{
  # Dedicated forwarding contract; a lost route must never fall back to WAN.
  networking.nftables.tables.netv-isolation = {
    family = "inet";
    content = ''
      chain input {
        type filter hook input priority -10; policy accept;
        iifname "${n.egressBridge}" drop
        iifname "${n.underlayBridge}" ct state established,related accept
        iifname "${n.underlayBridge}" drop
      }
      chain forward {
        type filter hook forward priority -10; policy accept;
        iifname "${n.egressBridge}" ip daddr ${appSet} ct state established,related accept
        iifname "${n.egressBridge}" ip saddr != ${appSet} drop
        iifname "${n.egressBridge}" ip daddr ${n.egressGuest} udp dport 53 accept
        iifname "${n.egressBridge}" ip daddr ${n.egressGuest} tcp dport 53 accept
        iifname "${n.egressBridge}" udp dport { 53, 853 } drop
        iifname "${n.egressBridge}" tcp dport { 53, 853 } drop
        iifname "${n.egressBridge}" ip daddr { 0.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 127.0.0.0/8, 169.254.0.0/16, 172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/4, 240.0.0.0/4 } drop
        iifname "${n.egressBridge}" oifname != "${n.egressBridge}" drop
        iifname "${n.egressBridge}" meta nfproto ipv6 drop
        iifname "${n.underlayBridge}" ip saddr ${n.underlayGuest} ip daddr ${n.endpoint} udp dport ${toString n.endpointPort} accept
        iifname "${n.underlayBridge}" drop
        oifname "${n.underlayBridge}" ip daddr ${n.underlayGuest} ct state established,related accept
        oifname "${n.underlayBridge}" drop
      }
      chain postrouting {
        type nat hook postrouting priority 99; policy accept;
        ip saddr ${n.underlayGuest} ip daddr ${n.endpoint} udp dport ${toString n.endpointPort} masquerade
      }
    '';
  };
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
  };
  systemd.services.netv-private-network = {
    description = "Private TAP links and fail-closed NetV policy routing";
    requires = [ "docker.service" "docker-lan-guard.service" "nftables.service" ];
    after = [ "docker.service" "docker-lan-guard.service" "nftables.service" ];
    before = [ "privacy-gateway-vm.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.docker pkgs.iproute2 pkgs.jq pkgs.iptables ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
    script = ''
      set -eu
      ensure_network() {
        name="$1"; subnet="$2"; internal="$3"
        if ! docker network inspect "$name" >/dev/null 2>&1; then
          if [ "$internal" = true ]; then
            docker network create --internal --subnet "$subnet" "$name" >/dev/null
          else
            docker network create --subnet "$subnet" --gateway ${n.egressHost} \
              --aux-address privacy-gateway=${n.egressGuest} \
              --opt com.docker.network.bridge.name=${n.egressBridge} \
              --opt com.docker.network.bridge.enable_ip_masquerade=false "$name" >/dev/null
          fi
        fi
        docker network inspect "$name" | jq -e --arg subnet "$subnet" --argjson internal "$internal" \
          '.[0] | .Driver == "bridge" and .Internal == $internal and .EnableIPv6 == false and .IPAM.Config[0].Subnet == $subnet' >/dev/null
      }
      ensure_network netv-ingress ${n.ingressSubnet} true
      ensure_network media-ingress ${n.mediaIngressSubnet} true
      ensure_network netv-egress ${n.egressSubnet} false
      docker network inspect netv-egress | jq -e \
        '.[0] | .Options["com.docker.network.bridge.name"] == "${n.egressBridge}" and .Options["com.docker.network.bridge.enable_ip_masquerade"] == "false" and .IPAM.Config[0].Gateway == "${n.egressHost}" and .IPAM.Config[0].AuxiliaryAddresses["privacy-gateway"] == "${n.egressGuest}"' >/dev/null
      ip link show ${n.underlayBridge} >/dev/null 2>&1 || ip link add ${n.underlayBridge} type bridge
      ip address replace ${n.underlayHost}/30 dev ${n.underlayBridge}
      ip link set ${n.underlayBridge} up
      # Docker's FORWARD default is DROP. Permit only the guest WireGuard
      # underlay, not a general trusted-bridge exception. nft is stricter too.
      iptables -w -N NETV-VM-TRANSIT 2>/dev/null || true
      iptables -w -F NETV-VM-TRANSIT
      iptables -w -A NETV-VM-TRANSIT -i ${n.underlayBridge} -s ${n.underlayGuest} -d ${n.endpoint} -p udp --dport ${toString n.endpointPort} -j ACCEPT
      iptables -w -A NETV-VM-TRANSIT -o ${n.underlayBridge} -d ${n.underlayGuest} -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
      iptables -w -A NETV-VM-TRANSIT -j RETURN
      iptables -w -C DOCKER-USER -j NETV-VM-TRANSIT 2>/dev/null || iptables -w -I DOCKER-USER 1 -j NETV-VM-TRANSIT
      for pair in '${n.underlayTap} ${n.underlayBridge}' '${n.egressTap} ${n.egressBridge}'; do
        set -- $pair
        ip link show "$1" >/dev/null 2>&1 || ip tuntap add dev "$1" mode tap user privacy-gateway-vm
        ip link set "$1" master "$2"
        ip link set "$1" up
      done
      ip route replace default via ${n.egressGuest} dev ${n.egressBridge} table ${n.routeTable}
      # An identical rule may remain after a test activation; never accumulate it.
      ${lib.concatMapStringsSep "\n" (app: ''
      if ! ip -4 rule show | ${pkgs.gnugrep}/bin/grep -q '^${app.priority}:.*from ${app.address} lookup ${n.routeTable}$'; then
        if ip -4 rule show | ${pkgs.gnugrep}/bin/grep -q '^${app.priority}:'; then
          echo 'Policy priority ${app.priority} already owned; refusing to overwrite it' >&2; exit 1
        fi
        ip -4 rule add priority ${app.priority} from ${app.address}/32 lookup ${n.routeTable}
      fi
      '') n.vpnApps}
    '';
    # Deliberately retain private links on stop: there is no fallback route and
    # deleting a Docker network with active endpoints would be destructive.
  };
  # Reapply TAP attachment and the narrow transit chain after daemon restart.
  systemd.services.docker.postStart = ''
    ${pkgs.systemd}/bin/systemctl --no-block restart netv-private-network.service
  '';
  systemd.services.privacy-gateway-vm = {
    requires = [ "netv-private-network.service" ];
    after = [ "netv-private-network.service" ];
    serviceConfig.DeviceAllow = [ "/dev/net/tun rw" ];
  };
  systemd.services.privacy-gateway-bootstrap-relay = {
    description = "Preserve the loopback-only SSH bootstrap endpoint after TAP migration";
    requires = [ "netv-private-network.service" ];
    after = [ "netv-private-network.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.socat}/bin/socat TCP4-LISTEN:2222,bind=127.0.0.1,reuseaddr,fork TCP4:${n.underlayGuest}:22";
      DynamicUser = true;
      Restart = "on-failure";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      CapabilityBoundingSet = "";
      RestrictAddressFamilies = [ "AF_INET" ];
    };
  };
}
