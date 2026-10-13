# Terraform + Ansible: AWS EC2 Nginx Lab

A minimal, working IaC pipeline: Terraform provisions an EC2 instance on AWS, Ansible configures it remotely and idempotently. Built as a hands-on learning project to demonstrate the standard provisioning-then-configuration pattern used in real DevOps workflows.

## What it does

1. **Terraform** creates an SSH key pair, a security group (SSH + HTTP), and an EC2 instance (Amazon Linux 2023, `t3.micro`, AWS Free Tier eligible). The latest AMI is resolved dynamically via a data source, avoiding hardcoded, quickly outdated AMI IDs.
2. **Ansible** connects to the instance over SSH and installs/configures Nginx via a reusable role, deploying a Jinja2 templated page.
3. The Ansible role is **OS-portable**: it detects the target's OS family (`ansible_os_family`) and loads the matching package/path variables, so the same role runs unmodified on Debian/Ubuntu or RedHat/Amazon Linux.

## Structure

- `terraform/`: provisions the AWS infrastructure
  - `main.tf`, `variables.tf`, `outputs.tf`
- `ansible/`: configures the provisioned instance
  - `nginx.yml`, `aws_ec2.yml`, `roles/nginx/`

## Usage

```bash
# 1. Generate a dedicated SSH key (once)
ssh-keygen -t ed25519 -f ~/.ssh/terraform-lab -N ""

# 2. Provision the infrastructure
cd terraform
terraform init
terraform apply

# 3. No IP to copy: the dynamic inventory (aws_ec2.yml) finds the instance by its tag

# 4. Configure it
cd ../ansible
ansible-playbook -i aws_ec2.yml nginx.yml

# 5. Tear down when done
cd ../terraform
terraform destroy
```

## Design choices worth noting

- **No hardcoded credentials anywhere.** The AWS provider reads credentials from the local AWS CLI configuration (`aws configure`), never from code.
- **Dedicated IAM user**, not root, with managed policies scoped to the services used (`AmazonEC2FullAccess`, `AmazonS3FullAccess`).
- **Idempotence is deliberate, not automatic.** An earlier version of this project used `timestamp()` in a resource, which broke Terraform idempotence (forced replace on every plan). Fixed by removing non-deterministic values from resource definitions.
- **`.terraform.lock.hcl` is committed** (not ignored) to pin provider versions for reproducibility.

## Remote state

Terraform state is stored in an S3 bucket instead of a local file, with versioning enabled, public access blocked, encryption at rest, and native state locking (`use_lockfile`, available since Terraform 1.10, no DynamoDB table needed).

The bucket is created once, outside Terraform, since it must exist before Terraform can store its state in it:

    aws s3api create-bucket --bucket <your-unique-bucket-name> --region eu-west-3 --create-bucket-configuration LocationConstraint=eu-west-3
    aws s3api put-bucket-versioning --bucket <your-unique-bucket-name> --versioning-configuration Status=Enabled
    aws s3api put-public-access-block --bucket <your-unique-bucket-name> --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

Then set the bucket name in the `backend "s3"` block of `terraform/main.tf` (backend blocks cannot use variables).

Why it matters: a local state file is a single point of failure and cannot be shared safely. A remote backend gives one source of truth, state history through versioning, and protection against two concurrent applies.

## Dynamic inventory

The `ansible/aws_ec2.yml` inventory queries AWS for running instances tagged `Name=terraform-lab`, so there is no IP to copy after each `terraform apply`. It requires the `amazon.aws` collection and `boto3`:

    ansible-galaxy collection install amazon.aws
    sudo apt install -y python3-boto3 python3-botocore

Check what Ansible discovers with `ansible-inventory -i aws_ec2.yml --graph`.
