---------------------------------------------------------------------------
-- Snort 3 configuration — gw / Phase 1: vlan-hosted
--
-- HOME_NET : 217.169.25.8/29 + 2001:8b0:bd9:106::/64
-- Interface: vlan-hosted (passive via AF_PACKET — set on CLI)
-- Rules    : ET Open, managed by snort-update-rules.service
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Network variables
---------------------------------------------------------------------------

HOME_NET     = '217.169.25.8/29,2001:8b0:bd9:106::/64'
EXTERNAL_NET = '!$HOME_NET'

-- All hosted services sit in HOME_NET
HTTP_SERVERS   = '$HOME_NET'
SMTP_SERVERS   = '$HOME_NET'
SQL_SERVERS    = '$HOME_NET'
DNS_SERVERS    = '$HOME_NET'
TELNET_SERVERS = '$HOME_NET'
SSH_SERVERS    = '$HOME_NET'
FTP_SERVERS    = '$HOME_NET'
SIP_SERVERS    = '$HOME_NET'

-- Port variables expected by ET Open rules
HTTP_PORTS      = '80,443,8080,8443'
SHELLCODE_PORTS = '!80'
ORACLE_PORTS    = '1521'
SSH_PORTS       = '22'
FTP_PORTS       = '21,2100,3535'
SIP_PORTS       = '5060,5061,5600'
FILE_DATA_PORTS = '$HTTP_PORTS'
GTP_PORTS       = '2123,2152,3386'

---------------------------------------------------------------------------
-- Stream reassembly and protocol inspection
-- Required for ET Open rules to match payload content correctly
---------------------------------------------------------------------------

stream = {}

stream_tcp = {
    policy          = 'os-policy-default',
    session_timeout = 30,
}

stream_udp = {
    session_timeout = 30,
}

stream_icmp = {
    session_timeout = 30,
}

-- HTTP normalisation and inspection (web_server, web_client rules)
http_inspect = {}

-- FTP/Telnet inspection
ftp_telnet = {}

-- SMTP decode (smtp rules, malware-in-mail detection)
smtp = {
    decode_mime = true,
}

-- SSH version/traffic analysis
ssh = {}

-- DNS response inspection
dns = {}

-- TLS/SSL metadata inspection (JA3, certificate-based rules)
ssl = {}

-- SIP inspection
sip = {}

---------------------------------------------------------------------------
-- IPS engine
---------------------------------------------------------------------------

ips = {
    enable_builtin_rules = true,
    variables            = default_variables,
    -- snort-update-rules.service writes ET Open includes here
    rules = [[
        include /var/lib/snort/rules/snort.rules
    ]],
}

---------------------------------------------------------------------------
-- Alert output
-- JSON alerts land at /var/log/snort/alert_json.txt
-- Alloy tails this file and ships to Loki
---------------------------------------------------------------------------

alert_json = {
    file  = true,
    limit = 100,    -- MB before rotation
    fields = 'seconds action class b64_data dir dst_addr dst_ap dst_port eth_dst eth_len eth_src eth_type gid icmp_code icmp_id icmp_seq icmp_type iface ip_id ip_len msg mpls pkt_gen pkt_len pkt_num priority proto rev rule service sid src_addr src_ap src_port target timestamp tos ttl udp_len vlan',
}

---------------------------------------------------------------------------
-- Suppress list
-- Add false-positive SIDs here after the initial observation period.
--
-- Example:
--   { gid = 1, sid = 2100498, track = 'by_dst', ip = '217.169.25.9' }
--
-- Phase 2 note: when expanding to vlan-private/public/lab, add suppressions
-- for expected inter-VLAN traffic patterns (e.g. Alloy scraping, DHCP noise).
---------------------------------------------------------------------------

suppress = {}
