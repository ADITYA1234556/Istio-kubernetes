# AWS EKS Infrastructure using terraform

## **Step 1: Host the infrastructure**
```terraform
terraform init
terraform fmt
terraform plan --out=tfplan
terraform apply tfplan
```

## **Step 2: Update the cluster to your current context in kubernetes ./kube/config**
```bash
aws eks update-kubeconfig --region $REGION --name $CLUSTERNAME
```

## **Step 3: Install istio components in the cluster**
- <a href="https://istio.io/latest/docs/setup/getting-started/">Istio Installation guide </a>
```bash
istioctl install --set profile=demo -y
#After installation
kubectl config set-context --current --namespace=istio-system
kubectl get pods
#Install istio addons like Kiali, Grafana, Prometheus
kubectl create -f /istio-addons/.
```
- Ingress gateway manages incoming traffic.
- Egress gateway manages outgoing traffic.
- <img src="https://github.com/ADITYA1234556/Istio-kubernetes/blob/master/istio-architecture.png"> Istio Architecture </img>

## **Step 4: Deploy the application**
```bash
kubectl create namespace production
kubectl label namespace production istio-injection=enabled
kubectl describe namespace production
kubectl apply -f application.yaml -n production
kubectl config set-context --current --namespace=production
kubectl get pods
kubectl get service 
```

## **Step 5: Configure security group on EKS cluster to allow Incoming traffic on port 80 and 443**

## **Step 6: Create Gateways and Virtual Service**
```bash
kubectl create -f kialivs.yaml
```
- access the kiali UI at elb/kiali
- access the grafana UI at elb/grafana
- access the prometheus UI at elb/prometheus

## **Step 7: Cleanup**
```terraform
terraform destroy --auto-approve
```
