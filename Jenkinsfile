pipeline {
    agent any

    environment {
        // AWS & Project Configuration
        AWS_REGION        = 'eu-central-1'
        AWS_ACCOUNT_ID    = credentials('aws-account-id')
        PROJECT_NAME      = 'monitor-spendwise'
        ENVIRONMENT       = 'dev'

        // ECR Repositories
        ECR_REGISTRY      = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        BACKEND_ECR_REPO  = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/monitor-spendwise-backend"
        FRONTEND_ECR_REPO = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/monitor-spendwise-frontend"

        // Image versioning
        IMAGE_TAG = "${env.BUILD_NUMBER}"

        // App Configuration
        APP_REPO_URL = 'https://github.com/KofiAckah/SpendWise-Core-App.git'
        BACKEND_PORT = '5000'

        // ECS Configuration
        ECS_CLUSTER   = 'monitor-spendwise-dev-cluster'
        ECS_SERVICE   = 'monitor-spendwise-dev-service'
        TASK_FAMILY   = 'monitor-spendwise-dev-task'

        // Security Reports Directory
        REPORTS_DIR = 'security-reports'
    }

    stages {

        // ── Stage 1 ──────────────────────────────────────────────────
        stage('Checkout') {
            steps {
                sh 'bash pipeline/stages/01_checkout.sh'
            }
        }

        // ── Stage 2 ──────────────────────────────────────────────────
        stage('Secret Scan - Gitleaks') {
            steps {
                sh 'bash pipeline/stages/02_secret_scan.sh'
            }
            post {
                always {
                    archiveArtifacts artifacts: 'security-reports/gitleaks-report.json',
                                     allowEmptyArchive: true
                }
            }
        }

        // ── Stage 3 ──────────────────────────────────────────────────
        stage('Run Backend Tests') {
            steps {
                sh 'bash pipeline/stages/03_backend_tests.sh'
            }
        }

        // ── Stage 4 ──────────────────────────────────────────────────
        stage('SCA Scan - Snyk') {
            steps {
                withCredentials([string(credentialsId: 'snyk-token', variable: 'SNYK_TOKEN')]) {
                    sh 'bash pipeline/stages/04_sca_scan.sh'
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'security-reports/snyk-report.json, security-reports/snyk-stderr.log',
                                     allowEmptyArchive: true
                }
            }
        }

        // ── Stage 5 ──────────────────────────────────────────────────
        stage('SAST Scan - CodeQL') {
            steps {
                sh 'bash pipeline/stages/05_sast_codeql.sh'
            }
            post {
                always {
                    archiveArtifacts artifacts: 'security-reports/codeql-results.sarif',
                                     allowEmptyArchive: true
                }
            }
        }

        // ── Stage 6 ──────────────────────────────────────────────────
        stage('Build Docker Images') {
            steps {
                sh 'bash pipeline/stages/06_build_images.sh'
            }
        }

        // ── Stage 7 ──────────────────────────────────────────────────
        stage('Image Scan - Trivy') {
            steps {
                sh 'bash pipeline/stages/07_image_scan.sh'
            }
            post {
                always {
                    archiveArtifacts artifacts: 'security-reports/trivy-*-report.json',
                                     allowEmptyArchive: true
                }
            }
        }

        // ── Stage 8 ──────────────────────────────────────────────────
        stage('Generate SBOM - Syft') {
            steps {
                sh 'bash pipeline/stages/08_generate_sbom.sh'
            }
            post {
                always {
                    archiveArtifacts artifacts: 'security-reports/sbom-*.json',
                                     allowEmptyArchive: true
                }
            }
        }

        // ── Stage 9 ──────────────────────────────────────────────────
        stage('Push to ECR') {
            steps {
                sh 'bash pipeline/stages/09_push_to_ecr.sh'
            }
        }

        // ── Stage 9b ─────────────────────────────────────────────────
        stage('DB Migration') {
            steps {
                sh 'bash pipeline/stages/09b_db_migration.sh'
            }
        }

        // ── Stage 10 ─────────────────────────────────────────────────
        stage('Deploy to ECS') {
            steps {
                sh 'bash pipeline/stages/10_deploy_to_ecs.sh'
            }
            post {
                failure {
                    sh 'bash pipeline/stages/10b_ecs_failure_diagnosis.sh'
                }
                always {
                    archiveArtifacts artifacts: 'security-reports/task-definition-rendered.json',
                                     allowEmptyArchive: true
                }
            }
        }

        // ── Stage 11 ─────────────────────────────────────────────────
        stage('Verify ECS Deployment') {
            steps {
                // 8 minutes max — 24 × 15 s = 360 s
                timeout(time: 8, unit: 'MINUTES') {
                    sh 'bash pipeline/stages/11_verify_ecs.sh'
                }
            }
        }

        // ── Stage 12 ─────────────────────────────────────────────────
        // After each ECS deploy the task gets a new private IP.
        // Prometheus uses file_sd_configs reading ecs_targets.json on the
        // monitoring server — this stage rewrites that file via SSH.
        stage('Update Prometheus ECS Target') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'ec2-ssh-key',
                                                   keyFileVariable: 'MONITORING_KEY',
                                                   usernameVariable: 'MONITORING_USER')]) {
                    sh 'bash pipeline/stages/12_update_prometheus.sh'
                }
            }
        }

        // ── Stage 13 ─────────────────────────────────────────────────
        stage('Cleanup Old Images') {
            steps {
                sh 'bash pipeline/stages/13_cleanup.sh'
            }
        }

    }

    // ── Post-build ───────────────────────────────────────────────────
    post {
        success {
            echo '=========================================='
            echo '✅ Pipeline completed successfully!'
            echo "ECS Cluster : ${ECS_CLUSTER}"
            echo "ECS Service : ${ECS_SERVICE}"
            echo "Image Tag   : ${IMAGE_TAG}"
            echo '=========================================='
            sh '''
                aws cloudwatch put-metric-data \
                    --region ${AWS_REGION} \
                    --namespace "monitor-spendwise/dev" \
                    --metric-name DeploymentSuccess \
                    --value 1 \
                    --unit Count \
                    --dimensions Pipeline=spendwise-cicd,Build=${IMAGE_TAG} || true
            '''
        }
        failure {
            echo '❌ Pipeline failed — check security reports in build artifacts'
            sh '''
                aws cloudwatch put-metric-data \
                    --region ${AWS_REGION} \
                    --namespace "monitor-spendwise/dev" \
                    --metric-name DeploymentFailures \
                    --value 1 \
                    --unit Count \
                    --dimensions Pipeline=spendwise-cicd,Build=${IMAGE_TAG} || true
            '''
        }
        always {
            sh '''
                docker system prune -f || true
                rm -f current-task-def.json new-task-def.json || true
            '''
        }
    }
}
