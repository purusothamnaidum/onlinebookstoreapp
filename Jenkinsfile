@Library('drilldevops-sharedlibrary@test') _
pipeline {
    agent any
    tools {
        maven "MAVEN_HOME"
    }
    environment {
        REPOSITORY = 'https://github.com/kalyanreddyc/onlinebookstoreapp.git'
        CREDENTIALS_ID = '636c6341-3a7a-491c-a744-67bf8769c54d'
        DOCKER_PATH = '/usr/local/bin'
        PATH = "${env.PATH}:${env.DOCKER_PATH}" // Properly set the PATH to include Docker
        ECR_REGISTRY = '590183739792.dkr.ecr.us-east-1.amazonaws.com'
        IMAGE_TAG = '' // This will be set dynamically based on Maven project version
        TRIVY_PATH = '/opt/homebrew/bin/'
    }
    stages {
        stage('Checkout') {
            steps {
                script {
                    def checkedOutBranch = checkBranch_demo()
                    gitCheckoutrepo(
                        repository: REPOSITORY,
                        credentialsId: CREDENTIALS_ID,
                        branch: checkedOutBranch
                    )
                }
            }
        }
        stage('Prepare Release') {
            when {
                expression { env.BUILD_TYPE == 'RELEASE' }
            }
            steps {
                script {
                    prepareRelease()
                }
            }
        }
        stage('Build and Verify') {
            steps {
                script {
                    buildandPublish('verify')
                }
            }
        }
        stage('Sonar/Quality Checks') {
            steps {
                script {
                    sonarQualityChecks()
                }
            }
        }
        stage('Publish to Nexus') {
            when {
                allOf {
                    expression { env.BUILD_TYPE in ['SNAPSHOT', 'RELEASE'] }
                    expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' }
                }
            }
            steps {
                script {
                    buildandPublish('deploy')
                }
            }
        }
        stage('Determine Image Tag') {
            steps {
                script {
                    // Extract version from the Maven pom.xml
                    IMAGE_TAG = sh(script: "mvn help:evaluate -Dexpression=project.version -q -DforceStdout", returnStdout: true).trim()
                }
            }
        }
        stage('Build and Scan Image') {
            when {
                allOf {
                    expression { env.BUILD_TYPE == 'SNAPSHOT' }
                    expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' }
                }
            }
            steps {
                script {
                    sh """
                    docker build -t ${ECR_REGISTRY}/onlinebookstore:${IMAGE_TAG} -f ${WORKSPACE}/Dockerfile_updated .
                    ${TRIVY_PATH}/trivy image --exit-code 0 --severity CRITICAL ${ECR_REGISTRY}/onlinebookstore:${IMAGE_TAG}
                    """
                }
            }
        }
        stage('Push to ECR') {
            when {
                allOf {
                    expression { env.BUILD_TYPE in ['SNAPSHOT', 'RELEASE'] }
                    expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' }
                }
            }
            steps {
                script {
                    withAWS(credentials: 'aws_keys', region: 'us-east-1') {
                        // Login to ECR and push the image
                        sh """
                        aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                        docker push ${ECR_REGISTRY}/onlinebookstoreapp:${IMAGE_TAG}
                        """
                    }
                }
            }
        }
    }
}
