# DevOps UE: Assignment 1<br>CI/CD pipeline in GitHub Actions for a web app

## Objective

Containerize a web application and build a CI/CD pipeline.<br>
**Focus:** Create a CI/CD pipeline for a simple web application using DevOps tools.<br>
**Prerequisite:** Understanding of relevant lecture material is required.

## Task

### 1. Containerize a Next.js web app and create a CI/CD pipeline using GitHub Actions

**Steps for the pipeline:** Set up linting, building, and auditing stages in the pipeline.<br>
**Triggers:** Different triggers for each stage

- The lint step should be run on each push to the repository and on every branch.
- The build step should be run on each push to the repository and on every branch.
- The audit step should only be run when merging to the _main_ or _release_ branch.

### 2. Images pushed to a Docker Hub repository during the release pipeline

### 3. Web app is being deployed on Azure Container Apps

## Solution

### 1. Containerize a Next.js web app and create a CI/CD pipeline using GitHub Actions

- Create necessary branches

  - release (default)
  - dev

- Create a Dockerfile for a multi-stage build

```
# Stage 1: Build the application
FROM node:20 AS builder
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: Production-ready image
FROM node:20-alpine AS runner
WORKDIR /app
COPY --from=builder /app ./
EXPOSE 3000
ENV NODE_ENV=production
CMD ["npm", "run", "start"]
```

- Write GitHub Actions pipeline:

```
name: CI/CD pipeline

on:
  push: # Push event for linting and building on every branch
    branches:
      - "**" # Run lint and build on any branch push
  pull_request: # Trigger audit only when PR is merged into release branch
    types:
      - closed
    branches:
      - release

jobs:
  # Linting job
  lint:
    name: Lint code
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "20"

      - name: Install dependencies
        run: npm install

      - name: Run lint
        run: npm run lint

  # Build job
  build:
    name: Build application
    runs-on: ubuntu-latest
    needs: lint
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "20"

      - name: Install dependencies
        run: npm install

      - name: Build app
        run: npm run build

  # Audit job (only runs after PR is merged to 'release')
  audit:
    name: Audit dependencies
    if: github.event_name == 'push' && github.ref == 'refs/heads/release' && contains(github.event.head_commit.message, 'Merge pull request')
    runs-on: ubuntu-latest
    needs: build
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "20"

      - name: Install dependencies
        run: npm install

      - name: Run npm audit
        run: npm audit
```

- Test the implementation<br>
  **Dev-Branch**<br>![alt text](https://github.com/fabiannaether/devops-assignment1-fabian/blob/dev/images/test_dev-branch.png?raw=true)<br>
  **Release-Branch**<br>![alt text](https://github.com/fabiannaether/devops-assignment1-fabian/blob/dev/images/test_release-branch.png?raw=true)

### 2. Images pushed to a Docker Hub repository during the release pipeline

- Create new _Docker Hub_ repository secrets<br>
  ![alt text](https://github.com/fabiannaether/devops-assignment1-fabian/blob/dev/images/secrets_docker-hub.png?raw=true)

- Create Docker Hub repository: [Docker Hub repository](https://hub.docker.com/repository/docker/fabiannaether/startup-nextjs-fabian/general)<br>
  ![alt text](https://github.com/fabiannaether/devops-assignment1-fabian/blob/dev/images/create_docker-hub-repository.png?raw=true)

- Add Docker build and push job in GitHub Actions pipeline

```
  # Docker build and push job (only runs after PR is merged to 'release')
  docker:
    name: Build and push Docker image
    if: github.event_name == 'push' && github.ref == 'refs/heads/release' && contains(github.event.head_commit.message, 'Merge pull request')
    runs-on: ubuntu-latest
    needs: audit
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Set up Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_HUB_USERNAME }}
          password: ${{ secrets.DOCKER_HUB_ACCESS_TOKEN }}

      - name: Build and push Docker image
        run: |
          docker build -t ${{ secrets.DOCKER_HUB_USERNAME }}/startup-nextjs-fabian:latest .
          docker push ${{ secrets.DOCKER_HUB_USERNAME }}/startup-nextjs-fabian:latest
```

- Check image in Docker Hub<br>
  ![alt text](https://github.com/fabiannaether/devops-assignment1-fabian/blob/dev/images/check_docker-hub-repository.png?raw=true)

### 3. Web app is being deployed on Azure Container Apps

- Create Azure resource group<br>
  ![alt text](https://github.com/fabiannaether/devops-assignment1-fabian/blob/dev/images/create_azure-resource-group.png?raw=true)<br>
- Create Azure container registry<br>
  ![alt text](https://github.com/fabiannaether/devops-assignment1-fabian/blob/dev/images/create_azure-container-registry.png?raw=true)<br>
- Get _ACR_ access keys
  ![alt text](https://github.com/fabiannaether/devops-assignment1-fabian/blob/dev/images/get_azure-access-keys.png?raw=true)<br>
- Create _Contentful_ API keys (Access token and space ID)<br>
  ![alt text](https://github.com/fabiannaether/devops-assignment1-fabian/blob/dev/images/create_contentful-api-keys.png?raw=true)<br>
- Create new _ACR_ and _Contentful_ repository secrets<br>
  ![alt text](https://github.com/fabiannaether/devops-assignment1-fabian/blob/dev/images/secrets_acr_contentful.png?raw=true)<br>
- Add deployment job in GitHub Actions pipeline

```
# Deployment job (only runs after PR is merged to 'release')
  deploy:
    name: Deploy Docker image to Azure Container Apps
    if: github.event_name == 'push' && github.ref == 'refs/heads/release' && contains(github.event.head_commit.message, 'Merge pull request')
    runs-on: ubuntu-latest
    needs: docker
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Log in to Azure Container Registry
        uses: azure/docker-login@v2
        with:
          login-server: ${{ secrets.ACR_LOGIN_SERVER }}
          username: ${{ secrets.ACR_USERNAME }}
          password: ${{ secrets.ACR_PASSWORD }}

      - name: Build and publish
        uses: docker/build-push-action@v6
        with:
          push: true
          build-args: |
            CONTENTFUL_SPACE_ID=${{ secrets.NEXT_PUBLIC_CONTENTFUL_SPACE_ID }}
            CONTENTFUL_ACCESS_TOKEN=${{ secrets.NEXT_PUBLIC_CONTENTFUL_ACCESS_TOKEN }}
          tags: ${{ secrets.ACR_LOGIN_SERVER }}/startup-nextjs-fabian:latest
          file: ./Dockerfile
```

- Check Docker image in repository of Azure container registry<br>
  ![alt text](https://github.com/fabiannaether/devops-assignment1-fabian/blob/dev/images/check_docker-image-repository.png?raw=true)<br>
- Create Azure web app<br>
  ![alt text](https://github.com/fabiannaether/devops-assignment1-fabian/blob/dev/images/create_azure-web-app.png?raw=true)<br>
- Update web app settings in Azure deployment center<br>
  ![alt text](https://github.com/fabiannaether/devops-assignment1-fabian/blob/dev/images/settings_azure-deployment-center.png?raw=true)<br>
- Start Azure web app: [Azure web app](https://startupnextjsfabian.azurewebsites.net)<br>
  ![alt text](https://github.com/fabiannaether/devops-assignment1-fabian/blob/dev/images/start_azure-web-app-1.png?raw=true)<br>
  ![alt text](https://github.com/fabiannaether/devops-assignment1-fabian/blob/dev/images/start_azure-web-app-2.png?raw=true)

## Contributor

Fabian Näther
