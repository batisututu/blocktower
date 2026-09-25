extends RefCounted
## W2 개발/테스트용. 프로세스 종료 후 보존되지 않으며 디스크 저장을 대체하지 않는다.
var _stored: Dictionary = {}
var fail_next_commit := false
var uncertain_next_commit := false

func load_snapshot() -> Dictionary:
	return {"ok": true, "found": not _stored.is_empty(), "snapshot": _stored.duplicate(true)}

func commit(candidate: Dictionary, expected_revision: int) -> Dictionary:
	if fail_next_commit:
		fail_next_commit = false
		return {"ok": false, "error": "SAVE_FAILED"}
	var revision: int = -1 if _stored.is_empty() else _stored.revision
	if revision != expected_revision:
		return {"ok": false, "error": "SAVE_CONFLICT"}
	_stored = candidate.duplicate(true)
	if uncertain_next_commit:
		uncertain_next_commit = false
		return {"ok": false, "error": "COMMIT_UNCERTAIN"}
	return {"ok": true}
