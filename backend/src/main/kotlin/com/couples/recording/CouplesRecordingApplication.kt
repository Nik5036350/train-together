package com.couples.recording

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication
import java.io.File

@SpringBootApplication
class CouplesRecordingApplication

fun main(args: Array<String>) {
    // SQLite won't create missing parent directories for the DB file, so ensure
    // the data directory exists before the datasource initializes.
    File("data").mkdirs()
    runApplication<CouplesRecordingApplication>(*args)
}
