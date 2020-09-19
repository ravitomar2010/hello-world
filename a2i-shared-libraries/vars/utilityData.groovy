import groovy.json.JsonBuilder
import groovy.json.JsonSlurper
import java.text.SimpleDateFormat

def cleanWorkspace()
    {
        echo "Cleaning up ${WORKSPACE}"
        // clean up our workspace
        //deleteDir()
        sh """
            sudo rm -rf ${WORKSPACE}
        """
        // clean up tmp directory
        //dir("${workspace}@tmp") {
        //    deleteDir()
        //}
    }

def getBranchName(branchName)
{

  //echo 'Pulling... ' + env.GIT_BRANCH
  return sh(echo $branchName | cut -d '/' -f2)
}

def getExecutionDay()
    {
        def date = new Date()
        def sdf = new SimpleDateFormat("EE")
        return sdf.format(date)
    }

def lastCommit()
    {
        // value = sh(returnStdout: true, script: "git tag --sort version:refname | tail -1").trim()
        return "we8578wer"
    }

def getEnvironment(branchName)
    {
        branchName = branchName.toLowerCase()
        if (branchName == 'master')
            return 'prod'
        else if (branchName == 'dev')
            return 'dev'
        else if (branchName == 'qa')
            return 'qa'
        else if (branchName == 'release')
            return 'qa'
        else
            return branchName
    }

def getAppName() {
        return "${scm.getUserRemoteConfigs()[0].getUrl()}".toString().split('/').last().split('\\.').first()
    }

def getClusterName(appName,environment){
    part1 = appName.split('-')[0]
    part2 = appName.split('-')[1]
    value = environment + "-${part1}-ecs-${part2}"
    return value
}

def getServiceName(appName,environment){
    value = environment+"-"+appName
    return value
}

def getDockerRepoName(appName){
    //part1 = appName.split('e')[1]
    //#part2 = appName.split('e')[2]
     value = "image" + "${appName}"
    return value
}

def getJavaBuildType() {
    //new gradleFile = new File('./build.gradle')
    //new mvnFile = new File('./pom.xml')
    if (fileExists('build.gradle')){
        return 'gradle'
    }
    else if (fileExists('pom.xml')){
        return 'maven'
    }
    else {
        return 'NA'
    }
}

def getECRName(){
    String repo = steps.sh(returnStdout: true, script: "/var/lib/jenkins/assume-role.sh aws ecr get-login --region eu-west-1 --no-include-email | cut -d \" \" -f 7" ).trim()
    return repo.replace("https://", "")
}

def getECRRepoLatestTag(def repo){
    String repoTag = steps.sh(returnStdout: true, script: "/var/lib/jenkins/assume-role.sh aws ecr describe-images --repository-name ${repo} --query 'sort_by(imageDetails,&imagePushedAt)[-1].imageTags[0]' --region eu-west-1" ).trim()
    return repoTag.replace("\"",'')
}

def getLatestImageTag(){
    def sout = new StringBuilder(), serr = new StringBuilder()
    //def proc = 'ls /badDir'.execute()
    command = "aws ecr describe-images --output json --repository-name java-poc --query sort_by(imageDetails,&imagePushedAt)[-1].imageTags[0] --region eu-west-1"// | jq . --raw-output"
    echo command
    def proc = command.execute()
    proc.consumeProcessOutput(sout, serr)
    proc.waitForOrKill(1000)
    echo "out> $sout "
    echo "err> $serr"
    if ("$sout"){
        return "$sout"
    }
    else{
        return "NoTagDefined"
    }

}

def getOrgName(){
        //return "${scm.getUserRemoteConfigs()}".toString().split(' ')[2].split('/')[3]
        return "${scm.getUserRemoteConfigs()[0].getUrl()}".toString().split('/')[3]
}

def getRepoURL(){
        //return "${scm.getUserRemoteConfigs()}".toString().split(' ')[2].split('/')[2]
        return "${scm.getUserRemoteConfigs()[0].getUrl()}".toString()
}

def createImageSecret(String namespace) {
    def sout = new StringBuilder(), serr = new StringBuilder()
    String repo = "${env.DOCKER_REPO_URL}".replace('https://','')
    command = "kubectl create secret docker-registry ${env.APP_NAME}-${BRANCH_NAME}-image-secret --docker-server=${repo} --docker-username=AWS --docker-password=\$pass --namespace ${namespace}"
    def proc = command.execute()
    proc.consumeProcessOutput(sout, serr)
    proc.waitForOrKill(1000)
    if ("$serr".contains('already exists') || "$sout".contains('created')){
        return 'success'
    }
    else{
        return 'failed'
    }
}

def createDockerRegistry(def dockerRepo) {
    def sout = new StringBuilder(), serr = new StringBuilder()
    command = "/var/lib/jenkins/assume-role.sh aws ecr describe-repositories --region eu-west-1"
    def proc = command.execute()
    proc.consumeProcessOutput(sout, serr)
    proc.waitForOrKill(10000)
    if ("$serr"){
        return "Unable to find registry information error is ${serr}"
    }
    else{
        if("$sout"){
            def str = "${sout}"
            def parser = new JsonSlurper()
            def json = parser.parseText(str)
            def reg_found = false
            assert json instanceof Map
            json.repositories.repositoryName.each{
                v -> if(v.toString().contains(dockerRepo)){
                    reg_found = true
                }
            }
            if(reg_found == true){
                println("Registry exists")
            }
            else{
                println("Creating registry now ...")
                def sout_rc = new StringBuilder(), serr_rc = new StringBuilder()
                command = "/var/lib/jenkins/assume-role.sh aws ecr create-repository --repository-name ${dockerRepo} --region eu-west-1"
                def proc_rc = command.execute()
                proc_rc.consumeProcessOutput(sout_rc, serr_rc)
                proc.waitForOrKill(10000)
                if(serr){
                    println("Error creating repository")
                    return
                }
            }
        }
        else{
            println("Creating registry now ...")
            def sout_rc = new StringBuilder(), serr_rc = new StringBuilder()
            command = "/var/lib/jenkins/assume-role.sh aws ecr create-repository --repository-name ${dockerRepo} --region eu-west-1"
            def proc_rc = command.execute()
            proc_rc.consumeProcessOutput(sout_rc, serr_rc)
            proc.waitForOrKill(10000)
            if(serr){
                println("Error creating repository")
                return "${sout_rc} : ${$err_rc}"
            }
            return "${sout_rc} : ${serr_rc}"
        }
    }
}


def createDockerfile(){
    if (fileExists('build.gradle')){
        def dockerfile = libraryResource 'Dockerfile.gradle'
        println('Identified as Gradle prject...')
        if (fileExists('Dockerfile')){
            println('\tDockerfile exists not creating...')
        }
        else{
            writeFile file: 'Dockerfile', text: dockerfile
        }
    }
    else if (fileExists('package.json')){
        def dockerfile = libraryResource 'Dockerfile.nodeecs.gradle'
        println('Identified as Node prject...')
        if (fileExists('Dockerfile')){
            println('\tDockerfile exists not creating...')
        }
        else{
            writeFile file: 'Dockerfile', text: dockerfile
        }
    }
    else{
        println('Unable to identify build type, not creating dockerfile...')
    }
}

def createJenkinsfile(){
    if (fileExists('build.gradle')){
        if (fileExists('Jenkinsfile')){
            println('\tJenkinsfile exists not creating...')
        }
        else{
            println('Creating Jenkinsfile for gradle project...')
            writeFile file: 'Jenkinsfile', text: '@Library(\'hyke-devops-libs\') _\ngradleBuild(deploy: true)'
        }
    }
    else if (fileExists('package.json')){
        if (fileExists('Jenkinsfile')){
            println('\tJenkinsfile exists not creating...')
        }
        else{
            println('Creating Jenkinsfile for Node project...')
            writeFile file: 'Jenkinsfile', text: '@Library(\'hyke-devops-libs\') _\nnodeBuild(deploy: true)'
        }
    }
    else{
        println('Unable to identify build type, not creating Jenkinsfile...')
    }
}

def createSonarProperty(){
    if (fileExists('build.gradle')){
        def sonar = libraryResource 'gradle.sonar'
        if (fileExists('sonar.properties')){
            println('\tsonar properties file exists not creating...')
        }
        else{
            println('Creating sonar.properties for gradle project...')
            writeFile file: 'sonar.properties', text: sonar
        }
    }
    else{
        println('Unable to identify build type, not creating sonar.properties...')
    }
}

def createTD(){
    def td = libraryResource 'ecs_td.template'
    println('Creating task definition for React project...')
    writeFile file: 'task_definition.json', text: td
}

def cloneRepo(){
    def sout = new StringBuilder(), serr = new StringBuilder()
    command = "git clone https://${REPO_URL}/${ORG}/${APP_NAME}.git; git checkout dev"
    def proc = command.execute()
    proc.consumeProcessOutput(sout, serr)
    proc.waitForOrKill(1000)
}
