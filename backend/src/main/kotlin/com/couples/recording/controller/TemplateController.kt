package com.couples.recording.controller

import com.couples.recording.controller.dto.SaveTemplateRequest
import com.couples.recording.controller.dto.SetAssignmentRequest
import com.couples.recording.controller.dto.StateResponse
import com.couples.recording.service.CatalogService
import com.couples.recording.service.StateService
import jakarta.validation.Valid
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.PatchMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/templates")
class TemplateController(
    private val catalog: CatalogService,
    private val stateService: StateService,
) {
    @PostMapping
    fun create(@Valid @RequestBody req: SaveTemplateRequest): StateResponse {
        catalog.saveTemplate(req.id, req.name, req.defaultMode, req.exercises)
        return stateService.getState()
    }

    @PutMapping("/{id}")
    fun update(@PathVariable id: String, @Valid @RequestBody req: SaveTemplateRequest): StateResponse {
        catalog.saveTemplate(id, req.name, req.defaultMode, req.exercises)
        return stateService.getState()
    }

    @DeleteMapping("/{id}")
    fun delete(@PathVariable id: String): StateResponse {
        catalog.deleteTemplate(id)
        return stateService.getState()
    }

    @PatchMapping("/{id}/exercises/{exerciseId}/assignment")
    fun setAssignment(
        @PathVariable id: String,
        @PathVariable exerciseId: String,
        @Valid @RequestBody req: SetAssignmentRequest,
    ): StateResponse {
        catalog.setAssignment(id, exerciseId, req.assignment)
        return stateService.getState()
    }
}
