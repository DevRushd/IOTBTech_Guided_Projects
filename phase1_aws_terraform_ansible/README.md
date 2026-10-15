# Phase 1: Terraform builds it, Ansible configures it

Two AWS servers, built with Terraform and set up with Ansible from the first server.

| Name in the task | Name in this repo | Job |
|---|---|---|
| master | **control node** | Runs Ansible. You log in to this one. |
| slave | **managed node** | Gets configured by Ansible. Only the control node can SSH to it. |

```
Your laptop --SSH (-A)--> Control node ---SSH over private IP---> Managed node
                          (Ansible lives here)                    (Docker installed by Ansible)
        both servers: same VPC, same public subnet, same key pair
```

## What is in the repo

```
.
├── terraform/
│   ├── bootstrap/                 # step 1: S3 bucket that stores Terraform state
│   ├── environments/dev/          # step 2: the real build (VPC + 2 servers)
│   │   ├── main.tf  variables.tf  outputs.tf  versions.tf
│   │   ├── terraform.tfvars.example   backend.hcl.example
│   │   └── templates/             # inventory template + control-node first-boot script
│   └── modules/
│       ├── vpc_subnet_igw_rtb/    # VPC, subnet, internet gateway, route table
│       └── ec2_with_SG/           # security group + EC2 instance (used twice)
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/                 # hosts.ini is written here by Terraform
│   ├── playbooks/                 # site.yml (configure) and verify.yml (test)
│   └── roles/                     # common (updates) and docker (install + start)
├── docs/screenshots/              # put your two screenshots here
└── .gitignore
```

## Before you start

- AWS credentials set up on your machine (profile or SSO). Check with `aws sts get-caller-identity`. Never paste keys into any file in this repo.
- Terraform **1.10 or newer** (needed for S3 state locking), AWS CLI v2, Git, OpenSSH.
- If you use Windows, run every command inside WSL, and keep your SSH keys in WSL's `~/.ssh` (not under `/mnt/c`), otherwise SSH will complain about key permissions.

## Step by step

### 1. Create a new SSH key pair

```bash
ssh-keygen -t ed25519 -f ~/.ssh/iotbtech-aws -C "iotbtech-phase1"
```

You get two files. The `.pub` file (public) goes to AWS. The other file (private) never leaves your machine and is never committed.

### 2. Find your public IP

```bash
curl -s https://checkip.amazonaws.com
```

You will use it as `<your-ip>/32` so only you can SSH in.

### 3. Create the state bucket (one time)

```bash
cd terraform/bootstrap
terraform init
terraform apply
terraform output -raw backend_hcl_example
```

Keep the output; you need it in the next step.

### 4. Build the infrastructure

```bash
cd ../environments/dev
cp terraform.tfvars.example terraform.tfvars   # set allowed_ssh_cidrs to your IP
cp backend.hcl.example backend.hcl             # paste the output from step 3

terraform init -backend-config=backend.hcl
terraform fmt -check -recursive ../..
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Terraform also writes `ansible/inventory/hosts.ini` for you.

**Screenshot 1:** AWS Console, EC2, Instances, both servers in the `running` state. Save it in `docs/screenshots/`.

### 5. Load your key and copy Ansible to the control node

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/iotbtech-aws

terraform output -raw copy_ansible_command    # prints the scp command
scp -r ../../../ansible ubuntu@<CONTROL_PUBLIC_IP>:~/
```

### 6. Log in to the control node

```bash
terraform output -raw ssh_command_control     # prints: ssh -A ubuntu@<ip>
ssh -A ubuntu@<CONTROL_PUBLIC_IP>
```

The `-A` lets the control node use your key through your laptop's SSH agent, so the private key is never copied to a server.

### 7. Run Ansible (on the control node)

```bash
cloud-init status --wait      # waits until Ansible finished installing
ansible --version
ssh-add -l                    # should list your key (confirms forwarding works)

cd ~/ansible
ansible nodes -m ping                      # both nodes should answer "pong"
ansible-playbook playbooks/site.yml        # update + install + start Docker
ansible-playbook playbooks/site.yml        # run again: expect changed=0 (idempotent)
ansible-playbook playbooks/verify.yml      # proves Docker works on both nodes
```

**Screenshot 2:** the `ansible-playbook` recap (`failed=0`) and the `verify.yml` output showing both nodes.

### 8. Push to GitHub

```bash
git init && git add . && git status    # make sure no .tfvars, .pem, .tfstate or hosts.ini appear
git commit -m "Phase 1: Terraform + Ansible"
git remote add origin <your-repo-url> && git push -u origin main
```

### 9. Clean up (to avoid charges)

```bash
cd terraform/environments/dev
terraform destroy
```

The state bucket is protected on purpose (`prevent_destroy`). Leave it; it costs almost nothing.

## Why it is built this way

- **No secrets in code.** Only the public key is given to Terraform. Credentials come from your AWS profile. `.gitignore` blocks keys, state files, and `.tfvars`.
- **State is stored safely.** The S3 bucket is encrypted, versioned, private, and TLS-only, with locking so two people cannot apply at once.
- **Least access.** Only your IP can SSH to the control node. The managed node accepts SSH only from the control node's security group. The VPC's default security group is emptied. Both disks are encrypted, and the instance metadata service requires IMDSv2. No IAM role is attached because nothing here needs one.
- **Reusable modules.** One module builds the network and one builds "security group + server"; the second is called twice with different settings.
- **Idempotent Ansible.** Run it as many times as you like; the second run changes nothing.

## Growing past two servers

Adding a server means launching it with the same key pair and adding it to the inventory. For many servers, replace the generated `hosts.ini` with Ansible's AWS dynamic inventory (the `amazon.aws.aws_ec2` plugin), which finds servers by tag.

## Troubleshooting

| Problem | Likely cause and fix |
|---|---|
| `Permission denied (publickey)` | Run `ssh-add ~/.ssh/iotbtech-aws` again; check `ssh-add -l`. |
| SSH hangs or times out | Your IP changed. Update `allowed_ssh_cidrs`, then `terraform apply`. |
| `ansible: command not found` on control node | First-boot install still running. Run `cloud-init status --wait`. |
| Ansible cannot reach the managed node | Run `ssh-add -l` on the control node. If empty, log in again with `ssh -A`. |
| No matching AMI | The AMI name pattern does not exist in your region. Check `ubuntu_ami_name_pattern`. |
| Backend error on `terraform init` | `backend.hcl` is missing or has the wrong bucket name. |
