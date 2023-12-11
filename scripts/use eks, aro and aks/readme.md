
skupper init --site-name aro --console-auth openshift
skupper init --site-name intel --console-auth openshift
skupper init --site-name aks --console-user admin --console-password admin

For aks or eks need to add this to the skupper deployment (goes at the same level as container)
      imagePullSecrets:
        - name: 11212394-eks-pull-secret


skupper gateway expose heroes-db 10.0.2.2 5432 --protocol tcp --type podman
skupper gateway forward rest-villains 8084 --loopback

psql --dbname=heroes_database --username=superman --host=heroes-db --password

select id, name, othername from Hero order by id;

SELECT id, name, othername FROM public.hero WHERE name='Chewbacca';

curl http://127.0.0.1:8084/api/villains |jq

kubectl config set-context --current --namespace=heroes


To pull the skuppper images you need to define a pull secret for the namespace to use. The secret allows access to the RH container registry

kubectl edit serviceaccount/default
kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "11212394-eks-pull-secret"}]}'

and paste imagePullSecrets at root level of the yaml, like this

apiVersion: v1
kind: ServiceAccount
metadata:
  creationTimestamp: "2023-02-15T17:53:05Z"
  name: default
  namespace: heroes
  resourceVersion: "92532"
  uid: 5440e392-7799-46b5-80a4-e5192794f0af
imagePullSecrets:
  - name: 11212394-eks-pull-secret


----------------
Getting messaging working
---------------
Run the broker on RHEL 8

bin/artemis run

skupper gateway expose messaging 0.0.0.0 5672

create a consumer on RHEL8

./artemis consumer --destination queue://exampleQueue  --message-count 1000  --url p://localhost:61616 --verbose

Run the camel k integration - messaging.camel.yaml
skupper gateway unexpose messaging


When using eks, need to init skupper with a user id 

```
skupper init --site-name eks --run-as-user 2000
```

Also need to predefine the skupper service accounts along with the skupper-site cm and trhe skupper-services cm