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
        ECR_REGISTRY = '767397971892.dkr.ecr.us-east-1.amazonaws.com'
        IMAGE_TAG = '' // This will be dynamically set
        DOCKER_IMAGE = '' // Full Docker image name will be set dynamically
        TRIVY_PATH = '/opt/homebrew/bin'
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
                    IMAGE_TAG = sh(script: "mvn help:evaluate -Dexpression=project.version -q -DforceStdout", returnStdout: true).trim()
                    DOCKER_IMAGE = "${ECR_REGISTRY}/bookstoreapp:${IMAGE_TAG}"
                }
            }
        }
        stage('Build and Scan Image') {
            when {
                allOf {
                    //expression { env.BUILD_TYPE == 'SNAPSHOT' }           //this is used when we wanted to promote same snapshot version to prod instead of having seperate release version image
                    expression { env.BUILD_TYPE in ['SNAPSHOT', 'RELEASE'] }
                    expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' }
                }
            }
            steps {
                script {
                    sh "docker build -t ${DOCKER_IMAGE} -f ${WORKSPACE}/Dockerfile_updated ."
                    sh "${TRIVY_PATH}/trivy image --exit-code 0 --severity CRITICAL ${DOCKER_IMAGE}"
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
                        sh "aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${ECR_REGISTRY}"
                        sh "docker push ${DOCKER_IMAGE}"
                    }
                }
            }
        }
    }
    post {
        success {
            script {
                sh "docker rmi ${DOCKER_IMAGE}" // Remove Docker images created during the build
                sh "docker image prune -f" // Clean up dangling images
                emailext(
                    subject: "Build Notification for ${JOB_NAME} #${BUILD_NUMBER}",
                    body: """Hello Team,
                    
                    The build for ${JOB_NAME} #${BUILD_NUMBER} has completed.
                    Status: SUCCESSFUL
                    
                    You can check the build details here: ${BUILD_URL}
                    
                    Best Regards,
                    DrillDevOps Team,
                    Kymera Tek Solutions""",
                    to: 'drilldevops@gmail.com'
                )
                slackSend(
                    channel: 'drilldevops-cicd-build-release-alerts',
                    color: 'good',
                    message: "Build Successful: Job '${JOB_NAME} #${BUILD_NUMBER}' See details at: ${BUILD_URL}"
                )
            }
        }
        failure {
            script {
                emailext(
                    subject: "Build Failure Notification for ${JOB_NAME} #${BUILD_NUMBER}",
                    body: """Hello Team,
                    
                    The build for ${JOB_NAME} #${BUILD_NUMBER} has failed.
                    Please check the build details here: ${BUILD_URL}
                    
                    Best Regards,
                    DrillDevOps Team,
                    Kymera Tek Solutions""",
                    to: 'drilldevops@gmail.com'
                )
                slackSend(
                    channel: 'drilldevops-cicd-build-release-alerts',
                    color: 'danger',
                    message: "Build Failed: Job '${JOB_NAME} #${BUILD_NUMBER}' Check details at: ${BUILD_URL}"
                )
            }
        }
        always {
            script {
                deleteDir() // Clean up the workspace
            }
            echo "Cleanup complete. Workspace and Docker images cleared."
            echo "The job ${JOB_NAME} #${BUILD_NUMBER} completed with result: ${currentBuild.currentResult}"
        }
    }
}
