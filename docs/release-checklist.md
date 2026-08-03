# 출시 점검표

## 자동 검증

PR과 `main` CI는 다음 항목을 모두 통과해야 합니다.

```bash
cd backend
pip check
test "$(alembic heads | wc -l | tr -d ' ')" = "1"
ruff check .
pytest
```

## 백엔드 확인 완료

- Alembic migration이 단일 head(`alembic heads`)이고 공유 DB가 최신 head입니다.
  스키마 SSOT는 `backend/alembic/versions/` 이며 `supabase/migrations/`와 중복
  관리하지 않습니다.
- `public`의 애플리케이션 테이블은 모두 RLS가 활성화되어 있습니다.
- Pl@ntNet 식물 인식, Kindwise 상태 진단, OpenAI `gpt-5-mini` 실제 요청이
  성공했습니다.
- Queue 재전달, 일시·영구 외부 오류, 재시도 소진과 멱등 상태 전이를 테스트합니다.
- FCM Worker는 사용자 설정과 활성 FID를 다시 확인하고, 무효 FID 폐기와 일시 오류
  재시도를 처리합니다.

## 배포 전 필수

- 운영 API와 Worker를 각각 배포하고 `/api/v1/health`, `/api/v1/ready`를 확인합니다.
- 배포 환경에 Supabase, Pl@ntNet, Kindwise, OpenAI와 Firebase 자격 증명을 비밀값으로
  등록합니다.
- Firebase 프로젝트 `leafie-2c528`의 Apple 앱 `com.yuengme.leafie`에 APNs 인증 키를
  등록합니다.
- Flutter의 bundle ID를 `com.yuengme.leafie`로 맞추고 Firebase 설정 파일을 앱에
  포함합니다.
- Flutter에서 Firebase Installations FID를 등록·갱신·폐기하고 실제 iPhone에서
  foreground, background, 종료 상태 푸시를 확인합니다.
- 이메일 인증, 비밀번호 재설정, Naver·Kakao·Apple OAuth 딥링크를 실기기에서
  확인합니다.
- 팀원의 홈·캘린더 기능 병합 후 식물 등록부터 일정 완료, 다이어리, 채팅, 진단,
  알림까지 한 계정으로 전체 흐름을 재검증합니다.

## 운영 게이트

- 코드의 외부 API 기본 사용량 상한을 운영 예상치에 맞게 조정하고 Provider 자체 예산
  상한도 설정합니다.
- Queue 적체, Worker 실패, Provider 오류율과 비용 알림을 설정합니다.
- Supabase 백업과 복구 절차를 한 번 실행해 확인합니다.
- 개인정보 처리방침, 계정 탈퇴, 사진 보관·삭제 정책을 App Store 제출 정보와
  일치시킵니다.
