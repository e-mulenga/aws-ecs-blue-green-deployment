# Regional availability (af-south-1) and the Ireland rule

A service that is not available or not GA in af-south-1 is deployed from eu-west-1, documented, and no other region is used.

Checked 2026-11-03.

| Service | af-south-1 | Source | Deployed |
|---|---|---|---|
| ECS on Fargate (Linux) | Yes | AWS Fargate Regions page | af-south-1 |
| CodeDeploy | Yes (`codedeploy.af-south-1`) | AWS General Reference | af-south-1 |
| WAF (wafv2) | Yes (`wafv2.af-south-1`) | AWS General Reference | af-south-1 |
| ALB, ECR, DynamoDB, SQS, ACM, CloudWatch, Route 53 | Yes (not individually re-checked today; Route 53 is global) | prior checks | af-south-1 |