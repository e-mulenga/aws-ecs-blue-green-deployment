# Roadmap

1. Run `validate` and `plan` against the real Landing Zone state; fix what a real plan finds.
2. Landing Zone exports CMKs (with DynamoDB and SQS domains), route tables, an eu-west-1 certificate and ECR replication, and a Terraform pipeline role.
3. Move Terraform apply into a gated pipeline using that role.
4. A test listener and pre-traffic hook (Lambda) in CodeDeploy.
5. ECS autoscaling and a second task in dev for AZ resilience testing.
6. Authentication and abuse controls on `/shorten`; deploy the Go analytics worker if Postgres is added.
7. Confirm Fargate ARM64 in af-south-1 and move to Graviton for cost.
