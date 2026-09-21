# Changelog

## 0.1.0 — 2026-09-21

첫 공개.

- 네 인물(제갈량·소크라테스·니체·세종대왕)이 매일 돌아가며 조언. 고정/무작위/포함 인물 설정.
- Claude Code 대화 기록에서 사용자 발화만 추출해 인물지 자동 작성, 주 1회 갱신.
- 설정 시각 20분 전 미리 짓기, 시각에 창 표시, 잠들어 있었으면 깨어난 뒤 표시. 하루 1회.
- 글 길이 3단계, 모델(Opus/Sonnet) 선택, 로그인 시 자동 시작.
- `sagebar://today` · `sagebar://regenerate?persona=…` · `sagebar://archive` URL 스킴.
- 헤드리스 CLI `SageBar --generate --persona … --model … --length …`.
