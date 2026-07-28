# Supabase

Supabase PostgreSQL migration, RLS policy, Storage bucket 설정, Queue와 Cron SQL을
관리하는 디렉터리입니다.

Auth는 이메일 인증과 Google·Kakao OAuth를 활성화하고, Naver는 Custom OAuth2
Provider로 등록합니다. Storage는 사용자 프로필, 식물명칭 인식, 다이어리, 진단,
채팅 이미지를 모두 비공개 버킷에 저장합니다.

```text
supabase/
└── migrations/
```

Migration 파일은 생성 순서를 보장하는 UTC timestamp 이름을 사용합니다.

```text
20260723090000_create_user_profiles.sql
```
