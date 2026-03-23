#!/bin/zsh

acquire_build_lock() {
    local build_dir="$1"
    local lock_dir="$build_dir/.build.lock"
    local wait_ticks=0
    local max_wait_ticks=1800

    mkdir -p "$build_dir"

    # Allow nested script calls to share the same lock without releasing it early.
    if [[ "${TOPMEMO_BUILD_LOCK_DIR:-}" == "$lock_dir" ]]; then
        return 0
    fi

    while ! mkdir "$lock_dir" 2>/dev/null; do
        if (( wait_ticks >= max_wait_ticks )); then
            echo "Another build is already using $build_dir. Remove $lock_dir if the lock is stale." >&2
            exit 1
        fi
        sleep 0.1
        wait_ticks=$((wait_ticks + 1))
    done

    export TOPMEMO_BUILD_LOCK_DIR="$lock_dir"
    export TOPMEMO_BUILD_LOCK_OWNER_PID="$$"
}

release_build_lock() {
    local lock_dir="${TOPMEMO_BUILD_LOCK_DIR:-}"

    if [[ -z "$lock_dir" ]]; then
        return 0
    fi

    if [[ "${TOPMEMO_BUILD_LOCK_OWNER_PID:-}" != "$$" ]]; then
        return 0
    fi

    rmdir "$lock_dir" 2>/dev/null || true
    unset TOPMEMO_BUILD_LOCK_DIR
    unset TOPMEMO_BUILD_LOCK_OWNER_PID
}
