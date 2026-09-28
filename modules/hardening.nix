{ ... }:

{
  # AppArmor / LSM
  security.apparmor.enable = true;

  # Nécessaire pour Nix sandbox et futurs conteneurs rootless.
  security.allowUserNamespaces = true;

  # Empêche le remplacement du kernel en cours d'exécution via kexec
  # et désactive l'hibernation.
  security.protectKernelImage = true;

  # Ne pas conserver de core dumps pouvant contenir des secrets.
  systemd.coredump.settings.Coredump = {
    Storage = "none";
    ProcessSizeMax = 0;
  };

  boot.kernel.sysctl = {
    # Mémoire / informations kernel
    "kernel.randomize_va_space" = 2;
    "kernel.kptr_restrict" = 2;
    "kernel.dmesg_restrict" = 1;
    "kernel.yama.ptrace_scope" = 1;
    "kernel.unprivileged_bpf_disabled" = 1;
    "kernel.perf_event_paranoid" = 3;
    "kernel.sysrq" = 0;

    # Pas de core dump pour les programmes SUID
    "fs.suid_dumpable" = 0;

    # Protections filesystem
    "fs.protected_fifos" = 2;
    "fs.protected_regular" = 2;
    "fs.protected_hardlinks" = 1;
    "fs.protected_symlinks" = 1;

    # IPv4
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.secure_redirects" = 0;
    "net.ipv4.conf.default.secure_redirects" = 0;

    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;

    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;

    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;

    "net.ipv4.tcp_syncookies" = 1;

    # IPv6
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;
    "net.ipv6.conf.all.accept_source_route" = 0;
    "net.ipv6.conf.default.accept_source_route" = 0;
  };
}
