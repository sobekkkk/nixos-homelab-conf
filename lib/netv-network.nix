# Public addresses shared by the host and the dedicated guest. No secrets.
{
  underlayBridge = "br-pgw";
  underlayTap = "pgw-uplink";
  underlayHost = "172.30.242.1";
  underlayGuest = "172.30.242.2";
  underlaySubnet = "172.30.242.0/30";
  egressBridge = "br-netve";
  egressTap = "pgw-netv";
  egressHost = "172.30.240.1";
  egressGuest = "172.30.240.2";
  app = "172.30.240.10";
  # Explicit migration allowlist; never authorize the whole Docker subnet.
  vpnApps = [
    { name = "netv"; address = "172.30.240.10"; priority = "4900"; }
    { name = "dispatcharr"; address = "172.30.240.11"; priority = "4901"; }
    { name = "jellyfin"; address = "172.30.240.12"; priority = "4902"; }
    { name = "dispatcharr-worker"; address = "172.30.240.13"; priority = "4903"; }
  ];
  mediaIngressSubnet = "172.30.243.0/28";
  egressSubnet = "172.30.240.0/28";
  ingressSubnet = "172.30.241.0/28";
  routeTable = "203";
  rulePriority = "4900";
  endpoint = "185.213.155.73";
  endpointPort = 51820;
}
