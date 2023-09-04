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
skupper init --site-name ocp4 --enable-console --enable-flow-collector --console-auth openshift
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
oc exec skupper-router-7b6c78c885-7vttl curl http://rest-heroes:80/api/heroes/1 |jq
```

## Make Heroes DB available in ocp4 

We are going to migrate the heroes service. The service has a dependency on a database that we will not migrate to start with so we need to make the heroes-db available to OCP 4 via the skupper network

```
oc annotate deployment heroes-db "skupper.io/address=heroes-db" "skupper.io/port=5432" "skupper.io/proxy=tcp"

```
or 
```
skupper expose deployment heroes-db --address heroes-db --port 5432
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
update hero SET othername='OCP3' where name = 'Chewbacca';
update hero SET othername='OCP4' where name = 'Chewbacca';
```

- do this on the OCP 3 cluster and check results on OCP4 - Update Chewbacca other name so we can see which db we are hitting



Test the service out to make sure it's ok and working with the existing DB

## Deploy the Heroes service to  OCP 4

Deploy the heros service and DB in OCP 4

```
oc apply -f ~/quarkus-superheroes-skupper/rest-heroes/deploy/k8s/native-openshift.yml
```

Test by using curl in the skupper router

```
oc exec skupper-router-7b6c78c885-7vttl curl http://rest-heroes:80/api/heroes/1
```


### move the heros-service and make it available to RHSI

```
oc annotate deploymentconfig rest-heroes "skupper.io/address=rest-heroes" "skupper.io/port=8083" "skupper.io/proxy=tcp"
```

```
skupper expose deploymentconfig rest-heroes --address rest-heroes --port 8083
```

Scale down the replica on OCP 3
```
oc scale deploymentconfig rest-heroes --replicas=0
```
### Switch over the database

set the replicas to 1 for the heroes-db in OCP 4

```
oc scale deployment heroes-db --replicas=1
```

Test out the service using curl... the skupper router has curl in it

Need to get the correct pod name using "oc get pods"

```
oc exec -it skupper-router-559957cc8b-zphcs curl http://rest-heroes.superheroes.svc.cluster.local:80/api/heroes/1 |jq
```

Unexpose the database from OCP 3

```
skupper unexpose deployment heroes-db --address heroes-db
```

Scale OCP 3 heroes-db to 0

```
oc scale deployment heroes-db --replicas=0
```

remove all heroes from OCP3

```
oc delete all -l app=rest-heroes 
oc delete all -l app=rest-heroes
```

# Move Villains

Run the script "deploy-villains.sh" on OCP4

```
sh ~/quarkus-superheroes-skupper/progressive-migration/deploy-villains.sh
```

Test

```
oc exec -it skupper-router-559957cc8b-zphcs curl http://rest-villains:8084/api/villains
```

Scale down Villains on OCP3

```
sh ~/quarkus-superheroes-skupper/progressive-migration/scaledown-villains.sh
```

Remove Villains

```
sh ~/quarkus-superheroes-skupper/progressive-migration/remove-villains.sh
```

Deploy fights

```
sh ~/quarkus-superheroes-skupper/progressive-migration/deploy-fights.sh
```

this should switch the UI over to ocp4 service


Just in case hit evicted pods 

```
oc get pod --all-namespaces  | awk '{if ($4=="Evicted") print "oc delete pod " $2 " -n " $1;}' | sh 
```