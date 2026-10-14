# ExactTime 2.1.0 — 2단계 보고 (데이터 모델 폴백 강화 + RootHide 빌드 검증)

```text
프로젝트: exacttime   빌드: 2.1.0 roothide FINALPACKAGE=1   날짜: 2026-10-14
VM: csw@192.168.1.21:~/theos_projects/ExactTime/   산출물: build/com.lclrc.exacttime_2.1.0_iphoneos-arm64e.deb
```

## claim inventory (§17)

```text
claim | type | verification source | status
objc_setAssociatedObject(object,key,value,policy) / objc_getAssociatedObject(object,key) / OBJC_ASSOCIATION_RETAIN_NONATOMIC 존재 | ObjC Runtime API | Apple Docs MCP 조회+expand (선언부 실측) | VERIFIED
tableView:cellForRowAtIndexPath: 데이터소스 시그니처 | UIKit API | 조회 시도 1회(AppKit 노이즈만 반환) → 추가 탐색 중단(§16 2-strike) | UNVERIFIED (recall)
CHRecentCall / -recentCallAtTableViewIndex: / CKConversationListCell.conversation / conversation.date 실재 | 비공개 심볼 | 런타임 무검증 (지시문 계승) | UNVERIFIED (recall)
iOS 18에서 label.date=nil 빈발 | 런타임 동작 | 실기기 로그 없음 | HYPOTHESIS
로컬 8파일 ↔ VM 8파일 SHA256 전량 일치 (동기화 무결성) | 파일 내용 | 양측 shasum 실측 | VERIFIED
빌드 성공·에러 0·아키텍처·해시·서명 전 항목 | 빌드/산출물 | 로그+측정 실측 | VERIFIED
ldid ad-hoc 서명 존재 (Apple codesign 인정 아님) | 서명 | ldid -e exit 0 실측 | VERIFIED
```

## 1) 작업 전 상태 및 분석

- `git status --short`: M 10파일(1단계+2단계 누적) + untracked `build/ docs/ extracted/ temp/` 및 원본 2.0.3 deb. `git log`: `9404195` 단일 베이스라인.
- `src/control` Version 2.1.0 유지 — 2.1.0 deb이 한 번도 빌드/배포된 적 없으므로 버전 재사용 금지(§10) 위반 아님. 별도 bump 불필요.
- 외부 동기분 발견(VERIFIED): 로컬 src가 1단계 종료 시점과 달라져 있었음 — `ExactTimePhone.x`/`ExactTimeMessages.xm`에 `#import <UIKit/UIKit.h>`·슈퍼클래스 명시·`(NSNumber *)` 캐스트, `exacttimeprefs/Makefile`에 `-fobjc-arc`+Frameworks 추가. VM 8파일과 로컬 8파일 SHA256 8/8 일치 확인 후 현 상태를 정본으로 채택(아래 §3 편차 고지).
- 사용자 증상 원문(1단계와 동일): 2.0.3이 iOS 18.7.1 RootHide에서 전화 무동작·메시지 잘림. 2단계 목표는 nil-date 절대 보장용 폴백 2종 + 실빌드 검증.

## 2) 실제 실행 명령

| # | 위치 | 명령 | 목적 | 결과 |
|---|------|------|------|------|
| 1 | 로컬 | `Read` Phone/Messages/PROJECT.md/stage1 docs | 현 상태 실측 | 성공 — 외부 변경분 확인 |
| 2 | 로컬+VM | `shasum -a 256` 8파일 양측 | 동기화 무결성 | exit 0, 8/8 일치 VERIFIED |
| 3 | Apple Docs MCP | associated-object 3건 search+expand, tableView search 1회 | §17 식별자 검증 | API VERIFIED, tableView는 노이즈 → 중단 |
| 4 | 로컬 | `Edit` Messages 2회 (superclass, labelDate) | 빌드 에러 수정 | 성공 |
| 5 | 로컬 | `Edit` prefs Makefile (`-fobjc-arc`→`-fno-objc-arc`) | ARC/MRC 충돌 수정 | 성공 |
| 6 | scp ×4 | 소스→VM 명시적 복사 (10+14+1+1 파일) | 동기화 | 성공, SHA 재확인 |
| 7 | VM ssh | `make clean && make package THEOS_PACKAGE_SCHEME=roothide FINALPACKAGE=1` (1차) | 빌드 | 도구 abort (로그 없음) |
| 8 | VM ssh | 동일 빌드 (2차) | 빌드 | Messages 2 errors로 중단 (아래 §4) |
| 9 | VM ssh | 동일 빌드 (3차) | 빌드 | prefs ARC 3 errors로 중단 (아래 §4) |
| 10 | VM ssh | 동일 빌드 (4차) | 빌드 | **성공**, deb 생성 |
| 11 | VM | ar/sha/lipo/otool/ldid/strings 스크립트 3종 (`temp/*.sh`, `temp/*.py`) | 5대 검증 | 전부 통과 |
| 12 | scp | VM→`build/com.lclrc.exacttime_2.1.0_iphoneos-arm64e.deb` | 회수 | 50396B·SHA256 VM=로컬 일치 |

쉘 함정 회피: PowerShell `&&`·`head` 미지원 → `; if ($?)`·분할 실행. zsh glob/quoting 파손 3회 → 스크립트 파일+scp 방식으로 전환. `lzma`/`xz` CLI 부재 → python3-lzma(FORMAT_ALONE)로 data.tar 해석.

## 3) 코드 변경 상세 (2단계분; 1단계는 stage1 문서 참조)

### 3-1. `src/ExactTimePhone.x` — controller 후킹 + associated callDate (1단계 가드 유지)
```objc
#import <objc/runtime.h>  // VERIFIED API용 헤더
@interface CHRecentCall
@property (nonatomic, strong) NSDate *date;   // UNVERIFIED (recall)
@end
@interface MPRecentsTableViewController
- (id)recentCallAtTableViewIndex:(NSInteger)index;  // UNVERIFIED (recall)
@end
static char kExactTimeCallDateKey;  // 문자열 리터럴 대신 정적 주소 키

%hook MPRecentsTableViewController
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell = %orig;  // 패스스루, 원본 동작 불변
    if(cell && [self respondsToSelector:@selector(recentCallAtTableViewIndex:)]){
        id call = [self recentCallAtTableViewIndex:indexPath.row];
        NSDate *callDate = nil;
        if(call && [call respondsToSelector:@selector(date)]){ callDate = [call date]; }
        // 날짜 없어도 nil을 기록 → 셀 재사용 시 stale 날짜 잔류 방지
        objc_setAssociatedObject(cell, &kExactTimeCallDateKey, callDate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return cell;
}
%end
// layoutSubviews: NSDate *labelDate = label.date; if(!labelDate){ labelDate = objc_getAssociatedObject(self, &kExactTimeCallDateKey); } if(!labelDate){ return; }
```
설계: 메서드 미존재 환경에선 후킹이 무연산 패스 → 1단계 동작으로 안전 강등. `?:` 한 줄 대신 if문 — `objc_getAssociatedObject` 반환 `id` 대입의 명시성 유지.

### 3-2. `src/ExactTimeMessages.xm` — conversation.date 폴백
```objc
@interface CKConversationListCell : UITableViewCell  // ← 빌드 수정: 무상속 → UITableViewCell
@property (nonatomic, strong) id conversation;        // UNVERIFIED (recall)
@end
// NSDate *labelDate = dateLabel.date;
if(!labelDate && [self respondsToSelector:@selector(conversation)]){
    id conv = [self conversation];
    if(conv && [conv respondsToSelector:@selector(date)]){ labelDate = [conv date]; }
}
if(!labelDate){ return; }
// ... stringFromDate:labelDate (기존 dateLabel.date 오용 수정)
```
빌드 수정 근거: 무상속 전방선언 상태에서 `self`가 정적 타입을 가져 `respondsToSelector:`/`bounds` 접근이 `-Werror` 하드 에러 발생 → `UITableViewCell` 상속 명시로 해결. 동작 변경 없음.

### 3-3. `src/exacttimeprefs/Makefile` — `-fobjc-arc` → `-fno-objc-arc`
근거: 번들 소스(`ExactTimeprefs.mm`)는 `retain`/C-cast를 쓰는 MRC 시대 코드. 트윅 4종이 `release` 호출 그대로 컴파일된 것이 MRC 모드의 실증. 외부 동기분이 넣은 `-fobjc-arc`가 3 errors 유발 → MRC로 복원. 소스 무수정(최소 변경).

### 3-4. 지시 외 편차 고지
- 외부 동기분(UIKit import·슈퍼클래스·NSNumber 캐스트·Frameworks 행)을 리뷰 후 채택: 컴파일에 필요·무해, Phone 빌드 성공으로 실증. `MPRecentsTableViewController : NSObject`의 슈퍼클래스 부정확성(실제는 테이블 컨트롤러 계열 추정)은 전방선언 용도에만 쓰여 컴파일·런타임 영향 없음(HYPOTHESIS 표기).
- 버전 bump 없음(§1 근거). `PROJECT.md` 미갱신(빌드 성공 후 일괄 갱신 권장). 커밋/푸시 미수행(지시 범위 외).

## 4) 빌드 진단 및 경고

- Logos 전처리: 4 tweak + 1 bundle 전 단계 `Preprocessing` 통과, `logos_exit` 에러 0 (VERIFIED — 로그 전문).
- clang: **Error 0, Warning 0**. 투입된 에러 2+3건은 모두 수정 후 재빌드에서 소멸:
  - Messages 2 errors: `may not respond to 'respondsToSelector:'`, `property 'bounds' not found` — 원인=무상속 전방선언, 해결=§3-2.
  - prefs 3 errors: `bridged cast requires __bridge`, `retain unavailable (ARC)` ×2 — 원인=`-fobjc-arc`, 해결=§3-3.
- 링커: `ld: warning: -multiply_defined is obsolete` 10회(타깃 5 × 아치 2). Theos 표준 경고로 무해 — 산출물 arm64/arm64e fat 병합 정상. `LC_RPATH` 4 dylib 전부 0개 → 중복 없음 VERIFIED.
- 빌드 시간 내내 `FINALPACKAGE=1` + `THEOS_PACKAGE_SCHEME=roothide`, SDK iPhoneOS26.0·TARGET 16.5·ARCHS arm64 arm64e 준수.

## 5) 산출물 무결성 (5대 검증 전부 통과)

- 경로: VM `~/theos_projects/ExactTime/packages/com.lclrc.exacttime_2.1.0_iphoneos-arm64e.deb` → 로컬 `D:\llama agent\tweak\exacttime\build\` 동명 회수.
- 크기·해시: **50396 bytes**, **SHA256 35d1a4e2483a9102a99fcef86bb2dd61f7c966479d631a4bcaf2039e5c9461e8** — VM=로컬 일치 VERIFIED.
- GNU ar: `debian-binary` → `control.tar.gz` → `data.tar.lzma` 순서 VERIFIED.
- control tar: `.` → `./control` 최상위 VERIFIED.
- `.roothidepatch`: **0개** VERIFIED (data.tar 32항목 전수, RootHide 레이아웃=`Library/...` prefix, `/var/jb` 없음).
- lipo: 5 Mach-O(ExactTime/Phone/Messages/Mail/ExactTimeprefs) 전부 **arm64+arm64e fat** VERIFIED.
- strings: Phone=`recentCallAtTableViewIndex:`·`tableView:cellForRowAtIndexPath:`·`callerDateLabel` 존재, Messages=`conversation`·`_dateLabel` 존재, 설정경로 `/var/mobile/.../com.lclrc.exacttimeprefs.plist` 유일·`/var/jb` 0건 VERIFIED.
- ldid: `ldid -e` exit 0 (ad-hoc 서명 존재). Apple `codesign`은 "no signature" — ldid 서명의 정상 특성, 결함 아님.

## 6) 영향도 및 잠재 리스크

- 전화: 컨트롤러 후킹은 `%orig` 패스스루 + 가드라 원본 셀 생성 경로 불변. `recentCallAtTableViewIndex:` 부재 기기 → associated 미기록 → 1단계 동작(라벨 단독)으로 강등, 크래시 불가 구조. associated nil 기록으로 stale 날짜 방지(§3-1). 잔류 리스크: 실기 iOS 18.7.1에서 해당 셀렉터 부재 시 폴백 무의미 — 설치 후 `callerDateLabel` 시간 표시율로 판정 (OPEN ISSUE, 실기기 관찰 필요).
- 메시지: `conversation` 부재 시 동일하게 강등. `stringFromDate:labelDate` 수정으로 폴백일이 실제 표시됨(수정 전이면 폴백 무의미 + nil 크래시 가능 — 본 단계에서 해소).
- 설정 번들 MRC 유지: 기존 메모리 관리와 동일, 신규 리스크 없음.
- 되돌리기 knob: 설정 OFF fallback YES 유지(1단계), deb 재설치 시 2.0.3 복원 가능(원본 deb 불변 보존).
- 실기기 관찰점: 전화 최근통화 ` • HH:mm` 표시 여부, 메시지 `...` 재발 여부, `/var/mobile/.../com.lclrc.exacttimeprefs.plist` 생성 여부, SpringBoard/mobilephone/MobileSMS 크래시 로그의 ExactTime 프레임.
- 후속 권장: `PROJECT.md` 버전이력 2.1.0 갱신 + `git add/commit/push` (별도 승인 후).
