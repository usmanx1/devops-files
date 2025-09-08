pipeline {

agent { 
label 'aithentic-jenkins-agent01'
}


/*parameters {
  //string(name: 'S3_OBJECT_KEY', defaultValue: '.env-dev', description: 'Select an S3 object key')
  //string(name: 'DOWNLOAD_FILE_NAME', defaultValue: '.env', description: 'Name to use when downloading the file')
  //booleanParam(name: 'skipSonarStage', defaultValue: false, description: 'Skip the sonar stage')
  }*/
  
triggers {
        bitbucketPush()
    }
	
options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
        timeout(time: 1, unit: 'HOURS')
        timestamps()
    }
    environment {
        ECR_REGISTRY= "323500295462.dkr.ecr.us-east-2.amazonaws.com"
        ECR_ACCOUNT_ID= "323500295462"
        ECR_REGION= "us-east-2"
        DOCKER_IMAGE_NAME = "aithentic-frontend"
        DOCKERFILE_PATH= "${env.WORKSPACE}/Dockerfile"
        IMAGE_REPO_NAME="aithentic-frontend"
        S3_BUCKET  = 'app-configs-aithentic'
        S3_PREFIX  = 'app-envs'
        S3_FOLDER    = 'apache2'
        LOCAL_FOLDER = 'apache2'
        NODE_OPTIONS = '--max-old-space-size=4096'
          }


 stages {
    stage('CheckOut') {
        steps {
            script{
             //git branch: "${params.GIT_BRANCH}", url: "${params.GIT_REPO_URL}", credentialsId: 'pipeline'
             checkout scm
             echo "${env.WORKSPACE}"
             echo "${env.GIT_BRANCH}"
             COMMIT_ID = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
             echo "$COMMIT_ID"
             
            }
        }    
        }
        stage('Download Env file from S3') {
            steps {
                script {
                   
                    // Download the file from S3 and rename it
                    //sh "aws s3 cp s3://${S3_BUCKET}/${S3_PREFIX}/${params.S3_OBJECT_KEY} ${env.WORKSPACE}/${params.DOWNLOAD_FILE_NAME}"
                   // Create the local folder if it doesn't exist
                    sh "mkdir -p ${LOCAL_FOLDER}"
                    // Download the entire S3 folder to the Jenkins workspace
                    //sh "aws s3 sync s3://${S3_BUCKET}/${S3_FOLDER} $env.{WORKSPACE}/${LOCAL_FOLDER}"
                    sh "aws s3 cp s3://${S3_BUCKET}/${S3_PREFIX}/.env  ."
                }
                
            }
        }
        
      stage('Install Dependencies and Run UnitTests') {
           when {
             anyOf {
                expression {
                   env.GIT_BRANCH == 'development'  
                 }
             }
          }
           steps {
               script {
                    dir('aithentic'){
                    // Install all dependencies listed in package.json -- --watch=false --browsers=ChromeHeadless
                   sh ' taskset -c 0,1 npm install --force'
                    //sh 'npm run test'
                   sh ' taskset -c 0,1 npm run test'
                   sh 'pwd'
                   sh 'ls -la'
               }
            }
        } 
   }
 
     stage('Sonar Scan'){

        when {
             anyOf {
                expression {
                   env.GIT_BRANCH == 'development'  
                 }
             }
          }
        steps{
             script{
                  // Read branch name
                    def branchName = env.BRANCH_NAME
                    echo "Branch Name: ${branchName}"
            withSonarQubeEnv(installationName:'SonarQube',credentialsId: 'SonarQube') {
            //sh 'mvn clean verify sonar:sonar -Dsonar.projectName=sip-google -Dsonar.projectKey=com.aithentic:google'
            sh '/opt/sonar-scanner/bin/sonar-scanner -Dsonar.projectKey=core-frontend-New -Dsonar.sources=. -Dsonar.branch.name=${branchName} -Dsonar.exclusions=Dockerfile -Dsonar.javascript.lcov.reportPaths=$(pwd)/aithentic/coverage/lcov.info'
              }
            }
          }
        } 
        
     stage('Quality Gate') {
        when {
             anyOf {
                expression {
                   env.GIT_BRANCH == 'development'  
                 }
             }
          }
       steps {
        timeout(time: 300, unit: 'SECONDS') {
          // Wait for the quality gate to pass
          script {
            def qg = waitForQualityGate()
            if (qg.status != 'OK') {
              error "Pipeline aborted due to quality gate failure: ${qg.status}"
            }
          }
        }
      }
    } 
     

     stage('Logging into AWS ECR') {
            steps {
                script {
                sh "aws ecr get-login-password --region ${ECR_REGION} | docker login --username AWS --password-stdin ${ECR_ACCOUNT_ID}.dkr.ecr.${ECR_REGION}.amazonaws.com"
                echo "Login success!!!!!!!!"
                }
                 
            }
        }   
    
            
    stage('Replace Configuration variable in Dockerfile') {
            steps {
                script {
				    
					def branchName = env.BRANCH_NAME

                    if (branchName == 'development') {
                        ENVIRONMENT_NAME = 'dev'
                    } else if (branchName == 'qa') {
                        ENVIRONMENT_NAME = 'qa'
                    } else if (branchName == 'uat') {
                        ENVIRONMENT_NAME = 'beta'
                    } else if (branchName == 'preprod') {
                        ENVIRONMENT_NAME = 'pre-prod'
                    } else {
                        ENVIRONMENT_NAME = 'dev'
                    }

                    echo "Environment Name: ${ENVIRONMENT_NAME}"
				     
                    // Read Dockerfile content
                    def dockerfile = readFile('Dockerfile')

                    // Replace variable value
                    def updatedDockerfile = dockerfile.replaceAll(/\$\{env\}/, "${ENVIRONMENT_NAME}")

                     // Write updated Dockerfile content back to file
                    writeFile file: 'Dockerfile', text: updatedDockerfile

                    sh 'cat Dockerfile'
                }
            }
        }
         

        stage('Image Build and Tag') {
            steps {
                  timeout(time: 60, unit: 'MINUTES') {
                script {
                    // --no-cache docker.build("${DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER}-${COMMIT_ID}","--file ${DOCKERFILE_PATH} .")
                    sh """
                         export DOCKER_BUILDKIT=0
                         docker build --no-cache -t "${DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER}-${COMMIT_ID}" -f "${DOCKERFILE_PATH}" .
                        """
                    
                    }
                }
            }
        }

        stage('Push to ECR') {
                when { expression { env.GIT_BRANCH in ['development', 'qa', 'uat'] } }

                 steps{  
         script {
                sh "docker tag ${DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER}-${COMMIT_ID} ${ECR_REGISTRY}/${IMAGE_REPO_NAME}:${env.BUILD_NUMBER}-${COMMIT_ID}"
                sh "docker push ${ECR_REGISTRY}/${IMAGE_REPO_NAME}:${env.BUILD_NUMBER}-${COMMIT_ID}"
                echo "Image Pushed Successfully!!!!!!!!"
                
         }
        }
      }
	  
	  stage('Replace Image Tag') {
            when { expression { env.GIT_BRANCH in ['development', 'qa', 'uat'] } }

            steps {
                script {
                      // Read branch name
                    def branchName = env.BRANCH_NAME
                    echo "Branch Name: ${branchName}"

                    // Determine environment name based on branch name
                    def environmentName = ''
                    if (branchName == 'development') {
                        environmentName = 'dev'
                    } else if (branchName == 'qa') {
                        environmentName = 'qa'
                    }else if (branchName == 'uat') {
                        environmentName = 'uat'
                    }else if (branchName == 'preprod') {
                        environmentName = 'pp'
                    } else {
                        environmentName = 'default'
                    }
                    echo "Environment Name: ${environmentName}"
                    // Update this line to point to your Kubernetes YAML file
                    def kubernetesYaml = 'aithentic-front.yaml'
                    // Read the Kubernetes YAML file
                    def yamlContent = readFile(kubernetesYaml)
                   // Replace the image tag dynamically
                   yamlContent = yamlContent.replaceAll(/\$\{image\}/, "${ECR_REGISTRY}/${IMAGE_REPO_NAME}:${env.BUILD_NUMBER}-${COMMIT_ID}").replaceAll(/\$\{env\}/, "${environmentName}")

                    // Write the modified content back to the YAML file
                    writeFile(file: kubernetesYaml, text: yamlContent)
                    echo "Image Tag Updated Successfully!!!!!!!!"
                    
                    sh "docker rmi ${ECR_REGISTRY}/${IMAGE_REPO_NAME}:${env.BUILD_NUMBER}-${COMMIT_ID}"
                    echo "Image Removed Successfully!!!!!!!!"
                    sh 'cat aithentic-front.yaml'
                }
            }
        }
	  
	  stage('Deploy to Kubernetes') {
           when { expression { env.GIT_BRANCH in ['development', 'qa', 'uat'] } }
            steps {
                script {
				     // create or update configmap
					 //sh "kubectl create configmap aithentic-core-qa-api.k8s.configmap --from-file .env -o yaml --dry-run=client | kubectl apply -f -"
                    // Apply the modified Kubernetes deployment
                    sh "kubectl apply -f aithentic-front.yaml"
                }
            }
        }
    }
      
 post { 
       always { 
             script {
               // Final cleanup
               sh '''
                   echo "=== Final Cleanup ==="
                   docker system prune -f --volumes || true
                   docker builder prune -f || true
                   echo "=== Final Resources ==="
                   free -h
                   df -h
               '''
           }
           cleanWs()
            echo 'Work space cleaned successfully!'
            script {
    // Define the build URL
    def buildUrl = env.BUILD_URL
    
    // Define the build number
    def buildNumber = env.BUILD_NUMBER
    
    // Read build log
    def buildLog
    try {
        buildLog = readFile("${env.BUILD_URL}consoleText")
    } catch (Exception e) {
        // Handle error reading build log
        buildLog = "Error reading build log: ${e.message}"
    }
    
    // Define the email body with dynamic build information including build log
    def emailBody = """<p>Hello Team,</p>
            <p>This is an automated email notification from Jenkins.</p>
            <p>Build Details:</p>
            <ul>
                <li>Job Name: ${env.JOB_NAME}</li>
                <li>Build Number: ${buildNumber}</li>
                <li>Build Status: ${currentBuild.currentResult}</li>
                <li>Build URL: <a href='${buildUrl}'>${buildUrl}</a></li>
            </ul>
            <p>Build Log:</p>
            <pre>${buildLog}</pre>
            <p>Regards,<br>Jenkins</p>"""
    
    // Send email notification
    emailext body: emailBody, 
              subject: "${env.JOB_NAME} - Build #${buildNumber} - ${currentBuild.currentResult}", 
              to: 'narendra.gaddam@aithentic.com,anuj.gupta@aithentic.com,ishwinder.singh@aithentic.com'
       
          }
        }
        success {
            script{
                currentBuild.result= currentBuild.result ?: 'SUCCESS'
            }
            echo "=====pipeline executed successfully============"
        }
        failure {
            script{
                currentBuild.result= currentBuild.result ?: 'FAILURE'
            }
            echo "=====pipeline executed failed============="
        }
    }
}
