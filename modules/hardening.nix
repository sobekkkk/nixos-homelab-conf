

{ ... }:

{
  # Mandatory Access Control
  security.apparmor.enable = true;

  # Durcissement kernel / réseau
  boot.kernel.sysctl = {
    # Empêche les utilisateurs non privilégiés de lire les adresses kernel
    "kernel.kptr_restrict" = 2;

    # Restreint l'accès à dmesg
    "kernel.dmesg_restrict" = 1;

    # Restreint ptrace aux processus descendants
    "kernel.yama.ptrace_scope" = 1;

    # Interdit eBPF non privilégié
    "kernel.unprivileged_bpf_disabled" = 1;

    # Limite l'accès aux compteurs de performance kernel
    "kernel.perf_event_paranoid" = 3;

    # Désactive SysRq
    "kernel.sysrq" = 0;

    # Protections filesystem
    "fs.protected_fifos" = 2;
    "fs.protected_regular" = 2;
    "fs.protected_hardlinks" = 1;
    "fs.protected_symlinks" = 1;

    # Refuse les ICMP redirects IPv4
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;

    # Ne génère pas d'ICMP redirects
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;

    # Refuse le source routing
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;

    # Protection SYN flood
    "net.ipv4.tcp_syncookies" = 1;

    # IPv6 : pas de redirects ni source routing
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;
    "net.ipv6.conf.all.accept_source_route" = 0;
    "net.ipv6.conf.default.accept_source_route" = 0;
  };

}
