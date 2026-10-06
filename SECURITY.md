# Security

이 저장소는 포트폴리오 공개용 사본입니다. 실제 운영/개발 환경의 비밀번호, JWT Secret, API Key, AWS 계정별 식별자, DB 엔드포인트와 팀원 IAM ARN은 포함하지 않습니다.

- `terraform.tfvars`와 Terraform state 파일은 Git에 커밋하지 않습니다.
- Kubernetes Secret 값은 저장소에 직접 작성하지 않습니다.
- 예제의 `<...>` 또는 `123456789012` 값은 실제 환경 값으로 교체해야 합니다.
- 실제 자격 증명이 노출된 경우 Git 기록 삭제만으로 끝내지 말고 해당 자격 증명을 즉시 폐기/회전합니다.
