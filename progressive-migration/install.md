# Install demo

## Install OpenShift 3

Installed using RHPDS worrkshop - https://demo.redhat.com/catalog?item=babylon-catalog-prod/sandboxes-gpte.ocp-ocs-migration-sb.prod&utm_source=webapp&utm_medium=share-link

## Install OpenShift 4

I've choosen to use demolab for this, however, any OCP 4 env will do

## Deploy superheroes into OpenShift 3

```
oc apply -f deploy/k8s/native-openshift.yml
```

## Install a little PostgreSQL db in OCP4

This is just to test the SQL connect back to OCP 3