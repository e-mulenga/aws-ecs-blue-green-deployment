# FinOps and KMS cost analysis

Development and Test environments use AWS-managed encryption keys to reduce AWS KMS operational costs and management overhead while maintaining encryption at rest. Production environments use Customer Managed Keys (CMKs) to satisfy governance, auditability, compliance, separation-of-duties, and enterprise security requirements.

| Driver | Dev | Stage / Prod |
|---|---|---|
| Keys | AWS-owned / SQS-managed | Landing Zone CMKs (about USD 1 per key per month plus requests, owned by the Landing Zone) |
| Fargate | 1 task, 0.25 vCPU, 0.5 GB | 2 tasks |
| ALB | 1 | 1, deletion protection on |
| WAF | 1 web ACL, 4 rules plus requests | same |
| Interface endpoints | up to 4 (ECR API, ECR registry, Logs, SQS) in 2 AZs | same |
| DynamoDB | on-demand, PITR | on-demand, PITR, replica in prod |
| Budget | `monthly_budget_usd` | same |

Biggest lever: the interface endpoints (hourly per AZ) and WAF. Removing NAT (the Landing Zone has none) avoids NAT hourly and per-GB charges. Prices differ by region: check af-south-1 rates in the AWS pricing pages before committing to the budget values in the example files. Tags (`Environment`, `Owner`, `CostCenter`, `Project`) come from the Landing Zone contract file.
