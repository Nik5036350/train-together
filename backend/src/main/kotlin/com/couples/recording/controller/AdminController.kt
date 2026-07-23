package com.couples.recording.controller

import com.couples.recording.controller.dto.StateResponse
import com.couples.recording.service.AdminService
import com.couples.recording.service.StateService
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/admin")
class AdminController(
    private val adminService: AdminService,
    private val stateService: StateService,
) {
    @PostMapping("/reset-demo")
    fun resetDemo(): StateResponse {
        adminService.resetDemo()
        return stateService.getState()
    }

    @PostMapping("/restore-demo-routine")
    fun restoreDemoRoutine(): StateResponse {
        adminService.restoreDemoRoutine()
        return stateService.getState()
    }
}
