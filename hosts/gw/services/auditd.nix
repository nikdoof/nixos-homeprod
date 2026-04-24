_: {
  # Kernel audit subsystem is enabled automatically by security.auditd.
  security.auditd.enable = true;

  # Forward every audit event to syslog — journald picks it up, and the shared
  # Alloy journal pipeline (server.nix) ships it to Loki with a host label.
  # audit.log remains at /var/log/audit/audit.log for local forensics.
  security.auditd.plugins.syslog.active = true;

  security.auditd.settings = {
    # Rotate at 20 MiB, keep 5 rotations (~100 MiB of local audit history).
    max_log_file = 20;
    num_logs = 5;
    max_log_file_action = "ROTATE";

    # Don't halt the router if the audit partition fills up — Loki has the
    # events regardless, and a router that stops forwarding traffic is worse
    # than one that has lost local audit history.
    space_left_action = "SYSLOG";
    admin_space_left_action = "SYSLOG";
    disk_full_action = "SYSLOG";
    disk_error_action = "SYSLOG";

    # ENRICHED resolves uid/gid to names and decodes hex fields inline.
    log_format = "ENRICHED";
  };

  # CIS 4.1 — minimal ruleset appropriate for a border router.
  # Keys (-k ...) surface in audit events as key=<value> for later filtering.
  security.audit.rules = [
    # 4.1.3 Time / clock changes
    "-a always,exit -F arch=b64 -S adjtimex,settimeofday,clock_settime -k time-change"
    "-w /etc/localtime -p wa -k time-change"

    # 4.1.4 User / group identity changes
    "-w /etc/group -p wa -k identity"
    "-w /etc/passwd -p wa -k identity"
    "-w /etc/shadow -p wa -k identity"
    "-w /etc/gshadow -p wa -k identity"
    "-w /etc/security/opasswd -p wa -k identity"

    # 4.1.5 Network environment
    "-a always,exit -F arch=b64 -S sethostname,setdomainname -k system-locale"
    "-w /etc/hosts -p wa -k system-locale"

    # 4.1.10 Privileged scope / sshd config
    "-w /etc/sudoers -p wa -k scope"
    "-w /etc/sudoers.d -p wa -k scope"
    "-w /etc/ssh/sshd_config -p wa -k sshd_config"

    # 4.1.7 / 4.1.8 Login, logout, session records
    "-w /var/log/faillog -p wa -k logins"
    "-w /var/log/lastlog -p wa -k logins"
    "-w /var/run/utmp -p wa -k session"
    "-w /var/log/wtmp -p wa -k logins"
    "-w /var/log/btmp -p wa -k logins"

    # 4.1.12 DAC permission changes by interactive users (auid>=1000)
    "-a always,exit -F arch=b64 -S chmod,fchmod,fchmodat -F auid>=1000 -F auid!=-1 -k perm_mod"
    "-a always,exit -F arch=b64 -S chown,fchown,fchownat,lchown -F auid>=1000 -F auid!=-1 -k perm_mod"

    # 4.1.14 Filesystem mounts by interactive users
    "-a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=-1 -k mounts"

    # 4.1.16 Kernel module load/unload — syscall-level so it catches every path
    "-a always,exit -F arch=b64 -S init_module,delete_module,finit_module -k modules"

    # Router-specific: resolver and nsswitch changes
    "-w /etc/resolv.conf -p wa -k resolv_conf"
    "-w /etc/nsswitch.conf -p wa -k nsswitch"
  ];
}
