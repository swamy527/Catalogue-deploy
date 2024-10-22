pipeline {
    agent {
        node {
           label 'Agent-1'   
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
    }
    parameters {
        string(name: 'version', defaultValue: '1.0.0', description: 'what is version?')
        string(name: 'environment', defaultValue: 'dev', description: 'what is environment?')
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
    }
    post {
        always {
            deleteDir()
        } 
        success {
            echo 'I succeeded!'
        }
        failure {
            echo 'I failed :('
        }
    }
}