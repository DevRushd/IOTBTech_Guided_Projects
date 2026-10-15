# IOTBTECH Guided Project: Build, Containerize, and Deploy an App on AWS

Part of the IOTBTECH 2026 Cloud & DevOps Fellowship.

This project has three phases. Each phase builds on the one before it, and together they take an application from a developer's laptop to a running server on AWS, with automatic deployment.

> **Status:** Phase 1 is fully documented below. Phases 2 and 3 are summarized from the project outline and will be filled in with full details as each phase is completed.

## Project at a glance

| Phase | Goal | Main tools | Status |
|---|---|---|---|
| **1. Provision AWS infrastructure** | Terraform builds the servers, Ansible sets them up with Docker | Terraform, Ansible, AWS | **In progress (documented below)** |
| **2. Containerize the application** | Package the provided app as a Docker image and push it to Amazon ECR | Docker, Amazon ECR | Planned |
| **3. Automate deployment** | GitHub Actions builds, pushes, and deploys the app to EC2 on every push | GitHub Actions, ECR, EC2 | Planned |

## The big picture

When all three phases are done, this is the full journey of a code change:

```
Developer pushes code
        |
     GitHub
        |
  GitHub Actions
        |
 Build Docker image        <- image defined in Phase 2
        |
   Push to ECR             <- registry created in Phase 2
        |
   EC2 server              <- server built in Phase 1
        |
 Pull new image, restart container
        |
 Application running
```

## Repository layout

```
.
├── terraform/                 # Phase 1: builds the AWS infrastructure
│   ├── bootstrap/             #   S3 bucket that stores Terraform's state
│   ├── environments/dev/      #   the real build (network + 2 servers)
│   └── modules/
│       ├── vpc_subnet_igw_rtb/    # VPC, subnet, internet gateway, route table
│       └── ec2_with_SG/           # security group + EC2 server (used twice)
├── ansible/                   # Phase 1: configures the servers
│   ├── ansible.cfg
│   ├── inventory/             #   hosts.ini is written here by Terraform
│   ├── playbooks/             #   site.yml (set up) and verify.yml (test)
│   └── roles/                 #   common (updates) and docker (install + start)
├── docs/screenshots/          # evidence screenshots for each phase
├── (app, Dockerfile, .dockerignore)     # Phase 2: planned
├── (.github/workflows/)                 # Phase 3: planned
├── .gitignore
└── README.md
```

---

## Phase 1: Provision AWS infrastructure with Terraform and Ansible

**In one sentence:** Terraform builds two servers on AWS, then Ansible logs in to them and sets them up with Docker.

```
Terraform creates the servers  -->  Ansible configures the servers
```

### What this phase does

| Tool | Job | What it produces |
|---|---|---|
| **Terraform** | Builds the infrastructure | A private network (VPC), a subnet, an internet gateway, a route table, security groups, one SSH key pair, and two EC2 servers |
| **Ansible** | Sets up the servers | Updated servers with Docker installed, started, and tested |

The two servers have different roles:

| Name in the task | Name in this repo | What it does |
|---|---|---|
| master | **control node** | Has Ansible installed. You log in here and run Ansible from here. |
| slave | **managed node** | Is configured by Ansible over SSH. It has no Ansible installed. Only the control node can SSH to it. |

### How the pieces connect

```
Your laptop --SSH (-A)--> CONTROL NODE ---SSH over private IP---> MANAGED NODE
                          Ansible installed here                  Docker installed here by Ansible
                          (Docker is installed here too)

Both servers: same VPC, same public subnet, same SSH key pair.
```

The `-A` option lets the control node borrow your SSH key through your laptop. The private key is never copied onto any server.

### Before you start

You need:

- An AWS account, with your login set up on your computer (profile or SSO). Check it with `aws sts get-caller-identity`. Never put access keys in any file in this repo.
- Terraform **1.10 or newer** (needed for state locking in S3), AWS CLI v2, Git, and OpenSSH.
- If you use Windows, run every command inside **WSL**, and keep the project and your SSH keys in WSL's home folder (`~`), not under `/mnt/c`. Keys and folders under `/mnt/c` get the wrong file permissions, and SSH and Ansible refuse to work with them.

### Step by step

#### 1. Create a new SSH key pair

```bash
ssh-keygen -t ed25519 -f ~/.ssh/iotbtech-aws -C "iotbtech-phase1"
```

This makes two files. The `.pub` file (public key) is given to AWS. The other file (private key) stays on your computer and is never committed. Set a passphrase when asked.

#### 2. Choose a server size

The default is `t3.micro`, which is Free Tier eligible on every account. AWS refuses other sizes on a Free Tier account (for example `t3.medium`). To see what your account allows:

```bash
aws ec2 describe-instance-types --region us-east-1 \
  --filters Name=free-tier-eligible,Values=true \
  --query "InstanceTypes[*].[InstanceType]" --output text | sort
```

Do not pick `t4g.*` sizes. They use a different processor type (ARM) than the Ubuntu image this project searches for.

#### 3. Create the state bucket (one time)

```bash
cd terraform/bootstrap
terraform init
terraform apply
terraform output -raw backend_hcl_example
```

Keep the printed text. It is the setting that tells Terraform where to store its state.

#### 4. Build the infrastructure

```bash
cd ../environments/dev
cp terraform.tfvars.example terraform.tfvars    # optional: change region or server size
cp backend.hcl.example backend.hcl              # paste the output from step 3

terraform init -backend-config=backend.hcl
terraform fmt -recursive ../..
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Your current public IP is detected automatically and is the only address allowed to SSH to the control node. If someone else also needs access, add their IP (with `/32`) to `allowed_ssh_cidrs` in `terraform.tfvars`.

When it finishes, Terraform has also written `ansible/inventory/hosts.ini`. Wait one to two minutes so the servers can finish starting.

#### 5. Load your key and copy Ansible to the control node

Run these from `terraform/environments/dev`:

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/iotbtech-aws
terraform output -raw copy_ansible_command       # shows the copy command
scp -r ../../../ansible ubuntu@<CONTROL_PUBLIC_IP>:~/
```

Copy the folder **after** `terraform apply` finishes, otherwise `hosts.ini` is missing.

#### 6. Log in to the control node

```bash
terraform output -raw ssh_command_control        # shows: ssh -A ubuntu@<ip>
ssh -A ubuntu@<CONTROL_PUBLIC_IP>
```

#### 7. Check the control node is ready

```bash
cloud-init status --wait      # waits for the Ansible install; should end with "status: done"
ansible --version
ssh-add -l                    # should list your key (proves key forwarding works)
```

#### 8. Run Ansible

```bash
cd ~/ansible                                   # always run Ansible from this folder
ansible nodes -m ping                          # both nodes should answer "pong"
ansible-playbook playbooks/site.yml            # update the servers, install and start Docker
ansible-playbook playbooks/site.yml            # run again: expect changed=0
ansible-playbook playbooks/verify.yml          # test Docker on both nodes
```

The second run showing `changed=0` proves the playbook is safe to run repeatedly.

#### 9. Clean up to avoid charges

When you are completely finished with the project (Phase 3 deploys to these servers, so keep them until then):

```bash
cd terraform/environments/dev
terraform destroy
```

The state bucket is protected on purpose. Leave it in place; it costs almost nothing.

### Phase 1 evidence

**1. Both EC2 servers running**

![EC2 instances running](docs/screenshots/01-ec2-running.png)

**2. Ansible configured both servers** (playbook recap with `failed=0`, and the Docker check on both nodes)

![Ansible success](docs/screenshots/02-ansible-success.png)

### Phase 1 security choices

- **No secrets in the code.** Terraform only receives the public key. AWS credentials come from your own login. `.gitignore` blocks keys, state files, and `.tfvars` files.
- **Safe state storage.** The S3 bucket is private, encrypted, versioned, and only accepts encrypted connections. State locking stops two people from applying changes at the same time.
- **Minimum access.** Only your IP can SSH to the control node. The managed node accepts SSH only from the control node. The VPC's default security group is emptied.
- **Hardened servers.** Disks are encrypted and the instance metadata service requires its newer, safer version (IMDSv2). No IAM role is attached because nothing in this phase needs one.
- **Reusable code.** One module builds the network and one builds a server with its security group. The server module is used twice with different settings.
- **Safe to repeat.** Ansible only changes what needs changing, so a second run changes nothing.

### Phase 1 troubleshooting

| What you see | Why and how to fix it |
|---|---|
| `The specified instance type is not eligible for Free Tier` | Your account only allows certain sizes. Set `instance_type = "t3.micro"` in `terraform.tfvars`, make a new plan, and apply it. |
| SSH times out | Your public IP changed (new network or VPN). Run `terraform apply` again; the allowed IP is updated automatically. |
| `Permission denied (publickey)` | Your key is not loaded. Run `ssh-add ~/.ssh/iotbtech-aws` and check with `ssh-add -l`. |
| `ansible: command not found` on the control node | The first-boot install is still running. Run `cloud-init status --wait`. |
| `provided hosts list is empty` or `Could not match supplied host pattern: nodes` | You are not in `~/ansible`, or `hosts.ini` was not copied, or Ansible ignored `ansible.cfg`. Run `cd ~/ansible`, check `ls inventory/`, and run `chmod 755 ~/ansible`. Check with `ansible-inventory --graph`. |
| `managed-node UNREACHABLE ... Host key verification failed` | SSH asked a question Ansible cannot answer. Fix the `ansible.cfg` problem above, or connect once by hand: `ssh ubuntu@<MANAGED_PRIVATE_IP>` and type `yes`. |
| `ssh-add -l` is empty on the control node | Key forwarding is off. Log out and log in again with `ssh -A`. |
| `The defaults/main.yml file for role ... must contain a dictionary of variables` | The file was changed or damaged during copying. Copy the `ansible` folder again from your laptop. |
| Files named `...:Zone.Identifier` appear | Windows adds these when you copy downloaded files into WSL. They are harmless. Delete them with `find . -name "*:Zone.Identifier" -type f -delete`. |
| Terraform cannot find the state | `backend.hcl` is missing or has the wrong bucket name. Do not change the `key` after the first apply. |

---

## Phase 2: Containerize the application and push to Amazon ECR

> **Status: planned.** The summary below comes from the project outline. Step-by-step instructions, commands, and screenshots will be added when this phase is done.

**Objective:** Take the application provided to the fellow, create a Docker image, test it locally, and push the image to Amazon Elastic Container Registry (ECR).

**What will be done:**

1. Clone the provided application and understand it: its dependencies, the port it needs, and the command that starts it.
2. Write a `Dockerfile` and a `.dockerignore` file.
3. Build the Docker image locally.
4. Run the container locally and confirm the application works.
5. Create an Amazon ECR repository.
6. Log Docker in to ECR, tag the image, and push it.
7. Check that the image appears in the ECR repository.
8. Document the process.

**Deliverables:**

- The provided application code, `Dockerfile`, and `.dockerignore`
- The Docker image and the ECR repository with the pushed image
- This README, updated with the Phase 2 steps
- Evidence that the application runs in a container
- Evidence that the image is in ECR

**Success looks like:**

```
Provided application --> Docker container --> Docker image --> Amazon ECR
```

**Documentation to be added:** _setup steps, application details (port, dependencies, start command), commands used, screenshots._

---

## Phase 3: Deploy the application using GitHub Actions

> **Status: planned.** The summary below comes from the project outline. Step-by-step instructions, the workflow file, and screenshots will be added when this phase is done.

**Objective:** Create a GitHub Actions pipeline (CI/CD) that automatically builds the application's Docker image, pushes it to Amazon ECR, and deploys it to the EC2 server from Phase 1.

**What will be done:**

1. Use the application from Phase 2 and the servers from Phase 1.
2. Create a GitHub Actions workflow that:
   - checks out the application code
   - builds the Docker image
   - signs in to AWS
   - pushes the image to ECR
   - connects to the EC2 server
   - deploys the new container
3. Store all credentials safely in GitHub Secrets (never in the code).
4. Set up the EC2 server to run the container.
5. Make sure the old container is replaced when a new version is deployed.
6. Start the pipeline automatically when changes are pushed to the chosen GitHub branch.
7. Check that the application is reachable after deployment.
8. Document the CI/CD process.

**Deliverables:**

- GitHub repository, `Dockerfile`, and the GitHub Actions workflow file
- ECR repository containing the application image
- The application deployed on EC2, with GitHub Secrets configured
- This README, updated with the Phase 3 steps
- Screenshot of a successful GitHub Actions run
- Screenshot of the application running on AWS

**Success looks like:** pushing an application update to GitHub automatically builds the new image, pushes it to ECR, and updates the application running on EC2, with no manual steps.

**Documentation to be added:** _workflow explanation, list of required secrets (names only), how to trigger a deployment, screenshots._

---

## Author

Ibrahim, IOTBTECH 2026 Cloud & DevOps Fellowship.