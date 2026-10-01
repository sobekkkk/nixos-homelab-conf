# Public routing metadata supplied by the owner on 2026-10-01.
# Contains no private key and does not enable or deploy the gateway.
{ ... }:
{
  homelab.privacyGateway = {
    endpointIPv4 = "138.199.6.207";
    endpointPort = 51820;
    peerPublicKey = "7VCMEE+Oljm/qKfQJSUCOYPtRSwdOnuPyqo5Vob+GRY=";
    addresses = [ "10.74.48.214/32" "fc00:bbbb:bbbb:bb01::b:30d5/128" ];
  };
}
