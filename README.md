# Terraform + Ansible: AWS EC2 Nginx Lab

A minimal, working IaC pipeline: Terraform provisions an EC2 instance on AWS, Ansible configures it remotely and idempotently. Built as a hands-on learning project to demonstrate the standard provisioning-then-configuration pattern used in real DevOps workflows.

## What it does

1. **Terraform** creates an SSH key pair, a security group (SSH + HTTP), and an EC2 instance (Amazon Linux 2023, `t3.micro`, AWS Free Tier eligible). The latest AMI is resolved dynamically via a data source, avoiding hardcoded, quickly outdated AMI IDs.
2. **Ansible** connects to the instance over SSH and installs/configures Nginx via a reusable role, deploying a Jinja2 templated page.
3. The Ansible role is **OS-portable**: it detects the target's OS family (`ansible_os_family`) and loads the matching package/path variables, so the same role runs unmodified on Debian/Ubuntu or RedHat/Amazon Linux.

## Structure

- `terraform/` — provisions the AWS infrastructure
  - `main.tf`, `variables.tf`, `outputs.tf`
- `ansible/` — configures the provisioned instance
  - `nginx.yml`, `inventory.ini.example`, `roles/nginx/`

## Usage

```bash
# 1. Generate a dedicated SSH key (once)
ssh-keygen -t ed25519 -f ~/.ssh/terraform-lab -N ""

# 2. Provision the infrastructure
cd terraform
terraform init
terraform apply

# 3. Point Ansible at the new instance
terraform output -raw public_ip
# copy inventory.ini.example -> inventory_aws.ini and set the IP

# 4. Configure it
cd ../ansible
ansible-playbook -i inventory_aws.ini nginx.yml

# 5. Tear down when done
cd ../terraform
terraform destroy
```

## Design choices worth noting

- **No hardcoded credentials anywhere.** The AWS provider reads credentials from the local AWS CLI configuration (`aws configure`), never from code.
- **Dedicated IAM user**, not root, with a scoped policy (`AmazonEC2FullAccess`).
- **Idempotence is deliberate, not automatic.** An earlier version of this project used `timestamp()` in a resource, which broke Terraform idempotence (forced replace on every plan). Fixed by removing non-deterministic values from resource definitions.
- **`.terraform.lock.hcl` is committed** (not ignored) to pin provider versions for reproducibility.
