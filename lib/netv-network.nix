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
  egressSubnet = "172.30.240.0/28";
  ingressSubnet = "172.30.241.0/28";
  routeTable = "203";
  rulePriority = "4900";
  endpoint = "138.199.6.207";
  endpointPort = 51820;
}
