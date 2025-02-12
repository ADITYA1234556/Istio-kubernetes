# Configuring Self-Hosted Kubernetes cluster to create a load balancer using metalb.

## Install Metalb
**Step 1: <a href="https://metallb.io/installation/">Install mettalb</a>**
```
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml
```

**Step 2: Configure Metallb**
```yaml
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: meta-lb-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.86.15-192.168.86.26
  autoAssign: true
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: meta-lb-pool
  namespace: metallb-system
```
```bash
kubectl apply -f metalb.yaml
```

**Step 3: Install ingress controller**
```bash
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set "controller.extraArgs.enable-ssl-passthrough=true"
```

**Step 4: Testing**
```bash
kubectl create deployment demo --image=httpd --port=80
kubectl expose deployment demo
kubectl create ingress demo-aditya --class=nginx --rule="demo.website.me/*=demo:80"
kubectl port-forward --namespace=ingress-nginx service/ingress-nginx-controller 8080:80
curl --resolve demo.website.me:8080:127.0.0.1 http://demo.website.me:8080
#<html><body><h1>It works!</h1></body></html>
```