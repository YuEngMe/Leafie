# 협업 규칙

## 기본 원칙

- `main`은 항상 실행 가능한 상태로 유지합니다.
- `main`에 직접 push하지 않고 Pull Request로 병합합니다.
- 한 브랜치에는 하나의 기능이나 수정만 포함합니다.
- 작업이 끝난 브랜치는 merge 후 원격과 로컬에서 삭제합니다.
- 비밀값, 개인 `.env`, 사용자 원본 사진은 커밋하지 않습니다.

## 브랜치 규칙

브랜치는 최신 `main`에서 생성합니다.

```text
<area>/<type>-<short-description>
```

### Area

| Area | 대상 |
|---|---|
| `backend` | FastAPI, Worker, AI, 테스트 |
| `frontend` | Flutter 화면과 상태 관리 |
| `infra` | Supabase, 배포, CI |
| `docs` | 설계 및 협업 문서 |

### Type

| Type | 용도 |
|---|---|
| `feat` | 새로운 기능 |
| `fix` | 버그 수정 |
| `refactor` | 동작 변경 없는 구조 개선 |
| `test` | 테스트 추가·수정 |
| `chore` | 설정, 의존성, 유지보수 |
| `update` | 문서와 계약 갱신 |

예시:

```text
backend/feat-supabase-auth
backend/feat-plant-crud
backend/fix-care-schedule
frontend/feat-login
frontend/feat-home
frontend/fix-calendar-layout
infra/feat-initial-schema
docs/update-api-spec
```

브랜치 이름은 영문 소문자와 숫자, 하이픈만 사용합니다. 이름에 담당자 이름이나
날짜를 넣지 않습니다.

## 작업 흐름

```bash
git switch main
git pull --ff-only
git switch -c backend/feat-plant-crud
```

작업 후:

```bash
git add <변경한 파일>
git commit -m "feat(backend): add plant creation API"
git push -u origin backend/feat-plant-crud
```

GitHub에서 `main`을 대상으로 Pull Request를 만들고 최소 한 명의 승인을 받은 뒤
merge합니다. 다른 사람의 작업이 먼저 병합됐다면 PR을 갱신하기 전에 최신
`main`을 반영합니다.

## 커밋 메시지 규칙

Conventional Commits 형식을 사용합니다.

```text
<type>(<scope>): <summary>
```

### Type

| Type | 용도 |
|---|---|
| `feat` | 사용자에게 보이는 기능 추가 |
| `fix` | 버그 수정 |
| `docs` | 문서만 변경 |
| `refactor` | 동작 변경 없는 코드 구조 개선 |
| `test` | 테스트 추가·수정 |
| `chore` | 설정, 의존성, 단순 유지보수 |
| `perf` | 성능 개선 |
| `ci` | CI/CD 변경 |
| `build` | 빌드 시스템 변경 |

### Scope

`backend`, `frontend`, `supabase`, `ai`, `worker`, `docs` 중 변경 영역을
사용합니다. 여러 영역을 동일하게 변경하면 scope를 생략할 수 있습니다.

### Summary

- 영문 소문자로 시작합니다.
- 명령형 현재 시제를 사용합니다.
- 마침표를 붙이지 않습니다.
- 무엇을 변경했는지 한 문장으로 작성합니다.
- 관련 없는 변경을 한 커밋에 섞지 않습니다.

좋은 예:

```text
feat(backend): add plant creation API
feat(frontend): add email verification screen
fix(worker): prevent duplicate diagnosis processing
docs(api): define diary response schema
chore(supabase): add local migration configuration
```

피해야 할 예:

```text
update
수정함
feat: 여러 기능 이것저것 추가
fix: final final
```

호환성이 깨지는 변경은 본문 또는 footer에 `BREAKING CHANGE:`를 작성하고 API
문서와 migration을 같은 PR에 포함합니다.

## Pull Request

PR 제목도 커밋 메시지와 같은 형식을 사용합니다.

```text
feat(backend): add plant creation API
```

PR 본문에는 다음을 적습니다.

- 변경한 기능
- 확인 방법과 테스트 결과
- API·DB 계약 변경 여부
- 화면 변경이 있으면 캡처
- 후속 작업이나 알려진 제한

## Merge 전 검사

백엔드:

```bash
cd backend
pytest
ruff check .
```

프론트엔드:

```bash
cd frontend
flutter analyze
flutter test
```

Supabase migration은 로컬 또는 staging에서 적용 순서와 rollback 가능성을
확인합니다.

## 계약 변경

API, Enum, 데이터 모델, Queue 작업, Tool Calling, Batch 계약을 변경할 때는 관련
코드와 함께 다음 문서를 갱신합니다.

- `docs/api-spec.md`
- `docs/erd.md`
- `docs/architecture.md`
- `docs/wireframe-mapping.md`
