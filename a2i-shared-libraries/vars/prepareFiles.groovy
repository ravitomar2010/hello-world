
def create() {
    def jenkinsJobTemplate = libraryResource 'multi-branch-template.xml'
    def check_deployment = libraryResource 'check_deploy.sh'

    writeFile file: 'template.xml', text: jenkinsJobTemplate
    if (fileExists('build.gradle')){
        def gitignore = libraryResource 'template.gitignore.gradle'
        writeFile file: '.gitignore', text: gitignore
    }
    else if (fileExists('package.json')){
        def gitignore = libraryResource 'template.gitignore.node'
        writeFile file: '.gitignore', text: gitignore
    }
    else {
        println('Unable to identify the type of project...')
    }
    writeFile file: 'check_deployment.sh', text: check_deployment
}