# Public routing metadata supplied by the owner on 2026-10-02 (Secure Salmon).
# Contains no private key and does not enable or deploy the gateway.
{ ... }:
{
  homelab.privacyGateway = {
    endpointIPv4 = "185.213.155.73";
    endpointPort = 51820;
    peerPublicKey = "HQHCrq4J6bSpdW1fI5hR/bvcrYa6HgGgwaa5ZY749ik=";
    addresses = [ "10.71.68.210/32" "fc00:bbbb:bbbb:bb01::8:44d1/128" ];
  };
}
