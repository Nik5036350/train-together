package com.couples.recording.controller

import com.couples.recording.controller.dto.SaveExerciseRequest
import com.couples.recording.controller.dto.StateResponse
import com.couples.recording.service.CatalogService
import com.couples.recording.service.StateService
import jakarta.validation.Valid
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/exercises")
class ExerciseController(
    private val catalog: CatalogService,
    private val stateService: StateService,
) {
    @PostMapping
    fun create(@Valid @RequestBody req: SaveExerciseRequest): StateResponse {
        catalog.saveExercise(req.id, req.name, req.category, req.equipment, req.tracks, req.defaultRestSeconds, req.profiles)
        return stateService.getState()
    }

    @PutMapping("/{id}")
    fun update(@PathVariable id: String, @Valid @RequestBody req: SaveExerciseRequest): StateResponse {
        catalog.saveExercise(id, req.name, req.category, req.equipment, req.tracks, req.defaultRestSeconds, req.profiles)
        return stateService.getState()
    }

    @DeleteMapping("/{id}")
    fun delete(@PathVariable id: String): StateResponse {
        catalog.deleteExercise(id)
        return stateService.getState()
    }
}
