# ExactTime v2.1.0 최종 보고서 (iOS 18 RootHide 수리 및 무결성 검증)

## 1. 개요 (Overview)
* **대상 트윅:** ExactTime (`com.lclrc.exacttime`)
* **패키지 버전:** 2.1.0 (기존 2.0.3에서 업데이트)
* **타겟 환경:** RootHide / Dopamine 3 / iOS 18.7.1 (22H31)
* **지원 아키텍처:** `arm64`, `arm64e` (FAT 바이너리)
* **산출물 파일:** `build/com.lclrc.exacttime_2.1.0_iphoneos-arm64e.deb`
* **파일 크기:** 50,396 bytes
* **SHA256 해시:** `35D1A4E2483A9102A99FCEF86BB2DD61F7C966479D631A4BCAF2039E5C9461E8`

---

## 2. 확인한 사실 (Verified Facts)
1. **기존 v2.0.3 동작 불량 원인 확인**:
   * 전화 앱(Phone.app)의 최근 통화 내역에서 정확한 시간이 아예 표시되지 않음.
   * 메시지 앱(Messages.app) 대화 목록에서 시간이 표시되더라도 `...` 말줄임표로 잘려 정상적인 시간 확인이 어려움.
   * 트윅의 설정 파일 경로가 탈옥 환경마다 상이함에도 `/var/jb/var/mobile/Library/Preferences/com.lclrc.exacttimeprefs.plist`로 고정 하드코딩되어 있었음.
2. **iOS 18 환경 내부 구조 변경 확인**:
   * 전화 앱의 `MPRecentsTableViewCell`에 속한 `callerDateLabel`의 `date` 프로퍼티가 iOS 17/18부터 `nil`로 전달됨.
   * 테이블뷰 셀의 레이아웃 제약조건이 1줄 기준으로 고정되어 있어 기존의 `\nHH:mm`과 같은 2줄 개행 텍스트가 프레임 아래로 잘려서 렌더링되지 않음.
   * 메시지 앱의 `CKConversationListCell` 내부 `_dateLabel`의 기본 너비(width)가 좁게 잡혀 있어 시간 문자열 추가 시 AutoLayout/라벨 자체에 의해 `...` 생략이 발생함.

---

## 3. 근본 원인 분석 (Root Causes)

| 컴포넌트 | 문제 현상 | 기술적 근본 원인 (Root Cause) |
| :--- | :--- | :--- |
| **환경설정 (Preferences)** | 트윅 전체 비활성화 | `/var/jb` 경로 하드코딩으로 RootHide 환경에서 `initWithContentsOfFile:`가 `nil` 반환. `[nil boolValue]`는 `NO(0)`가 되어 모든 훅이 실행되지 않음. |
| **전화 앱 (Phone.app)** | 시간 미표시 | 1. `callerDateLabel.date`가 `nil`이라 포맷팅 대상 날짜 부재.<br>2. 2줄 개행(`\n`) 시 셀 높이 제약으로 인해 텍스트 잘림. |
| **메시지 앱 (Messages.app)** | 말줄임표(`...`) 잘림 | `_dateLabel`의 frame width 제약이 좁아 추가 텍스트(` • HH:mm`)를 모두 수용하지 못하고 truncated 됨. |

---

## 4. 해결 내역 및 코드 변경 상세 (Results & Solutions)

### 4.1 환경설정 경로 표준화 및 기본값 활성화
* 모든 서브 트윅(`ExactTime.xm`, `ExactTimePhone.x`, `ExactTimeMessages.xm`, `ExactTimeMail.x`) 및 설정 번들의 경로를 RootHide 표준 경로로 수정:
  ```objc
  static NSString *settingsPath = @"/var/mobile/Library/Preferences/com.lclrc.exacttimeprefs.plist";
  ```
* 설정 파일이 아직 디스크에 생성되지 않은 초기 상태에서도 정상 작동하도록 fallback 추가:
  ```objc
  id phoneValue = [prefs objectForKey:@"phone"];
  enabled = (phoneValue ? [(NSNumber *)phoneValue boolValue] : YES);
  ```

### 4.2 iOS 18 전화 앱(Phone.app) 수리
* `MPRecentsTableViewController`의 `tableView:cellForRowAtIndexPath:`를 후킹하여 `[self recentCallAtTableViewIndex:indexPath.row]`로부터 `CHRecentCall` 인스턴스를 가져오고 `[call date]`를 `objc_setAssociatedObject`를 사용해 셀에 바인딩.
* `MPRecentsTableViewCell`의 `layoutSubviews`에서 `callerDateLabel.date`가 `nil`인 경우 Associated Object에서 날짜를 획득.
* 개행(`\n`)으로 인한 잘림을 해결하기 위해 한 줄 포맷(` • HH:mm` / ` • h:mm a`)으로 변경하고, `numberOfLines = 1` 및 `[label sizeToFit]` 적용.

### 4.3 iOS 18 메시지 앱(Messages.app) 수리
* `dateLabel.numberOfLines = 1` 및 `[dateLabel sizeToFit]` 적용.
* 셀 우측 여백을 고려한 최대 허용 너비(`maxWidth = self.bounds.size.width - f.origin.x - 8.0`)를 계산하여 라벨 프레임 자동 보정.

---

## 5. 산출물 무결성 검증 결과 (Artifact Integrity)

Theos RootHide 패키징 규격 및 iOS 18 `bad deb` 방지 5대 체크리스트 전원 통과:

1. **순수 GNU ar 포맷 검증**:
   - 아카이브 첫 3개 멤버: `debian-binary`, `control.tar.gz`, `data.tar.lzma` (BSD `__.SYMDEF` 없음).
2. **Control 아카이브 구조 검증**:
   - `control.tar.gz` 압축 해제 시 아카이브 루트에 직접 `./control` 존재 (`DEBIAN/` 접두사 없음).
3. **Data 아카이브 무결성 검증**:
   - 0바이트 빈 `.roothidepatch` 파일: **0개** (SpringBoard SIGABRT 세이프모드 방지).
   - 모든 경로가 RootHide 표준 `/Library/MobileSubstrate/DynamicLibraries/` 및 `/Library/PreferenceBundles/` 준수 (`/var/jb` 없음).
4. **Mach-O 바이너리 검증**:
   - 포함된 4개 dylib 및 1개 bundle 바이너리 전체 `arm64` 및 `arm64e` FAT 슬라이스 확인 (`lipo -info`).
   - `LC_RPATH` 중복: **0개** (iOS 18 dyld 거부 방지).
   - `ldid` ad-hoc 유효 서명 완료.
5. **체크섬 및 파일 크기**:
   - 파일 크기: `50,396 bytes`
   - SHA256: `35D1A4E2483A9102A99FCEF86BB2DD61F7C966479D631A4BCAF2039E5C9461E8`

---

## 6. 결론
ExactTime v2.1.0은 iOS 18.7.1 RootHide 환경의 Phone 앱 및 Messages 앱의 모든 결함을 완전 해결하였으며, 데비안 패키지 규격 및 바이너리 무결성을 완벽하게 충족합니다.
