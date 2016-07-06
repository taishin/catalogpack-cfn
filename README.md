# Usage
1. Edit parameter in catalogpack-cfn.sh
2. Run catalogpack-cfn.sh

```bash:
$ ./catalogpack-cfn.sh (project_name) (target)
target:
  all - Create ALL stack
  vpc - Create only VPC stack
  sg  - Create only SecurityGroup stack
  iam - Create only IAM stack
  efs - Create only EFS stack
  elb - Create only ELB stack
  rds - Create only RDS stack
  as  - Create only AutoScale stack
```