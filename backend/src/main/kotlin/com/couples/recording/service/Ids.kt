package com.couples.recording.service

import java.util.concurrent.atomic.AtomicLong

// Mirrors the client's src/lib/ids.js: `${prefix}_${base36 time}_${base36 counter}`.
// Keeps ids short and readable, and keeps the JSON shape identical to the old app.
object Ids {
    private val counter = AtomicLong(0)

    fun uid(prefix: String = "id"): String {
        val n = counter.incrementAndGet()
        val time = System.currentTimeMillis().toString(36)
        return "${prefix}_${time}_${n.toString(36)}"
    }
}
