def initTaskDefinition_FE(def BE_IMAGE_VER){
    steps.sh("VER=`cat VERSION` && sed -i \"s;IMAGE_FE;${IMAGE}:\$VER;g\" ${APP_TD}")
    steps.sh("sed -i \"s;IMAGE_BE;530328198985.dkr.ecr.eu-west-1.amazonaws.com/axiom-telecom/a2i-data-supplier-visibility-api-${ENV_NAME}:${BE_IMAGE_VER};g\" ${APP_TD}")
    steps.sh("sed -i \"s;APP_NAME_FE;${APP_NAME}-${ENV_NAME};g\" ${APP_TD}")
    steps.sh("sed -i \"s;NODENV;${ENV_NAME};g\" ${APP_TD}")
    steps.sh("sed -i \"s;APP_NAME_BE;a2i-data-supplier-visibility-api-${ENV_NAME};g\" ${APP_TD}")
    steps.sh("sed -i \"s;ORG_NAME;${ORG};g\" ${APP_TD}")
    steps.sh("sed -i \"s;PHASE;${PHASE};g\" ${APP_TD}")
    steps.sh("/var/lib/jenkins/assume-role.sh aws ecs register-task-definition --cli-input-json file://${APP_TD} --region eu-west-1")
}

def initTaskDefinition_BE(def FE_IMAGE_VER){
    steps.sh("VER=`cat VERSION` && sed -i \"s;IMAGE_BE;${IMAGE}:\$VER;g\" ${APP_TD}")
    //def BE_IMAGE = utilityData.getECRRepoLatestTag("axiom-telecom/a2i-data-supplier-visibility-${ENV_NAME}")
    steps.sh("sed -i \"s;IMAGE_FE;530328198985.dkr.ecr.eu-west-1.amazonaws.com/axiom-telecom/a2i-data-supplier-visibility-${ENV_NAME}:${FE_IMAGE_VER};g\" ${APP_TD}")
    steps.sh("sed -i \"s;APP_NAME_FE;a2i-data-supplier-visibility-${ENV_NAME};g\" ${APP_TD}")
    steps.sh("sed -i \"s;NODENV;${ENV_NAME};g\" ${APP_TD}")
    steps.sh("sed -i \"s;APP_NAME_BE;${APP_NAME}-${ENV_NAME};g\" ${APP_TD}")
    steps.sh("sed -i \"s;ORG_NAME;${ORG};g\" ${APP_TD}")
    steps.sh("sed -i \"s;PHASE;${PHASE};g\" ${APP_TD}")
    steps.sh("/var/lib/jenkins/assume-role.sh aws ecs register-task-definition --cli-input-json file://${APP_TD} --region eu-west-1")
}

def createTargetGroup(def tgNAME, def PORT){
    def command = """
    /var/lib/jenkins/assume-role.sh aws elbv2 create-target-group \
    --name ${tgNAME} \
    --protocol HTTP \
    --port ${PORT} \
    --matcher HttpCode=200-399 \
    --health-check-interval-seconds 120 \
    --health-check-timeout-seconds 90 \
    --target-type ip \
    --region eu-west-1 \
    --vpc-id "vpc-08556c49da6c6f3c1" \
    | jq -r '.TargetGroups[0].TargetGroupArn'
    """
    def proc = ['bash', '-c', command].execute()
    proc.waitFor()
    return proc.text
}

def isService(){
    def command = """
    /var/lib/jenkins/assume-role.sh aws ecs list-services \
    --region eu-west-1 \
    --cluster ${APP_NAME}-${ENV_NAME} \
    | grep ${APP_NAME}-${ENV_NAME}-service
    """
    def proc = ['bash', '-c', command].execute()
    proc.waitFor()
    if (proc.text.contains("${APP_NAME}-${ENV_NAME}")){
        return true
    }
    return false
}

def isServiceSupplier(){
    def command = """
    /var/lib/jenkins/assume-role.sh aws ecs list-services \
    --region eu-west-1 \
    --cluster ${APP_NAME}-${ENV_NAME} \
    | grep "a2i-data-supplier-visibility-${ENV_NAME}-service"
    """
    def proc = ['bash', '-c', command].execute()
    proc.waitFor()
    if (proc.text.contains("${APP_NAME}-${ENV_NAME}-service")){
        return true
    }
    return false
}

def getVersionSupplier(){
    def command = """
    /var/lib/jenkins/assume-role.sh aws ecs describe-task-definition \
    --region eu-west-1 \
    --task-definition a2i-data-supplier-visibility-${ENV_NAME} \
    | egrep "revision" \
    | tr "/" " " \
    | awk '{print \$2}' \
    | sed 's/"\$//'
    """
    def proc = ['bash', '-c', command].execute()
    proc.waitFor()
    def task_ver = proc.text.replace(',','').trim()
    return task_ver
}

def getVersion(){
    def command = """
    /var/lib/jenkins/assume-role.sh aws ecs describe-task-definition \
    --region eu-west-1 \
    --task-definition ${APP_NAME}-${ENV_NAME} \
    | egrep "revision" \
    | tr "/" " " \
    | awk '{print \$2}' \
    | sed 's/"\$//'
    """
    def proc = ['bash', '-c', command].execute()
    proc.waitFor()
    def task_ver = proc.text.replace(',','').trim()
    return task_ver
}
//def updateService(def VERSION){
//    steps.sh("/var/lib/jenkins/assume-role.sh aws ecs update-service \
//    --cluster ${APP_NAME} --service ${APP_NAME}-service \
//    --region eu-west-1 \
//    --task-definition ${APP_NAME}:${VERSION}")
//}


def updateService(def VERSION){
    steps.sh("/var/lib/jenkins/assume-role.sh aws ecs update-service \
    --cluster a2i-data-supplier-visibility-${ENV_NAME} --service a2i-data-supplier-visibility-${ENV_NAME}-service \
    --region eu-west-1 \
    --task-definition a2i-data-supplier-visibility-${ENV_NAME}:${VERSION}")
}

def createLB(){
    def command = """
    /var/lib/jenkins/assume-role.sh aws elbv2 create-load-balancer \
    --name ${APP_NAME}-${ENV_NAME} \
    --scheme internet-facing \
    --subnets subnet-0af1631fcb0f3dfaf subnet-0c2fb07ba10716188 \
    --region eu-west-1 \
    | jq -r '.LoadBalancers[0].LoadBalancerArn'
    """
    def proc = ['bash', '-c', command].execute()
    proc.waitFor()
    return proc.text
}

def createListener(def tgARN1, def PORT, def lbARN, def PROTO){
    lbARN = lbARN.trim()
    tgARN1 = tgARN1.trim()
    steps.sh("/var/lib/jenkins/assume-role.sh aws elbv2 create-listener \
    --load-balancer-arn ${lbARN} \
    --protocol ${PROTO} \
    --certificates CertificateArn=arn:aws:acm:eu-west-1:530328198985:certificate/641c3223-4c97-44d5-ab80-663af6db2a60 \
    --port ${PORT} \
    --region eu-west-1 \
    --default-actions Type=forward,TargetGroupArn=${tgARN1}")
 }
 
def createService(def tgARN1, def tgARN2){
    tgARN1 = tgARN1.trim()
    tgARN2 = tgARN2.trim()
    steps.sh("/var/lib/jenkins/assume-role.sh aws ecs create-service \
    --launch-type \"FARGATE\" \
    --load-balancers targetGroupArn=${tgARN1},containerName=${APP_NAME}-${ENV_NAME},containerPort=3001 \
    targetGroupArn=${tgARN2},containerName=${APP_NAME}-api-${ENV_NAME},containerPort=3003 \
    --cluster ${APP_NAME}-${ENV_NAME} \
    --service-name ${APP_NAME}-${ENV_NAME}-service \
    --task-definition ${APP_NAME}-${ENV_NAME} \
    --desired-count 1 \
    --region eu-west-1 \
    --network-configuration \"awsvpcConfiguration={subnets=[subnet-047c2eddab2f30af3,subnet-0d10cea26a7f8ef7c],securityGroups=[sg-00fb97e76f62f4b5c]}\"")
}

def createCluster(){
    steps.sh("/var/lib/jenkins/assume-role.sh aws ecs create-cluster --cluster-name ${APP_NAME}-${ENV_NAME} --region eu-west-1")
}