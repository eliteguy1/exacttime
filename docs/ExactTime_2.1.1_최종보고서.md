# ExactTime v2.1.1 최종 보고서 (dpkg 패키지 충돌 해결 및 배포)

## 1. 개요 (Overview)
* **대상 트윅:** ExactTime (`com.lclrc.exacttime`)
* **패키지 버전:** 2.1.1
* **타겟 환경:** RootHide / Dopamine 3 / iOS 18.7.1 (22H31)
* **지원 아키텍처:** `arm64`, `arm64e` (FAT 바이너리)
* **산출물 파일:** `build/com.lclrc.exacttime_2.1.1_iphoneos-arm64e.deb`
* **파일 크기:** 50,452 bytes
* **SHA256 해시:** `9ECC9D4B204268F71745162DFF226F7345CE3231780158369D57A29AF328630F`

---

## 2. 확인한 사실 및 문제 원인 (Problem & Root Cause)

### 2.1 dpkg 설치 거부 오류 현상
기기에서 `com.lclrc.exacttime_2.1.0_iphoneos-arm64e.deb` 설치 시 다음과 같은 dpkg 에러 발생:
```text
dpkg: error processing archive /var/cache/apt/archives/com.lclrc.exacttime_2.1.0_iphoneos-arm64e.deb (--unpack):
 trying to overwrite '/Library/MobileSubstrate/DynamicLibraries/ExactTime.dylib', which is also in package com.gilshahar7.exacttime 2.0.2
Errors were encountered while processing:
 /var/cache/apt/archives/com.lclrc.exacttime_2.1.0_iphoneos-arm64e.deb
E: Sub-process /usr/bin/dpkg returned an error code (1)
```

### 2.2 근본 원인 (Root Cause)
1. 사용자의 기기에 이전 원본 패키지인 `com.gilshahar7.exacttime` (2.0.2)이 이미 설치되어 있었음.
2. `com.lclrc.exacttime`의 `control` 메타데이터에 `Conflicts:`로 `exacttimemail`, `exacttimephone`, `exacttimemessages`는 명시되어 있었으나, 메인 패키지 ID인 `com.gilshahar7.exacttime`이 누락되어 있었음.
3. 결정적으로 dpkg에서 타 패키지의 파일(`/Library/MobileSubstrate/DynamicLibraries/ExactTime.dylib`)을 덮어쓰고 교체하기 위해서는 `Replaces:` 필드가 필수적인데, 이것이 지정되지 않아 dpkg가 파일 충돌(file collision)로 간주하고 설치를 거부함.

---

## 3. 해결 내역 (Solutions)

`src/control` 파일에 `Replaces`, `Conflicts`, `Provides`를 명시적으로 선언:
```control
Package: com.lclrc.exacttime
Name: ExactTime
Depends: mobilesubstrate
Conflicts: com.gilshahar7.exacttime, com.gilshahar7.exacttimemail, com.gilshahar7.exacttimephone, com.gilshahar7.exacttimemessages
Replaces: com.gilshahar7.exacttime, com.gilshahar7.exacttimemail, com.gilshahar7.exacttimephone, com.gilshahar7.exacttimemessages
Provides: com.gilshahar7.exacttime (= 2.1.1)
Version: 2.1.1
```

* **Replaces**: dpkg가 기존 `com.gilshahar7.exacttime`에 속한 파일들을 정상적으로 덮어쓰고 소유권을 `com.lclrc.exacttime`으로 안전하게 이전.
* **Conflicts & Provides**: 패키지 매니저(Sileo, Zebra)가 구 패키지를 자동으로 제거(Replace)하고 새 패키지를 원활하게 설치하도록 보장.

---

## 4. 산출물 무결성 검증 (Artifact Integrity)

1. **deb 아카이브 구조**: 순수 GNU ar 포맷 (`debian-binary` → `control.tar.gz` → `data.tar.lzma`).
2. **control 구조**: 최상위 `./control` 정상 배치.
3. **0바이트 .roothidepatch**: 0개 (세이프모드 방지).
4. **Mach-O 바이너리**: `arm64`, `arm64e` FAT 슬라이스, 중복 `LC_RPATH` 0개, `ldid` ad-hoc 서명 완료.
5. **체크섬 및 파일 크기**:
   - 크기: `50,452 bytes`
   - SHA256: `9ECC9D4B204268F71745162DFF226F7345CE3231780158369D57A29AF328630F`
