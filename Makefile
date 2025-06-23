# Variables
STACK_NAME := codebuild-sample-stack
PROJECT_NAME := sample-build-project
BRANCH_NAME := main
REGION := ap-northeast-1

# Default target
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  deploy         - Deploy CloudFormation stack"
	@echo "  delete         - Delete CloudFormation stack"
	@echo "  status         - Show stack status"
	@echo "  outputs        - Show stack outputs"
	@echo "  start-build    - Start CodeBuild project"
	@echo "  build-status   - Show build status"
	@echo "  clone-repo     - Clone CodeCommit repository"
	@echo "  push-code      - Push code to CodeCommit"
	@echo "  list-builds    - List recent builds"
	@echo "  validate       - Validate CloudFormation template"

# Deploy CloudFormation stack
.PHONY: deploy
deploy:
	@echo "Deploying CloudFormation stack..."
	aws cloudformation deploy \
		--template-file cloudformation.yaml \
		--stack-name $(STACK_NAME) \
		--parameter-overrides \
			ProjectName=$(PROJECT_NAME) \
			BranchName=$(BRANCH_NAME) \
		--capabilities CAPABILITY_NAMED_IAM \
		--region $(REGION)

# Delete CloudFormation stack
.PHONY: delete
delete:
	@echo "Deleting CloudFormation stack..."
	aws cloudformation delete-stack \
		--stack-name $(STACK_NAME) \
		--region $(REGION)
	@echo "Waiting for stack deletion..."
	aws cloudformation wait stack-delete-complete \
		--stack-name $(STACK_NAME) \
		--region $(REGION)

# Show stack status
.PHONY: status
status:
	aws cloudformation describe-stacks \
		--stack-name $(STACK_NAME) \
		--region $(REGION) \
		--query 'Stacks[0].StackStatus' \
		--output text

# Show stack outputs
.PHONY: outputs
outputs:
	aws cloudformation describe-stacks \
		--stack-name $(STACK_NAME) \
		--region $(REGION) \
		--query 'Stacks[0].Outputs' \
		--output table

# Start CodeBuild project
.PHONY: start-build
start-build:
	@echo "Starting CodeBuild project..."
	aws codebuild start-build \
		--project-name $(PROJECT_NAME) \
		--region $(REGION)

# Show build status
.PHONY: build-status
build-status:
	aws codebuild list-builds-for-project \
		--project-name $(PROJECT_NAME) \
		--region $(REGION) \
		--query 'ids[0]' \
		--output text | \
	xargs -I {} aws codebuild batch-get-builds \
		--ids {} \
		--region $(REGION) \
		--query 'builds[0].buildStatus' \
		--output text

# Clone CodeCommit repository
.PHONY: clone-repo
clone-repo:
	$(eval REPO_URL := $(shell aws cloudformation describe-stacks \
		--stack-name $(STACK_NAME) \
		--region $(REGION) \
		--query 'Stacks[0].Outputs[?OutputKey==`RepositoryCloneUrlHttp`].OutputValue' \
		--output text))
	@echo "Cloning repository from: $(REPO_URL)"
	git clone $(REPO_URL) source-code

# Push code to CodeCommit (assumes you're in the cloned repository directory)
.PHONY: push-code
push-code:
	@echo "Adding and committing files..."
	git add .
	git commit -m "Add buildspec.yml and source code"
	@echo "Pushing to CodeCommit..."
	git push origin $(BRANCH_NAME)

# List recent builds
.PHONY: list-builds
list-builds:
	aws codebuild list-builds-for-project \
		--project-name $(PROJECT_NAME) \
		--region $(REGION) \
		--query 'ids[:5]' \
		--output text | \
	xargs aws codebuild batch-get-builds \
		--ids \
		--region $(REGION) \
		--query 'builds[*].[buildNumber,buildStatus,startTime]' \
		--output table

# Validate CloudFormation template
.PHONY: validate
validate:
	@echo "Validating CloudFormation template..."
	aws cloudformation validate-template \
		--template-body file://cloudformation.yaml \
		--region $(REGION)

# Setup complete pipeline (deploy and configure)
.PHONY: setup
setup: validate deploy
	@echo "Stack deployed successfully!"
	@echo "Repository URL:"
	@make outputs | grep RepositoryCloneUrlHttp
	@echo ""
	@echo "Next steps:"
	@echo "1. Clone the repository: make clone-repo"
	@echo "2. Add your source code to the cloned repository"
	@echo "3. Push code: make push-code"
	@echo "4. Start a build: make start-build"

# Clean up everything
.PHONY: cleanup
cleanup:
	@echo "Cleaning up resources..."
	@echo "Emptying S3 bucket first..."
	$(eval BUCKET_NAME := $(shell aws cloudformation describe-stacks \
		--stack-name $(STACK_NAME) \
		--region $(REGION) \
		--query 'Stacks[0].Outputs[?OutputKey==`ArtifactsBucketName`].OutputValue' \
		--output text 2>/dev/null || echo ""))
	@if [ -n "$(BUCKET_NAME)" ]; then \
		aws s3 rm s3://$(BUCKET_NAME) --recursive --region $(REGION); \
	fi
	@make delete