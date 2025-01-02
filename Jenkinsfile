pipeline {
    agent {
        node {
           label 'agent-1'   
        }
    }
    // environment {
    //     packageVersion = ''
    //     nexurl = '3.80.129.216:8081'
    // }

    options {
        // Timeout counter starts AFTER agent is allocated
        timeout(time: 1, unit: 'HOURS')
        disableConcurrentBuilds()
        ansiColor('xterm')
    }
    // environment {
    //     AWS_SHARED_CREDENTIALS_FILE = '/root/.aws/credentials'
    // }
    parameters {
        string(name: 'version', defaultValue: '1.0.0', description: 'what is version?')
        string(name: 'environment', defaultValue: 'dev', description: 'what is environment?')
        choice(name: 'action', choices: ['apply', 'destroy'],description: 'Select the environment to deploy')
    }
    stages {
        stage('version-scan') {
            steps {
              sh """
                 echo "print the version is ${params.version}"
                 echo "print the environment is ${params.environment}"
              """
            }
        }
        stage('terraform-init') {
            steps {
              sh """
                 terraform init
              """
            }
        }
        stage('terraform-apply') {
            input {
                message "should we proceed?"
                ok "yes go ahead" 
            }
            steps { 
               withAWS(credentials: 'aws-auth') {
                 sh  "terraform ${params.action} -var=app_version=${params.version} -auto-approve"
               }       
            }
        }
    }
    post {
        success {
            echo 'I succeeded!'
        }
        failure {
            echo 'I failed :('
        }
    }
}