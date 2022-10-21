VNET_NAME="cluster-vnet"
MASTER_SUBNET="master-subnet"
WORKER_SUBNET="worker-subnet"
NSG_NAME="aroNSG"
RULE_NAME="verysecure"

lab2_build() {
    build_common_infra

    # Build our (not really) insecure ARO cluster
    az aro create -g $RG_NAME \
        -n $ARO_NAME \
        --vnet $VNET_NAME \
        --master-subnet $MASTER_SUBNET \
        --worker-subnet $WORKER_SUBNET \
        --location $LOCATION \
        --output none

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

    # Assign it to the master subnet
    az network vnet subnet update -n $MASTER_SUBNET \
        -g $RG_NAME \
        --vnet-name $VNET_NAME
        --nsg $NSG_NAME
}

lab2_validate() {
    # The validation here is going to check if...
    #   - the NSG has been removed from the subnet entirely
    #   - the deny outbound rule has been removed from the NSG (more targeted fix approach)
    #   - TODO: additional allows were added before the outbound deny to meet egress requirements

    # Check the subnet to see if the NSG is even around - if it's gone, then we can pass the validation
    nsg_id=$(az network vnet subnet show -g $RG_NAME --vnet-name $VNET_NAME -n $MASTER_SUBNET -o tsv --query "networkSecurityGroup.id")
    if [ -z "${nsg_id}" ]; then
        return 0
    fi

    # Since the NSG is still applied to the subnet, let's list the outbound rules and see how many we have.
    #   - If we have more than 1 (when defaults are excluded) then we know there's been more additions made.
    #   - If we have zero, then the problem rule has been removed.
    #
    # TODO: There's some logic that needs to be applied in this case if there's more
    # than 1 rule present for outbound - how do we know if there's the correct
    # allows made that the ARO cluster creation would succeed?
    check=$(command -v jq > /dev/null 2>&1)

    if [ check -eq 0]; then
        # We have `jq' so let's use it
        rule_id=$(az network nsg rule show -n $RULE_NAME --nsg-name $NSG_NAME -g $RG_NAME --query id -o tsv)

        if [ -z "${rule_id}" && $? -ne 0 ]; then
            # NSG rule is missing from the NSG because there's no ID and the exit code is non-zero
            # return successful validation
            return 0
        else
            rule_count=$(az network nsg rule list -g $RG_NAME --nsg-name $NSG_NAME | jq '. | length')
            allow_rules=$(az network nsg rule list -g $RG_NAME --nsg-name $NSG_NAME | jq '.[] | select(.access == Allow)' | jq -s)
            if [ $rule_count -gt 1 ]; then
                # TODO: How do we assess the allow rules we have here?
            fi
        fi
    else
        # Doing this the hard way I guess
        rule_id=$(az network nsg rule show -n $RULE_NAME --nsg-name $NSG_NAME -g $RG_NAME --query id -o tsv)

        if [ -z "${rule_id}" && $? -ne 0 ]; then
            # NSG rule is missing from the NSG because there's no ID and the exit code is non-zero
            # return successful validation
            return 0
        else
            # Unimplemented: further validation if the rule is still there
        fi
    fi
}