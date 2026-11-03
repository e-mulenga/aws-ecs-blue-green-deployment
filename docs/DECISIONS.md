# Architecture Decision Records

## ADR-001 - Consume the Landing Zone through remote state, with a contract guard
- **What:** `infra/landing_zone.tf` reads the Landing Zone outputs with `terraform_remote_state` and checks them in a `terraform_data` precondition: contract version 2, regions, subnets (two public, two private), Route 53 zone, ACM certificate, GitHub OIDC provider, the `shared-applications` ECR repository, and CMKs for stage/prod. State for this repo lives in the Landing Zone state bucket (`backend "s3" {}` plus `backend.tf`, native lock files). The bootstrap stack, its state bucket and lock table are removed.
- **Why:** Plans fail early and readably when the Landing Zone changes shape. Persona rule: never recreate Landing Zone resources.
- **Rejected:** Looking the VPC up by tag; keeping a bootstrap stack.

## ADR-002 - Tasks move to the Landing Zone private subnets with no public IP
- **What:** The original ran Fargate in public subnets with `assign_public_ip = true`. Tasks now run in the two Landing Zone private subnets with no public IP. The task security group accepts only the app port from the ALB and sends only HTTPS to the VPC and to the S3 and DynamoDB prefix lists.
- **Why:** A public IP on a task is an unneeded exposure; the ALB is the one entry point.

## ADR-003 - No NAT: create only the VPC endpoints that are missing
- **What:** The Landing Zone has no NAT and exports no endpoints. The `endpoints` module checks the VPC and creates only missing ones: S3 and DynamoDB (gateway), ECR API, ECR registry, CloudWatch Logs and SQS (interface). Route tables are resolved from the private subnets because the Landing Zone does not export them.
- **Why:** Without NAT, tasks cannot pull images or write logs otherwise. Checking first avoids duplicating, or colliding with, endpoints the Landing Zone adds later.

## ADR-004 - TLS certificate and DNS zone come from the Landing Zone
- **What:** The ALB uses `acm_certificate_arn`; the alias record is written to the Landing Zone zone (`route53_zone_id`, `route53_domain_name`) as `<app_subdomain>.<domain>`. The original ACM and Route 53 modules are removed.
- **Open point:** The certificate must cover that hostname. This cannot be checked by Terraform.

## ADR-005 - Image in the shared ECR repository; AppSpec passed inline
- **What:** Images go to the Landing Zone `shared-applications` repository with tags `url-shortener-<sha>`. The repository policy is not touched: the task execution role pulls through its identity policy (same account). CodeDeploy receives the AppSpec inline (`AppSpecContent`), so the S3 revisions bucket is gone.
- **Rejected:** A repo-specific ECR repository (the Landing Zone provides the shared ones); an S3 revisions bucket.

## ADR-006 - Deploy-only OIDC role on the Landing Zone provider; no automated destroy
- **What:** The Landing Zone's GitHub OIDC provider is referenced, not created. The deploy role can only push to the one ECR repository, register task definitions, start CodeDeploy deployments for this app and pass the two workload roles. It trusts `repo:<owner/repo>:environment:<env>` only. The original `test_role_v2` (`s3:*`, `iam:*`, `ec2:*` and more on `*`) and the `destroy` workflow that ran on every push to `main` are removed. Terraform is applied by an operator with `scripts/tf.sh`.
- **Why:** The original role was effectively account admin for any workflow in the repo; the destroy workflow would delete the platform on each push.
- **Rejected:** A CI role that applies Terraform (needs broad rights; the Landing Zone exports no pipeline roles yet, see roadmap).

## ADR-007 - Canary and alarm rollback outside dev
- **What:** dev uses `ECSAllAtOnce`; stage and prod use `ECSCanary10Percent5Minutes`. A CloudWatch alarm on target 5xx stops and rolls back a deployment and notifies the Landing Zone SNS topic (its policy must allow CloudWatch to publish). The blue task set stays for 5 minutes after success.
- **Why:** The 5xx alarm and canary shorten the blast radius of a bad release.

## ADR-008 - WAF in block mode with logging
- **What:** Common, known-bad-inputs and IP-reputation managed groups plus a per-IP rate limit, metrics and sampled requests on, logs to a CloudWatch log group, authorization header redacted. No geo restriction.
- **Why:** The original used count mode, a US/NL scope-down, metrics off and placeholder token domains, so it blocked nothing.

## ADR-009 - Encryption follows the Landing Zone key strategy
- **What:** `key_strategy = aws-managed` (dev): DynamoDB and SQS use AWS-owned or SQS-managed encryption. stage/prod require Landing Zone CMKs; a missing ARN fails the plan.
- **Why:** FinOps encryption rule in the README.

## ADR-010 - DR as a pilot light from the same code
- **What:** `deployment_role = "dr"` deploys the stack to eu-west-1 using the Landing Zone `eu_west_1` network. It needs `dr_image_repository` and `dr_acm_certificate_arn`. DNS cut-over is manual (`create_dns_record`).
- **Rejected:** Active-active (cost, and the Landing Zone gives no cross-region image replication).

## ADR-011 - Service regional availability
- **What:** Checked 2026-11-03: Fargate (AWS Fargate Regions page), CodeDeploy and WAF (AWS General Reference endpoint tables) list af-south-1. Nothing is deployed from Ireland. The `ireland` provider alias exists for the day that changes.

## ADR-012 - Naming and file convention
- **What:** Repository name `aws-ecs-blue-green-deployment`. Each root and child module declares its terraform block and providers in `provider.tf` (never `versions.tf`). Resource names use `<workload>-<env>`.
