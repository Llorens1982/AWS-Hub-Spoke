# AWS Hub & Spoke — Terraform + GitHub Actions

Infraestructura Hub & Spoke en AWS desplegada con Terraform y automatizada con GitHub Actions.

## Arquitectura

```
                        ┌─────────────────────────────────┐
                        │          AWS Account             │
                        │                                  │
                        │   ┌──────────────────────────┐  │
                        │   │       HUB VPC            │  │
                        │   │  10.0.0.0/16             │  │
                        │   │                          │  │
                        │   │  ┌──────────┐            │  │
                        │   │  │ Bastion  │            │  │
                        │   │  │  Host    │            │  │
                        │   │  └──────────┘            │  │
                        │   │  ┌──────────┐            │  │
                        │   │  │ Shared   │            │  │
                        │   │  │ Services │            │  │
                        │   │  └──────────┘            │  │
                        │   └──────────┬───────────────┘  │
                        │              │                   │
                        │   ┌──────────▼───────────────┐  │
                        │   │   Transit Gateway (TGW)  │  │
                        │   └──────┬──────────┬────────┘  │
                        │          │          │            │
                        │   ┌──────▼──┐  ┌───▼─────┐     │
                        │   │ SPOKE 1 │  │ SPOKE 2 │     │
                        │   │ Dev VPC │  │ Prod VPC│     │
                        │   │10.1.0/16│  │10.2.0/16│     │
                        │   └─────────┘  └─────────┘     │
                        └─────────────────────────────────┘
```

## Estructura del Repositorio

```
aws-hub-spoke/
├── modules/
│   ├── vpc/                # Módulo VPC reutilizable
│   ├── tgw/                # Transit Gateway + attachments
│   ├── security-groups/    # Security Groups por rol
│   └── ec2-bastion/        # Bastion Host en Hub
├── envs/
│   ├── dev/                # Entorno de desarrollo (Spoke 1)
│   └── prod/               # Entorno de producción (Spoke 2)
├── scripts/                # Scripts de utilidad
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml    # PR → terraform plan
│       └── terraform-apply.yml   # main → terraform apply
├── backend.tf              # Remote state (S3 + DynamoDB)
├── main.tf                 # Hub + TGW + Spokes
├── variables.tf
├── outputs.tf
└── versions.tf
```

## Pre-requisitos

| Herramienta | Versión mínima |
|-------------|---------------|
| Terraform   | >= 1.6.0      |
| AWS CLI     | >= 2.x        |
| Git         | >= 2.x        |

## GitHub Actions Secrets requeridos

```
AWS_ACCESS_KEY_ID        # IAM credentials con permisos de despliegue
AWS_SECRET_ACCESS_KEY
TF_STATE_BUCKET          # Nombre del bucket S3 para el estado
TF_LOCK_TABLE            # Nombre de la tabla DynamoDB para locks
AWS_REGION               # Región principal (ej: eu-west-1)
```

## Bootstrap inicial (una sola vez)

```bash
# 1. Crear el bucket S3 y tabla DynamoDB para el estado remoto
./scripts/bootstrap.sh <nombre-bucket> <nombre-tabla> <region>

# 2. Inicializar Terraform
terraform init

# 3. Plan y Apply
terraform plan -out=tfplan
terraform apply tfplan
```

## Flujo de trabajo CI/CD

- **Pull Request** → ejecuta `terraform fmt`, `terraform validate`, `terraform plan`
- **Merge a main** → ejecuta `terraform apply` automáticamente
- **Destroy** → workflow manual con confirmación explícita

## Módulos

### `modules/vpc`
VPC con subnets públicas, privadas y de datos. Incluye IGW, NAT Gateway y route tables.

### `modules/tgw`
Transit Gateway con attachments a cada VPC y route tables de TGW para controlar el tráfico entre spokes.

### `modules/security-groups`
Security Groups por rol: bastion, shared-services, app, data.

### `modules/ec2-bastion`
Bastion Host en el Hub con Session Manager (SSM) — sin exposición de puerto 22 a internet.

## Seguridad

- El tráfico Spoke→Spoke está **bloqueado por defecto** en el TGW
- Todo el acceso a instancias se hace vía **AWS Systems Manager Session Manager**
- Estado de Terraform cifrado en S3 con KMS
- Locking del estado con DynamoDB
