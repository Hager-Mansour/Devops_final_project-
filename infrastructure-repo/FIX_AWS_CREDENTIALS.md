# Quick Fix Guide: AWS Credentials

Your pipeline also needs AWS credentials. Here's how to add them:

## Option 1: Add to Variable Group (Recommended)

1. Go to Azure DevOps → **Pipelines** → **Library**
2. Click on `infrastructure-dev` variable group
3. Add/Update these variables:
   - `AWS_ACCESS_KEY_ID` = your-access-key-id (🔒 mark as secret)
   - `AWS_SECRET_ACCESS_KEY` = your-secret-access-key (🔒 mark as secret)
4. Click **Save**

## Option 2: Use AWS Service Connection

1. Go to **Project Settings** → **Service connections**
2. Click **New service connection**
3. Select **AWS**
4. Enter your credentials
5. Name it `aws-connection`
6. Update pipeline to use it

## Test Credentials

```bash
export AWS_ACCESS_KEY_ID=your-key
export AWS_SECRET_ACCESS_KEY=your-secret
aws sts get-caller-identity
```

Should return your AWS account info.
