# 앱·펌웨어 연동 테스트 계획 (임시)

앱(실기기)과 ESP32-C3 펌웨어(`~/leafie`)가 로컬 백엔드를 사이에 두고 프로비저닝,
클레임, 식물 등록·센서 연결까지 이어지는지 확인한다.

- DB·인증은 `backend/.env`의 공유 개발 Supabase를 그대로 쓴다. 테스트 데이터는 마지막에 정리한다.
- 텔레메트리는 로컬 백엔드가 아니라 AWS API Gateway로 간다.
- 아래 `<맥IP>`는 테스트 당일 `ipconfig getifaddr en0`로 확인한 값이다. IP가 바뀌면 앱 재빌드,
  펌웨어 재플래시가 필요하므로 가능하면 공유기에서 맥 IP를 고정한다.

## 사전 준비

- [ ] 맥, 폰, ESP가 같은 공유기에 연결된다 (ESP는 2.4GHz, 공유기 AP 격리 꺼짐)
- [ ] 맥 IP 확인: `<맥IP>` = ____________

## 1. 백엔드 세팅

```bash
cd backend
uv sync
uv run alembic current   # heads와 같아야 함 (다르면 팀과 상의 후 upgrade)
uv run alembic heads
uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

- [ ] `--host 0.0.0.0`으로 실행 (127.0.0.1이면 폰·ESP가 접속 못 함)
- [ ] macOS 방화벽이 켜져 있으면 python 수신 연결 허용
- [ ] 공유 DB 마이그레이션이 head인지 확인
- [ ] Worker는 띄우지 않는다 (사진 종 인식을 쓰지 않으므로 불필요)

**확인**: 폰 브라우저에서 `http://<맥IP>:8000/api/v1/ready`가 열린다.

## 2. 프론트 설정 + 실기기 빌드

`frontend/.env`는 빌드 시 asset으로 묶이므로 반드시 빌드 전에 설정한다.

```
SUPABASE_URL=<backend/.env와 동일>
SUPABASE_PUBLISHABLE_KEY=<backend/.env와 동일>
API_BASE_URL=http://<맥IP>:8000/api/v1
```

평문 HTTP 허용 (실험용, 커밋하지 않음):

- [ ] iOS: `ios/Runner/Info.plist`의 `NSAppTransportSecurity`에 `NSAllowsLocalNetworking = true` 추가
- [ ] Android: `android/app/src/debug/AndroidManifest.xml`의 `<application>`에 `android:usesCleartextTraffic="true"` 추가
- [ ] 실기기에 빌드·설치 (`flutter run`)
- [ ] iOS 첫 실행 시 로컬 네트워크·블루투스 권한 허용
- [ ] 테스트 계정 준비 (앱 가입 또는 Supabase 대시보드. 이메일 인증 필요 시 완료)

**확인**: 앱 로그인 후 홈 등 API를 쓰는 화면이 정상 로드된다.

## 3. 펌웨어 세팅 (`~/leafie`)

- [ ] `main/main.c`의 `MOCK_SERVER_BASE_URL`을 `http://<맥IP>:8000`으로 변경
- [ ] `main/secrets.h`에 `TELEMETRY_API_KEY` 확인
- [ ] 빌드·플래시 후 시리얼 모니터 연결
- [ ] 부팅 로그 `label -> ID: ...  PIN: ...`에서 값 기록: ID ____________ / PIN ____________
- [ ] 이전에 claim된 기기면 해제(앱 마이페이지 또는 `DELETE /api/v1/sensor-devices/{id}`)하거나 공장 초기화

참고: 부팅 시 `/ping` 호출은 실제 백엔드에 없는 경로라 404가 찍히며 무시해도 된다.

## 4. 앱으로 테스트

| # | 단계 | 동작 | 성공 기준 | 결과 |
|---|---|---|---|---|
| 4-1 | 프로비저닝 | 앱에서 센서 등록 시작 → BLE 스캔·연결 → PIN 입력 → Wi-Fi 정보 전달 | ESP 로그에 Wi-Fi 연결·IP 획득 | |
| 4-2 | 클레임 | 앱이 claim 진행 | uvicorn 로그에 `POST /sensor-devices` → `POST /sensor-devices/{id}/claims` → `POST /sensor-device-claims/{token}/complete`(ESP) → `GET /sensor-device-claims/{token}` polling 순서로 찍히고, 앱에 등록 완료 표시. 5분(claim TTL) 안에 완료 | |
| 4-3 | 식물 등록 | 식물 이름 직접 입력으로 등록 (사진 인식 제외) | 식물 생성 성공, 목록에 표시 | |
| 4-4 | 센서 연결 | 등록한 식물에 센서 기기 연결 | `PUT /plants/{id}/sensor-device` 성공, 식물 화면에 센서 상태 표시 | |
| 4-5 | (선택) 텔레메트리 | 측정 주기 대기 (개발 펌웨어는 10초) | ESP 로그 `telemetry ... -> status=200`대, 앱에 센서 값 반영 | |

실패 시 기록할 것: 단계, 앱 화면/에러 메시지, uvicorn 로그, ESP 시리얼 로그.

## 5. 정리

- [ ] 앱에서 센서 연결 해제 및 기기 해제
- [ ] 테스트 식물 삭제
- [ ] `frontend/.env`, Info.plist, debug AndroidManifest 변경 되돌리기 (커밋 금지)
- [ ] 펌웨어 `MOCK_SERVER_BASE_URL` 변경 되돌리기
