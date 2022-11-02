VNET_NAME="cluster-vnet"
MASTER_SUBNET="master-subnet"
WORKER_SUBNET="worker-subnet"

lab3_build() {
    echo -e "*** Starting the build for lab scenario 3!"
    build_common_infra

    echo -e "***** Building our ARO lab cluster - this could take up to 30 minutes..."
    az aro create -g $RG_NAME \
        -n $ARO_NAME \
        --vnet $VNET_NAME \
        --master-subnet $MASTER_SUBNET \
        --worker-subnet $WORKER_SUBNET \
        --location $LOCATION \
        --output none

    if [ $? -gt 0 ]; then
      echo -e "An error was encountered while attempting to build this lab scenario."
      echo -e ""
      echo -e "Please delete the resource group '$RG_NAME' and re-run the lab creation."
      exit 1
    fi

    echo -e "***** Finishing a few more work items"
    pass=$(az aro list-credentials -g $RG_NAME -n $ARO_NAME --query kubeadminPassword -o tsv)
    apiServer=$(az aro show -g $RG_NAME -n $ARO_NAME --query apiserverProfile.url -o tsv)
    apiServerIp=$(az aro show -g $RG_NAME -n $ARO_NAME --query apiserverProfile.address -o tsv)


    echo -e "***** Finalizing the setup and configuration on the lab scenario"
    sleep 120
    oc login $apiServer -u kubeadmin -p $pass

cat <<EOF | oc apply -f &>/dev/null -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin
  labels:
    app: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin
      role: frontend
  template:
    metadata:
      labels:
        app: httpbin
        role: frontend
    spec:
      containers:
        - name: httpbin
          image: kennethreitz/httpbin
          resources:
            requests:
              cpu: 500m
---
apiVersion: v1
kind: Service
metadata:
  name: httpbin
  labels:
    app: httpbin
spec:
  selector:
    app: httpbin
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: httpbin-ingress
  annotations:
    nginx.ingress.kubernetes.io/use-regex: "true"
spec:
  ingressClassName: nginx
  rules:
  - host: "httpbin.example.com"
    http:
      paths:
        - path: /(.*)
          pathType: Prefix
          backend:
            service:
              name: httpbin
              port:
                number: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: httpbin-tester
spec:
  containers:
    - name: ubuntu
      image: ubuntu
      command:
        - /bin/bash
        - -c
        - |
          apt update && apt install curl -y
          while true
          do
              curl -vvLk http://httpbin.default.svc.cluster.local/status/200
              sleep 15s
          done
---
apiVersion: network.openshift.io/v1
kind: EgressNetworkPolicy
metadata:
  name: network-security-baseline
  namespace: default
spec:
  egress:
    - to:
        cidrSelector: $apiServerIp
      type: Allow
    - to:
        cidrSelector: 0.0.0.0/0
      type: Deny
EOF

    echo -e "*** Lab number 3 deployment has finished. For some reason, the pods within the default namespace aren't accessible..."
}

lab3_validate() {
  echo -e "Beginning validation for lab scenario 3..."

  pass=$(az aro list-credentials -g $RG_NAME -n $ARO_NAME --query kubeadminPassword -o tsv)
  apiServer=$(az aro show -g $RG_NAME -n $ARO_NAME --query apiserverProfile.url -o tsv)

  oc login $apiServer -u kubeadmin -p $pass

  enp_name=$(oc get egressnetworkpolicy -n default network-security-baseline -o jsonpath='{.metadata.name}')
  if [ $? -gt 0 ]; then
    echo -e "The restricting network policy has been removed - great job!"
    echo -e ""
    echo -e "You've completed this lab scenario. Feel free to delete the resource group for this lab to clean up your ARO cluster and related resources!"
    
    return 0
  else
    echo -e "Network traffic is still being restricted in the default namespace - please try again."
    return 1
  fi
}