VNET_NAME="cluster-vnet"
MASTER_SUBNET="master-subnet"
WORKER_SUBNET="worker-subnet"
NSG_NAME="aroNSG"
RULE_NAME="verysecure"

lab2_build() {
    echo -e "Starting the build for lab scenario 2!"
    build_common_infra

    # Build our (not really) insecure ARO cluster
    echo -e "***** Building our ARO lab cluster - this could take up to 30 minutes..."
    az aro create -g $RG_NAME \
        -n $ARO_NAME \
        --vnet $VNET_NAME \
        --master-subnet $MASTER_SUBNET \
        --worker-subnet $WORKER_SUBNET \
        --location $LOCATION \
        --output none

    echo -e "***** Finishing a few more work items"
    # Generate an NSG that blocks all outbound traffic on the subnets
    nsg_id=$(az network nsg create -g $RG_NAME --name aroNSG --location $LOCATION -o tsv --query id)
    az network nsg rule create --name verysecure \
        --nsg-name aroNSG \
        --priority 101 \
        -g $RG_NAME \
        --destination-address-prefixes "*" \
        --destination-port-ranges "*" \
        --source-address-prefixes "*" \
        --source-port-ranges "*" \
        --direction Inbound \
        --access Deny \
        -o none

    echo -e "***** Just finishing up a few more things...thank you for waiting!"
    sleep 180

    # Assign it to the master subnet
    az network vnet subnet update -n $MASTER_SUBNET \
        -g $RG_NAME \
        --vnet-name $VNET_NAME \
        --nsg $NSG_NAME \
        -o none

    echo -e "*** Lab number 2 deployment has finished. It looks like we're now unable to get to the master nodes..."
}

lab2_validate() {
    # The validation here is going to check if...
    #   - the NSG has been removed from the subnet entirely
    #   - the deny outbound rule has been removed from the NSG (more targeted fix approach)

    echo -e "*** Beginning validation for lab scenario 2..."

    # Check the subnet to see if the NSG is even around - if it's gone, then we can pass the validation
    subnet_nsg_id=$(az network vnet subnet show -g $RG_NAME --vnet-name $VNET_NAME -n $MASTER_SUBNET -o tsv --query "networkSecurityGroup.id")
    target_nsg_id=$(az network nsg show -g $RG_NAME -n $NSG_NAME --query id -o tsv)
    if [ -z "${subnet_nsg_id}" -o "${subnet_nsg_id}" != "${target_nsg_id}" ]; then
        echo -e "*** The NSG has been removed from the subnet - this has restored connectivity!"
        echo -e "***"
        echo -e "*** Congratulations on completing this lab scenarion - you can remove the RG created during this lab."
        return 0
    fi

    az network nsg rule show -n $RULE_NAME --nsg-name $NSG_NAME -g $RG_NAME --query id -o none
    if [ $? -ne 0 ]; then
        # NSG rule is missing from the NSG because there's no ID and the exit code is non-zero
        # return successful validation
        echo -e "*** The deny rule on the NSG has been removed - this has restored connectivity!"
        echo -e "***"
        echo -e "*** Congratulations on completing this lab scenarion - you can remove the RG created during this lab."
        return 0
    fi

    echo -e "*** Not quite...master connectivity is still disrupted!"
}