# 🏗️ AWS Hub & Spoke - Terraform + GitHub Actions

**Arquitectura enterprise para workloads multi-VPC en AWS (eu-south-2 Madrid)**

[![Terraform](https://img.shields.io/badge/Terraform-1.9%2B-blue)](https://www.terraform.io)
[![AWS](https://img.shields.io/badge/AWS-eu--south--2-orange)](https://aws.amazon.com/es/about-aws/global-infrastructure/regions_az/)
[![GitHub Actions](https://github.com/[tu-user]/hub-spoke-aws-terraform/workflows/Terraform/badge.svg)](https://github.com/[tu-user]/hub-spoke-aws-terraform/actions)

## 🎯 Features
- **Hub VPC** (10.0.0.0/16): NAT, VPC Endpoints, Route53 Resolver
- **2 Spokes**: Prod (10.1.0.0/16) + Dev (10.2.0.0/16)
- **Transit Gateway**: Route tables segregadas [web:11]
- **CI/CD**: Plan en PRs, Apply auto en merge (OIDC)
- **Coste**: ~€48/mes (t3.micro + NAT) [web:27]

```mermaid
graph TD
    TG[Transit Gateway<br/>eu-south-2]:::hub
    HUB[VPC Hub<br/>10.0.0.0/16<br/>NAT + Endpoints]:::hub
    SPOKE1[VPC Prod<br/>10.1.0.0/16<br/>App + DB]:::spoke
    SPOKE2[VPC Dev<br/>10.2.0.0/16<br/>Workloads]:::spoke
    
    HUB -->|Hub RT| TG
    SPOKE1 -->|Prod RT| TG
    SPOKE2 -->|Dev RT| TG
    TG -->|Inspection| INTERNET[Internet Gateway]
    
    classDef hub fill:#ff9999
    classDef spoke fill:#66b3ff
