VNET_NAME="cluster-vnet"
MASTER_SUBNET="master-subnet"
WORKER_SUBNET="worker-subnet"

lab3_build() {
    build_common_infra

    az aro create -g $RG_NAME \
        -n $ARO_NAME \
        --vnet $VNET_NAME \
        --master-subnet $MASTER_SUBNET \
        --worker-subnet $WORKER_SUBNET \
        --location $LOCATION \
        --output none

    pass=$(az aro list-credentials -g $RG_NAME -n $ARO_NAME --query kubeadminPassword -o tsv)
    apiServer=$(az aro show -g $RG_NAME -n $ARO_NAME --query apiserverProfile.url -o tsv)

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
        cidrSelector: <<<REPLACE_WITH_IP>>>
      type: Allow
    - to:
        cidrSelector: 0.0.0.0/0
      type: Deny
EOF

    echo -e "Lab number 3 deployment has finished. For some reason, the pods within the default namespace aren't accessible..."
}

lab3_validate() {

}