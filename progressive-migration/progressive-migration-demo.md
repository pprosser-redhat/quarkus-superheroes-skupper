# Progressive Migration Demo

## Prepare OCP 3 - Deploy the superheroes app

### create namespace

```
oc new-project superheroes
```

### Deploy the application

```
oc apply -f quarkus-superheroes-skupper/deploy/k8s/native-openshift.yml
```

## Prepare OCP 4 

Create a namespace to migrate the application to

```
oc new-project heroes
```

# Get terminal windows ready

To run the skupper cli, you need to have a RHEL machine. I use a RHEL vm on my laptop

## Open a terminal window 

Use SSH to login to the RHEL machine twice - one for ocp 3 and one for ocp4

### set the kubeconfig in terminal 1 to ocp3

```
export KUBECONFIG=$HOME/.kube/config-ocp3
```

### set the kubeconfig in terminal 2 to ocp4

```
export KUBECONFIG=$HOME/.kube/config-ocp4
```

# Start the demo 

## Instal Red Hat Service Interconnect

### in OCP 3 cluster

make sure you are logged into the cluster on using the "superheroes" project

install RHSI 

```
skupper init --site-name ocp3
```

check the status 

```
skupper status
```

### in OCP 4 cluster

```
skupper init --site-name ocp4 --enable-console --enable-flow-collector
```

check the status 

```
skupper status
```

## Link the Service Interconnect sites together

### link most private to most public 

linking demolab to ocp3

#### In OCP 3 create a token 

```
skupper token create ~/ocp3.yaml -t cert --name ocp3
```

Since we are using the same VM to access both clusters, the token is available in both windows.

#### In OCP 4, create the link 

```
skupper link create --name ocp4-to-ocp3  ~/ocp3.yaml
```

# Starting Migration the app - heroes db

### Track whats going on

Update the OCP 3 DB just so we can see what we are accessing

```
psql --dbname=heroes_database --host=heroes-db --username=superman --password
```
```
update hero SET othername='OCP3' where name = 'Chewbacca';
commit;
select id, name, othername from hero where name = 'Chewbacca';
```

Test out by curling the service 

```
oc exec deploy/skupper-router curl http://rest-heroes:80/api/heroes/1 |jq
```

## Make Heroes DB available in ocp4 

We are going to migrate the heroes service. The service has a dependency on a database that we will not migrate to start with so we need to make the heroes-db available to OCP 4 via the skupper network

(for demo, cli is preferred approach)
```
skupper expose deployment heroes-db --address heroes-db --port 5432
```

or

```
oc annotate deployment heroes-db "skupper.io/address=heroes-db" "skupper.io/port=5432" "skupper.io/proxy=tcp"

```


Test the DB using the little PostgreSQL pod 

Get a terminal window into the pod and try

```
psql --dbname=heroes_database --host=heroes-db --username=superman --password
```

followed by

```
select id, name, othername from hero;
select id, name, othername from hero where name = 'Chewbacca';
```

Test the service out to make sure it's ok and working with the existing DB

## Deploy the rest-heroes service to  OCP 4

Deploy the heros service and DB in OCP 4

```
oc apply -f ~/quarkus-superheroes-skupper/rest-heroes/deploy/k8s/native-openshift.yml
```

Test by using curl in the skupper router

**NOTE** use **oc get pods** to find skupper router instance

```
oc exec deploy/skupper-router curl http://rest-heroes:80/api/heroes/1 |jq
```


### make rest-heroes available to RHSI

expose the OCP4 version of rest heroes
(skupper cli preferred for demo)
```
skupper expose deploymentconfig rest-heroes --address rest-heroes --port 8083
```
or
```
oc annotate deploymentconfig rest-heroes "skupper.io/address=rest-heroes" "skupper.io/port=8083" "skupper.io/proxy=tcp"
```

Test the new service. 

### Scale down the replica on OCP 3
```
oc scale deploymentconfig rest-heroes --replicas=0
```
### Switch over the database

Unexpose the OCP 3 Db
```
skupper unexpose deployment heroes-db --address heroes-db
```

Because the service was created by SI it will be delete (deployment of service failed as it already exists). 

Need to create the service for heroes-db

```
oc expose deployment heroes-db
```

To show this working because of caching you migth need to restart the rest-heroes service on OCP4

```
oc scale deployment heroes-db --replicas=0
```

Test out the service using curl... the skupper router has curl in it

Need to get the correct pod name using "oc get pods"

```
oc exec deploy/skupper-router curl http://rest-heroes:8083/api/heroes/1 | jq
```

remove all heroes from OCP3

```
oc delete all -l application=heroes-service 
```

# Move Villains

### Run the script "deploy-villains.sh" on OCP4

```
sh ~/quarkus-superheroes-skupper/progressive-migration/deploy-villains.sh
```

### Test villains

```
oc exec -it deploy/skupper-router curl http://rest-villains:8084/api/villains
```

### Scale down Villains on OCP3

```
sh ~/quarkus-superheroes-skupper/progressive-migration/scaledown-villains.sh
```

### Remove Villains from OCP 3

```
sh ~/quarkus-superheroes-skupper/progressive-migration/remove-villains.sh
```

# Move Fights

### Deploy fights to OCP4

```
sh ~/quarkus-superheroes-skupper/progressive-migration/deploy-fights.sh
```

***Note*** Before testing, make sure you remove fights as this redoes the http route

### Remove fights from OCP3

```
sh quarkus-superheroes-skupper/progressive-migration/remove-fight.sh
```

# Switch over the User Interface

### Deploy the UI
```
sh quarkus-superheroes-skupper/progressive-migration/deploy-ui.sh
```

### Remove the UI

```
sh quarkus-superheroes-skupper/progressive-migration/remove-ui.sh
```

# clean up the Heroes namespace and remove all traces of Skupper

```
skupper unexpose deploymentconfig rest-heroes
skupper unexpose deploymentconfig rest-villains
skupper unexpose deploymentconfig rest-fights
```

```
skupper delete
```

# Other stuff
Just in case hit evicted pods 

```
oc get pod --all-namespaces  | awk '{if ($4=="Evicted") print "oc delete pod " $2 " -n " $1;}' | sh 
```

How to delete completed pods

```
oc delete pod --field-selector=status.phase==Succeeded --all-namespaces
```