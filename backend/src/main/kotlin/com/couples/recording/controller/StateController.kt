package com.couples.recording.controller

import com.couples.recording.controller.dto.StateResponse
import com.couples.recording.service.AdminService
import com.couples.recording.service.StateService
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api")
class StateController(
    private val stateService: StateService,
    private val adminService: AdminService,
) {
    @GetMapping("/state")
    fun getState(): StateResponse = stateService.getState()

    // Full import / replace-all (the old HYDRATE from a JSON backup).
    @PutMapping("/state")
    fun importState(@RequestBody state: StateResponse): StateResponse {
        adminService.importState(state)
        return stateService.getState()
    }
}
