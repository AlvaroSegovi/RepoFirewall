
# Crear un grupo de recursos
az group create --name FWRG --location eastus

#Crear la VNet FWVN y la subnet AzureFirewallSubnet
az network vnet create --name FWVN --resource-group FWRG --location eastus --address-prefixes 10.0.0.0/16 --subnet-name AzureFirewallSubnet --subnet-prefixes 10.0.1.0/24

#Crear la subred FWSN1 
az network vnet subnet create --name FWSN1 --vnet-name FWVN --resource-group FWRG --address-prefixes "10.0.2.0/24" 

#Crear la subred FWSN2
az network vnet subnet create --name FWSN2 --vnet-name FWVN --resource-group FWRG --address-prefixes "10.0.3.0/24"

#Crear maquina virtual VMpublica en  la subred FWSN2
az vm create --name VMpublica --resource-group FWRG --location eastus --image Win2019Datacenter --admin-username alvaro  --size Standard_B1s --os-disk-size-gb 130 --os-disk-name DiscoVMpublica --vnet-name FWVN --subnet FWSN2 

#Abrir el puerto RDP 3389
az vm open-port --name VMpublica --resource-group FWRG --port 3389  

#Crear la NIC para VMprivada sin ip pública.
 az network nic create --name NicVMprivada --resource-group FWRG --location eastus --vnet-name FWVN --subnet FWSN1

#Crear maquina virtual VMprivada en la subred FWSN2
az vm create --name VMprivada --resource-group FWRG --nics NicVMprivada --location eastus --image Win2019Datacenter --admin-username alvaro --size Standard_B1s --os-disk-size-gb 130 --os-disk-name DiscoVMprivada
 # When specifying an existing NIC, do not specify NSG, public IP, ASGs, VNet or subnet.
 
#Crear la ip pública Fuera del Firewall
az network public-ip create --name ippublic1 --resource-group FWRG --sku Standard --allocation-method Static

#Implementar el Firewall
az network firewall create --name AzureFirewall --resource-group FWRG --location eastus --sku AZFW_VNet --vnet-name AzureFirewallSubnet --public-ip ippublic1

# Configurar la ip publica dentro del firewall, si no se hace esto no se puede ver la configuracion ip del firewall (AzureFirewall/Public IP configuration) y no se puede conectar con escritorio remoto. 
az network firewall ip-config create --firewall-name AzureFirewall --name publicipconf --public-ip-address ippublic1 --resource-group FWRG --vnet-name FWVN

#-----Ejecutar hasta aqui y luego en la siguiente regla llenar los parametros:
# --source-addresses x.x.x.x (IP pública desde donde nos vamos a conectar)
# --destination-addresses x.x.x.x (IP pública del Firewall)
# --translated-address x.x.x.x  (IP privada de la máquina virtual a la que se quiere acceder)

#Crear la regla DNAT Regla1RDP
az network firewall nat-rule create --firewall-name AzureFirewall --resource-group FWRG --collection-name Regla1RDP --priority 101 --action DNAT --name vmaccess --source-addresses 170.84.135.64 --protocols TCP --destination-ports 3500 --destination-addresses 172.190.222.69 --translated-address 10.0.2.4 --translated-port 3389

# Configurar la ip publica dentro del firewall, si no se hace esto no se puede ver la configuracion ip del firewall (AzureFirewall/Public IP configuration) y no se puede conectar con escritorio remoto.
#Esta configuracion se puso aqui nuevamente cuando se cambie la ip fuente y la ip destino en la regla DNAT.
az network firewall ip-config create --firewall-name AzureFirewall --name publicipconf --public-ip-address ippublic1 --resource-group FWRG --vnet-name FWVN

#Actualizar el firewall
az network firewall update --name AzureFirewall --resource-group FWRG

#Crear la tabla de rutas
az network route-table create --name tabladerutas1 --resource-group FWRG --location eastus

#Asociar la subnet FWSN1 a la tabla de rutas tabladerutas1 
az network vnet subnet create --name FWSN1 --vnet-name FWVN --resource-group FWRG --address-prefixes "10.0.2.0/24" --route-table tabladerutas1

# Crear la ruta1 para que todo lo que vaya a internet salga por el firewall  
az network route-table route create --name ruta1 --resource-group FWRG --route-table-name tabladerutas1 --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address 10.0.1.4

#Crear regla de aplicación del Firewall
az network firewall application-rule create --collection-name Reglaaplicacion1 --resource-group FWRG --firewall-name AzureFirewall --priority 106 --action Allow --name google --protocols Http=80, Https=443 --source-addresses 10.0.2.4 --target-fqdns www.google.com