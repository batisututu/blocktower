# ADR-0006: Android 저장 중 프로세스 종료 복구

날짜: 2026-09-21. 상태: 구현, 기기 검증 결과는 W5 보고서 참조.

## 문제

W3의 두 세대 저장·검증·손상 보존은 구현돼 있으나, Android에서 강제 종료된 프로세스의 `.writer_<PID>.lock`이 남으면 다음 실행이 저장을 열지 못했다. Windows의 tasklist 조회를 Android에 그대로 적용할 수 없다. `/proc` 접근 실패, PID 조회 오류, 경과 시간은 프로세스가 종료됐다는 증거가 아니다.

## 결정

Android에서는 Godot JavaClassWrapper로 RandomAccessFile → FileChannel.tryLock을 호출한다. `.writer.guard`는 삭제하지 않고 동일 inode를 계속 사용한다. 프로세스 종료 시 커널이 잠금을 해제하므로 정상적인 새 버전 저장은 잔여 PID 폴더 정리를 필요로 하지 않는다. 다른 실행이 소유하면 SAVE_BUSY, JNI·닫기 오류는 쓰기를 차단한다.

실제 4.7.2 브리지 검증에서 확인한 주의점: `tryLock(0, 1, false)`의 3인자 overload를 사용한다. `wrap()`은 직전 Java 호출의 예외 상태를 지우지 않으므로 반환 객체로 성공 여부를 검사하고 실제 Java 호출 직후에만 `get_exception()`을 검사한다. ErrnoException의 공개 인스턴스 필드는 JavaObject property로 노출되지 않아 `Class.getField("errno").getInt(error)`로 읽는다. SDK의 공개 API만 사용한다.

동일 프로세스는 canonical 경로를 먼저 예약한다. 두 번째 채널을 열었다 닫는 행위가 기존 POSIX 잠금을 해제할 수 있으므로 예약 실패 시 파일을 열지 않는다. 작업은 기존 계약대로 메인 스레드 동기식이며 백그라운드 저장은 도입하지 않는다.

기존 버전의 PID 폴더는 새 잠금을 잡은 뒤 검사한다. android.system.Os.kill(pid, 0)의 ESRCH만 종료로 인정한다. EPERM은 살아 있는 접근 불가 프로세스로 취급한다. 알 수 없는 오류·잘못된 PID·비어 있지 않은 폴더는 그대로 보존하고 차단한다. PID 재사용 시 보수적으로 SAVE_BUSY가 될 수 있다. 업데이트는 구버전 앱 종료 후 설치를 전제하며 구/신 프로토콜의 동시 실행은 지원하지 않는다.

저장 schema, RNG, 보상 규칙과 공개 지점은 바꾸지 않는다. pending은 확정 세대가 아니며 공개 전 종료는 이전 정상 세대, 공개 후 종료는 새 세대로 재개한다. 최신 세대가 손상됐을 때만 이전 세대와 복구 안내를 사용하고, 양쪽 손상·미지원 버전이면 초기화하지 않는다. 전체 계약은 [file_save_contract](../../game/scripts/core/contracts/file_save_contract.md).

## 검증과 한계

별도 `com.blocktower.recovery.qa`에 실제 core/persistence 소스를 복사하고 해시를 기록한다. 테스트용 subclass가 6개 커밋 지점에서 정지하면 호스트가 force-stop하고 새 PID로 재개한다. 전체 직렬화 상태 비교와 이벤트 재전송으로 중복 보상을 검사한다. 본 앱에는 QA 명령·중단 스크립트를 포함하지 않는다. 사용자 세이브에 손상 주입을 하지 않는다.

이 검증은 앱 프로세스 종료/재실행을 다룬다. 저장 장치 전원 차단, 디렉터리 fsync, 클라우드 동기화, 앱 삭제 후 복원, iOS 내구성을 보장하지 않는다. 기기별 실제 결과는 후속 보고서를 따른다.

## 근거

- [Godot JavaClassWrapper](https://docs.godotengine.org/en/stable/classes/class_javaclasswrapper.html): Android Java 호출 및 get_exception. 고정 엔진 4.7.2에서 실행 검증한다.
- [Android FileLock](https://developer.android.com/reference/java/nio/channels/FileLock): 채널/프로세스 수명, 동일 파일의 여러 채널 주의, 협력적 잠금의 범위.
- [Android Os.kill](https://developer.android.com/reference/android/system/Os#kill(int,%20int)) 및 [ErrnoException](https://developer.android.com/reference/android/system/ErrnoException): 시그널 0과 구조화된 errno. 번역된 오류 문자열로 판정하지 않는다.
