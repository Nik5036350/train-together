package com.couples.recording.controller

import com.couples.recording.controller.dto.ActiveRowRequest
import com.couples.recording.controller.dto.LoggingModeRequest
import com.couples.recording.controller.dto.PersonStatusRequest
import com.couples.recording.controller.dto.SkipExerciseRequest
import com.couples.recording.controller.dto.SkipTurnRequest
import com.couples.recording.controller.dto.StateResponse
import com.couples.recording.controller.dto.SubstituteRequest
import com.couples.recording.service.SessionService
import com.couples.recording.service.StateService
import jakarta.validation.Valid
import org.springframework.web.bind.annotation.PatchMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/session-exercises")
class SessionExerciseController(
    private val sessionService: SessionService,
    private val stateService: StateService,
) {
    @PostMapping("/{id}/skip-turn")
    fun skipTurn(@PathVariable id: String, @Valid @RequestBody req: SkipTurnRequest): StateResponse {
        sessionService.skipTurn(id, req.personId)
        return stateService.getState()
    }

    @PostMapping("/{id}/skip")
    fun skipExercise(@PathVariable id: String, @Valid @RequestBody req: SkipExerciseRequest): StateResponse {
        sessionService.skipExercise(id, req.personId, req.reason)
        return stateService.getState()
    }

    @PatchMapping("/{id}/substitute")
    fun substitute(@PathVariable id: String, @Valid @RequestBody req: SubstituteRequest): StateResponse {
        sessionService.substituteExercise(id, req.personId, req.substituteExerciseId)
        return stateService.getState()
    }

    @PatchMapping("/{id}/person-status")
    fun personStatus(@PathVariable id: String, @Valid @RequestBody req: PersonStatusRequest): StateResponse {
        sessionService.setPersonStatus(id, req.personId, req.status)
        return stateService.getState()
    }

    @PatchMapping("/{id}/logging-mode")
    fun loggingMode(@PathVariable id: String, @Valid @RequestBody req: LoggingModeRequest): StateResponse {
        sessionService.setLoggingMode(id, req.mode)
        return stateService.getState()
    }

    @PatchMapping("/{id}/active-row")
    fun activeRow(@PathVariable id: String, @Valid @RequestBody req: ActiveRowRequest): StateResponse {
        sessionService.setActiveRow(id, req.personId)
        return stateService.getState()
    }
}
