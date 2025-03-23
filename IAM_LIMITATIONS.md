# Working with IAM Role Limitations in AWS Academy

## Understanding IAM Limitations in AWS Academy

AWS Academy environments provide students with valuable hands-on experience with AWS services. However, these environments come with certain restrictions to protect resources and ensure lab environments remain stable. One of the most significant limitations is the inability to create custom IAM roles.

## Key Limitations

1. **No IAM Role Creation**: 
   ```
   User: arn:aws:sts::990064625834:assumed-role/voclabs/user is not authorized to perform: iam:CreateRole
   ```
   - This error prevents students from creating custom IAM roles needed for services to interact with each other

2. **No IAM Policy Attachment**:
   - Even if using existing roles, attaching policies may be restricted

3. **CloudFormation Deployment Constraints**:
   - Since CloudFormation templates often require creating IAM resources, many standard templates fail

## The LabRole Solution

AWS Academy provides a pre-configured IAM role called "LabRole" that has permissions to many AWS services. This is the recommended approach when working in AWS Academy environments.

### How to Use LabRole

1. **CloudFormation Templates**: 
   - Instead of creating new IAM roles, reference the existing LabRole:
   ```yaml
   # Instead of creating a new role:
   LambdaExecutionRole:
     Type: AWS::IAM::Role
     # ... role creation that would fail
     
   # Use the existing role:
   Lambda:
     Type: AWS::Lambda::Function
     Properties:
       Role: !Sub "arn:aws:iam::${AWS::AccountId}:role/LabRole"
       # ... other properties
   ```

2. **Service-to-Service Communication**:
   - When one AWS service needs to access another, use LabRole where possible
   - Example for Lambda accessing DynamoDB:
   ```javascript
   // The Lambda already has permissions via LabRole
   const AWS = require('aws-sdk');
   const dynamodb = new AWS.DynamoDB.DocumentClient();
   ```

## Our Approach to Working Around IAM Limitations

For our Real-Time Chat Application, we've implemented several strategies to work within AWS Academy constraints:

### 1. Modified CloudFormation Template

We created a special version of our CloudFormation template (`main-template-labmode.yml`) that:
- Uses the existing LabRole instead of creating new roles
- Simplifies the deployment architecture when needed
- Removes IAM resources that would cause deployment failure

### 2. Fallback to Manual Deployment

When even the LabRole approach fails (due to specific AWS Academy environment configurations), we provide a detailed manual deployment guide:
- Step-by-step instructions for creating resources via the AWS Console
- Focus on S3 static website hosting for the frontend
- Demonstration of the UI with simulated backend functionality

### 3. Frontend Demo Mode

Our application includes a demo mode that:
- Runs entirely in the browser with no backend dependencies
- Simulates WebSocket connections and message exchange
- Implements client-side sentiment analysis
- Provides a realistic experience of the application without requiring backend services

## Documentation of Limitations in Project Deliverables

In our final report and project documentation, we:
1. Clearly explain AWS Academy restrictions and their impact
2. Detail our architecture decisions in light of these constraints
3. Demonstrate our understanding of IAM best practices even if we couldn't implement them
4. Show how we'd implement the full solution in a non-restricted environment

## References

1. [AWS Academy Learner Lab - Supported Services](https://aws.amazon.com/blogs/training-and-certification/accessing-aws-services-from-the-aws-academy-learner-lab/)
2. [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
3. [CloudFormation Resource Specification](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-iam-role.html) 