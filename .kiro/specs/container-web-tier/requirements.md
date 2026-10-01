# Requirements Document

## Introduction

This feature adds a containerized web tier to the `client-hosting-iac` Terraform project. A container image is stored in an Amazon ECR repository and served by EC2 instances that pull and run the image behind the existing Application Load Balancer target group.

The work spans two existing Terraform layers. The ECR repository is declared in the `persistent/` layer because container images must survive the frequent destroy/apply cycles of the disposable compute layer. All compute resources (IAM role, instance profile, launch template, autoscaling group, and user data) are declared in the `ephemeral/` layer, which reads the persistent layer's outputs exclusively through the existing `terraform_remote_state` data source named `persistent`. A minimal Dockerfile that serves a static page on port 80 is added as a repository source artifact.

The design prioritizes, in order: security (least privilege, encryption, no static credentials in code or git), cost control (free-tier `t3.micro` only, NAT gateway disabled), readability/explainability (this is a portfolio project), and features. This document defines requirements only; it does not prescribe implementation detail, which is reserved for design.

## Glossary

- **ECR_Repository**: The `aws_ecr_repository` resource declared in the Persistent_Layer that stores the container image for the web tier.
- **Dockerfile**: A source-artifact file committed to the repository that defines a minimal container image serving a static page on port 80.
- **Instance_Role**: The `aws_iam_role` declared in the Ephemeral_Layer that grants EC2 instances read-only permission to pull images from the ECR_Repository.
- **Instance_Profile**: The `aws_iam_instance_profile` declared in the Ephemeral_Layer that attaches the Instance_Role to EC2 instances.
- **Launch_Template**: The `aws_launch_template` declared in the Ephemeral_Layer that defines the instance configuration, including instance type, security group, Instance_Profile, and User_Data.
- **Auto_Scaling_Group**: The `aws_autoscaling_group` declared in the Ephemeral_Layer that launches and manages web-tier instances and registers them to the Target_Group.
- **Target_Group**: The existing `aws_alb_target_group.web` resource (port 80, HTTP, `target_type = "instance"`) in the Persistent_Layer, exported as the `target_group_arn` output.
- **Web_Security_Group**: The existing `aws_security_group.web` resource in the Persistent_Layer, exported as the `web_security_group_id` output; ingress allows port 80 from the ALB SG, egress allows 3306 to the DB SG and 443 to `0.0.0.0/0`.
- **User_Data**: The instance bootstrap script embedded in the Launch_Template that installs Docker, authenticates to ECR, pulls the image, and runs the container.
- **Persistent_Layer**: The long-lived Terraform layer at `persistent/` (state key `persistent/terraform.tfstate`) containing VPC, subnets, security groups, KMS, Secrets Manager, ALB, target group, and ACM resources.
- **Ephemeral_Layer**: The disposable Terraform layer at `ephemeral/` (state key `ephemeral/terraform.tfstate`) containing compute and other resources intended for frequent destroy/apply cycles.
- **Remote_State_Source**: The existing `terraform_remote_state` data source named `persistent` in the Ephemeral_Layer that reads the Persistent_Layer state at key `persistent/terraform.tfstate`.
- **Agent**: The automated assistant that generates and modifies Terraform code and may run `terraform fmt`, `validate`, `init`, and `plan`.
- **Operator**: The human who reviews changes and is the only party permitted to run `terraform apply` or `terraform destroy`.

## Requirements

### Requirement 1: ECR Repository in the Persistent Layer

**User Story:** As a cloud engineer, I want the container image repository to live in the persistent layer, so that pushed images survive ephemeral destroy/apply cycles.

#### Acceptance Criteria

1. THE Persistent_Layer SHALL declare an `aws_ecr_repository` resource named using the `${var.project_name}-<thing>` convention.
2. THE ECR_Repository SHALL enable image scanning on push by setting `image_scanning_configuration` `scan_on_push` to `true`.
3. THE ECR_Repository SHALL carry a `Name` tag following the `${var.project_name}-<thing>` convention.
4. THE Persistent_Layer SHALL expose the ECR_Repository URL as a new Terraform output.
5. WHERE additional consumption is required, THE Persistent_Layer SHALL expose the ECR_Repository name and ARN as Terraform outputs.

### Requirement 2: Minimal Dockerfile Source Artifact

**User Story:** As a cloud engineer, I want a minimal Dockerfile that serves a static page on port 80, so that the web tier has an image to run.

#### Acceptance Criteria

1. THE Dockerfile SHALL be committed to the repository as a source artifact rather than a Terraform-managed resource.
2. THE Dockerfile SHALL define an image that serves a static page over HTTP on port 80.
3. THE Dockerfile SHALL declare port 80 as the exposed container port.
4. WHEN the Dockerfile is built, THE Dockerfile SHALL produce an image that responds to an HTTP request on port 80 with the static page.

### Requirement 3: Least-Privilege ECR Pull Role and Instance Profile

**User Story:** As a security-conscious engineer, I want the instances to have read-only ECR access and nothing more, so that the deployment follows least privilege.

#### Acceptance Criteria

1. WHEN the Ephemeral_Layer is applied, THE Ephemeral_Layer SHALL declare exactly one Instance_Role named `${var.project_name}-ecr-pull-role` and exactly one Instance_Profile named `${var.project_name}-ecr-pull-profile`.
2. THE Instance_Role trust policy SHALL allow the AssumeRole action for the Amazon EC2 service principal only.
3. IF any principal other than the Amazon EC2 service principal is present in the Instance_Role trust policy, THEN THE Ephemeral_Layer SHALL be considered non-compliant and SHALL NOT be applied.
4. THE Instance_Role permission policy SHALL grant exactly these four ECR actions and no others: `ecr:GetDownloadUrlForLayer`, `ecr:BatchGetImage`, `ecr:BatchCheckLayerAvailability`, and `ecr:GetAuthorizationToken`.
5. THE Instance_Role permission policy SHALL exclude all ECR write, push, delete, and repository-management actions (for example `ecr:PutImage`, `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`, `ecr:CreateRepository`, `ecr:DeleteRepository`).
6. THE Instance_Role permission policy SHALL exclude all actions for services other than the four ECR actions listed in criterion 4.
7. WHEN the Ephemeral_Layer is applied, THE Instance_Profile SHALL attach the Instance_Role and SHALL be the profile referenced by the web-tier Launch_Template.
8. THE Instance_Role AND THE Instance_Profile SHALL each carry a `Name` tag equal to their respective resource name following the `${var.project_name}-<thing>` convention.

### Requirement 4: Launch Template and Autoscaling Group in the Ephemeral Layer

**User Story:** As a cloud engineer, I want an autoscaling group of free-tier instances behind the existing load balancer, so that the containerized web tier is served with minimal cost.

#### Acceptance Criteria

1. THE Ephemeral_Layer SHALL declare a Launch_Template and an Auto_Scaling_Group named using the `${var.project_name}-<thing>` convention.
2. THE Launch_Template SHALL set the instance type to `t3.micro`.
3. THE Auto_Scaling_Group SHALL set minimum size to 1 and maximum size to 2.
4. THE Auto_Scaling_Group SHALL place instances in the public subnets read from `public_subnet_ids` via the Remote_State_Source.
5. THE Launch_Template SHALL attach the Web_Security_Group read from `web_security_group_id` via the Remote_State_Source.
6. THE Launch_Template SHALL attach the Instance_Profile from Requirement 3.
7. THE Auto_Scaling_Group SHALL register instances to the Target_Group read from `target_group_arn` via the Remote_State_Source.
8. THE Launch_Template AND THE Auto_Scaling_Group SHALL propagate a `Name` tag following the `${var.project_name}-<thing>` convention to launched instances.

### Requirement 5: User Data Bootstraps the Container

**User Story:** As a cloud engineer, I want instance user data to install Docker and run the container from ECR, so that each instance serves the web application automatically at boot.

#### Acceptance Criteria

1. WHEN an instance boots, THE User_Data SHALL install Docker within 300 seconds and start the Docker service.
2. IF Docker installation does not complete successfully within 300 seconds, THEN THE User_Data SHALL retry installation up to 3 times, and after the final failed attempt SHALL log an error indicating Docker installation failure and stop the bootstrap sequence.
3. WHEN Docker is installed and running, THE User_Data SHALL authenticate to the ECR_Repository over port 443 by piping `aws ecr get-login-password` into `docker login`, using credentials obtained from the Instance_Profile.
4. IF authentication to the ECR_Repository fails, THEN THE User_Data SHALL retry authentication up to 3 times with a delay of 10 seconds between attempts, and after the final failed attempt SHALL log an error indicating ECR authentication failure and stop the bootstrap sequence.
5. WHEN authentication to the ECR_Repository succeeds, THE User_Data SHALL pull the container image from the ECR_Repository within 300 seconds.
6. IF the image pull from the ECR_Repository fails, THEN THE User_Data SHALL retry the pull up to 3 times with a delay of 10 seconds between attempts, and after the final failed attempt SHALL log an error indicating image pull failure and stop the bootstrap sequence.
7. WHEN the container image is pulled, THE User_Data SHALL run the container publishing container port 80 to host port 80 so that the Target_Group with instance target type on port 80 can reach it.
8. THE User_Data SHALL configure the container with a restart policy of `always` or `unless-stopped`.
9. IF the container fails to start after being run, THEN THE User_Data SHALL retry starting the container up to 3 times, and after the final failed attempt SHALL log an error indicating container start failure.

### Requirement 6: Runtime Credentials via Instance Role, No Static Credentials

**User Story:** As a security-conscious engineer, I want ECR credentials obtained at runtime through the instance role, so that no static AWS credentials exist anywhere in the deployment.

#### Acceptance Criteria

1. WHEN the User_Data authenticates to the ECR_Repository, THE User_Data SHALL obtain temporary credentials at instance runtime through the Instance_Role attached via the Instance_Profile, without any literal AWS access key ID, secret access key, or session token value being present in the User_Data.
2. THE User_Data SHALL exclude any literal long-lived AWS credential value, defined as any embedded AWS access key ID, secret access key, or session token string.
3. THE Launch_Template SHALL exclude any literal long-lived AWS credential value, defined as any AWS access key ID, secret access key, or session token string in any field, including the rendered User_Data block.
4. THE Dockerfile AND the resulting image, including all image layers, environment variables, and build arguments, SHALL exclude any literal AWS access key ID, secret access key, or session token string.
5. THE `.tfvars` files SHALL exclude any literal AWS access key ID, secret access key, or session token string.
6. THE repository committed to git SHALL exclude any literal AWS access key ID, secret access key, or session token string across all tracked files.
7. IF the Instance_Role cannot be assumed or ECR_Repository authentication fails at instance runtime, THEN THE User_Data SHALL halt the container startup sequence and record a failure indication in the instance log, without substituting or falling back to any static AWS credential.

### Requirement 7: Cross-Layer Placement and Apply Order

**User Story:** As a cloud engineer, I want a clear layer separation and apply order, so that the persistent repository exists before the ephemeral compute consumes it.

#### Acceptance Criteria

1. THE ECR_Repository SHALL be declared in the Persistent_Layer and applied before the Ephemeral_Layer compute resources.
2. THE Persistent_Layer SHALL expose the ECR_Repository URL output before the Ephemeral_Layer consumes it.
3. THE Ephemeral_Layer SHALL read the ECR_Repository URL, `target_group_arn`, `public_subnet_ids`, and `web_security_group_id` through the Remote_State_Source.
4. THE Ephemeral_Layer compute SHALL exclude direct references to Persistent_Layer resources, referencing them only through the Remote_State_Source.

### Requirement 8: Agent Safety Constraints

**User Story:** As the Operator, I want the Agent restricted to non-destructive commands, so that no infrastructure is applied or destroyed without my review.

#### Acceptance Criteria

1. THE Agent SHALL run only `terraform fmt`, `terraform validate`, `terraform init`, and `terraform plan`.
2. THE Agent SHALL exclude running `terraform apply`.
3. THE Agent SHALL exclude running `terraform destroy`.
4. THE Agent SHALL exclude modifying files in the `bootstrap/` directory.
5. IF a planned change would destroy an existing resource, THEN THE Agent SHALL halt and warn the Operator.

### Requirement 9: Success Criteria

**User Story:** As the Operator, I want objective success criteria, so that I can verify the feature is correct before applying.

#### Acceptance Criteria

1. WHEN `terraform validate` runs in the Persistent_Layer, THE Persistent_Layer SHALL pass validation.
2. WHEN `terraform validate` runs in the Ephemeral_Layer, THE Ephemeral_Layer SHALL pass validation.
3. WHEN `terraform plan` runs in the Persistent_Layer, THE Persistent_Layer plan SHALL show the new resources as creates.
4. WHEN `terraform plan` runs in the Ephemeral_Layer, THE Ephemeral_Layer plan SHALL show the new resources as creates.
5. IF a `terraform plan` in either layer shows a destroy of an existing resource, THEN THE Agent SHALL halt and warn the Operator.
6. WHEN the Dockerfile is built, THE Dockerfile SHALL produce an image that serves a page on port 80.
