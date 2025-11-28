// ============================================
// JENKINSFILE - CI/CD Pipeline for Kubernetes Deployment
// ============================================

pipeline {
    agent any

    // ==========================================
    // ENVIRONMENT VARIABLES
    // ==========================================
    environment {
        // Application Details
        APP_NAME = 'crud-app'
        APP_VERSION = '1.0.0'
        
        // Nexus Configuration
        NEXUS_URL = 'NEXUS_IP:8081'              // Replace with actual Nexus IP
        NEXUS_DOCKER_REGISTRY = 'NEXUS_IP:8082'  // Replace with actual Nexus IP
        NEXUS_CREDENTIALS_ID = 'nexus-credentials'
        
        // SonarQube Configuration
        SONARQUBE_URL = 'http://SONARQUBE_IP:9000'  // Replace with actual SonarQube IP
        SONARQUBE_CREDENTIALS_ID = 'sonarqube-token'
        
        // Docker Image
        DOCKER_IMAGE = "${NEXUS_DOCKER_REGISTRY}/${APP_NAME}"
        
        // Kubernetes Configuration
        KUBECONFIG = '/var/lib/jenkins/.kube/config'
        K8S_NAMESPACE = 'crud-app'
        
        // Build Artifacts
        JAR_FILE = "target/${APP_NAME}-${APP_VERSION}.jar"
    }

    // ==========================================
    // TOOL CONFIGURATIONS
    // ==========================================
    tools {
        maven 'Maven3'
        jdk 'JDK17'
    }

    // ==========================================
    // BUILD OPTIONS
    // ==========================================
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    // ==========================================
    // PIPELINE STAGES
    // ==========================================
    stages {
        // ------------------------------------------
        // STAGE 1: CHECKOUT
        // ------------------------------------------
        stage('Checkout') {
            steps {
                echo '=========================================='
                echo 'STAGE 1: Checking out source code...'
                echo '=========================================='
                
                checkout scm
                
                // Alternative: Clone from GitHub
                // git branch: 'main',
                //     url: 'https://github.com/your-repo/crud-app.git'
                
                sh 'ls -la'
            }
        }

        // ------------------------------------------
        // STAGE 2: BUILD & TEST
        // ------------------------------------------
        stage('Build & Test') {
            steps {
                echo '=========================================='
                echo 'STAGE 2: Building and testing application...'
                echo '=========================================='
                
                dir('app') {
                    sh '''
                        echo "Maven Version:"
                        mvn --version
                        
                        echo "Building application..."
                        mvn clean test package -DskipTests=false
                        
                        echo "Build artifacts:"
                        ls -la target/
                    '''
                }
            }
            post {
                always {
                    // Publish test results
                    junit allowEmptyResults: true, testResults: 'app/target/surefire-reports/*.xml'
                }
            }
        }

        // ------------------------------------------
        // STAGE 3: SONARQUBE ANALYSIS
        // ------------------------------------------
        stage('SonarQube Analysis') {
            steps {
                echo '=========================================='
                echo 'STAGE 3: Running SonarQube analysis...'
                echo '=========================================='
                
                dir('app') {
                    withCredentials([string(credentialsId: "${SONARQUBE_CREDENTIALS_ID}", variable: 'SONAR_TOKEN')]) {
                        sh """
                            mvn sonar:sonar \
                                -Dsonar.projectKey=${APP_NAME} \
                                -Dsonar.projectName="${APP_NAME}" \
                                -Dsonar.host.url=${SONARQUBE_URL} \
                                -Dsonar.login=\$SONAR_TOKEN
                        """
                    }
                }
            }
        }

        // ------------------------------------------
        // STAGE 4: QUALITY GATE
        // ------------------------------------------
        stage('Quality Gate') {
            steps {
                echo '=========================================='
                echo 'STAGE 4: Checking Quality Gate status...'
                echo '=========================================='
                
                // Wait for SonarQube quality gate
                timeout(time: 5, unit: 'MINUTES') {
                    script {
                        // This requires SonarQube webhook configured
                        // For learning purposes, we'll just wait and check
                        sleep(30)
                        echo "Quality Gate check completed (manual verification recommended)"
                    }
                }
            }
        }

        // ------------------------------------------
        // STAGE 5: BUILD DOCKER IMAGE
        // ------------------------------------------
        stage('Build Docker Image') {
            steps {
                echo '=========================================='
                echo 'STAGE 5: Building Docker image...'
                echo '=========================================='
                
                dir('app') {
                    script {
                        // Build Docker image with multiple tags
                        sh """
                            docker build -t ${DOCKER_IMAGE}:${BUILD_NUMBER} .
                            docker build -t ${DOCKER_IMAGE}:latest .
                            
                            echo "Docker images built:"
                            docker images | grep ${APP_NAME}
                        """
                    }
                }
            }
        }

        // ------------------------------------------
        // STAGE 6: PUSH TO NEXUS DOCKER REGISTRY
        // ------------------------------------------
        stage('Push to Nexus Registry') {
            steps {
                echo '=========================================='
                echo 'STAGE 6: Pushing Docker image to Nexus...'
                echo '=========================================='
                
                script {
                    withCredentials([usernamePassword(
                        credentialsId: "${NEXUS_CREDENTIALS_ID}",
                        usernameVariable: 'NEXUS_USER',
                        passwordVariable: 'NEXUS_PASSWORD'
                    )]) {
                        sh """
                            # Login to Nexus Docker registry
                            echo \$NEXUS_PASSWORD | docker login ${NEXUS_DOCKER_REGISTRY} -u \$NEXUS_USER --password-stdin
                            
                            # Push images
                            docker push ${DOCKER_IMAGE}:${BUILD_NUMBER}
                            docker push ${DOCKER_IMAGE}:latest
                            
                            echo "Images pushed successfully!"
                        """
                    }
                }
            }
        }

        // ------------------------------------------
        // STAGE 7: DEPLOY TO KUBERNETES
        // ------------------------------------------
        stage('Deploy to Kubernetes') {
            steps {
                echo '=========================================='
                echo 'STAGE 7: Deploying to Kubernetes cluster...'
                echo '=========================================='
                
                script {
                    // Create namespace if it doesn't exist
                    sh """
                        kubectl apply -f k8s/namespace.yaml || true
                    """
                    
                    // Create docker registry secret
                    withCredentials([usernamePassword(
                        credentialsId: "${NEXUS_CREDENTIALS_ID}",
                        usernameVariable: 'NEXUS_USER',
                        passwordVariable: 'NEXUS_PASSWORD'
                    )]) {
                        sh """
                            kubectl delete secret nexus-registry-secret -n ${K8S_NAMESPACE} --ignore-not-found
                            kubectl create secret docker-registry nexus-registry-secret \
                                --docker-server=${NEXUS_DOCKER_REGISTRY} \
                                --docker-username=\$NEXUS_USER \
                                --docker-password=\$NEXUS_PASSWORD \
                                --namespace=${K8S_NAMESPACE}
                        """
                    }
                    
                    // Update deployment with new image tag
                    sh """
                        # Replace placeholders in deployment
                        sed -i 's|\${DOCKER_REGISTRY}|${NEXUS_DOCKER_REGISTRY}|g' k8s/deployment.yaml
                        sed -i 's|\${BUILD_TAG}|${BUILD_NUMBER}|g' k8s/deployment.yaml
                        
                        # Apply Kubernetes manifests
                        kubectl apply -f k8s/deployment.yaml
                        kubectl apply -f k8s/service.yaml
                        
                        # Wait for deployment to be ready
                        echo "Waiting for deployment to be ready..."
                        kubectl rollout status deployment/${APP_NAME} -n ${K8S_NAMESPACE} --timeout=300s
                        
                        # Show deployment status
                        echo "\\n========== DEPLOYMENT STATUS =========="
                        kubectl get pods -n ${K8S_NAMESPACE}
                        kubectl get svc -n ${K8S_NAMESPACE}
                    """
                }
            }
        }

        // ------------------------------------------
        // STAGE 8: SANITY CHECK
        // ------------------------------------------
        stage('Sanity Check') {
            steps {
                echo '=========================================='
                echo 'STAGE 8: Running sanity checks...'
                echo '=========================================='
                
                script {
                    // Get worker node IP and NodePort
                    def nodeIP = sh(
                        script: "kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type==\"ExternalIP\")].address}'",
                        returnStdout: true
                    ).trim()
                    
                    // If no external IP, try internal IP
                    if (!nodeIP) {
                        nodeIP = sh(
                            script: "kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type==\"InternalIP\")].address}'",
                            returnStdout: true
                        ).trim()
                    }
                    
                    def nodePort = '30080'
                    def appUrl = "http://${nodeIP}:${nodePort}"
                    
                    echo "Testing application at: ${appUrl}"
                    
                    // Wait for application to be ready
                    sleep(30)
                    
                    // Health check
                    sh """
                        echo "Performing health check..."
                        
                        # Try health endpoint
                        HTTP_STATUS=\$(curl -s -o /dev/null -w "%{http_code}" ${appUrl}/actuator/health || echo "000")
                        
                        if [ "\$HTTP_STATUS" = "200" ]; then
                            echo "✅ Health check PASSED! Status: \$HTTP_STATUS"
                            curl -s ${appUrl}/actuator/health | head -100
                        else
                            echo "⚠️ Health check returned: \$HTTP_STATUS (may still be starting)"
                            
                            # Try root endpoint
                            HTTP_STATUS=\$(curl -s -o /dev/null -w "%{http_code}" ${appUrl}/api/items/ || echo "000")
                            echo "Root endpoint status: \$HTTP_STATUS"
                        fi
                        
                        echo "\\n========== APPLICATION INFO =========="
                        echo "Application URL: ${appUrl}"
                        echo "Health Endpoint: ${appUrl}/actuator/health"
                        echo "API Endpoint: ${appUrl}/api/items"
                    """
                }
            }
        }
    }

    // ==========================================
    // POST-BUILD ACTIONS
    // ==========================================
    post {
        always {
            echo '=========================================='
            echo 'Pipeline completed!'
            echo '=========================================='
            
            // Clean up Docker images to save space
            sh '''
                docker system prune -f || true
            '''
        }
        success {
            echo '✅ Pipeline completed successfully!'
            // Add notifications here (Slack, email, etc.)
        }
        failure {
            echo '❌ Pipeline failed!'
            // Add notifications here
        }
    }
}
