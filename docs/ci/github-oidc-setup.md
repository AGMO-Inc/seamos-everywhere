# GitHub Actions → AWS OIDC Setup

seamos-everywhere 의 `.github/workflows/build-fd-image.yml` 워크플로가 AWS 에 액세스하기 위한 OIDC (OpenID Connect) 인증 설정 절차.

## 개요

GitHub Actions 워크플로는 IAM 사용자 access key 를 저장하는 대신 OIDC 토큰을 사용해 AWS IAM role 을 assume 한다. 이로써 장기 credential 이 레포에 저장되지 않는다.

## 1. AWS OIDC Provider 등록 (1회성)

GitHub 의 OIDC 발급자(`https://token.actions.githubusercontent.com`)를 AWS 계정에 등록.

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list <github-oidc-thumbprint>
```

Thumbprint 는 AWS 공식 문서(https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)에서 최신 값을 확인해 사용.

## 2. IAM Role 생성

**Trust policy (`trust-policy.json`)**:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<account-id>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:<org>/<repo>:ref:refs/tags/fd-v*"
        }
      }
    }
  ]
}
```

- `<account-id>`: 조직 AWS 계정 ID (12자리)
- `<org>/<repo>`: `AGMO-Inc/seamos-everywhere`
- `sub` 의 `ref:refs/tags/fd-v*` 는 워크플로가 `fd-v*` 태그 push 로 트리거되는 경우에 한해 role assume 허용. `workflow_dispatch` 도 별도 `Condition` 추가 가능.

**Role 생성**:

```bash
aws iam create-role \
  --role-name seamos-everywhere-fd-build \
  --assume-role-policy-document file://trust-policy.json
```

## 3. Role 에 권한 부착

`permissions-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadFDArtifacts",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::<bucket>",
        "arn:aws:s3:::<bucket>/fd-headless/*"
      ]
    },
    {
      "Sid": "PushPublicECR",
      "Effect": "Allow",
      "Action": [
        "ecr-public:GetAuthorizationToken",
        "sts:GetServiceBearerToken",
        "ecr-public:BatchCheckLayerAvailability",
        "ecr-public:GetRepositoryPolicy",
        "ecr-public:DescribeRepositories",
        "ecr-public:DescribeRegistries",
        "ecr-public:DescribeImages",
        "ecr-public:InitiateLayerUpload",
        "ecr-public:UploadLayerPart",
        "ecr-public:CompleteLayerUpload",
        "ecr-public:PutImage"
      ],
      "Resource": "*"
    }
  ]
}
```

```bash
aws iam put-role-policy \
  --role-name seamos-everywhere-fd-build \
  --policy-name fd-build-policy \
  --policy-document file://permissions-policy.json
```

## 4. GitHub 레포 시크릿 설정

GitHub → Settings → Secrets and variables → Actions 에 추가:
- `AWS_ROLE_ARN`: `arn:aws:iam::<account-id>:role/seamos-everywhere-fd-build`
- `AWS_REGION`: 예: `ap-northeast-2`
- `AWS_S3_ARTIFACT_BUCKET`: `<bucket>`
- `AWS_ECR_PUBLIC_ALIAS`: `g0j5z0m9` (Public ECR registry alias)

## 5. 검증

워크플로가 아래 스텝으로 role 을 assume 하면 성공:

```yaml
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: ${{ secrets.AWS_REGION }}

- run: aws sts get-caller-identity
```

성공 시 `aws sts get-caller-identity` 출력에 assumed role ARN 이 표시된다 (`Arn: arn:aws:sts::...:assumed-role/seamos-everywhere-fd-build/...`).

**기대 결과**: `aws sts assume-role-with-web-identity` 가 성공하여 credential 이 발급됨.

## 참고 자료

- [AWS 공식: Creating OIDC identity providers](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [GitHub Docs: About security hardening with OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [`aws-actions/configure-aws-credentials`](https://github.com/aws-actions/configure-aws-credentials)
