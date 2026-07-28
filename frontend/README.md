# Frontend

Flutter 애플리케이션 위치입니다. 프론트엔드 담당자가 이 디렉터리에서 프로젝트를
초기화합니다.

```bash
flutter create --project-name yeso_plant .
```

Supabase URL과 publishable key만 앱 설정에 포함합니다. `service_role` 키,
OpenAI API Key, 데이터베이스 접속 문자열은 모바일 앱에 넣지 않습니다.
이메일 인증과 Google·Kakao·Naver OAuth callback을 받을 앱 딥링크를 플랫폼별로
설정합니다. App Store 제출 전 Sign in with Apple 지원 여부를 출시 게이트에서
확인합니다.
