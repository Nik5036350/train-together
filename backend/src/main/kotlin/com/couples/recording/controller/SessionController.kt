package com.couples.recording.controller

import com.couples.recording.controller.dto.AddSessionExerciseRequest
import com.couples.recording.controller.dto.EditSetRequest
import com.couples.recording.controller.dto.LogSetRequest
import com.couples.recording.controller.dto.ReassignSetRequest
import com.couples.recording.controller.dto.StartSessionRequest
import com.couples.recording.controller.dto.StateResponse
import com.couples.recording.service.SessionService
import com.couples.recording.service.StateService
import jakarta.validation.Valid
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.PatchMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/sessions")
class SessionController(
    private val sessionService: SessionService,
    private val stateService: StateService,
) {
    @PostMapping
    fun start(@Valid @RequestBody req: StartSessionRequest): StateResponse {
        sessionService.startSession(req.templateId, req.participantIds, req.loggingStyle)
        return stateService.getState()
    }

    @PostMapping("/{id}/finish")
    fun finish(@PathVariable id: String): StateResponse {
        sessionService.finishSession(id)
        return stateService.getState()
    }

    @PostMapping("/{id}/sets")
    fun logSet(@PathVariable id: String, @Valid @RequestBody req: LogSetRequest): StateResponse {
        sessionService.logSet(id, req.sessionExerciseId, req.personId, req.values, req.setType)
        return stateService.getState()
    }

    @PostMapping("/{id}/sets/{setId}/undo")
    fun undo(@PathVariable id: String, @PathVariable setId: String): StateResponse {
        sessionService.undoSet(id, setId)
        return stateService.getState()
    }

    @PatchMapping("/{id}/sets/{setId}")
    fun editSet(@PathVariable id: String, @PathVariable setId: String, @RequestBody req: EditSetRequest): StateResponse {
        sessionService.editSet(setId, req.values)
        return stateService.getState()
    }

    @DeleteMapping("/{id}/sets/{setId}")
    fun deleteSet(@PathVariable id: String, @PathVariable setId: String): StateResponse {
        sessionService.deleteSet(id, setId)
        return stateService.getState()
    }

    @PatchMapping("/{id}/sets/{setId}/reassign")
    fun reassignSet(
        @PathVariable id: String,
        @PathVariable setId: String,
        @Valid @RequestBody req: ReassignSetRequest,
    ): StateResponse {
        sessionService.reassignSet(setId, req.toPersonId)
        return stateService.getState()
    }

    @PostMapping("/{id}/exercises")
    fun addExercise(@PathVariable id: String, @Valid @RequestBody req: AddSessionExerciseRequest): StateResponse {
        sessionService.addSessionExercise(id, req.exerciseId, req.assignment)
        return stateService.getState()
    }
}
