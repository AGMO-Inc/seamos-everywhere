# AWS Public ECR Repository Setup

FD Headless Docker 이미지를 배포할 AWS Public ECR 리포지토리 생성 절차. 초기 1회만 수동 실행한다(CI 자동화 금지).

## Prerequisites

- AWS CLI v2 이상 설치
- Public ECR 은 `us-east-1` 리전에서만 관리 API 가 동작 — AWS CLI 는 항상 `--region us-east-1` 로 실행
- 관리자 권한 IAM 사용자 또는 role 으로 AWS CLI 인증

## 1. 리포지토리 생성

```bash
aws ecr-public create-repository \
  --repository-name seamos-fd-headless \
  --region us-east-1 \
  --catalog-data '{
    "description": "FD Headless for SeamOS app project creation (Linux/amd64)",
    "aboutText": "FD Headless 8.6.0-SNAPSHOT wrapped for the seamos-everywhere Claude Code plugin. See LEGAL.md and docker/fd-headless/README.md.",
    "usageText": "docker pull public.ecr.aws/<alias>/seamos-fd-headless:latest",
    "architectures": ["x86-64"],
    "operatingSystems": ["Linux"]
  }'
```

성공 시 출력 예시:

```json
{
  "repository": {
    "repositoryArn": "arn:aws:ecr-public::<account-id>:repository/seamos-fd-headless",
    "registryId": "<account-id>",
    "repositoryName": "seamos-fd-headless",
    "repositoryUri": "public.ecr.aws/<alias>/seamos-fd-headless",
    "createdAt": "2026-04-22T..."
  },
  "catalogData": { ... }
}
```

`repositoryUri` 의 `<alias>` 를 기록해 두고 GitHub Actions 시크릿 `AWS_ECR_PUBLIC_ALIAS` 에 저장한다.

## 2. 익명 Pull 권한 정책

Public ECR 은 기본적으로 익명 pull 을 허용하지만, 명시적 policy 로 의도를 문서화한다.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowAnonymousPull",
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
        "ecr-public:BatchCheckLayerAvailability",
        "ecr-public:GetDownloadUrlForLayer",
        "ecr-public:BatchGetImage"
      ]
    }
  ]
}
```

(참고: Public ECR 의 리포지토리 정책은 Private ECR 과 스키마가 다르며, `set-repository-policy` API 는 `ecr-public` 에는 없다. 익명 pull 은 Public ECR 기본 동작이며 이 JSON 은 문서적 참고용.)

## 3. 초기 이미지 푸시 테스트 (선택)

로컬에 빌드한 `seamos-fd-headless:dev` 이미지로 푸시 테스트:

```bash
aws ecr-public get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin public.ecr.aws

docker tag seamos-fd-headless:dev public.ecr.aws/<alias>/seamos-fd-headless:test
docker push public.ecr.aws/<alias>/seamos-fd-headless:test
```

`aws ecr-public describe-images --repository-name seamos-fd-headless --region us-east-1` 으로 이미지 존재 확인.

테스트 완료 후 `:test` 태그는 `aws ecr-public batch-delete-image` 로 제거.

## 4. CI 연결

생성된 `<alias>` 를 `.github/workflows/build-fd-image.yml` 의 시크릿 또는 env 에 주입:

```yaml
env:
  ECR_PUBLIC_ALIAS: ${{ secrets.AWS_ECR_PUBLIC_ALIAS }}
```

워크플로는 OIDC 인증(참고: `docs/ci/github-oidc-setup.md`) 후 이미지 tag push.

## Revocation / Cleanup

리포지토리를 내리려면:

```bash
aws ecr-public delete-repository \
  --repository-name seamos-fd-headless \
  --region us-east-1 \
  --force  # 내부 이미지까지 함께 삭제
```
