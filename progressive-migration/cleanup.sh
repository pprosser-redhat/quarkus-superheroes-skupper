skupper unexpose deploymentconfig rest-heroes
skupper unexpose deploymentconfig rest-villains
skupper unexpose deploymentconfig rest-fights
skupper unexpose deployment heroes-db
oc expose deploymentconfig rest-villains --port 8084
skupper delete