{ ... }:

{
  # Les journaux restent disponibles après redémarrage, sans pouvoir
  # occuper indéfiniment le disque système.
  services.journald = {
    storage = "persistent";
    extraConfig = ''
      SystemMaxUse=512M
      SystemKeepFree=2G
      MaxRetentionSec=1month
      Compress=yes
    '';
  };

  # Audit local des changements de configuration sensibles. Le mode
  # "printk" préserve la disponibilité de la machine en cas d'incident
  # du sous-système d'audit.
  security.audit = {
    enable = true;
    failureMode = "printk";
    backlogLimit = 8192;
    rules = [
      "-w /etc/nixos -p wa -k nixos-configuration"
      "-w /etc/ssh -p wa -k ssh-configuration"
      "-w /var/lib/sbctl -p wa -k secure-boot-keys"
    ];
  };

  security.auditd = {
    enable = true;
    settings = {
      max_log_file = 50;
      num_logs = 10;
      max_log_file_action = "ROTATE";
      space_left = "5%";
      space_left_action = "SYSLOG";
      admin_space_left = "2%";
      admin_space_left_action = "SYSLOG";
      disk_full_action = "SUSPEND";
      disk_error_action = "SUSPEND";
    };
  };
}
