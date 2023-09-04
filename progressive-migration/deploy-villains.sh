# deploy the villains app into OCP4
oc apply -f quarkus-superheroes-skupper/rest-villains/deploy/k8s/native-openshift.yml
# expose the villains service to OCP4
skupper expose deploymentconfig rest-villains --address rest-villains --port 8084

