# Demo goals

This is a simple demo that shows the connection of an application running on OpenShift to a database that's running on premises. 

You have 2 options for the demo.

1. Connect direct from Laptop to OpenShift running the app
2. Connect threough a pass through OpenShift router cluster

If the demo is really trying to show the sending of TCP messages over non-routeable networks then a pass through router helps

# Prepare Environment 

Ensure that both RHSI Operators are installed in the clusters


Make sure you have installed the RHSI Network Observer into the Superheroes project


Create a namespace in OpenShift called superheroes.

```
oc new-project superheroes
```

Deploy the whole of the superheroes application the superheroes namespace

```
oc apply -f deploy/k8s/native-openshift.yml
```

To enable us to suport the remote database, lets remove the heroes database from the superheroes namespace

```
oc delete all -l app=heroes-db
oc delete all -l name=heroes-db
```

If you think you want to do some SQL testing as well, make sure you have install a PSQL DB so you can get access to the CLI


## Direct Connection

This demo will use an OpenShift Cluster and a VM running Podman sites on my laptop

Ensure the latest version of Skupper is installed in the RHEL VM.

It's best to use 2 terminal windows for this demo.

1. OpenShift skupper

Ensure you are logged into the cluster
and set

```
export SKUPPER_PLATFORM=kubernetes
```

2. RHEL Skupper

```
export SKUPPER_PLATFORM=podman
```


## Pass through router


This demo will use an 2 OpenShift Clusters and a VM running Podman sites on my laptop. The purpose here to simulate being about to route through a site as if it was in a DMZ for example.

Need to set up 2 OpenShift clusters, typically use OpenShift in different regions




Create a namespace called router-site

```
oc new-project router-site
```

To save confusion, use 3  terminals

Far right terminal - Superheroes
Middle - Passthrough Router
Left - Podman 

In the right hand side terminal window, log into the OpenShift cluster

```
oc project superheroes
```
set the contenxt
```
export KUBECONFIG=$HOME/.kube/config-superheroes
```
Then log into the cluster

In the middle terminal window 

```
oc project router-site
```
set the contenxt
```
export KUBECONFIG=$HOME/.kube/config-router
```
Then login into the cluster


# The demo with direction connection

## Configure OpenShift Skupper

Use the OpenShift terminal window

Install Skupper on OpenShift 

```
skupper site create superheroes --enable-link-access
```

Confirm the sites status

```
skupper site status
```

It should say that superheroes is Ready and OK

## Configure Podman Skupper

Use the Podman terminal window

Install Skupper on RHEL with Podman

```
skupper system install
```

Create a podman site called laptop

```
skupper site create laptop 
```

To make the site active, you have to reload the system

```
skupper system reload
```

Confirm the site status

```
skupper site status
```

It should say that laptop is Ready and OK.

## Create the link between the sites

### create the token on OpenShift

On the OpenShift site 

```
skupper token issue superheroes-token.yaml
```

### Redeem the token in Podman

On the Podman site

```
skupper token redeem superheroes-token.yaml
```

Reload the site

```
skupper system reload
```

Check the status of the link

```
skupper link status
```

Note: It can take a couple of minutes for the link to establish

Once completed look at the RHSI monitoring tool to see the link


## Create the Connector to the laptop database

On the Podman site 

```
skupper connector create heroes-db 5432 --host 10.0.2.2 --routing-key heroes-db
```

Reload the system

```
skupper system reload
```

## Create the listener on OpenShift

On the OpenShift side

```
skupper listener create heroes-db 5432
```

Check the listener status

```
skupper listener status 
```

Note: can take a while to update. Try the app anyway


[If you want to test with SQL](#testing-with-sql)

# The demo with pass through connection

## Configure OpenShift Superheroes Skupper

Use the OpenShift terminal window

Install Skupper on OpenShift 

```
skupper site create superheroes --enable-link-access
```

Confirm the sites status

```
skupper site status
```

It should say that superheroes is Ready and OK

## Configure OpenShift router-site Skupper

Use the OpenShift terminal window

Install Skupper on OpenShift 

```
skupper site create pass-through --enable-link-access
```

Confirm the sites status

```
skupper site status
```

It should say that pass-through is Ready and OK

## Connect superheroes to pass through

On the pass through router, issue a token 

```
skupper token issue superheroes-token.yaml
```

On the superherpes router, redeem the token

```
skupper token redeem superheroes-token.yaml
```

## Configure Podman Skupper

Use the Podman terminal window

Install Skupper on RHEL with Podman

```
skupper system install
```

Create a podman site called laptop

```
skupper site create laptop 
```

To make the site active, you have to reload the system

```
skupper system reload
```

Confirm the site status

```
skupper site status
```

It should say that laptop is Ready and OK.

## Create the link to the pass-through site

### create the token on pass-throgh OpenShift

On the OpenShift site 

```
skupper token issue pass-through-token.yaml
```

### Redeem the token in Podman

On the Podman site

```
skupper token redeem pass-through-token.yaml
```

Reload the site

```
skupper system reload
```

Check the status of the link

```
skupper link status
```

Note: It can take a couple of minutes for the link to establish

Once completed look at the RHSI monitoring tool to see the link


## Create the Connector to the laptop database

On the Podman site 

```
skupper connector create heroes-db 5432 --host 10.0.2.2 --routing-key heroes-db
```

Reload the system

```
skupper system reload
```

## Create the listener on Superheroes OpenShift

On the OpenShift side

```
skupper listener create heroes-db 5432
```

Check the listener status

```
skupper listener status 
```

Note: can take a while to update. Try the app anyway

[If you want to test with SQL](#testing-with-sql)

## Testing with SQL

You can also test with psql if you want. 

Install a psql db into superheroes (just so you have access to psql)

In the containers terminal window... type 

```
psql --dbname=heroes_database --host=heroes-db --username=superman --password
```

run some SQL

```
select id, name, othername from hero;
select id, name, othername from hero where name = 'Chewbacca';
```