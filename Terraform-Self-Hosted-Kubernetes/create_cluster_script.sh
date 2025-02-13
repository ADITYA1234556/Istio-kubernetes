#!/bin/bash

set -e  # Exit immediately if any command exits with a non-zero status

trap 'echo "Script failed at line $LINENO with exit code $?"' ERR
read -rp "Provide hostname for this node: " HOST_NAME
hostnamectl set-hostname $HOST_NAME
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root or with sudo"
    exit 1
fi

#Check memory and CPU of the system
echo "Checking memory and cpu requirements...."
CORES=$(nproc)
MEM=$(free -g | awk '/^Mem/ {print $2}')
if [[ "$CORES" -lt 2 ]] || [[ "$MEM" -lt 2 ]]; then
    echo "cpu or memory is below minimum requirements"
    exit 1
fi

#disable swap
echo "disabling swap.."
sudo swapoff -a

#Enable port forwarding for containers
echo "enable port forwarding..."
echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.d/k8s.conf
sysctl --system > /dev/null 2>&1

if grep -q "net.ipv4.ip_forward = 1" /etc/sysctl.d/k8s.conf; then
    echo "IP forwarding is enabled"
else
    echo "IP forwarding not enabled .. quitting"
    exit 1
fi

#Detect OS and version
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION_ID=$VERSION_ID
else
    echo "Cannot detect OS version"
    exit 1
fi

#Function to install packages based on OS
#will use this below
install_packages() {
    case "$OS" in
        "ubuntu"|"debian")
            apt-get update -y -qq && apt-get upgrade -y -qq
            apt-get install -y "$@" -qq
            ;;
        "rhel"|"centos"|"fedora"|"rocky"|"almalinux"|"amzn")
            dnf update -y -q
            dnf install -y "$@" -q
            ;;
        *)
            echo "Unsupported OS: $OS"
            exit 1
            ;;
    esac
}

#Ensure jq,curl and wget are installed

case "$OS" in
    "ubuntu"|"debian")
        install_packages jq iproute2
        ;;
    "rhel"|"centos"|"fedora"|"rocky"|"almalinux"|"amzn")
        install_packages jq
        install_packages iproute iproute-tc
        ;;
esac

#Detect architecture and containerd and its components
ARCH=$(uname -m)
echo "Detected architecture: $ARCH"

CONTAINERD_VERSION=$(curl -sSL "https://api.github.com/repos/containerd/containerd/releases/latest" | jq -r '.tag_name' | sed 's/^v//')
if [[ -z "$CONTAINERD_VERSION" ]]; then
    echo "Failed to fetch CNI version"
    exit 1
fi

RUNC_VERSION=$(curl -sSL "https://api.github.com/repos/opencontainers/runc/releases/latest" | jq -r '.tag_name')
if [[ -z "$RUNC_VERSION" ]]; then
    echo "Failed to fetch CNI version"
    exit 1
fi

CNI_VERSION=$(curl -sSL "https://api.github.com/repos/containernetworking/plugins/releases/latest" | jq -r '.tag_name')
if [[ -z "$CNI_VERSION" ]]; then
    echo "Failed to fetch CNI version"
    exit 1
fi

case "$ARCH" in
    "x86_64")
        #install containerd
        echo "Installing containerd..."
        wget -q "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz"
        tar Cxzf /usr/local "containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz"
        if ! command -v containerd >/dev/null 2>&1; then
            echo "containerd installation failed"
            exit 1
        fi
        mkdir -p /usr/local/lib/systemd/system/
        curl -o /usr/local/lib/systemd/system/containerd.service https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
        rm "containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz"
        systemctl daemon-reload
        systemctl enable --now containerd
        
        #install runc
        echo "Installing runc..."
        wget -q "https://github.com/opencontainers/runc/releases/download/${RUNC_VERSION}/runc.amd64"
        install -m 755 runc.amd64 /usr/local/sbin/runc
        
        #install cni plugins
        echo "Installing CNI plugin..."
        mkdir -p /opt/cni/bin
        wget -q "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-amd64-${CNI_VERSION}.tgz"
        tar Cxzf /opt/cni/bin "cni-plugins-linux-amd64-${CNI_VERSION}.tgz"
        rm "cni-plugins-linux-amd64-${CNI_VERSION}.tgz"
        ;;

    "aarch64")

        #install containerd
        echo "Installing containerd..."
        wget -q "https://github.com/containerd/containerd/releases/download/${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-arm64.tar.gz"
        tar Cxzf /usr/local "containerd-${CONTAINERD_VERSION}-linux-arm64.tar.gz"
        rm "containerd-${CONTAINERD_VERSION}-linux-arm64.tar.gz"
        if ! command -v containerd >/dev/null 2>&1; then
            echo "containerd installation failed"
            exit 1
        fi
        mkdir -p /usr/local/lib/systemd/system/
        curl -o /usr/local/lib/systemd/system/containerd.service https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
        systemctl daemon-reload
        systemctl enable --now containerd
        
        #install runc
        echo "Installing runc..."
        wget -q "https://github.com/opencontainers/runc/releases/download/${RUNC_VERSION}/runc.arm64"
        install -m 755 runc.arm64 /usr/local/sbin/runc
        
        #install cni plugins
        echo "Installing CNI plugin..."
        mkdir -p /opt/cni/bin
        wget -q "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-arm64-${CNI_VERSION}.tgz"
        tar Cxzf /opt/cni/bin "cni-plugins-linux-arm64-${CNI_VERSION}.tgz"
        rm "cni-plugins-linux-arm64-${CNI_VERSION}.tgz"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac


#Configure containerd
echo "Configuring containerd..."
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

config_file="/etc/containerd/config.toml"

#Remove CRI from disabled plugins if present
if grep -q "disabled_plugins.*cri" "$config_file"; then
    echo "Enabling CRI plugin..."
    sed -i 's/disabled_plugins.*=.*\[.*"cri".*\]/disabled_plugins = []/' "$config_file"
fi

#Configure systemd cgroup driver
echo "Configuring systemd cgroup driver..."
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' "$config_file"

sudo sed -i "/\[plugins\.'io\.containerd\.grpc\.v1\.cri'\]/a\    sandbox_image = \"registry.k8s.io\/pause:3.10\"" $config_file

#Restart containerd
systemctl restart containerd

#Install Kubernetes components based on OS
echo "Installing kubeadm and kubelet"
RELEASE="$(curl -sSL https://dl.k8s.io/release/stable.txt)"
RELEASE="${RELEASE%.*}"

case "$OS" in
    "ubuntu"|"debian")
        install_packages apt-transport-https ca-certificates curl gpg
        curl -fsSL "https://pkgs.k8s.io/core:/stable:/${RELEASE}/deb/Release.key" | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
        echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${RELEASE}/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
        apt-get update -qq
        install_packages kubelet kubeadm
        apt-mark hold kubelet kubeadm
        systemctl enable --now kubelet
        ;;

    "rhel"|"centos"|"fedora"|"rocky"|"almalinux"|"amzn")
        setenforce 0
        sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/${RELEASE}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/${RELEASE}/rpm/repodata/repomd.xml.key
EOF
        install_packages kubelet kubeadm

        #Prevent automatic updates
        if command -v dnf >/dev/null 2>&1; then
            dnf mark install kubelet kubeadm
            systemctl enable kubelet.service
        else
            yum versionlock add kubelet kubeadm
        fi
        ;;
esac

#Prompt for control plane installation
while true; do
    read -rp "Is this a control plane node? Install kubectl (yes/no): " answer
    case "${answer,,}" in
        yes|y)
            echo "Installing kubectl..."
            case "$OS" in
                "ubuntu"|"debian")
                    install_packages kubectl
                    apt-mark hold kubectl
                    ;;
                "rhel"|"centos"|"fedora"|"rocky"|"almalinux"|"amzn")
                    install_packages kubectl
                    if command -v dnf >/dev/null 2>&1; then
                        dnf mark install kubectl
                    else
                        yum versionlock add kubectl
                    fi
                    ;;
            esac

            echo "Initializing control plane..."
            #kubeadm init > /dev/null
            kubeadm init --pod-network-cidr=192.168.0.0/16

            echo "Configuring kubectl for user..."
            USER_HOME=$(eval echo ~${SUDO_USER:-$USER}) 
            mkdir -p "$USER_HOME/.kube"
            cp -i /etc/kubernetes/admin.conf "$USER_HOME/.kube/config"
            chown "$(id -u ${SUDO_USER:-$USER}):$(id -g ${SUDO_USER:-$USER})" "$USER_HOME/.kube/config"

            echo
            echo "******************************************"
            echo "            Join Command                 "
            echo "******************************************"
            kubeadm token create --print-join-command
            echo "******************************************"
            echo
            break
            ;;
        no|n)
            echo "Worker node setup complete. Use 'kubeadm join' to connect to the cluster"
            exit 0
            ;;
        *)
            echo "Invalid input. Please enter 'yes' or 'no'"
            ;;
    esac
done

echo "Installation completed successfully"