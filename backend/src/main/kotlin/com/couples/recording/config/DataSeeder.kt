package com.couples.recording.config

import com.couples.recording.service.SeedService
import org.springframework.boot.CommandLineRunner
import org.springframework.stereotype.Component

// Seeds the demo data on first boot (empty DB), mirroring the frontend's seed.js.
@Component
class DataSeeder(private val seedService: SeedService) : CommandLineRunner {
    override fun run(vararg args: String?) {
        seedService.seedIfEmpty()
    }
}
