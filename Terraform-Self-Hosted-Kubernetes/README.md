# Terraform Self Hosted Kuberentes Cluster
- We will create one master node and two worker nodes and one bastion host.

## Create EC2 Instances & Other Components for the Cluster Using Terraform

Resources created:  
__VPC__: 2 Private subnets, 2 Public subnets, 1 nat gw, 1 igw and 2 security groups(cluster and bastion node)  
__IAM role__: Permissions required to create load balancer  
__EC2 instances__: 1 master, 2 worker nodes (t2.medium), and 1 Bastian host(t2.micro)

## Access EC2 Instnaces
__NOTE__: Only the bastion host is accessible from the external network. Cluster nodes reside in private subnets and can be accessed from the bastion host.

1. Copy the PEM key to the bastion host  
    `scp -i <key for ssh> <pem key> ec2-user@<bastin_public_ip>:<dst_location>`  
    _Example_: `scp -i key.pem key.pem ec2-user@$BASTIAN_IP:/home/ec2-user`
2. (Optional) Copy tmux or other personalized config to the bastion host.  
    _Example_: `scp -i key.pem ~/.tmux.conf ec2-user@$BASTIAN_IP:/home/ec2-user`
3. Connect to the bastain host via SSH.  
    _Example_: `ssh -i key.pem ec2-user@$BASTIAN_IP`  
4. Connect to each instance via SSH from th bastion host. 
5. (Tip) Install tmux, export IPs into variables and create multiple sessions in tmux to connect to all instance at once. \
    `export MASTER_IP=172.32.110.142`
    `export WORKER1_IP=172.32.120.33` 
    `export WORKER2_IP=172.32.120.104`
    `ssh -i key.pem ec2-user@<MASTER_IP>`  
    `ssh -i key.pem ec2-user@<WORKER1_IP>`  
    `ssh -i key.pem ec2-user@<WORKER2_IP>`
 
### Create Kubernetes Cluster
Use a script to create a Kubernetes cluster with kubeadm.

1. Download the [create_cluster](scripts/create_cluster.sh) on each node.  
`wget ###`
2. Change permissions for the script.  
`chmod +x create_cluster.sh`  
NOTE: This script prepares the nodes with kubeadm as the [docs](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/). The cluster is intialized with pod-network-cidr=192.168.0.0/16
3. Run the script on each node.  
`sudo ./create_cluster.sh`
Name the controlplane as **controlplane** and worker nodes as **worker1** and **worker2**
4. Select `yes` for control plane & `No` for worker nodes.  
__NOTE: Make note of cluster join command.__
5. Install the network CNI:
    ```
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/tigera-operator.yaml
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/custom-resources.yaml
    watch kubectl get pods -n calico-system
    ```
    NOTE: Download and update `custom-resources.yaml` with a different CIDR IF NEEDED.
5. Join worker nodes to the cluster.  
_Example_: `kubeadm join 172.31.25.150:6443 --token 2i8vrs.wsshnhe5zf87rhhu --discovery-token-ca-cert-hash sha256:eacbaf01cc58203f3ddd69061db2ef8e64f450748aef5620ec04308eac44bd77`
6. Check nodes and calico status:  
`kubectl get pods -n calico-system`  
`kubectl logs -n calico-system -l=k8s-app=calico-node`  
`kubect get nodes`  

Exit the nodes and return to the bastion host.

### Configure kubectl on Bastian Host

1. <a href="https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/">Add the Kubernetes repo and install `kubectl`</a>:
    ```
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    mkdir -p ~/.local/bin
    mv ./kubectl ~/.local/bin/kubectl
    ```
2. Create the config dir and move the kubernetes config from the master node:
    ```
    mkdir -p $HOME/.kube
    scp -i key.pem ec2-user@$MASTER_IP:/home/ec2-user/.kube/config $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    ```
    NOTE: change Master_IP

### Install Load Balancer Controller

1. Install Helm and the AWS Load Balancer Controller:
    ```
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh

    #Install aws-load-balancer controller
    helm repo add eks https://aws.github.io/eks-charts
    helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=kubernetes #update cluster name if needed
    ```
    Check pods status:  
    `kubectl get pods -n kube-system -l=app.kubernetes.io/instance=aws-load-balancer-controller`  
    `kubectl logs -n kube-system -l=app.kubernetes.io/instance=aws-load-balancer-controller`
### Create Deployment and Services for the Blog App.

1. Download app [manifest](manifests/app.yaml)  
`wget ###`
2. Apply the manifest:    
`kubectl -f app.yaml`  
NOTE: Update the URLs in the configmap with your domain.  
3. Check if the app is reachable  
`curl http:<worker1 or worker 2 IP>:30011`  
`curl http:<worker1 or worker 2 IP>:30012`
### Set Up ACM certificate
Assumption: You have a domain.

1. Go to the AWS Certificate Manager service
2. Click __Request__ and select __Request a public certificate__
3. Provide FQDN, select __DNS validation__ and select __RSA 2048__
4. Click __Request__

### Create Ingress and load balancer

1. Patch worker nodes with `Provider_ID`:  
    `kubectl patch node <worker_node_name> -p '{"spec":{"providerID":"aws:///<Region>/<WORKER_ID>"}}'`  
    _Example_: 
    `kubectl patch node worker1 -p '{"spec":{"providerID":"aws:///eu-west-2/i-070f38a9c84a8bb67"}}'`
    `kubectl patch node worker2 -p '{"spec":{"providerID":"aws:///eu-west-2/i-07229a43d8a7aee95"}}'`

2. Download the Ingress manifest [here](manifests/ingress.yaml)  
 `wget ###`
3. Apply the Ingress manifest:  
 `kubectl create -f ingress.yaml`  
    NOTE: If a domain isn't available. Remove the host and HTTPS from ingress manifest:  
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80} ~~, {"HTTPS": 443}~~]'  
    ~~host: testblog.gurlal.com~~  
    Without a domain, ACM setup won’t be applicable, and app redirects won’t work. You can access the app using the load balancer’s DNS name.
4. View Ingress logs:  
    `kubectl describe ingress blog-app-ingress`  
    `kubectl logs -n kube-system -l=app.kubernetes.io/instance=aws-load-balancer-controller`  
 Wait for the load balancer to be created.
 5. Change the health path for the login app to `/health`
 6. Take note of the DNS name of the load balancer.

### Add a CNAME Record for the Subdomain

1. Go to Route 53 Service. Select __Hosted Zones__ and create a __new record__
2. Enter the subdomain in the __Record name__ 
3. Provide the load balancer DNS in __Value__.

### Clean up

1. Delete Ingress  
`kubectl delete -f ingress.yaml`
2. Exit the bastion host.
3. Destroy the terraform resources  
`terraform destroy`


### Images
**Welcome Page**<img src="./welcome-page.png">
**Login Page**<img src="./login-page.png">
**Logout Page**<img src="./logout-page.png">
