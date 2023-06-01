oc delete kafkaconnector phils-connector
oc delete kafkaconnect my-connect-cluster 
oc delete kafka my-cluster
oc delete kafkatopic -l strimzi.io/cluster=my-cluster

# reset heroes DB

export POD=$(oc get pods -l name=heroes-db -n superheroes -o jsonpath="{.items[0].metadata.name}")
oc exec -it $POD -n default -- bash -c 'export PGUSER=superman ; export PGPASSWORD=superman ; export PGDATABASE=heroes_database ; export PGHOST=heroes-db.default.svc.cluster.local ; psql -c "delete from hero;"'