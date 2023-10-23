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