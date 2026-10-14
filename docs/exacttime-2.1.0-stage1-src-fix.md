# ExactTime 2.1.0 — 1단계 소스코드 수정 보고 (iOS 18 RootHide 수리)

```text
프로젝트: exacttime   빌드: 2.1.0 (src-only, 미빌드)   날짜: 2026-10-14
지침 파일: (사용자 직접 지시, temp/prompt 없음)      산출물: 없음 (2단계 빌드 예정)
```

## claim inventory (§17 Fact-Check 게이트)

```text
claim | type | verification source | status
extracted 2.0.3 4개 dylib에 '/var/jb/var/mobile/Library/Preferences/com.lclrc.exacttimeprefs.plist' 하드코딩 | 바이너리 문자열 | python bytes+regex 실측 (4/4 파일) | VERIFIED
작업 전 src 4개 트윅 파일이 '/var/mobile/.../com.gilshahar7.exacttimeprefs.plist' 사용 (var/jb 없음) | 소스 내용 | Read 실측 | VERIFIED
원본 control(2.0.3)에 'Icon: file:///var/jb/Library/...' 포함 | 패키지 메타데이터 | extracted/control/control 실측 | VERIFIED
iOS 18에서 MPRecentsTableViewCell.callerDateLabel.date=nil + 1줄 높이 제약으로 '\n' 잘림 | 런타임 동작 | 이번 세션 런타임 로그 없음, 사용자 증상+코드 추론 | HYPOTHESIS
CKConversationListCell '_dateLabel' ivar / MessageListCellView 'dateLabel' 속성 실재 | 심볼/ivar | 이번 세션 무검증 (상류 코드 계승) | UNVERIFIED (recall)
Logos %orig 재호출(Mail) 위치 선정·frame 보정식의 iOS 18 레이아웃 효과 | 프레임워크 의미 | 실기기 미검증 | OPEN ISSUE
본 단계에서 컴파일·패키징 미수행 | 빌드 상태 | Windows + macOS SSH 미사용 (1단계 범위) | OPEN ISSUE
```

## 1) 작업 전 상태 및 분석

- `git status --short`: `M src/ExactTime.xm, M src/ExactTimeMail.x, M src/ExactTimeMessages.xm, M src/ExactTimePhone.x, M src/Makefile, M src/control, M src/exacttimeprefs/ExactTimeprefs.mm, M src/exacttimeprefs/Makefile, M src/exacttimeprefs/Resources/ExactTimeprefs.plist, M src/exacttimeprefs/Resources/Info.plist` + untracked `com.lclrc.exacttime_2.0.3_iphoneos-arm64e.deb, extracted/, temp/`.
- `git log --oneline -3`: `9404195 ExactTime: initial baseline from gilshahar7 upstream and 2.0.3 analysis` (단일 베이스라인).
- `src/control` 작업 전: `Package: com.gilshahar7.exacttime / Version: 2.0.1 / Architecture: iphoneos-arm`, Icon 필드 없음.
- `src/Makefile` 작업 전: `ARCHS = armv7 arm64 arm64e`, `TARGET = iphone:clang:11.2:7.0`.
- 사용자 보고 증상 원문: "com.lclrc.exacttime_2.0.3_iphoneos-arm64e.deb 트윅이 iOS 18.7.1 RootHide 환경에서 전화 앱은 전혀 동작하지 않고, 메시지 앱은 라벨이 잘리는 등의 결함 발생."
- 원인 분석 (실측 기반):
  1. 설정 경로 이중 prefix (VERIFIED): 추출 dylib 4/4에서 `/var/jb/var/mobile/Library/Preferences/com.lclrc.exacttimeprefs.plist` 확인. RootHide에는 `/var/jb`가 없어 `initWithContentsOfFile:`가 nil → `boolValue`(nil)=NO → 전 기능 OFF. src 베이스라인은 구 번들ID(`com.gilshahar7...`, `/var/mobile/...`, `/var/jb` 없음)라서 어느 쪽으로도 2.0.3 설정 파일과 매칭되지 않음.
  2. 전화 앱 (HYPOTHESIS): `ExactTimePhone.x` 구 코드 `setDateFormat:@"\nHH:mm"`, `numberOfLines=2`, `date` nil 체크 없음. iOS 18 셀 1줄 제약 + nil date 조합에서 잘림/미표시.
  3. 메시지 앱 (HYPOTHESIS + UNVERIFIED ivar): ` • HH:mm` 추가 후 `sizeToFit`/폭 보정 없음 → `...` 말줄임.
- 영향 범위: 수정 파일 10개(아래 §3), 프레임워크 UIKit/Preferences(링크 유지, 변경 없음), 타겟 프로세스 SpringBoard(`ExactTime`), MobileSMS(`ExactTimeMessages`), mobilephone(`ExactTimePhone`), mobilemail(`ExactTimeMail`), 설정 앱(`ExactTimeprefs`).

## 2) 실제 실행 명령

| # | 위치 | 명령 | 목적 | 결과 |
|---|------|------|------|------|
| 1 | `D:\llama agent\tweak\exacttime` | `git status` / `git log --oneline -5` / `git diff --stat` | 작업 전 형상·버전 확인 | exit 0, M 10파일 + untracked 3건 |
| 2 | src 6파일 + prefs 3파일 | `Read` | 작업 전 소스 실측 | 성공, 구 번들ID·`\n` 포맷·구 Makefile 확인 |
| 3 | extracted | `Get-ChildItem -Recurse` + control 읽기 | 원본 패키지 구조·Icon `/var/jb` 확인 | 성공, VERIFIED |
| 4 | extracted dylib 4개 | `python -c` bytes regex (`/var…`, `com.…exacttime…`) | 하드코딩 경로 실측 | 성공 (strings.exe 없음 → python 대체, VERIFIED) |
| 5 | src 10파일 | `Edit` 11회 | 본 수정 반영 | 전부 성공 |
| 6 | src | `python -c` 잔류 검사 (`/var/jb`, `com.gilshahar7.exacttimeprefs`) | 회귀 검사 | 성공 — src 8/8 OK (`obj/` 빌드잔재 제외) |
| 7 | src 5파일 | `python -c` 균형 검사 (`%hook/%end/%ctor`, `{}`/`[]`/`()`) | 정적 구문 검증 | 성공, 전부 균형 (ExactTime.xm `%end`=6=hook 3+group 3) |

실패·재시도: (a) `strings` Windows 부재 → python bytes regex로 대체. (b) `git diff … | head` — Windows PowerShell에 `head` 없음 → `git diff --stat`로 대체. (c) python 기본 인코딩(cp949)에서 `•`(U+2022) 디코딩 실패 → `encoding='utf-8'` 명시로 해결.

## 3) 코드 변경 상세

변경 파일 10개 (수정 10, 추가/삭제 0):

### 3-1. `src/ExactTimePhone.x` — 경로+fallback+한줄표기+nil가드+sizeToFit
Before:
```objc
static NSString *settingsPath = @"/var/mobile/Library/Preferences/com.gilshahar7.exacttimeprefs.plist";
...
[dateFormatter setDateFormat:@"\nHH:mm"]; // / @"\nh:mm a"
self.callerDateLabel.textAlignment = 2;
self.callerDateLabel.numberOfLines = 2;
self.callerDateLabel.text = [self.callerDateLabel.text stringByAppendingString:[dateFormatter stringFromDate:self.callerDateLabel.date]];
...
enabled =  [[prefs objectForKey:@"phone"] boolValue];
```
After:
```objc
static NSString *settingsPath = @"/var/mobile/Library/Preferences/com.lclrc.exacttimeprefs.plist";
...
UIDateLabel *label = self.callerDateLabel;
if(!label || !label.text){ return; }
if(![label.text containsString:@":"]){
    NSDate *labelDate = label.date;
    if(!labelDate){ return; }
    ...
    [dateFormatter setDateFormat:@" • HH:mm"]; // / @" • h:mm a"
    label.textAlignment = 2;
    label.numberOfLines = 1;
    label.text = [label.text stringByAppendingString:[dateFormatter stringFromDate:labelDate]];
    [label sizeToFit];
}
...
id phoneValue = [prefs objectForKey:@"phone"];
enabled = (phoneValue ? [phoneValue boolValue] : YES);
```
근거: `/var/jb` 제거(원본 이중 prefix의 정반대 오류 방지 — RootHide 샌드박스 외 경로는 해석 불가), 번들ID를 2.0.3 설정 파일(`com.lclrc…`)과 일치, prefs 부재 시 YES(사용자 요구 fallback — 첫 설치 시 기능 ON), `\n`→` • ` 한줄 표기로 1줄 셀 제약 회피, nil date 가드로 nil 포맷팅 크래시/오표기 방지, `sizeToFit`으로 잘림 보정.

### 3-2. `src/ExactTimeMessages.xm` — 경로+fallback+nil가드+sizeToFit+폭클램프
Before: 구 번들ID 경로, `enabled=[[prefs objectForKey:@"messages"] boolValue]`, `dateLabel.text` nil/date 체크 없이 append, `sizeToFit` 없음.
After: 신 경로 + `id messagesValue…? … : YES`, `if(!dateLabel || !dateLabel.text || !dateLabel.date){ return; }`, append 후 `dateLabel.numberOfLines=1; [dateLabel sizeToFit];` + `CGRect f…; maxWidth=self.bounds.size.width-f.origin.x-8.0; 초과 시 폭 클램프`.
근거: 사용자 요구(`sizeToFit`+프레임 너비 보정) 반영. 클램프는 셀 우측 마진 8pt 가정(HYPOTHESIS) — 실기기에서 `...` 재발 시 마진값 조정 필요(OPEN ISSUE).

### 3-3. `src/ExactTimeMail.x` — 경로+fallback+nil가드 (포맷·sizeToFit 유지)
After: 신 경로, `id mailValue…? … : YES`, `if(!self.dateLabel || !self.dateLabel.text || !self.dateLabel.date){ return; }` 추가. 기존 ` • ` 포맷·`sizeToFit`·이중 `%orig` 주석은 유지(지시 외 변경 최소화).
편차 고지: 이중 `%orig` 호출은 레이아웃 재배치 목적 주석이 있어 이번 단계에서 제거하지 않음.

### 3-4. `src/ExactTime.xm` — 경로+notifications fallback (3 group 동일)
`settingsPath` → `com.lclrc…`, 각 group의 `bool enabled=[[prefs objectForKey:@"notifications"] boolValue]` → `id notificationsValue…; bool enabled=(…? … : YES)`. 그 외 로직 불변.

### 3-5. `src/control` — 2.1.0 메타데이터
Before: `Package: com.gilshahar7.exacttime / Version: 2.0.1 / Architecture: iphoneos-arm`, Maintainer gilshahar7, Icon 없음.
After:
```text
Package: com.lclrc.exacttime
Name: ExactTime
Depends: mobilesubstrate
Conflicts: com.gilshahar7.exacttimemail, com.gilshahar7.exacttimephone, com.gilshahar7.exacttimemessages
Version: 2.1.0
Architecture: iphoneos-arm64e
Description: Shows the exact time of notifications, messages, calls and emails.
Maintainer: SquidForce
Author: gilshahar7, SquidForce
Section: Tweaks
Icon: file:///Library/PreferenceBundles/ExactTimeprefs.bundle/ExactTime@3x.png
```
근거: 사용자 지정 4종(Package/Version/Architecture/Icon `/var/jb` 제거) 반영. 원본 2.0.3 control 실측(Maintainer SquidForce, Author gilshahar7·SquidForce)을 계승 — `SquidForce` 표기는 recall이 아닌 control 실측 기반(VERIFIED). `Conflicts` 구 패키지명 3종은 지시 없어 유지.

### 3-6. `src/Makefile`, `src/exacttimeprefs/Makefile` — 빌드 규격
`ARCHS = armv7 arm64 arm64e` → `ARCHS = arm64 arm64e`, `TARGET = iphone:clang:11.2:7.0` → `TARGET = iphone:clang:latest:16.5` (2파일 동일).

### 3-7. 지시 외 추가 수정 (편차 고지 — 안전 근거 포함)
- `exacttimeprefs/Resources/ExactTimeprefs.plist` 9건 `defaults: com.gilshahar7…` → `com.lclrc…`, `Resources/Info.plist` `CFBundleIdentifier` → `com.lclrc.exacttimeprefs`, `ExactTimeprefs.mm` 하드코딩 2건 → 신 경로. 이유: 트윅이 읽는 파일과 설정 번들이 쓰는 파일이 다르면 사용자 토글이 절대 반영되지 않고 fallback YES만 영구 동작하는 치명적 불일치. 쓰기/읽기 모두 `/var/mobile/…/com.lclrc.exacttimeprefs.plist`로 통일. 기존 `com.gilshahar7…` 사용자에게는 설정 초기화(마이그레이션 없음) — 2단계에서 필요 시 마이그레이션 스크립트 검토(OPEN ISSUE).
- `src/exacttimeprefs/obj/` 하위 빌드 잔재(`ExactTimeprefs.plist`, `Info.plist` 구 ID)는 수정하지 않음. 재빌드 시 재생성되는 파생물이며 `git status` untracked도 아님(추적 파일 아님) — 2단계 빌드에서 자동 갱신.

## 4) 빌드 진단 및 경고

- Logos 전처리: 미수행. Windows에 `logos.pl`/Theos 없음 → `logos_exit` OPEN ISSUE. 대신 수동 균형 검사 통과(§2 #7): 5파일 `%hook/%end/%ctor`·`{}`·`[]`·`()` 전부 균형.
- clang: 미수행 (macOS SSH 빌드는 2단계). Error 0 미확인 — 2단계에서 `make package` 시 확인 예정.
- 링커: `nm -u`/`otool -L` 미수행 (산출물 없음). 링크 라이브러리 변경 없음/UIKit·Preferences 유지.
- 정적 회귀 검사: `/var/jb` 0건, `com.gilshahar7.exacttimeprefs` 0건(src 추적 8파일), `setDateFormat:@"\n` 0건 — 통과.

## 5) 산출물 무결성

- 본 1단계는 src-only 수정 단계로 deb 산출물 없음. `build/` 디렉터리 변경 없음.
- `src/control` Version 2.1.0 선언과 `PROJECT.md` 기재 2.0.3 간 불일치는 의도적(2단계 빌드 시 deb 파일명 `com.lclrc.exacttime_2.1.0_iphoneos-arm64e.deb` 생성 예정). `PROJECT.md`는 지시 범위(src/) 밖이라 이번 단계에서 미갱신 — 2단계 빌드 성공 후 일괄 갱신 권장.
- 2단계에서 확인할 항목: deb 바이트 크기·SHA256(로컬/VM), `lipo -info`(arm64+arm64e), `ar tv` 순서, control tar 최상위 `./control`, `.roothidepatch` 0바이트 카운트, `nm -u`/`strings`(셀렉터·`callerDateLabel`·`_dateLabel`·` • ` 포맷 문자열).

## 6) 영향도 및 잠재 리스크

- SpringBoard(알림): `notifications` fallback YES로 기존 OFF 사용자도 업데이트 후 알림 시간 표시 ON — 의도된 기본값 변경이나, 원치 않는 노출 가능. 되돌리기 knob: 설정에서 Notifications OFF.
- 전화 앱: nil date 가드가 `return`이라 iOS 18에서 date가 항상 nil이면 시간이 영구 미표시(안전 실패). 로그 없이 침묵하므로 2단계에서 `label.date==nil` 빈도 로깅 후, 필요 시 대체 소스(통화기록 DB 날짜)로 전환 검토. `numberOfLines` 2→1 변경은 기존 2줄 레이아웃 기대와 다름 — 실기기 스크린샷 확인 필요.
- 메시지 앱: 폭 클램프 마진 8pt는 가정치. 좁은 셀·Dynamic Type 확대 시 여전히 `...` 가능. `sizeToFit`이 AutoLayout과 경합하면 깜빡임 가능 — `layoutSubviews` 내 중복 append는 `containsString:@":"` 가드로 방지(기존 로직 유지).
- 메일 앱: 이중 `%orig` 유지 — 레이아웃 루프 위험은 기존과 동일, 이번 단계에서 증가 없음.
- 설정 마이그레이션: 구 ID 사용자의 기존 토글값 미승계(초기화). 2단계 패키지에 `preinst`/`extrainst_` 마이그레이션 포함 여부 결정 필요.
- 실기기 관찰 로그 문자열 (2단계 검증용): 설정 파일 존재 확인 `ls -l /var/mobile/Library/Preferences/com.lclrc.exacttimeprefs.plist`; 토글 키 `phone/messages/mail/notifications`; 전화 셀 `callerDateLabel.text`에 ` • HH:mm` 포함 여부; 메시지 셀 `_dateLabel` `...` 여부; SpringBoard 크래시 로그에서 `ExactTime` 프레임 여부.
