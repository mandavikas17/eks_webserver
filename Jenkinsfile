// Jenkinsfile
pipeline {
    // Define the agent where the pipeline will run.
    // 'any' means Jenkins will pick any available agent.
    // For specific needs, use 'agent { label 'your-terraform-agent' }'
    agent any

    // Define parameters for the pipeline, allowing user input when triggering the build.
    parameters {
        string(name: 'ACTION', defaultValue: 'apply', description: 'Terraform action: apply or destroy')
        booleanParam(name: 'AUTO_APPROVE', defaultValue: false, description: 'Automatically approve Terraform apply/destroy')
    }

    // Define environment variables that will be available to all steps in the pipeline.
    environment {
        // AWS credentials:
        // These reference Jenkins 'Secret text' credentials.
        // If your Jenkins EC2 instance has an IAM role with appropriate permissions,
        // you might not need these and can remove them for better security.
        AWS_ACCESS_KEY_ID       = credentials('aws-access-key-id') // Replace with your AWS Access Key ID credential ID in Jenkins
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key') // Replace with your AWS Secret Access Key credential ID in Jenkins

        // Terraform variables passed as environment variables (TF_VAR_*).
        // Terraform automatically picks up environment variables prefixed with TF_VAR_.
        TF_VAR_cluster_name     = "my-jenkins-eks-${UUID.randomUUID().toString()[0..7]}" // Generates a unique cluster name to avoid conflicts
        TF_VAR_environment      = "dev"
        TF_VAR_aws_region       = "ap-south-1" // Ensure this matches the region configured in your backend.tf
    }

    // Define the stages of your pipeline.
    stages {
        stage('Checkout Code') {
            steps {
                // Checkout your Terraform code from Git.
                // Replace 'your-git-credentials-id' with the ID of your Git credentials in Jenkins.
                // Replace 'https://github.com/your-org/your-eks-terraform-repo.git' with your actual repository URL.
                git branch: 'main', url: 'https://github.com/mandavikas17/eks_webserver.git'
            }
        }

        stage('Terraform Init') {
            steps {
                script {
                    // Change directory to where your Terraform code resides.
                    // Adjust 'terraform' if your Terraform files are in a different subdirectory.
                    dir('terraform') {
                        // Use the Terraform tool installed and configured in Jenkins.
                        // Replace 'Terraform_1.x.x' with the exact name of your Terraform tool configuration in Jenkins.
                        withEnv(["PATH+TF=${tool 'Terraform_1.x.x'}/bin"]) {
                            // Initialize Terraform with backend configuration.
                            // Ensure the bucket, key, region, and dynamodb_table match your setup.
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
                            // Generate a Terraform plan and save it to a file.
                            sh 'terraform plan -out=tfplan'
                            // Save the human-readable output of the plan for review.
                            sh 'terraform show -no-color tfplan > tfplan.txt'
                            // Archive the plan output as an artifact, making it accessible from the build page.
                            archiveArtifacts artifacts: 'tfplan.txt', fingerprint: true
                        }
                    }
                }
            }
        }

        stage('Manual Approval for Apply') {
            // This stage runs only if the action is 'apply' and auto-approval is not enabled.
            when {
                expression { params.ACTION == 'apply' && !params.AUTO_APPROVE }
            }
            steps {
                script {
                    // Read the Terraform plan output to display to the user for review.
                    // Ensure the path 'terraform/tfplan.txt' is correct relative to the workspace.
                    def planOutput = readFile('terraform/tfplan.txt')
                    // Pause the pipeline for manual input, displaying the plan output.
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
                                // Apply the Terraform plan.
                                sh 'terraform apply -auto-approve tfplan'
                            } else if (params.ACTION == 'destroy') {
                                // For destroy actions, add an additional manual approval for safety,
                                // even if AUTO_APPROVE is set to true.
                                input message: "WARNING: You are about to DESTROY the EKS cluster and application. Confirm to proceed.", ok: 'Destroy'
                                // Execute Terraform destroy.
                                sh 'terraform destroy -auto-approve'
                            } else {
                                // Fail the pipeline if an invalid action is provided.
                                error "Invalid ACTION parameter: ${params.ACTION}. Must be 'apply' or 'destroy'."
                            }
                        }
                    }
                }
            }
        }

        stage('Verify EKS Cluster & App Access') {
            // This stage runs only when the action is 'apply'.
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                script {
                    dir('terraform') {
                        // Update kubeconfig to connect to the newly created EKS cluster.
                        // This assumes AWS CLI is installed and configured on the agent.
                        sh "aws eks update-kubeconfig --region ${TF_VAR_aws_region} --name ${TF_VAR_cluster_name}"

                        // Verify cluster nodes are running.
                        sh 'kubectl get nodes'

                        // Uncomment and adjust the following lines if you have Nginx or other services
                        // and want to verify their URLs or perform curl checks.
                        // // Get Nginx service URL from Terraform output
                        // def nginxServiceURL = sh(returnStdout: true, script: 'terraform output -raw nginx_service_url').trim()
                        // echo "Nginx application should be accessible at: http://${nginxServiceURL}"

                        // // Optional: Perform a curl to verify app is reachable
                        // // sh "curl -v http://${nginxServiceURL}"
                    }
                }
            }
        }
    }

    // Define post-build actions that run after all stages are completed.
    post {
        // The 'always' block runs regardless of the pipeline's success or failure.
        always {
            // The 'cleanWs()' step requires a 'FilePath' context, which is provided by a 'node' block.
            // This ensures the workspace is cleaned up on the agent.
            node ('jenkins'){ 
                script {
                    try {
                        cleanWs() // Clean up the workspace after the build
                        echo "Workspace cleaned successfully."
                    } catch (IOException e) {
                        echo "Error cleaning workspace: ${e.getMessage()}"
                    }
                }
            }
        }
        // The 'failure' block runs only if the pipeline fails.
        failure {
            echo "Pipeline failed! Check the console output for details."
        }
        // The 'success' block runs only if the pipeline succeeds.
        success {
            echo "EKS cluster and application deployment/destruction completed successfully!"
        }
    }
}
