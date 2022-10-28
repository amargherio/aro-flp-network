build_common_infra() {
    # Create the RG
    echo -e "***** Creating the resource group and vnet..."
    az group create -n "$RG_NAME" -l $LOCATION -o none

    az network vnet create -g $RG_NAME \
        -n $VNET_NAME \
        --address-prefixes 172.16.0.0/16 \
        --location $LOCATION \
        --output none
    az network vnet subnet create -g $RG_NAME \
        --vnet-name $VNET_NAME \
        --name $MASTER_SUBNET \
        --address-prefixes 172.16.0.0/27 \
        --service-endpoints Microsoft.ContainerRegistry \
        --output none
    az network vnet subnet create -g $RG_NAME \
        --vnet-name $VNET_NAME \
        --name $WORKER_SUBNET \
        --address-prefixes 172.16.1.0/27 \
        --service-endpoints Microsoft.ContainerRegistry \
        --output none

    # Update the master subnet to disable private link network policies
    az network vnet subnet update --name $MASTER_SUBNET \
        -g $RG_NAME \
        --vnet-name $VNET_NAME \
        --disable-private-link-service-network-policies true \
        --output none
    
    sleep 30
}

debug_vars() {
    echo -e "**VARS CONFIGURED**"
    echo -e "LOCATION: $LOCATION"
    #echo -e "POSTFIX: $POSTFIX"
    echo -e "RG_NAME: $RG_NAME"
    echo -e "ARO_NAME: $ARO_NAME"
    echo -e "LAB_SCENARIO: $LAB_SCENARIO"
    echo -e "USER_ALIAS: $USER_ALIAS"
    echo -e "SHOULD_VALIDATE: $SHOULD_VALIDATE"
}

function az_login_check () {
    if $(az account list 2>&1 | grep -q 'az login')
    then
        echo -e "\n--> Warning: You have to login first with the 'az login' command before you can run this lab tool\n"
        az login -o table
    fi
}