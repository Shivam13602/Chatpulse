#!/bin/bash
# Simplified Deployment Script for Real-Time Chat Application with Sentiment Insights

# Configuration parameters
REGION=${1:-"us-west-2"}
S3_BUCKET_NAME=${2:-"cloud-chat-app-bucket"}
STACK_NAME=${3:-"real-time-chat-app"}
ENVIRONMENT=${4:-"Prod"}
ADMIN_EMAIL=${5:-"admin@example.com"}

echo -e "\e[32mStarting deployment of the Real-Time Chat Application with Sentiment Insights...\e[0m"

# Step 1: Check if the S3 bucket exists, if not create it
echo -e "\e[33mChecking if S3 bucket '$S3_BUCKET_NAME' exists...\e[0m"
BUCKET_EXISTS=$(aws s3api list-buckets --query "Buckets[?Name=='$S3_BUCKET_NAME'].Name" --output text --region $REGION)

if [ -z "$BUCKET_EXISTS" ]; then
    echo -e "\e[33mCreating S3 bucket '$S3_BUCKET_NAME'...\e[0m"
    aws s3api create-bucket --bucket $S3_BUCKET_NAME --region $REGION --create-bucket-configuration LocationConstraint=$REGION
    
    if [ $? -ne 0 ]; then
        echo -e "\e[31mError creating S3 bucket\e[0m"
        exit 1
    fi
    
    # Configure bucket for website hosting
    aws s3api put-bucket-policy --bucket $S3_BUCKET_NAME --policy file://bucket_policy.json
    aws s3 website --bucket $S3_BUCKET_NAME --index-document index.html --error-document error.html
    echo -e "\e[32mS3 bucket created and configured successfully.\e[0m"
else
    echo -e "\e[32mS3 bucket '$S3_BUCKET_NAME' already exists.\e[0m"
fi

# Step 2: Package and upload Lambda functions
echo -e "\e[33mPackaging Lambda functions...\e[0m"

# Create a temporary directory for packaging
TEMP_DIR="./temp"
mkdir -p $TEMP_DIR

# Package connection_manager.py Lambda function
echo -e "\e[33mPackaging connection_manager.py Lambda function...\e[0m"
cp ./lambda/functions/connection_manager.py $TEMP_DIR/
cd $TEMP_DIR
zip -j connection_manager.zip connection_manager.py
aws s3 cp connection_manager.zip s3://$S3_BUCKET_NAME/lambda/connection_manager.zip --region $REGION

# Package message_processor.js Lambda function
echo -e "\e[33mPackaging message_processor.js Lambda function...\e[0m"
rm -f ./*.py ./*.zip
cp ../lambda/functions/message_processor.js ./
cp ../lambda/functions/package.json ./
npm install --production
zip -r message_processor.zip node_modules message_processor.js package.json
aws s3 cp message_processor.zip s3://$S3_BUCKET_NAME/lambda/message_processor.zip --region $REGION

# Package default_handler.js Lambda function
echo -e "\e[33mPackaging default_handler.js Lambda function...\e[0m"
rm -rf node_modules *.js *.json *.zip
cp ../lambda/functions/default_handler.js ./
cp ../lambda/functions/package.json ./
npm install --production
zip -r default_handler.zip node_modules default_handler.js package.json
aws s3 cp default_handler.zip s3://$S3_BUCKET_NAME/lambda/default_handler.zip --region $REGION

# Package message_broadcast.js Lambda function
echo -e "\e[33mPackaging message_broadcast.js Lambda function...\e[0m"
rm -rf node_modules *.js *.json *.zip
cp ../lambda/functions/message_broadcast.js ./
cp ../lambda/functions/package.json ./
npm install --production
zip -r message_broadcast.zip node_modules message_broadcast.js package.json
aws s3 cp message_broadcast.zip s3://$S3_BUCKET_NAME/lambda/message_broadcast.zip --region $REGION

# Return to original directory
cd ..
echo -e "\e[32mAll Lambda functions packaged and uploaded.\e[0m"

# Step 3: Upload CloudFormation templates
echo -e "\e[33mUploading CloudFormation templates...\e[0m"
aws s3 cp ./infrastructure/cloudformation/main-template.yml s3://$S3_BUCKET_NAME/cloudformation/main-template.yml --region $REGION
aws s3 cp ./infrastructure/cloudformation/ec2-training.yml s3://$S3_BUCKET_NAME/cloudformation/ec2-training.yml --region $REGION
aws s3 cp ./infrastructure/cloudformation/eventbridge.yml s3://$S3_BUCKET_NAME/cloudformation/eventbridge.yml --region $REGION
aws s3 cp ./infrastructure/cloudformation/cloudwatch.yml s3://$S3_BUCKET_NAME/cloudformation/cloudwatch.yml --region $REGION
aws s3 cp ./infrastructure/cloudformation/s3-bucket.yml s3://$S3_BUCKET_NAME/cloudformation/s3-bucket.yml --region $REGION
echo -e "\e[32mCloudFormation templates uploaded.\e[0m"

# Step 4: Upload frontend files
echo -e "\e[33mUploading frontend files...\e[0m"
aws s3 cp ./src/index.html s3://$S3_BUCKET_NAME/index.html --region $REGION
echo -e "\e[32mFrontend files uploaded.\e[0m"

# Step 5: Create/update the CloudFormation stack
echo -e "\e[33mDeploying CloudFormation stack '$STACK_NAME'...\e[0m"
aws cloudformation deploy \
    --template-url "https://$S3_BUCKET_NAME.s3.$REGION.amazonaws.com/cloudformation/main-template.yml" \
    --stack-name $STACK_NAME \
    --parameter-overrides \
        EnvironmentName=$ENVIRONMENT \
        S3BucketName=$S3_BUCKET_NAME \
        AdminEmail=$ADMIN_EMAIL \
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
    --region $REGION

if [ $? -ne 0 ]; then
    echo -e "\e[31mError deploying CloudFormation stack\e[0m"
    exit 1
fi

echo -e "\e[32mCloudFormation stack deployed successfully.\e[0m"

# Step 6: Get outputs from the CloudFormation stack
echo -e "\e[33mRetrieving CloudFormation stack outputs...\e[0m"
OUTPUTS=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs" --output json --region $REGION)

WEBSOCKET_URL=$(echo $OUTPUTS | jq -r '.[] | select(.OutputKey=="WebSocketURL") | .OutputValue')
FRONTEND_URL=$(echo $OUTPUTS | jq -r '.[] | select(.OutputKey=="FrontendURL") | .OutputValue')
DASHBOARD_URL=$(echo $OUTPUTS | jq -r '.[] | select(.OutputKey=="DashboardURL") | .OutputValue')
EC2_INSTANCE_ID=$(echo $OUTPUTS | jq -r '.[] | select(.OutputKey=="ModelTrainingInstanceId") | .OutputValue')

echo -e "\e[32mDeployment successful!\e[0m"
echo -e "\e[36mWebSocket URL: $WEBSOCKET_URL\e[0m"
echo -e "\e[36mFrontend URL: $FRONTEND_URL\e[0m"
echo -e "\e[36mCloudWatch Dashboard: $DASHBOARD_URL\e[0m"
echo -e "\e[36mEC2 Training Instance ID: $EC2_INSTANCE_ID\e[0m"

# Clean up temporary directory
rm -rf $TEMP_DIR

echo -e "\e[32mDeployment completed successfully.\e[0m" 