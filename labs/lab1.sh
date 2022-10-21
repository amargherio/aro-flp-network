VNET_NAME="cluster-vnet"
MASTER_SUBNET="master-subnet"
WORKER_SUBNET="worker-subnet"
RT_NAME="aroRT"

FW_NAME="gateway-fw"
FW_PIP="fw-public-ip"
FW_PIP_CONFIG="fw-pip-config"


lab1_build() {
    build_common_infra

    # Build our (not really) insecure ARO cluster
    az aro create -g $RG_NAME \
        -n $ARO_NAME \
        --vnet $VNET_NAME \
        --master-subnet $MASTER_SUBNET \
        --worker-subnet $WORKER_SUBNET \
        --location $LOCATION \
        --output none

    # Create Azure Firewall
    az network firewall create \
        -n $FW_NAME \
        -g $RG_NAME \
        -l $LOCATION
    
    az network public-ip create \
        -g $RG_NAME \
        -n $FW_PIP \
        -l $LOCATION \
        --allocation-method Static \
        --sku Standard

    az network firewall ip-config create \
        -g $RG_NAME
        --firewall-name $FW_NAME \
        --name $FW_PIP_CONFIG \
        --public-ip-address $FW_PIP \
        --vnet-name $VNET_NAME

    az network firewall update \
        -g $RG_NAME \
        -n $FW_NAME

    fw_internal_ip=$(az network firewall ip-config list -g $RG_NAME -f $FW_NAME --query "[?name=$FW_PIP_CONFIG].privateIpAddress" -o tsv)
    
    # Create the RT with a default route to the firewall configured previously
    az network route-table create \
        -g $RG_NAME \
        -n $RT_NAME \
        -l $LOCATION \
        --disable-bgp-route-propagation true

    az network route-table route create \
        -g $RG_NAME \
        -n default \
        --route-table-name $RT_NAME \
        --address-prefix 0.0.0.0/0 \
        --next-hop-type VirtualAppliance \
        --next-hop-ip-address $fw_internal_ip
   

    # Assign it to the master subnet
    az network vnet subnet update -n $WORKER_SUBNET \
        -g $RG_NAME \
        --vnet-name $VNET_NAME
        --route-table $RT_NAME

}

lab1_validate() {
    # Validation will consist of removing the default route from the route table.
    rt_id=$(az network vnet subnet show -g $RG_NAME --vnet-name $VNET_NAME -n $WORKER_SUBNET --query "routeTable.id" -o tsv)
    if [ $? -gt 0  ]; then
        echo -e "Unable to retrieve the subnet details used by the worker nodes."
        return 1
    fi

    # We could take this further and see if the default route still exists or not and whether
    # the next hop address is the same as the internal IP of the firewall, but we won't
    # do that yet.
    if [ -z $rt_id ]; then
        echo -e "The route table preventing worker connectivity has been removed. Well done!"
        return 0
    else
        echo -e "The outbound connectivity from the worker nodes is still broken - keep trying..."
    fi
}