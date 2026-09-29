{ config, pkgs, ... }:

let
  snapshotDirectory = "/var/lib/homelab-security-snapshot";
in
{
  # The audit operator receives read access to a curated snapshot, not sudo or
  # Docker-socket access. The files remain root-owned and are retained briefly.
  users.groups.homelab-audit = { };
  users.users.sobek.extraGroups = [ "homelab-audit" ];

  systemd.tmpfiles.rules = [
    "d ${snapshotDirectory} 0750 root homelab-audit 14d"
  ];

  systemd.services.homelab-security-snapshot = {
    description = "Create a read-only security evidence snapshot for the audit operator";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "root";
      UMask = "0027";
    };
    path = [
      pkgs.audit
      pkgs.coreutils
      pkgs.cryptsetup
      config.virtualisation.docker.package
      pkgs.iptables
      pkgs.nftables
      pkgs.sbctl
    ];
    script = ''
      set -eu
      umask 0027

      install -d -m 0750 -o root -g homelab-audit "${snapshotDirectory}"
      snapshot="$(date -u +%Y%m%dT%H%M%SZ)"
      work="$(mktemp -d "${snapshotDirectory}/.''${snapshot}.XXXXXX")"

      capture() {
        name="$1"
        shift
        "$@" > "$work/$name.txt" 2>&1 || true
      }

      printf 'generated_at=%s\n' "$(date -u --iso-8601=seconds)" > "$work/metadata.txt"
      printf 'collector=homelab-security-snapshot\n' >> "$work/metadata.txt"

      capture services systemctl --no-pager --type=service --state=running
      capture sockets /run/current-system/sw/bin/ss -lntup
      capture nftables nft list ruleset
      capture docker-user-ipv4 iptables -S DOCKER-USER
      capture docker-user-ipv6 ip6tables -S DOCKER-USER
      capture ssh-effective /run/current-system/sw/bin/sshd -T
      capture audit-rules auditctl -l
      # aa-status peut refuser l'énumération selon les permissions de l'ABI
      # AppArmor. Conserver aussi les deux sources noyau permet de distinguer
      # un outil limité d'une absence de profils appliqués.
      capture lsm cat /sys/kernel/security/lsm
      capture apparmor-status /run/current-system/sw/bin/aa-status
      capture apparmor-profiles cat /sys/kernel/security/apparmor/profiles
      capture secure-boot sbctl status
      capture boot bootctl status
      capture luks cryptsetup status cryptroot
      capture docker-version docker version
      capture docker-info docker info
      docker ps -a --no-trunc --format 'table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}\t{{.Names}}' > "$work/docker-containers.txt" 2>&1 || true
      {
        docker ps -aq | while read -r container; do
          docker inspect --format 'id={{.Id}} name={{.Name}} image={{.Config.Image}} privileged={{.HostConfig.Privileged}} readonlyRootfs={{.HostConfig.ReadonlyRootfs}} capAdd={{json .HostConfig.CapAdd}} capDrop={{json .HostConfig.CapDrop}} mounts={{json .Mounts}} networks={{json .NetworkSettings.Networks}}' "$container"
        done
      } > "$work/docker-runtime.txt" 2>&1 || true

      chmod 0750 "$work"
      chmod 0640 "$work"/*.txt
      chown root:homelab-audit "$work" "$work"/*.txt
      mv "$work" "${snapshotDirectory}/$snapshot"
      ln -sfn "$snapshot" "${snapshotDirectory}/latest"
    '';
  };

  systemd.timers.homelab-security-snapshot = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "15m";
    };
  };
}
