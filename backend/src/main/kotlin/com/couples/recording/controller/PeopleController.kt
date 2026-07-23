package com.couples.recording.controller

import com.couples.recording.controller.dto.SavePartnerRequest
import com.couples.recording.controller.dto.StateResponse
import com.couples.recording.controller.dto.UpdatePersonRequest
import com.couples.recording.controller.dto.UpdateSettingsRequest
import com.couples.recording.service.CatalogService
import com.couples.recording.service.StateService
import jakarta.validation.Valid
import org.springframework.web.bind.annotation.PatchMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api")
class PeopleController(
    private val catalog: CatalogService,
    private val stateService: StateService,
) {
    @PutMapping("/partner")
    fun savePartner(@Valid @RequestBody req: SavePartnerRequest): StateResponse {
        catalog.savePartner(req.name, req.color, req.unit, req.initials)
        return stateService.getState()
    }

    @PatchMapping("/people/{id}")
    fun updatePerson(@PathVariable id: String, @RequestBody req: UpdatePersonRequest): StateResponse {
        catalog.updatePerson(id, req.name, req.color, req.unit, req.initials, req.active)
        return stateService.getState()
    }

    @PatchMapping("/settings")
    fun updateSettings(@RequestBody req: UpdateSettingsRequest): StateResponse {
        catalog.updateSettings(
            req.coupleModeEnabled, req.defaultParticipants, req.defaultLoggingStyle,
            req.allowCopyPartnerValues, req.showPartnerHistory,
        )
        return stateService.getState()
    }

    @PostMapping("/settings/toggle-couple-mode")
    fun toggleCoupleMode(): StateResponse {
        catalog.toggleCoupleMode()
        return stateService.getState()
    }
}
