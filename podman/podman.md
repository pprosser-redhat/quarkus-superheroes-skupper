 # In demolab
 
 ## superheroes ui
```
podman run --name ui-superheroes -d -p 8080:8080 -e API_BASE_URL=http://10.50.2.97:8082 quay.io/quarkus-super-heroes/ui-super-heroes:latest
```
 
 
 ## fights db 
 
```
podman run --name fights-db -d -p 27017:27017  -e MONGO_INITDB_DATABASE=fights -e MONGO_INITDB_ROOT_USERNAME=super -e MONGO_INITDB_ROOT_PASSWORD=super mongo:5.0
```

To define the user and db....

```
podman exec -it --tty fights-db bash
```

```
mongosh --host 10.50.2.97 --port 27017 -u super -p super
```

```
use fights
```

```
db.createUser( { user: "superfight", pwd: "superfight", roles: [ { role: "readWrite", db: "fights" }] } )
```

## rest fights
```
podman run --name rest-fights -d -p 8082:8082 \
      -e QUARKUS_MONGODB_HOSTS=10.50.2.97:27017 \
      -e KAFKA_BOOTSTRAP_SERVERS=PLAINTEXT://localhost:9092 \
      -e QUARKUS_LIQUIBASE_MONGODB_MIGRATE_AT_START="false" \
      -e QUARKUS_MONGODB_CREDENTIALS_USERNAME="superfight" \
      -e QUARKUS_MONGODB_CREDENTIALS_PASSWORD="superfight" \
      -e QUARKUS_STORK_HERO_SERVICE_SERVICE_DISCOVERY_ADDRESS_LIST=10.50.1.127:8083 \
      -e QUARKUS_STORK_VILLAIN_SERVICE_SERVICE_DISCOVERY_ADDRESS_LIST=10.50.1.127:8084 \
      -e MP_MESSAGING_CONNECTOR_SMALLRYE_KAFKA_APICURIO_REGISTRY_URL=http://apicurio:8086/apis/registry/v2 \
      -e QUARKUS_OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://otel-collector:4317 \
      quay.io/quarkus-super-heroes/rest-fights:java17-latest
```

## heroes-db

We are deploying the heroes db in demolab to test out SQL across skupper. Proves TCP connectivity

```
podman run --name heroes-db -d -p 5432:5432 \
     -e POSTGRES_USER=superman \
     -e POSTGRES_PASSWORD=superman \
     -e POSTGRES_DB=heroes_database \
     postgres:14
```
Once skupper is configured, this is the command to expose the database

```
skupper expose host 10.50.2.97 --address heroes-db --port 5432 --target-port 5432
```

define to the private skupper

```
skupper service create heroes-db 5432 --host-ip 10.0.141.78 --host-port 5432
```

# In AWS

## rest-heroes native

When deploying rest-heroes, either the dns name or IP of private skupper address is required.... the remotely hosted DB will be exposed through the site.

```
podman run --name rest-heroes -d -p 8083:8083 \
     -e QUARKUS_DATASOURCE_REACTIVE_URL=postgresql://ip-10-0-141-78.eu-north-1.compute.internal:5432/heroes_database \
     -e QUARKUS_HIBERNATE_ORM_DATABASE_GENERATION=drop-and-create \
     -e QUARKUS_DATASOURCE_USERNAME=superman \
     -e QUARKUS_DATASOURCE_PASSWORD=superman \
     -e QUARKUS_HIBERNATE_ORM_SQL_LOAD_SCRIPT=import.sql \
     -e QUARKUS_OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://otel-collector:4317 \
     quay.io/quarkus-super-heroes/rest-heroes:native-latest
```



## Expose rest-heroes in AWS skupper router 

This will need to be done, tested, and removed before a demo to populate the database.

```
skupper expose host  ip-10-0-138-53.eu-north-1.compute.internal --address rest-heroes --port 8083 --target-port 8083 --host-ip 10.0.141.78
```

Probably don't need --host-ip, just using for local testing

## create service definition in demolab  for rest-heroes

```
skupper service create rest-heroes 8083 --host-ip 10.50.1.127 --host-port 8083
```

## villains db

```podman run --name villains-db -d -p 5432:5432 \
      -e POSTGRES_USER=superbad \
      -e POSTGRES_PASSWORD=superbad \
      -e POSTGRES_DB=villains_database \
      postgres:14
```
## rest villains 

```
podman run --name rest-villains -d -p 8084:8084 \
      -e QUARKUS_DATASOURCE_JDBC_URL=jdbc:postgresql://ip-10-0-131-3.eu-north-1.compute.internal:5432/villains_database \
      -e QUARKUS_HIBERNATE_ORM_DATABASE_GENERATION=drop-and-create \
      -e QUARKUS_DATASOURCE_USERNAME=superbad \
      -e QUARKUS_DATASOURCE_PASSWORD=superbad \
      -e QUARKUS_HIBERNATE_ORM_SQL_LOAD_SCRIPT=import.sql \
      -e QUARKUS_OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://otel-collector:4317 \
      quay.io/quarkus-super-heroes/rest-villains:native-latest
```

## expose rest-villains in skupper router

```
skupper expose host ip-10-0-131-3.eu-north-1.compute.internal --address rest-villains --port 8084 --target-port 8084
```

## create service definition in demolab for rest villains

```
skupper service create rest-villains 8084 --host-ip 10.50.1.127 --host-port 8084
```

## AWS VM's config

need to expose ports

45671
55671

every VM had limit problems. Had to run

sudo usermod --add-subgids 10000-75535 USERNAME

skupper init --ingress-host ec2-13-53-35-150.eu-north-1.compute.amazonaws.com

## setup podman for skupper to use 

systemctl --user enable podman.socket

loginctl enable-linger <USER>

systemctl --user start podman.socket

in each podman vm have to create mountd.conf (empty file) at  ~/.config/containers/mounts.conf

## install skupper cli

sudo subscription-manager register --username <user@redhat.com>
sudo subscription-manager config --rhsm.manage_repos=1
sudo subscription-manager list --available #Find the one for Service Interconnect.
sudo subscription-manager attach --pool=2c94876883ce67be0183d4e691d55e63 # Also, this command claims that it fails, but it actually works.
sudo subscription-manager repos --enable=service-interconnect-1-for-rhel-9-x86_64-rpms
sudo dnf install skupper-cli
