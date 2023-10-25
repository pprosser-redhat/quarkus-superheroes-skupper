# Demo goals

This is a simple demo that shows the connection of an application running on OpenShift to a database that's running on premises. It will use a "pass through" router to demonstate show easy it is to conenect truely across non-routeabe networks. 

# Prepare Environment 

In the current release I'll use 2 OpenShift clusters and my laptop for the database. Whilst podman sites is in tech preview, I use the RHSI gateway so we see things happening in the console.

Need to set up 2 OpenShift clusters, typically I use one in the cloud and one on our demolab env.

Install the super heroes Hero service into the demolab OpenShift

```
oc apply -f native-openshift.yml
```

Remove the database

```
oc delete all -l app=heroes-db
```

Install a standalone Postgresql DB into the namespace so we can do some SQL queries

Install RHSI into the middle (routing) OpenShift to save time during the demo

Using a project called router

---
** NOTE ** Make sure to use a RHEL VM for the skupper cli and gateway
---
```
skupper init --site-name cloud --enable-console --enable-flow-collector
```

Slightly different path for testing policy

Do all of this as cluster admin

if you would rather use the operator and apply a policy then in the cloud cluster install the Service Interconnect operator as cluster admin 

Deploy the policy CRD as cluster admin

```
wget https://raw.githubusercontent.com/skupperproject/skupper/1.4/api/types/crds/skupper_cluster_policy_crd.yaml
oc apply -f skupper_cluster_policy_crd.yaml
```

Define a clusterrolebinding for the router namespace
```
oc create clusterrolebinding skupper-service-controller-router --clusterrole=skupper-service-controller --serviceaccount=router:skupper-service-controller
```

define a simple policy to allowlinks only to the cloud site

```
apiVersion: skupper.io/v1alpha1
kind: SkupperClusterPolicy
metadata:
  name: mypolicy
spec:
  namespaces:
    - "router"
  allowIncomingLinks: true
  allowedServices:
    - "heroes-db"
```

To create the site, create the following configmap

```
apiVersion: v1
kind: ConfigMap
metadata:
  name: skupper-site
  namespace: router
data:
  console: "true"
  flow-collector: "true"
  console-user: "admin"
  console-password: "changeme"
  name: "cloud"
  ```


To extract the admin password

```
oc extract secret/skupper-console-users -n router --to=-
```

Set up terminal windows and use a kubeconfig to access the correct clusters

For demolab use
```
export KUBECONFIG=$HOME/.kube/config-demolab
```

for cloud and the gateway use
```
export KUBECONFIG=$HOME/.kube/config-cloud
```

# The demo

Install RHSI into the On premises side 

```
skupper init --site-name onprem
```

Install into my VM

```
skupper gateway init --type podman
```

Create the token on the cloud OpenShift Cluster

```
skupper token create ~/cloud.yaml -t cert --name cloud
```

Link on premises to cloud using the generate cert above

```
skupper link create --name onprem-to-cloud  ~/cloud.yaml
```

Expose the database to RHSI in the laptop VM

```
skupper gateway expose heroes-db 10.0.2.2 5432 --protocol tcp --type podman
```

if you are using policies in the cloud site then expose will not work due to services not being allowed in the cloud site.

You have to use 2 steps. In the on-premises side do

```
skupper service create heroes-db 5432
```

and then on the gateway side do

```
skupper gateway bind heroes-db 10.0.2.2 5432
```

Test the app out should be working 

Look at the networking routes it's created

Take a look round the RHSI console 

Try running SQL against the DB 

Test that I can connect to to DB, in a postgres pod on the villains project

```
psql --dbname=heroes_database --host=heroes-db --username=superman --password
```
```
select id, name, othername from hero;
select id, name, othername from hero where name = 'Chewbacca';
```