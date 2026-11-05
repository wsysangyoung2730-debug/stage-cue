# Git 작업 규칙

## 커밋

```text
[태그] 작업 내용
```

태그는 소문자, 작업 내용은 한글 명령조로 작성합니다. 제목은 50자를 넘기지 않으며 추가 설명은 본문에 작성합니다.

| 태그 | 사용 기준 |
| --- | --- |
| `init` | 최초 초기 커밋 |
| `feat` | 새로운 기능 |
| `fix` | 버그·오류 수정 |
| `docs` | README·템플릿 등 문서 |
| `setting` | 프로젝트 설정 |
| `add` | 에셋·라이브러리 추가 |
| `refactor` | 기존 코드 구조 개선 |
| `chore` | 기타 유지보수 |

예: `[feat] 무대 지시 단계 정리 구현`

## 브랜치

```text
태그/#이슈번호-작업하는파일
```

예: `feat/#1-stageCue`, `docs/#2-readme`, `setting/#3-projectStructure`

- `main`: 출시용 브랜치
- `develop`: 완료한 기능을 모아 최종 확인하는 개발 브랜치
- 모든 작업은 이슈를 만들고 별도 작업 브랜치에서 진행합니다.

## 반영 순서

1. 최신 `develop`에서 작업 브랜치를 만듭니다.
2. 해당 범위의 구현과 테스트를 완료합니다.
3. 작업 브랜치에 최신 `develop`을 먼저 병합하고 충돌을 확인합니다.
4. 원격에 푸시하고 `develop`을 대상으로 Pull Request를 엽니다.
5. 검토와 확인 후 `develop`에 병합합니다.

## 프로젝트 확인

- 타깃이나 빌드 설정을 바꿀 때는 `project.yml`을 수정하고 `xcodegen generate`를 실행합니다.
- `swift test --package-path Packages/StageCueCore`로 코어 테스트를 확인합니다.
- 화면 흐름을 바꾸면 Xcode의 `StageCue` 스킴에서 UI 테스트를 확인합니다.
- AI·음성 관련 변경은 실기기 확인 여부를 PR에 구분해 적습니다.
- API 키, 서명 인증서, 개인정보, 개인 Xcode 사용자 설정은 커밋하지 않습니다.
