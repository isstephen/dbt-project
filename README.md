# dbt on OpenShift with ECR Demo

这个 demo 展示一个企业级 dbt 批处理部署方式：

- dbt 项目代码打进不可变镜像
- 镜像推送到 AWS ECR
- OpenShift 用 `CronJob` 定时执行 `dbt build`
- 数据库密码、ECR 拉取凭证全部放到 Kubernetes/OpenShift `Secret`
- 容器默认非 root、只读根文件系统、资源限制、NetworkPolicy、RBAC 最小化

> 默认示例运行在 `OpenShift` 上。如果企业里用 Snowflake、Redshift、BigQuery 或 Databricks，只需要替换 `requirements.txt` 里的 adapter，并调整 `dbt/profiles.yml` 与对应 Secret 字段。

## 目录

```text
.
├── dbt/                         # dbt 项目
├── deploy/openshift/base/       # OpenShift manifests
├── scripts/                     # 构建、推送、部署脚本
├── Dockerfile
├── Makefile
└── requirements.txt
```

## 前置条件

- AWS CLI 已登录到目标 AWS 账号
- `docker` 或兼容的容器构建工具可用
- `oc` 已登录到目标 OpenShift 集群
- 目标数据库可从 OpenShift namespace 访问

## 1. 配置环境变量

复制示例文件：

```bash
cp .env.example .env
```

编辑 `.env`，填入企业环境值。不要提交 `.env`。

## 2. 创建 OpenShift Secret

数据库凭证：

```bash
source .env
./scripts/create-db-secret.sh
```

ECR 镜像拉取凭证：

```bash
source .env
./scripts/create-ecr-pull-secret.sh
```

ECR token 有有效期，通常建议用 External Secrets Operator、AWS Controllers for Kubernetes 或平台流水线定期刷新。本 demo 用脚本显式创建，便于本地演示。

## 3. 构建并推送 dbt 镜像到 ECR

```bash
source .env
./scripts/build-and-push.sh
```

脚本会：

1. 确认 ECR repository 存在，不存在则创建。
2. 登录 ECR。
3. 构建镜像，并在构建阶段执行 `dbt deps`。
4. 推送 `${IMAGE_TAG}` 标签。

## 4. 部署到 OpenShift

更新部署镜像并应用清单：

```bash
source .env
./scripts/deploy-openshift.sh
```

查看 CronJob：

```bash
oc -n "${OPENSHIFT_NAMESPACE}" get cronjob dbt-demo
```

手动触发一次：

```bash
oc -n "${OPENSHIFT_NAMESPACE}" create job --from=cronjob/dbt-demo dbt-demo-manual-$(date +%Y%m%d%H%M%S)
```

查看日志：

```bash
oc -n "${OPENSHIFT_NAMESPACE}" logs -l app.kubernetes.io/name=dbt-demo --tail=200
```

## 5. 从 GitHub Actions 推送到 AWS ECR

仓库包含 `.github/workflows/build-push-ecr.yml`。推荐使用 GitHub OIDC 连接 AWS，不在 GitHub 里保存长期 AWS access key。

GitHub Repository Variables:

- `AWS_REGION`
- `AWS_ACCOUNT_ID`
- `ECR_REPOSITORY`
- `OPENSHIFT_NAMESPACE`
- `OPENSHIFT_INSECURE_SKIP_TLS_VERIFY`，可选，默认 `false`

GitHub Repository Secrets:

- `AWS_ROLE_TO_ASSUME`，允许 GitHub Actions assume 的 AWS IAM role ARN
- `OPENSHIFT_SERVER_URL`，可选，只有部署到 OpenShift 时需要
- `OPENSHIFT_TOKEN`，可选，只有部署到 OpenShift 时需要

IAM role trust policy 需要允许当前 GitHub repo 使用 OIDC：

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<AWS_ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:<GITHUB_OWNER>/<GITHUB_REPO>:*"
        }
      }
    }
  ]
}
```

最小 IAM permissions 需要覆盖：

- `ecr:CreateRepository`
- `ecr:DescribeRepositories`
- `ecr:GetAuthorizationToken`
- `ecr:BatchCheckLayerAvailability`
- `ecr:InitiateLayerUpload`
- `ecr:UploadLayerPart`
- `ecr:CompleteLayerUpload`
- `ecr:PutImage`

## Secret 设计

`dbt/profiles.yml` 只引用环境变量，不写明文密码：

- `DBT_TARGET`
- `DB_HOST`
- `DB_PORT`
- `DB_NAME`
- `DB_SCHEMA`
- `DB_USER`
- `DB_PASSWORD`
- `DB_THREADS`

OpenShift `CronJob` 使用 `envFrom.secretRef` 从 `dbt-demo-db` 注入这些变量。

ECR 拉取凭证放在 `dbt-demo-ecr-pull`，并通过 `ServiceAccount.imagePullSecrets` 绑定。

## 企业化建议

- 用 GitHub Actions、Jenkins、Tekton 或 Argo CD 管理构建和部署。
- 用 External Secrets Operator 从 AWS Secrets Manager 或 Vault 同步数据库密码。
- ECR pull secret 建议由平台层自动刷新。
- 生产环境使用不可变标签，例如 Git SHA，不要用 `latest`。
- 为每个环境维护独立 namespace、Secret、镜像标签和 dbt target。
- 将 `target/`、`logs/` 上传到对象存储或集中日志平台，用于审计和排障。
