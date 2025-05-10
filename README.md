# Private Azure DevOps Build Agent with Controlled Internet Access via Azure Firewall

This setup provisions a private self-hosted Azure DevOps build
agent that resides in a secure Azure Virtual Network (VNet) and communicates with Azure DevOps over
the internet in a controlled way using Azure Firewall. The configuration is managed using Terraform.

- [Azure DevOps allowed urls](https://learn.microsoft.com/en-us/azure/devops/organizations/security/allow-list-ip-url?view=azure-devops&tabs=IP-V4)

## Objective

- Deploy a self-hosted Azure DevOps build agent within a private VNet (no public IP).
- Restrict internet access to only what is required for Azure DevOps communication.
- Use Azure Firewall to inspect and control all outbound traffic.

## Architecture Overview

### VNet Structure

- **Private Subnet**: Hosts the self-hosted build agent.
- **Firewall Subnet**: Dedicated subnet to host the Azure Firewall (requires name "AzureFirewallSubnet").
- **(Optional) Jumpbox Subnet**: Optional subnet for a Bastion host or Jumpbox to allow administrative access.

### Azure Firewall Configuration

- Acts as a NAT gateway to provide outbound internet access to the build agent.
- Configured with outbound rules to only allow traffic to Azure DevOps services.
- All other internet traffic is denied.
- DNS settings configured for name resolution if necessary.
- UDRs (User Defined Routes) force all traffic through the firewall.

### Route Table

- Associated with the private subnet where the agent resides.
- Includes a default route (0.0.0.0/0) that points to the private IP of the Azure Firewall in the same VNet.

## Azure DevOps Access Rules

- Configure Azure Firewall application and network rules to allow traffic to:
    - Azure DevOps service tags or specific IP ranges
    - Required domain names (e.g., dev.azure.com, *.vsts.ms, etc.)

Ensure the list of allowed endpoints is kept up to date by referencing the official Azure DevOps IP ranges.

## Notes

- Use Terraform to declaratively define and deploy all components.
- Regularly validate the list of Azure DevOps IPs and URLs, as they may change.
- Consider enabling diagnostics and logging on the firewall for monitoring.

This architecture provides a secure and scalable foundation for running private build agents in Azure with controlled
external connectivity.

## DevOps project

- https://dev.azure.com/PetroKolosovProjects/AzureDevOpsPrivateNetworkIntegration

## Modules used

- https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/firewall
- https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/firewall_application_rule_collection
- https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/bastion_host
- https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route_table
- https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route
- https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_route_table_association
