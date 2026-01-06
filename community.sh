#!/bin/bash
<<<<<<< HEAD
# Prompt user for subscription ID
read -p "Enter your Azure Subscription ID: " subscriptionId
az account set --subscription "$subscriptionId"
=======


# Pre-Requisite
# Check if virtual wan extension is installed if not install it
if ! az extension list | grep -q virtual-wan; then
    echo "virtual-wan extension is not installed, installing it now..."
    az extension add --name virtual-wan --only-show-errors
fi
# Check if ssh extension is installed if not install it
if ! az extension list | grep -q '"name": "ssh"'; then
     echo "SSH extension not found. Installing..."
     az extension add --name ssh
fi
# Check if bastion extension is installed if not install it
if ! az extension list | grep -q '"name": "bastion"'; then
     echo "Bastion extension not found. Installing..."
     az extension add --name bastion
fi

resourceGroup="CommunityRG"
location="eastus2"
vwanName="Vwan"
vhubName="Vhub"
vhubAddressPrefix="10.200.0.0/24"
vpnGatewayName="VpnGateway"
erGatewayName="ErGateway"
NVAvnetName="NVA-VNET"
branchvnet="branch1-Vnet"
vnet1="Spoke-VNET1"
vnet2="Spoke-VNET2"

#Create RG
az group create --name $resourceGroup --location $location
echo Creating vwan ..
# Create a Virtual WAN     
az network vwan create --resource-group $resourceGroup --name $vwanName --location $location
# Create a Virtual WAN Hub
az network vhub create --resource-group $resourceGroup --name $vhubName --address-prefix $vhubAddressPrefix --vwan $vwanName --location $location
# Create an ExpressRoute Gateway in the Virtual WAN Hub
az network express-route gateway create --name $erGatewayName --resource-group $resourceGroup --location $location --virtual-hub $vhubName --min-val 1 --max-val 1

echo Creating NVA VNET 
# Create a Virtual Network and Subnets for the NVA/SDWAN
az network vnet create --resource-group $resourceGroup --name $NVAvnetName --location $location --address-prefixes 10.50.0.0/24 --subnet-name NVAsubnet  --subnet-prefix 10.50.0.0/27 
az network vnet subnet create --address-prefix 10.50.0.64/26 --name AzureBastionSubnet --resource-group $resourceGroup --vnet-name $NVAvnetName

echo Creating Branch VNET 
#branch1
az network vnet create --resource-group $resourceGroup --name $branchvnet --location $location --address-prefixes 192.168.0.0/24 --subnet-name Subnet-1 --subnet-prefix 192.168.0.0/27 
az network vnet subnet create --address-prefix 192.168.0.32/27 --name GatewaySubnet --resource-group $resourceGroup --vnet-name $branchvnet
az network vnet subnet create --address-prefix 192.168.0.64/26 --name AzureBastionSubnet --resource-group $resourceGroup --vnet-name $branchvnet

echo Creating Spoke-VNET1 
#spoke-VNET1
az network vnet create --resource-group $resourceGroup --name $vnet1 --location $location --address-prefixes 10.1.0.0/24 --subnet-name Subnet-1 --subnet-prefix 10.1.0.0/27 
az network vnet subnet create --address-prefix 10.1.0.64/26 --name AzureBastionSubnet --resource-group $resourceGroup --vnet-name $vnet1

echo Create a Spoke-VNET2
#Spoke-VNET2
az network vnet create --resource-group $resourceGroup --name $vnet2 --location $location --address-prefixes 172.16.0.0/24 --subnet-name Subnet-1 --subnet-prefix 172.16.0.0/27 

echo Create peering between NVA-VNET and Spoke-VNET2
#peering between NVA VNET and Spoke-VNET2
az network vnet peering create --name NVAtoSpoke-VNET2 --resource-group $resourceGroup --vnet-name $NVAvnetName --remote-vnet $vnet2 --allow-vnet-access --allow-forwarded-traffic
az network vnet peering create  --name Spoke-VNET2toNVA --resource-group $resourceGroup --vnet-name $vnet2 --remote-vnet $NVAvnetName --allow-vnet-access --allow-forwarded-traffic



echo Creating Branch VMs...
#VM-Branch1
az network nic create --resource-group $resourceGroup -n branch1-VMNIC --location $location --subnet Subnet-1 --private-ip-address 192.168.0.4 --vnet-name $branchvnet
az vm create -n branch1-VM -g $resourceGroup --image Ubuntu2204 --admin-username azureuser --admin-password Community123 --size Standard_B1ls --location $location --private-ip-address 192.168.0.4 --nics branch1-VMNIC

echo Create Bastion Host for Branch VNET
#Bastion Branch1
az network public-ip create --name branch1bastionpublicIP --resource-group $resourceGroup --location $location --allocation-method static 
az network bastion create --name branch1bastionHost --resource-group $resourceGroup --vnet-name $branchvnet --location $location --public-ip-address branch1bastionpublicIP --sku Standard --enable-tunneling
echo Create Bastion Host for Spoke-VNET1
#Create Bastion for spoke-VNET1
az network public-ip create --name vnet1bastionpublicIP --resource-group $resourceGroup --location $location --allocation-method static 
az network bastion create --name vnet1bastionHost --resource-group $resourceGroup --vnet-name $vnet1 --location $location --public-ip-address vnet1bastionpublicIP --sku Standard --enable-tunneling

echo Creating Spoke-VNET1 VM...
#VM-Spoke-VNET1
az network nic create --resource-group $resourceGroup -n VM1NIC --location $location --subnet Subnet-1 --private-ip-address 10.1.0.4 --vnet-name Spoke-VNET1
az vm create -n VM1 -g $resourceGroup --image Ubuntu2204 --admin-username azureuser --admin-password Community123 --size Standard_B1ls --location $location --private-ip-address 10.1.0.4 --nics VM1NIC

echo Creating Spoke-VNET2 VM...
#VM-Spoke-VNET2
az network nic create --resource-group $resourceGroup -n VM2NIC --location $location --subnet Subnet-1 --private-ip-address 172.16.0.4 --vnet-name Spoke-VNET2
az vm create -n VM2 -g $resourceGroup --image Ubuntu2204 --admin-username azureuser --admin-password Community123 --size Standard_B1ls --location $location --private-ip-address 172.16.0.4 --nics VM2NIC

echo "Creating UDR on Spoke-VNET2"
# Create a route table for Spoke-VNET2
az network route-table create --name SpokeVNET2-UDR --resource-group $resourceGroup --location $location

# Add a route to the route table (example: route all traffic to NVA LB IP)
az network route-table route create --resource-group $resourceGroup --route-table-name SpokeVNET2-UDR --name ToNVA --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address 10.50.0.10

# Associate the route table with Spoke-VNET2's subnet
az network vnet subnet update --resource-group $resourceGroup --vnet-name $vnet2 --name Subnet-1 --route-table SpokeVNET2-UDR

echo Creating VPN Gateway in the Branch VNET
#VPN GW branch1
az network public-ip create --name branch1-VNGpubip --resource-group $resourceGroup --allocation-method static --location $location
az network vnet-gateway create --name branch1-VNG --public-ip-address branch1-VNGpubip --resource-group $resourceGroup --vnet $branchvnet --gateway-type Vpn --vpn-type RouteBased --sku VpnGw1 --asn 65001 --bgp-peering-address 192.168.0.36 --location $location

echo Checking Vhub provisioning status...
# Checking Vhub provisioning and routing state
prState=''
rtState=''
while [[ $prState != 'Succeeded' ]];
do
    prState=$(az network vhub show -g $resourceGroup -n $vhubName --query 'provisioningState' -o tsv)
    echo "$hub1name provisioningState="$prState
    sleep 5
done

while [[ $rtState != 'Provisioned' ]];
do
    rtState=$(az network vhub show -g $resourceGroup -n $vhubName --query 'routingState' -o tsv)
    echo "$hub1name routingState="$rtState
    sleep 5
done

echo Creating Vhub VPN Gateway
# Create a VPN Gateway in the Virtual WAN Hub
az network vpn-gateway create --resource-group $resourceGroup --location $location --name $vpnGatewayName --vhub $vhubName --scale-unit 1

echo Creating connection between Spoke VNET1 and VHub
# Create a connection between Spoke VNET1 and VHub
az network vhub connection create --resource-group $resourceGroup --name VNET1-conn --vhub-name $vhubName --remote-vnet Spoke-VNET1
echo Creating connection between NVA VNET and VHub
# Create a connection between NVA VNET and VHub
az network vhub connection create --resource-group $resourceGroup --name NVA-conn --vhub-name $vhubName --remote-vnet $NVAvnetName

echo connection status
prState=''
while [[ $prState != 'Succeeded' ]];
do
    prState=$(az network vhub connection show -n VNET1-conn --vhub-name $vhubName -g $resourceGroup  --query 'provisioningState' -o tsv)
    echo "vnet connection vnet1conn provisioningState="$prState
    sleep 5
done
prState=''
while [[ $prState != 'Succeeded' ]];
do
    prState=$(az network vhub connection show -n NVA-conn --vhub-name $vhubName -g $resourceGroup  --query 'provisioningState' -o tsv)
    echo "vnet connection nvaconn provisioningState="$prState
    sleep 5
done

echo Create two instances of Cisco 8KV
#NVA/SDWAN
az network public-ip create --name NVA1PublicIP --resource-group $resourceGroup --idle-timeout 30 --allocation-method Static --location $location
az network nic create --name NVA1NIC -g $resourceGroup --subnet NVAsubnet --vnet $NVAvnetName --public-ip-address NVA1PublicIP --ip-forwarding true --private-ip-address 10.50.0.4 --location $location
az network public-ip create --name NVA2PublicIP --resource-group $resourceGroup --idle-timeout 30 --allocation-method Static --location $location
az network nic create --name NVA2NIC -g $resourceGroup --subnet NVAsubnet --vnet $NVAvnetName --public-ip-address NVA2PublicIP --ip-forwarding true --private-ip-address 10.50.0.5 --location $location
# Create the NVA1/SDWAN VM
az vm image list --publisher cisco --offer cisco-c8000v-byol --sku 17_14_01a-byol --all --output table
az vm image terms accept --urn cisco:cisco-c8000v-byol:17_14_01a-byol:17.14.0120240501
az vm create --resource-group $resourceGroup --location $location --name NVA1 --size Standard_DS3_v2 --nics NVA1NIC --image cisco:cisco-c8000v-byol:17_14_01a-byol:17.14.0120240501 --admin-username azureuser --admin-password Community123
# Create the NVA2/SDWAN VM
az vm image list --publisher cisco --offer cisco-c8000v-byol --sku 17_14_01a-byol --all --output table
az vm image terms accept --urn cisco:cisco-c8000v-byol:17_14_01a-byol:17.14.0120240501
az vm create --resource-group $resourceGroup --location $location --name NVA2 --size Standard_DS3_v2 --nics NVA2NIC --image cisco:cisco-c8000v-byol:17_14_01a-byol:17.14.0120240501 --admin-username azureuser --admin-password Community123

echo Create a load-balancer in the NVA VNET to load balance the NVA VMs
#LB create
#az network lb frontend-ip create -g $resourceGroup -n Int-LB-IP --lb-name MyLb --private-ip-address 10.50.0.10 --subnet NVAsubnet --vnet-name $NVA-vnetName
az network lb create --resource-group $resourceGroup --name Int_LB --sku Standard --vnet-name $NVAvnetName --subnet NVAsubnet --backend-pool-name NVApool --private-ip-address 10.50.0.10 --location $location
#pool
az network lb address-pool address add --resource-group $resourceGroup --lb-name Int_LB --pool-name NVApool --ip-address 10.50.0.4 --name NVA1 --subnet NVAsubnet --virtual-network $NVAvnetName
az network lb address-pool address add --resource-group $resourceGroup --lb-name Int_LB --pool-name NVApool --ip-address 10.50.0.5 --name NVA2 --subnet NVAsubnet --virtual-network $NVAvnetName
#Probe
az network lb probe create -g $resourceGroup --lb-name Int_LB -n Probe --protocol tcp --port 22
#LBrule
az network lb rule create -g $resourceGroup --lb-name Int_LB -n HAports --protocol All --frontend-port 0 --backend-port 0 --frontend-ip LoadBalancerFrontEnd --backend-pool-name NVApool

echo Create Bastion Host for NVA VNET
#Add Bation to NVA/SDWAN VNET
az network public-ip create --name NVAbastionpublicIP --resource-group $resourceGroup --location $location --allocation-method static 
az network bastion create --name NVAbastionHost --resource-group $resourceGroup --vnet-name $NVAvnetName --location $location --public-ip-address NVAbastionpublicIP --sku Standard --enable-tunneling

echo Creating BGP endping from Vhub to NVA IPs
#NVA VNET Connection ID
NVAconnID=$(az network vhub connection show --name NVA-conn --resource-group $resourceGroup --vhub-name $vhubName --query "id" --output tsv)
#Create BGP connection from Vhub to NVA1
az network vhub bgpconnection create --name NVA1BGP --resource-group $resourceGroup --vhub-name $vhubName --peer-asn 65005 --peer-ip 10.50.0.4 --vhub-conn $NVAconnID
#Create BGP connection from Vhub to NVA2
az network vhub bgpconnection create --name NVA2BGP --resource-group $resourceGroup --vhub-name $vhubName --peer-asn 65005 --peer-ip 10.50.0.5 --vhub-conn $NVAconnID

echo Validating vHubs VPN Gateways provisioning...
#vWAN Hubs VPN Gateway Status
vpnGatewayName="VpnGateway"
prState=$(az network vpn-gateway show -g $resourceGroup -n $vpnGatewayName --query provisioningState -o tsv)
if [[ $prState == 'Failed' ]];
then
    echo VPN Gateway is in fail state. Deleting and rebuilding.
    az network vpn-gateway delete -n $vpnGatewayName -g $resourceGroup
    az network vpn-gateway create -n $vpnGatewayName -g $resourceGroup --location $location --vhub $vhubName --no-wait
    sleep 5
else
    prState=''
    while [[ $prState != 'Succeeded' ]];
    do
        prState=$(az network vpn-gateway show -g $resourceGroup -n $vpnGatewayName --query provisioningState -o tsv)
        echo $vpnGatewayName "provisioningState="$prState
        sleep 5
    done
fi

echo Validating Branches VPN Gateways provisioning...
#Branches VPN Gateways provisioning status
prState=$(az network vnet-gateway show -g $resourceGroup -n branch1-VNG --query provisioningState -o tsv)
if [[ $prState == 'Failed' ]];
then
    echo VPN Gateway is in fail state. Deleting and rebuilding.
    az network vnet-gateway delete -n branch1-VNG -g $resourceGroup
    az network vnet-gateway create --name branch1-VNG --public-ip-address branch1-VNGpubip --resource-group $resourceGroup --vnet $branchvnet --gateway-type Vpn --vpn-type RouteBased --sku VpnGw1 --asn 65001 --bgp-peering-address 192.168.0.36 --location $location
    sleep 5
else
    prState=''
    while [[ $prState != 'Succeeded' ]];
    do
        prState=$(az network vnet-gateway show -g $resourceGroup -n branch1-VNG --query provisioningState -o tsv)
        echo "branch1-VNG provisioningState="$prState
        sleep 5
    done
fi

echo Building VPN connections from VPN Gateways to the respective Branches...

#NVAPUBLICIP (172.200.147.165)
#az network public-ip show -g CommunityRG -n NVAPublicIP --query "{address: ipAddress}
NVApubIP=$(az network public-ip show -g CommunityRG -n NVAPublicIP --query ipAddress)
#Get the Gateway IPs and BGP IPs from the Virtual WAN VPN gateway
#az network vpn-gateway show --name $vpnGatewayName --resource-group $resourceGroup --query "{TunnelIPs: bgpSettings.bgpPeeringAddresses[].tunnelIpAddresses, BgpIPs: bgpSettings.bgpPeeringAddresses[].defaultBgpIpAddresses}"

#GWIPof the primary VWAN VPN GW:
vwangwIP=$(az network vpn-gateway show --name $vpnGatewayName --resource-group $resourceGroup --query "ipConfigurations[0].publicIpAddress" --output  tsv)
#BGP IPof the primary VWAN VPN GW:
vwangwbgpip=$(az network vpn-gateway show --name $vpnGatewayName --resource-group $resourceGroup --query "bgpSettings.bgpPeeringAddresses[0].defaultBgpIpAddresses[0]" --output tsv)

#BRANCH1 VPNGWIP  (172.203.21.202 (branch1-VNGpubip))
#az network public-ip show -g $resourceGroup -n branch1-VNGpubip --query "{address: ipAddress}"
branchvpnip=$(az network public-ip show -g $resourceGroup -n branch1-VNGpubip --query ipAddress --output tsv)

#LNG
az network local-gateway create --gateway-ip-address $vwangwIP --name vWAN-LNG --resource-group $resourceGroup --asn 65515 --bgp-peering-address $vwangwbgpip --local-address-prefixes $vwangwbgpip/32
#Create the VPN connection from Branch1 to NVA
az network vpn-connection create --name branch1-to-vWAN --resource-group $resourceGroup --vnet-gateway1 branch1-VNG --shared-key 'Community123' --location $location --enable-bgp --local-gateway2 vWAN-LNG 

# Create a VPN site and link in the Virtual WAN
az network vpn-site create --name branchSite --resource-group $resourceGroup --location $location  --virtual-wan Vwan --ip-address $branchvpnip  --address-prefixes 192.168.0.36/32 --device-vendor microsoft --device-model Azure --link-speed 100 --asn 65001 --bgp-peering-address 192.168.0.36 --with-link true

# Connect the VPN site to the VPN gateway (establish the VPN tunnel)
az network vpn-gateway connection create --name Vwantobranch --gateway-name $vpnGatewayName --resource-group $resourceGroup --remote-vpn-site branchSite --enable-bgp true --protocol-type IKEv2 --shared-key "Community123" 
