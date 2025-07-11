// Jenkinsfile
pipeline {
    agent any // Or 'agent { label 'your-terraform-agent' }' if you have a specific agent

    parameters {
        string(name: 'ACTION', defaultValue: 'apply', description: 'Terraform action: apply or destroy')
        booleanParam(name: 'AUTO_APPROVE', defaultValue: false, description: 'Automatically approve Terraform apply/destroy')
    }

    environment {
        // Reference your Jenkins credentials here for AWS CLI
        // If using an IAM role on the Jenkins EC2 instance, remove these
        AWS_ACCESS_KEY_ID     = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')

        // Pass Terraform variables as environment variables (TF_VAR_*)
        TF_VAR_cluster_name   = "my-jenkins-eks-${UUID.randomUUID().toString()[0..7]}" // Generates a unique cluster name
        TF_VAR_environment    = "dev"
        TF_VAR_aws_region     = "ap-south-1" // Ensure this matches your backend.tf region
    }

    stages {
        stage('Checkout Code') {
            steps {
                git branch: 'main', credentialsId: 'your-git-credentials-id', url: 'https://github.com/your-org/your-eks-terraform-repo.git' // Replace with your repo and credentials ID
            }
        }

        stage('Terraform Init') {
            steps {
                script {
                    dir('terraform') { // Change directory to your Terraform code
                        withEnv(["PATH+TF=${tool 'Terraform_1.x.x'}/bin"]) { // Use the Terraform version installed in Jenkins
                            sh 'terraform init -backend-config="bucket=my-jenkins-eks-terraform-state" -backend-config="key=eks/terraform.tfstate" -backend-config="region=ap-south-1" -backend-config="dynamodb_table=my-jenkins-terraform-lock"'
                        }
                    }
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                script {
                    dir('terraform') {
                        withEnv(["PATH+TF=${tool 'Terraform_1.x.x'}/bin"]) {
                            sh 'terraform plan -out=tfplan'
                            // Optional: Save plan output for review
                            sh 'terraform show -no-color tfplan > tfplan.txt'
                            archiveArtifacts artifacts: 'tfplan.txt', fingerprint: true
                        }
                    }
                }
            }
        }

        stage('Manual Approval for Apply') {
            when {
                expression { params.ACTION == 'apply' && !params.AUTO_APPROVE }
            }
            steps {
                script {
                    def planOutput = readFile('terraform/tfplan.txt') // Read from the 'terraform' directory
                    input message: "Review Terraform Plan and Confirm Apply:\n\n${planOutput}", ok: 'Apply'
                }
            }
        }

        stage('Terraform Apply / Destroy') {
            steps {
                script {
                    dir('terraform') {
                        withEnv(["PATH+TF=${tool 'Terraform_1.x.x'}/bin"]) {
                            if (params.ACTION == 'apply') {
                                sh 'terraform apply -auto-approve tfplan'
                            } else if (params.ACTION == 'destroy') {
                                // Add a separate approval for destroy, even if AUTO_APPROVE is true, for safety
                                input message: "WARNING: You are about to DESTROY the EKS cluster and application. Confirm to proceed.", ok: 'Destroy'
                                sh 'terraform destroy -auto-approve'
                            } else {
                                error "Invalid ACTION parameter: ${params.ACTION}. Must be 'apply' or 'destroy'."
                            }
                        }
                    }
                }
            }
        }

        stage('Verify EKS Cluster & App Access') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                script {
                    dir('terraform') {
                        // Ensure AWS CLI is configured to get kubeconfig
                        // If using IAM role, no need for AWS_ACCESS_KEY_ID/SECRET_ACCESS_KEY env vars here
                        sh "aws eks update-kubeconfig --region ${TF_VAR_aws_region} --name ${TF_VAR_cluster_name}"

                        // Verify cluster nodes
                        sh 'kubectl get nodes'

                        // // Get Nginx service URL from Terraform output
                        // def nginxServiceURL = sh(returnStdout: true, script: 'terraform output -raw nginx_service_url').trim()
                        // echo "Nginx application should be accessible at: http://${nginxServiceURL}"

                        // Optional: Perform a curl to verify app is reachable
                        // sh "curl -v http://${nginxServiceURL}"
                    }
                }
            }
        }
    }

    post {
        always {
            cleanWs() // Clean up the workspace after the build
        }
        failure {
            echo "Pipeline failed! Check the console output for details."
        }
        success {
            echo "EKS cluster and application deployment/destruction completed successfully!"
        }
    }
}
