# Superheroes and Skupper demo

This demo focuses on Skupper configuration, Service Federatation and Remote database

## Introduction

The purpose of this demo is to show how easy it is to setup Skupper. I choose to use the Superheroes demo because its microservice architecure. It makes it very to use Skupper with.

The demo uses 2 OpenShift clusters, really doesn't matter which or where you deploy them. Clearly, the bigger the seperation, the more effective the demo is. I also use a local database running on my laptop.

Here is an architecture diagram of the application:
![Superheroes architecture diagram](images/application-architecture.png)

Here is how the distribution will be set up:
![Network distribution diagram](images/remote-db.png)
I have chosen to split the villain service out on to a seperate cluster using Skupper and exposing the service. 

For the Heroes service.... I have hosted a mysql DB on my laptop that containes a table with the data in.

The demo will use a Skupper Gateway to expose the mysql DB to the Skupper Virutal application network.

Having exposed the database, Debezium is used to replicated the database, and then replicate changes to Kafka (either running on the OpenShift cluster, or usinf RHOSAK).

A small Camel K Integration will read the messages from Kafka and route them to the Postgres DB, allowing the full application to work.

## Setting up the Demo

This demo using the following 

AWS <---------- My Laptop ----------> Azure

Everything routes through the laptop..

### Deploy 2 OpenShift clusters

Choose one of the 2 clusters to host the Superheroes fight game. Typically choose the most public cluster if you have one.

I'm normally using AWS hosted and Azure

### Deploy the demo

Clone this repo so you can run the commands locally

#### Create the superheroes namespace in the Azure cluster

```
oc new-project superheroes
```

#### Deploy the application into the superheroes namespace (In Azure)

* clone the repository (note - change to use the stand demo rather than my own fork)

  ```
  git clone https://github.com/quarkusio/quarkus-super-heroes.git
  ```

* deploy the whole application into the superheroes namespace

   cd to the root of the cloned project

   ```
   oc apply -f deploy/k8s/native-openshift.yml
   ```

   remove the villain service so it can be deployed in the other cluster

   ```
   oc delete all -l app.kubernetes.io/part-of=villains-service
   ```

   remove the heroes database
   ```
   oc delete all -l app=heroes-db
   oc delete all -l name=heroes-db 
   ```

   update the "rest-heroes-config" configmap
   
   change the property quarkus.hibernate-orm.database.generation=validate

   to

   quarkus.hibernate-orm.database.generation=none

#### deploy the villain service to the 2nd OpenShift cluster (AWS)

  oc to the second cluster

  create a new namespace 

  ```
  oc new-project villains
  ```

  deploy the villain service

  ```
  oc apply -f rest-villains/deploy/k8s/native-kubernetes.yml
  ```

  Demo code should all now be deployed

In the terminal windows you are using for the skupper cli, ensure you set KUBECONFIG

For the AWS cloud site use :-
```
export KUBECONFIG=$HOME/.kube/config-aws
```

For the Azure env use :-

```
export KUBECONFIG=$HOME/.kube/config-azure
```
For the Virtual machine environment export
```
export SKUPPER_PLATFORM=podman
```
# Demo Instructions

## Open up the superheroes UI in a Browser

```
http://ui-super-heroes-superheroes.apps.ocp4-vfg9f-ipi.azure.opentlc.com
```
Check that the app is in a fallback situation

## Open up the Rest Heroes UI in a Browser

```
http://rest-heroes-superheroes.apps.ocp4-vfg9f-ipi.azure.opentlc.com
```
It should fail (the service cannot access it's DB)

## Initialise Skupper in VM with podman sites

For podman site

```
skupper system install
```
```
skupper site create my-laptop-podman
```
```
skupper system reload
```


## Initialise Skupper in each namespace

For AWS
```
skupper site create aws --enable-link-access
```
For Azure 
```
skupper site create azure --enable-link-access
```

## Generate tokens for both AWS and Azure

In the VM, make sure you are in the tokens folder. This ensures sharing of the tokens between the SSH sessions.

In AWS window
```
skupper token issue podman-aws.yaml
```

In Azure window
```
skupper token issue podman-azure.yaml
```




## Link the sites together (most private to the most public)

Once connected, the VM will appear

AWS <---------- My Laptop ----------> Azure


In Virtual machine window link podman to AWS
```
skupper token redeem podman-aws.yaml
```
```
skupper system reload
```
Make sure the link has been established by running (in the VM)

```
skupper link status
```

In Virtual machine window link podman to Azure
```
skupper token redeem podman-azure.yaml
```
```
skupper system reload
```

Make sure the link has been established by running (in the VM)

```
skupper link status
```

Check what the sites look like in the RHSI console

Make sure the superheroes ui is still falling back

## Expose  the villain service on the Villains side

Link up the Villains service so that the superheroes ui starts showing real villains

```
skupper connector create rest-villains 8084 --workload deployment/rest-villains
```
```
skupper connector status
```

On the other cluster, create the listener

```
skupper listener create rest-villains 8084
```

If you want, an alternative way to expose is by defining an annotation to the deployment

```
skupper.io/proxy: tcp
```
Check the game, villains should start appearing.... might need to refresh the page.

## Expose my legacy laptop data using the VM based podman site


### Expose my database

If running in a VM in another env, need to work out IP
```
skupper connector create heroes-db 5432 --host 10.0.2.2
```
```
skupper system reload
```

Run (might need to run it a few times - it's creating the pods)

```
skupper connector status
```

The reload means you need to wait for the links to come back up.

```
skupper link status
```

## Create the service in the Superheroes OpenShift

```
skupper listener create heroes-db 5432
```

## For fun, you can make the villains api available to the VM to curl to it

```
skupper listener create rest-villains 8084 --host 192.168.58.4
```
```
skupper system reload 
```
```
skupper links status
```

On the command line do a curl 

```
curl http://rhel9:8084/api/villains |jq
```
## note for using podman sites, if you use a podman site to expose the DB then it doesn't seen to like working through vbox gateway to using postgres in the VM. Connection this way looks like 
```
skupper expose host rhel8 --address heroes-db  --port 5432 --target-port 6543 --host-ip 192.168.58.4
```

Test that I can connect to to DB, in a postgres pod on the villains project

```
psql --dbname=heroes_database --host=heroes-db --username=superman --password
```
```
select id, name, othername from hero;
select id, name, othername from hero where name = 'Chewbacca';
```

Access from the podman vm

```
podman exec -it heroes-db bash
```

change data

```
update hero set othername = 'Phil' where name='Chewbacca';
```
