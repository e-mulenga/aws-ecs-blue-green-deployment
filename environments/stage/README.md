# stage environment

| | stage |
|---|---|
| Encryption | Landing Zone CMKs required: plans fail until the Landing Zone exports them |
| Traffic shifting | Canary 10% for 5 minutes |
| Deletion protection | on |

Copy `backend.hcl.example` and `terraform.tfvars.example` to their real names (git-ignored), fill in the Landing Zone values, then:

```bash
scripts/tf.sh stage init && scripts/tf.sh stage plan && scripts/tf.sh stage apply
```
