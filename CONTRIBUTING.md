# 협업 규칙

## 브랜치

- `main`에는 직접 push하지 않습니다.
- 백엔드: `backend/<feature>`
- 프론트엔드: `frontend/<feature>`
- 공통 문서와 인프라: `chore/<topic>`

## 작업 흐름

```bash
git switch main
git pull --ff-only
git switch -c backend/example
```

작업 후 원격 브랜치에 push하고 Pull Request를 생성합니다. 최소 한 명의 리뷰 후
merge합니다.

## 커밋

Conventional Commit의 핵심 prefix를 사용합니다.

```text
feat: 기능 추가
fix: 버그 수정
docs: 문서 수정
test: 테스트 추가
refactor: 동작 변경 없는 구조 수정
chore: 설정과 도구 변경
```

## 계약 변경

API, Enum, 데이터 모델, 비동기 작업 계약을 변경할 때는 관련 코드와 함께
`docs/api-spec.md`, `docs/erd.md`, `docs/architecture.md`를 갱신합니다.
