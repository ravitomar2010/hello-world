def installChart(){
    steps.sh("helm upgrade --install \${APP_NAME}-\${ENV_NAME} axiom-chartmuseum/java-gradle --version 0.25 \
    --set service.internalPort=8080 \
    --set image.repository=\${DOCKER_REGISTRY_ORG}/\${ORG}/\${APP_NAME} \
    --set image.tag=\$(cat VERSION) \
    --set service.name=\${APP_NAME} \
    --set deployment.env=\${ENV_NAME} \
    --set probePath=/\${APP_NAME}/actuator/health \
    --set env.ELASTIC_APM_SERVICE_NAME=\${APP_NAME} \
    --set env.ELASTIC_APM_ENVIRONMENT=\${ENV_NAME} \
    --set env.ELASTIC_APM_SERVER_URLS=http://apm-server.monitoring.svc.cluster.local:8200 \
    --set env.SPRING_PROFILE=\${ENV_NAME} \
    --set env.CONFIG_URL=http://config-server.hykeapi.com \
    --set env.CONFIG_PROFILE=\${ENV_NAME} \
    --set env.PORT=8080 \
    --namespace hyke-\${ENV_NAME}")
    steps.sh("sleep 5 && bash check_deploy.sh -n hyke-\${ENV_NAME} -t 500 \${APP_NAME}")
}

def installGradleIstioChart(){
    steps.sh("helm upgrade --install \${APP_NAME}-\${ENV_NAME} axiom-chartmuseum/java-gradle-istio-mesh --version 0.4 \
    --set service.internalPort=8080 \
    --set image.repository=\${DOCKER_REGISTRY_ORG}/\${ORG}/\${APP_NAME} \
    --set image.tag=\$(cat VERSION) \
    --set service.name=\${APP_NAME} \
    --set service.version=v1 \
    --set deployment.env=\${ENV_NAME} \
    --set probePath=/\${APP_NAME}/actuator/health \
    --set env.ELASTIC_APM_SERVICE_NAME=\${APP_NAME} \
    --set env.ELASTIC_APM_ENVIRONMENT=\${ENV_NAME} \
    --set env.ELASTIC_APM_SERVER_URLS=http://apm-server.monitoring.svc.cluster.local:8200 \
    --set env.SPRING_PROFILE=\${ENV_NAME} \
    --set env.CONFIG_URL=http://config-server.hykeapi.com \
    --set env.CONFIG_PROFILE=\${ENV_NAME} \
    --set env.PORT=8080 \
    --namespace hyke-\${ENV_NAME}")
    steps.sh("sleep 5 && bash check_deploy.sh -n hyke-\${ENV_NAME} -t 500 \${APP_NAME}")
}

def installerpGradleIstioChart(){
    steps.sh("helm upgrade --install \${APP_NAME}-\${ENV_NAME} axiom-chartmuseum/java-gradle-istio-mesh --version 0.5 \
    --set service.internalPort=8080 \
    --set image.repository=\${DOCKER_REGISTRY_ORG}/\${ORG}/\${APP_NAME} \
    --set image.tag=\$(cat VERSION) \
    --set service.name=\${APP_NAME} \
    --set service.version=v1 \
    --set deployment.env=\${ENV_NAME} \
    --set probePath=/\${APP_NAME}/actuator/health \
    --set env.ELASTIC_APM_SERVICE_NAME=\${APP_NAME} \
    --set env.ELASTIC_APM_ENVIRONMENT=\${ENV_NAME} \
    --set env.ELASTIC_APM_SERVER_URLS=http://apm-server.monitoring.svc.cluster.local:8200 \
    --set env.SPRING_PROFILE=\${ENV_NAME} \
    --set env.CONFIG_URL=http://config-server.hykeapi.com \
    --set env.CONFIG_PROFILE=\${ENV_NAME} \
    --set env.PORT=8080 \
    --namespace erp-\${ENV_NAME}")
    steps.sh("sleep 5 && bash check_deploy.sh -n erp-\${ENV_NAME} -t 500 \${APP_NAME}")
}

def installProdGradleIstioChart(){
    utility.createKubeConfigProd()
    steps.sh("helm upgrade --install \${APP_NAME}-\${ENV_NAME} axiom-chartmuseum/java-gradle --version 0.25 \
    --set service.internalPort=8080 \
    --set image.repository=\${DOCKER_REGISTRY_ORG}/\${ORG}/\${APP_NAME} \
    --set image.tag=\$(cat VERSION) \
    --set service.name=\${APP_NAME} \
    --set service.version=v1 \
    --set deployment.env=\${ENV_NAME} \
    --set probePath=/\${APP_NAME}/actuator/health \
    --set env.ELASTIC_APM_SERVICE_NAME=\${APP_NAME} \
    --set env.ELASTIC_APM_ENVIRONMENT=\${ENV_NAME} \
    --set env.ELASTIC_APM_SERVER_URLS=http://apm-server-monitoring.monitoring.svc.cluster.local:8200 \
    --set env.SPRING_PROFILE=\${ENV_NAME} \
    --set env.CONFIG_URL=http://config-prod.hykeapi.com \
    --set env.CONFIG_PROFILE=\${ENV_NAME} \
    --set env.PORT=8080 \
    --namespace hyke-\${ENV_NAME} \
    --kubeconfig /var/lib/jenkins/.kube/config_prod")
    steps.sh("export KUBECONFIG=/var/lib/jenkins/.kube/config_prod && sleep 5 && bash check_deploy.sh -n hyke-\${ENV_NAME} -t 500 \${APP_NAME}")
}

def installNodeChart(){
    steps.sh("helm upgrade --install \${APP_NAME}-\${ENV_NAME} axiom-chartmuseum/javascript \
    --set service.internalPort=3001 \
    --set image.repository=\${DOCKER_REGISTRY_ORG}/\${ORG}/\${APP_NAME} \
    --set image.tag=\$(cat VERSION) \
    --set service.name=\${APP_NAME} \
    --set deployment.env=\${ENV_NAME} \
    --set env.PHASE=\${PHASE} \
    --set probePath=/ \
    --set env.SPRING_PROFILE=\${ENV_NAME} \
    --set env.CONFIG_URL=http://config-server.hykeapi.com \
    --set env.CONFIG_PROFILE=\${ENV_NAME} \
    --set env.PORT=3001 \
    --set resources.limits.cpu=900M \
    --set resources.limits.memory=800Mi \
    --namespace hyke-${ENV_NAME}")
    steps.sh("sleep 5 && bash check_deploy.sh -n hyke-\${ENV_NAME} -t 450 \${APP_NAME}")
}

def installProdNodeChart(){
    utility.createKubeConfigProd()
    steps.sh("helm upgrade --install \${APP_NAME}-\${ENV_NAME} axiom-chartmuseum/javascript \
    --set service.internalPort=3001 \
    --set image.repository=\${DOCKER_REGISTRY_ORG}/\${ORG}/\${APP_NAME} \
    --set image.tag=\$(cat VERSION) \
    --set service.name=\${APP_NAME} \
    --set deployment.env=\${ENV_NAME} \
    --set env.PHASE=\${PHASE} \
    --set probePath=/ \
    --set env.SPRING_PROFILE=\${ENV_NAME} \
    --set env.CONFIG_URL=http://config-prod.hykeapi.com \
    --set env.CONFIG_PROFILE=\${ENV_NAME} \
    --set env.PORT=3001 \
    --set resources.limits.cpu=900M \
    --set resources.limits.memory=800Mi \
    --namespace hyke-${ENV_NAME} \
    --kubeconfig /var/lib/jenkins/.kube/config_prod")
    steps.sh("export KUBECONFIG=/var/lib/jenkins/.kube/config_prod && sleep 5 && bash check_deploy.sh -n hyke-\${ENV_NAME} -t 450 \${APP_NAME}")
}

def installProdErpChart(){
    utility.createKubeConfigErpProd()
    steps.sh("helm upgrade --install \${APP_NAME}-\${ENV_NAME} axiom-chartmuseum/java-gradle-erp --version 0.1 \
    --set service.internalPort=8080 \
    --set image.repository=\${DOCKER_REGISTRY_ORG}/\${ORG}/\${APP_NAME} \
    --set image.tag=\$(cat VERSION) \
    --set service.name=\${APP_NAME} \
    --set service.version=v1 \
    --set deployment.env=\${ENV_NAME} \
    --set probePath=/\${APP_NAME}/actuator/health \
    --set env.ELASTIC_APM_SERVICE_NAME=\${APP_NAME} \
    --set env.ELASTIC_APM_ENVIRONMENT=\${ENV_NAME} \
    --set env.ELASTIC_APM_SERVER_URLS=http://apm-server.axiom-erp-monitoring.svc.cluster.local:8200 \
    --set env.SPRING_PROFILE=\${ENV_NAME} \
    --set env.CONFIG_URL=http://config-axiom.hykeapi.com \
    --set env.CONFIG_PROFILE=\${ENV_NAME} \
    --set env.PORT=8080 \
    --namespace axiom-erp-\${ENV_NAME} \
    --kubeconfig /var/lib/jenkins/.kube/config_erp_prod")
    steps.sh("export KUBECONFIG=/var/lib/jenkins/.kube/config_erp_prod && sleep 5 && bash check_deploy.sh -n axiom-erp-\${ENV_NAME} -t 450 \${APP_NAME}")
}