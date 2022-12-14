FROM ubuntu:22.04

RUN apt-get update && apt-get install bash-completion apt-transport-https gnupg wget curl vim openssh-client iputils-ping nmap jq -y \
    && curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - \
    && curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/microsoft.asc.gpg \
    && echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list \
    && echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ jammy main" > /etc/apt/sources.list.d/azure-cli.list \
    && apt-get update && apt-get install -y kubectl azure-cli \
    && apt-get clean all

# Install OC CLI
RUN curl -L https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz -o /tmp/openshift-client.tar.gz \
    && tar xf /tmp/openshift-client.tar.gz -C /tmp/oc \
    && mv /tmp/oc/oc /usr/local/bin \
    && chmod +x /usr/local/bin/oc

COPY ./bashrc /root/.bashrc

COPY ./lab_binaries/* /usr/local/bin/

CMD ["/bin/bash"]