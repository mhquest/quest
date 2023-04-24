# Deploying Infrastructure

1. Make sure you have a AWS profile `quest-<env>` in your AWS creds
2. Install Terraform 1.4.4 via download or `tfenv`
3. Run the following commands

```
terraform workspace select staging
terraform init -backend-config=staging.s3.tfbackend
terraform apply -var-file=staging.tfvars
```

# Deploying App

> Normally, I do this in CI on the app side of things

```
docker tag staging-quest-app 732332138136.dkr.ecr.us-east-2.amazonaws.com/staging-quest-app:latest && docker push 732332138136.dkr.ecr.us-east-2.amazonaws.com/staging-quest-app:latest
```
