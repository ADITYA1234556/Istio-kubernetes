# ISTIO
---
## Service Mesh
- Handles service to service communication.
- Service mesh is placed seperately as a single logical component in k8s cluster.
- Every request from one service to another service goes via service mesh.
- We can use monitoring tools like Prometheus, Grafana, Splunk, etc to monitor the service to service communication.
---

## SideCar, Proxy.
- Every application pod will have a SideCar container that helps the application to handle service to service communication.
- Proxy will receive all the requests and responses from application to client and application.
- Istio uses Service Mesh Proxy also called as Envoy Proxy, this is the side car container.
---

## Envoy Proxy
- Istio injects the side car container that is Envoy Proxy along with the application container.
- All the communication from one application continer to another application container goes via Envoy Proxy container present along with that application containers.
---

## Custom Resource Definitions CRD's
- Kind of objects in kubernetes clusters
---

## Installing istio
- <a href="https://istio.io/latest/docs/setup/getting-started/"> Istio Getting Started Documentation. </a>
### STEPS
1. **STEP 1: INSTALL BINARIES**
```bash
curl -L https://istio.io/downloadIstio | sh -
#PreCheck if it is the right source and hashes match
istioctl x precheck
cd istio-1.24.2
export PATH=$PWD/bin:$PATH
```
2. **STEP 2: INSTALL ISTIO**
- Profiles available = default/demo/minimal/remote
```bash
istioctl manifest apply --set profile=demo
#Verify
kubectl get pods -n istio-system
#To delete istio 
istioctl manifest generate --set profile=demo | kubectl delete -f -
```
3. **STEP 3: LABEL NAMESPACE FOR ISTIO TO DEPLOY SIDECAR CONTAINERS/ ENVOY PROXIES**
- Label the namespaces where the application pods are running and where you want the istio to be enabled.
- All pods created in the namespace will be created along with a side car container taken care of by istio.
```bash
kubectl create namespace production
kubectl label namespace production istio-injection=enabled
```



