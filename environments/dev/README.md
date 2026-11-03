# dev environment

| | dev |
|---|---|
| Encryption | AWS-managed / service-owned keys (cost-optimised) |
| Traffic shifting | All at once |
| Deletion protection | off |

Copy `backend.hcl.example` and `terraform.tfvars.example` to their real names (git-ignored), fill in the Landing Zone values, then:

```bash
scripts/tf.sh dev init && scripts/tf.sh dev plan && scripts/tf.sh dev apply
```
