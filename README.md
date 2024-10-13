# DevOps UE: Assignment 3<br>IaC with Terraform & Azure

## Objective

**Assignment objective:** Gain practical experience with IaC using Terraform.<br>
**Key concepts:** Terraform, IaC, Azure Cloud.<br>
**Requirements:** Azure CLI, Terraform.

## Task

- Deploy a containerized web application in the cloud using Terraform.
- The application should be accessed by a DNS record.

## Solution

### 1. Prepare environment

- Install Azure CLI: [Install Azure CLI on Windows](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=azure-cli)
- Install Terraform: [Install Terraform on Windows](https://developer.hashicorp.com/terraform/install)
- Login to Azure

```
az login
```

- Create Azure service principal

**Request**

```
az sp create-for-rbac --name nextjs-fabian --role Contributor --scopes /subscriptions/{subscriptionId}
```

**Response**

```
{
  "appId": "", // AZURE_CLIENT_ID
  "displayName": "",
  "password": "", // AZURE_CLIENT_SECRET
  "tenant": "" // AZURE_TENANT_ID
}
```

- Create required application access keys<br>
  ![alt text](https://github.com/fabiannaether/devops-assignment1-fabian/blob/f/assignment3/images/secrets_service-principal.png?raw=true)

### 2. Utilize Terraform with Azure components

**terraform/providers.tf**

```
# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.0"
    }
  }
  required_version = ">= 0.14.9"
}
provider "azurerm" {
  features {}
}
```

**terraform/main.tf**

```
# Create the resource group
resource "azurerm_resource_group" "rg" {
  name     = "nextjs-fabian"
  location = "westus"
}

# 2. Create the container registry
resource "azurerm_container_registry" "acr" {
  name                = "nextjsacrfabian"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

# Create the Linux app service plan
resource "azurerm_service_plan" "appserviceplan" {
  name                = "nextjs-asp-fabian"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "B1"
}

# Create the web app with Docker image
resource "azurerm_linux_web_app" "webapp" {
  name                  = "nextjs-fabian"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  service_plan_id       = azurerm_service_plan.appserviceplan.id
  https_only            = true
  site_config {
    minimum_tls_version = "1.2"
    application_stack {
      docker_image     = "${azurerm_container_registry.acr.login_server}/startup-nextjs-fabian"
      docker_image_tag = "latest"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"
    DOCKER_REGISTRY_SERVER_URL          = "https://${azurerm_container_registry.acr.login_server}"
    DOCKER_REGISTRY_SERVER_USERNAME     = azurerm_container_registry.acr.admin_username
    DOCKER_REGISTRY_SERVER_PASSWORD     = azurerm_container_registry.acr.admin_password
    DOCKER_ENABLE_CI                    = "true"
  }
}
```

### 3. Implement Terraform steps in GitHub pipeline and provisioning in Azure

- Terraform steps in GitHub pipeline

```
# Terraform job
  terraform:
    name: Deploy web app to Azure using Terraform
    if: env.ENVIRONMENT == 'production'
    runs-on: ubuntu-latest
    needs: build

    env:
      ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
      ARM_CLIENT_SECRET: ${{ secrets.AZURE_CLIENT_SECRET }}
      ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Log in to Azure
        uses: azure/login@v2
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Terraform Init
        run: terraform init
        working-directory: ./terraform

      - name: Terraform Validate
        run: terraform validate
        working-directory: ./terraform

      - name: Terraform Plan
        run: terraform plan
        working-directory: ./terraform

      - name: Terraform Apply
        run: terraform apply -auto-approve
        working-directory: ./terraform

      - name: Log in to ACR
        uses: docker/login-action@v3
        with:
          registry: nextjsacrfabian.azurecr.io
          username: ${{ secrets.AZURE_CLIENT_ID }}
          password: ${{ secrets.AZURE_CLIENT_SECRET }}

      - name: Build and push Docker image to ACR
        run: |
          docker build -t nextjsacrfabian.azurecr.io/startup-nextjs-fabian:latest .
          docker push nextjsacrfabian.azurecr.io/startup-nextjs-fabian:latest
```

![alt text](https://github.com/fabiannaether/devops-assignment1-fabian/blob/f/assignment3/images/terraform_deployment.png?raw=true)<br>

- Check provisioning in Azure: [Azure web app](https://nextjs-fabian.azurewebsites.net)<br>
  ![alt text](https://github.com/fabiannaether/devops-assignment1-fabian/blob/f/assignment3/images/check_provisioning-azure.png?raw=true)

## Contributor

Fabian Näther
