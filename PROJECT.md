# iOS RootHide Tweak Master Project Guide

> 본 문서는 `D:\llama agent\tweak\exacttime` 트윅 프로젝트(`ExactTime`)에 적용되는 표준 아키텍처, 빌드 파이프라인, deb 패키징 규격, RootHide 런타임 호환성 및 트러블슈팅 가이드이다.

---

## 1. 프로젝트 기본 정보 (Project Overview)

* **템플릿 대상:** `D:\llama agent\tweak\exacttime`
* **현재 트윅 인스턴스:** ExactTime (`com.lclrc.exacttime`)
* **로컬 경로:** `D:\llama agent\tweak\exacttime`
* **Git 저장소:** `D:\llama agent\tweak\exacttime\.git`
* **타겟 환경:** RootHide / Dopamine 3 / iOS 18.7.1 (22H31)
* **지원 아키텍처:** `arm64`, `arm64e`
* **현재 패키지 버전:** 2.1.2 (`com.lclrc.exacttime_2.1.2_iphoneos-arm64e.deb`)
* **프로젝트 상태:** 검증 완료 (Stable)

---

## 2. 표준 디렉터리 구조 (Directory Structure)

```text
exacttime\
├── PROJECT.md        # 트윅 프로젝트 규격서 및 상태 문서
├── com.lclrc.exacttime_2.0.3_iphoneos-arm64e.deb   # 원본 패키지 레퍼런스 (불변 보존)
├── .git\             # 로컬 Git 형상 관리
├── extracted\        # 원본 패키지 분석 및 역공학 레퍼런스
├── src\              # 최신 개발 소스코드 (Makefile, Tweak, control 등)
├── build\            # 빌드 완료된 산출물 deb 패키지
├── mcp\              # MCP / 외부 참조 소스 및 문서
├── logs\             # 런타임 로그, 진단 결과
├── temp\             # 임시/스테이징 작업 파일
└── docs\             # 검증된 기술 지식, 원인 분석 보고서
```

---

## 3. 원본 패키지 결함 분석 (v2.0.3)

1. **RootHide 미지원 경로 하드코딩**:
   - 설정 파일 경로가 `/var/jb/var/mobile/Library/Preferences/com.lclrc.exacttimeprefs.plist`로 하드코딩됨.
   - RootHide에는 `/var/jb`가 없어 `[NSMutableDictionary initWithContentsOfFile:]`가 `nil`을 반환하고, 기본값이 `enabled = 0`으로 처리되어 모든 기능이 비활성화됨.
2. **전화 앱(Phone.app) 통화 기록 렌더링 실패 (iOS 17/18)**:
   - `MPRecentsTableViewCell.callerDateLabel.date` 속성이 iOS 17/18에서 `nil`로 넘어와 날짜 포맷팅 실패.
   - 셀 높이 AutoLayout 1줄 고정 제약조건으로 인해 `\n` 개행 텍스트가 프레임 아래로 잘려 보이지 않음.
3. **메시지 앱(Messages.app) 라벨 말줄임표(...) 잘림**:
   - `CKConversationListCell._dateLabel`의 프레임 폭이 좁게 제한되어 있어 긴 시간 문자열(` • HH:mm`) 추가 시 `...`로 잘림.

---

## 4. 버전 이력 (Version History)

| 버전 | 일자 | 변경 내역 | 결과 |
| :--- | :--- | :--- | :--- |
| `2.1.2` | 2026-10-14 | • iOS 18 전화 앱 셀 감지 전면 개편: `MPRecentsTableViewCell`뿐만 아니라 모든 `UITableViewCell` 및 `UICollectionViewCell`을 포괄 훅<br>• `FindDateLabelInView`: 우측 날짜 라벨(상대시각 문자열 "어제", "요일" 등) 및 `UIDateLabel` 재귀적 동적 탐색<br>• `ExtractDateFromCell`: `label.date`, Associated Object, 셀 메서드(`recentCall`, `call`), 셀 ivar 탐색을 통한 4중 `NSDate` 획득 파이프라인 구축<br>• 진단 로깅(`/var/mobile/exacttime_phone.log`) 추가<br>• SHA256: `15A3F17E5520...` | 정상 빌드 및 배포 완료 |
| `2.1.1` | 2026-10-14 | • dpkg 충돌 해결: `Replaces:` 및 `Conflicts:`, `Provides:`에 기존 원본 패키지(`com.gilshahar7.exacttime`) 추가하여 `trying to overwrite ... which is also in package` 오류 완벽 방지<br>• arm64/arm64e FAT 바이너리 및 순수 GNU ar 포맷 검증 완료 (SHA256: `9ECC9D4B2042...`) | 정상 빌드 및 배포 완료 |
| `2.1.0` | 2026-10-14 | • RootHide 표준 경로(`/var/mobile/Library/Preferences/...`)로 전면 수정 및 설정 파일 미생성 시 기본값 YES(활성화) 폴백 적용<br>• iOS 18 전화 앱: `MPRecentsTableViewController` 훅을 통해 `CHRecentCall.date`를 셀에 `objc_setAssociatedObject`로 바인딩하여 date가 nil인 문제 해결<br>• 전화 앱 개행 잘림 방지: 한 줄 포맷(` • HH:mm` / ` • h:mm a`) 및 `numberOfLines = 1`, `sizeToFit` 적용<br>• iOS 18 메시지 앱: `_dateLabel` nil/bounds 방어 및 `sizeToFit` + 우측 여백 제약 반영하여 `...` 잘림 방지<br>• Theos iOS 16.5 SDK 호환성: UIKit/Foundation 명시적 import 및 클래스 상속 선언 수정<br>• arm64/arm64e FAT 바이너리, 순수 GNU ar 포맷 deb 패키징 완료 (SHA256: `35D1A4E2483A...`) | 정상 빌드 및 검증 완료 |
| `2.0.3` | 2024-01-22 | 원본 패키지 (SquidForce 리패키징, iOS 18 전화/메시지 동작 불량) | 결함 확인 |
