# Testing strategy

| Level | What | Where |
|---|---|---|
| Unit | FastAPI tests with storage mocked (6 tests) | `app/tests`, CI `ci` |
| Static | `tofu fmt -check`, `tofu validate` | CI `ci` |
| Security scan | tfsec, Checkov, Trivy, Gitleaks, Bandit | CI `security` |
| Plan-time contract | Landing Zone guard (version, regions, subnets, zone, cert, OIDC, ECR, CMKs) | every plan |
| Release gate | Trivy image scan, CodeDeploy health checks, 5xx alarm | `build-push`, `deploy` |
| Smoke test after deploy | `curl https://<app_url>/healthz`, create and resolve a short link | manual, see below |
| Not done here | `validate`/`plan` against the real Landing Zone state; a real blue/green run in af-south-1 | **run before relying on this** |

Smoke test: `curl -s https://<app_url>/healthz`, then `POST /shorten {"url":"https://example.com"}` and `GET /<short>`.
