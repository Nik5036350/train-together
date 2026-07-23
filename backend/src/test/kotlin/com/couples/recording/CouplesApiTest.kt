package com.couples.recording

import com.couples.recording.controller.dto.StateResponse
import com.couples.recording.service.SeedService
import com.fasterxml.jackson.databind.ObjectMapper
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

@SpringBootTest
@AutoConfigureMockMvc
class CouplesApiTest(
    @Autowired val mockMvc: MockMvc,
    @Autowired val mapper: ObjectMapper,
    @Autowired val seedService: SeedService,
) {
    @BeforeEach
    fun reset() = seedService.resetToSeed()

    private fun stateAfter(json: String): StateResponse = mapper.readValue(json, StateResponse::class.java)

    @Test
    fun `getState returns seeded aggregate shape`() {
        mockMvc.perform(get("/api/state"))
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.people.length()").value(2))
            .andExpect(jsonPath("$.exercises.length()").value(8))
            .andExpect(jsonPath("$.templates.t_push.name").value("Push Day"))
            .andExpect(jsonPath("$.history.length()").value(1))
            .andExpect(jsonPath("$.history[0].sets.length()").value(24))
            .andExpect(jsonPath("$.session").doesNotExist())
    }

    @Test
    fun `logging a set switches the active row and increments setIndex`() {
        val started = mockMvc.perform(
            post("/api/sessions").contentType(MediaType.APPLICATION_JSON).content(
                """{"templateId":"t_push","participantIds":["p_alex","p_maria"],"loggingStyle":"alternate"}""",
            ),
        ).andExpect(status().isOk).andReturn().response.contentAsString
        val state = stateAfter(started)
        val session = state.session!!
        val se = session.exercises.first()
        assertEquals("p_alex", se.activePersonId)

        // Alex logs -> active flips to Maria, Alex's set is index 0.
        val afterAlex = stateAfter(
            mockMvc.perform(
                post("/api/sessions/${session.id}/sets").contentType(MediaType.APPLICATION_JSON).content(
                    """{"sessionExerciseId":"${se.id}","personId":"p_alex","values":{"weight":80,"reps":8}}""",
                ),
            ).andExpect(status().isOk).andReturn().response.contentAsString,
        )
        val se1 = afterAlex.session!!.exercises.first { it.id == se.id }
        assertEquals("p_maria", se1.activePersonId)
        assertEquals("logged", se1.perPerson["p_alex"]!!.status)
        val alexSets = afterAlex.session!!.sets.filter { it.personId == "p_alex" }
        assertEquals(1, alexSets.size)
        assertEquals(0, alexSets.first().setIndex)
        // Rest timer started for Alex using his 150s bench profile override.
        assertEquals(150, afterAlex.session!!.timers["p_alex"]!!.durationSeconds)

        // Second Alex set gets index 1.
        val afterSecond = stateAfter(
            mockMvc.perform(
                post("/api/sessions/${session.id}/sets").contentType(MediaType.APPLICATION_JSON).content(
                    """{"sessionExerciseId":"${se.id}","personId":"p_alex","values":{"weight":80,"reps":7}}""",
                ),
            ).andExpect(status().isOk).andReturn().response.contentAsString,
        )
        val alexIdx = afterSecond.session!!.sets.filter { it.personId == "p_alex" }.map { it.setIndex }.sorted()
        assertEquals(listOf(0, 1), alexIdx)
    }

    @Test
    fun `deleting a set renumbers remaining sets contiguously`() {
        val started = stateAfter(
            mockMvc.perform(
                post("/api/sessions").contentType(MediaType.APPLICATION_JSON).content(
                    """{"templateId":"t_push","participantIds":["p_alex","p_maria"],"loggingStyle":"independent"}""",
                ),
            ).andReturn().response.contentAsString,
        )
        val session = started.session!!
        val se = session.exercises.first()
        repeat(3) { i ->
            mockMvc.perform(
                post("/api/sessions/${session.id}/sets").contentType(MediaType.APPLICATION_JSON).content(
                    """{"sessionExerciseId":"${se.id}","personId":"p_alex","values":{"weight":${80 + i},"reps":8}}""",
                ),
            ).andExpect(status().isOk)
        }
        var state = stateAfter(mockMvc.perform(get("/api/state")).andReturn().response.contentAsString)
        val middle = state.session!!.sets.first { it.personId == "p_alex" && it.setIndex == 1 }

        state = stateAfter(
            mockMvc.perform(delete("/api/sessions/${session.id}/sets/${middle.id}"))
                .andExpect(status().isOk).andReturn().response.contentAsString,
        )
        val idx = state.session!!.sets.filter { it.personId == "p_alex" }.map { it.setIndex }.sorted()
        assertEquals(listOf(0, 1), idx)
    }

    @Test
    fun `finishing a session moves it into history`() {
        val started = stateAfter(
            mockMvc.perform(
                post("/api/sessions").contentType(MediaType.APPLICATION_JSON).content(
                    """{"templateId":"t_push","participantIds":["p_alex","p_maria"]}""",
                ),
            ).andReturn().response.contentAsString,
        )
        val id = started.session!!.id
        val finished = stateAfter(
            mockMvc.perform(post("/api/sessions/$id/finish"))
                .andExpect(status().isOk).andReturn().response.contentAsString,
        )
        assertNull(finished.session)
        assertEquals(2, finished.history.size)
        val newest = finished.history.first { it.id == id }
        assertEquals("finished", newest.status)
        assertTrue(newest.endTime != null)
    }
}
