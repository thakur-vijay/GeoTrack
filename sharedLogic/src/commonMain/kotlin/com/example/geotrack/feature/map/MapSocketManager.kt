package com.example.geotrack.feature.map

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.doubleOrNull

class MapSocketManager(
    private val mapViewModel: MapViewModel
) {

    private val scope =
        CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private val _memberLocations =
        MutableStateFlow<Map<String, MapCoordinate>>(emptyMap())

    val memberLocations: StateFlow<Map<String, MapCoordinate>> =
        _memberLocations.asStateFlow()

    var onUserWentOutside: (userID: String, fullName: String) -> Unit =
        { _, _ -> }

    fun observeState(onChange: () -> Unit) {
        scope.launch {
            memberLocations
                .map { Unit }
                .collect {
                    onChange()
                }
        }
    }

    fun setMemberLocation(
        userID: String,
        coordinate: MapCoordinate
    ) {
        _memberLocations.value += userID to coordinate
    }

    fun removeMemberLocation(userID: String) {
        _memberLocations.value -= userID
    }

    fun clearMemberLocations() {
        _memberLocations.value = emptyMap()
    }

    fun handleSocketEvent(event: String) {
        val payload = runCatching {
            Json.parseToJsonElement(event).jsonObject
        }.getOrNull() ?: return

        val eventType =
            payload["type"]?.jsonPrimitive?.content ?: return

        val data = payload["data"]?.jsonObject ?: return

        when (eventType) {
            "location.updated" -> handleLocationUpdated(data)
            "user.disconnected" -> handleUserDisconnected(data)
            "user_went_outside" -> handleUserWentOutside(data)
        }
    }

    private fun handleLocationUpdated(payload: JsonObject) {
        val userID =
            payload["user_id"]?.jsonPrimitive?.content ?: return

        val latitude =
            payload["latitude"]?.jsonPrimitive?.doubleOrNull
                ?: payload["latitude"]?.jsonPrimitive?.content?.toDoubleOrNull()
                ?: return

        val longitude =
            payload["longitude"]?.jsonPrimitive?.doubleOrNull
                ?: payload["longitude"]?.jsonPrimitive?.content?.toDoubleOrNull()
                ?: return

        if (latitude !in -90.0..90.0 || longitude !in -180.0..180.0) {
            return
        }

        val selectedGroup = mapViewModel.selectedGroup.value ?: return

        if (selectedGroup.members.none { it.id == userID }) return

        setMemberLocation(
            userID = userID,
            coordinate = MapCoordinate(
                latitude = latitude,
                longitude = longitude
            )
        )
    }

    private fun handleUserDisconnected(payload: JsonObject) {
        val userID =
            payload["user_id"]?.jsonPrimitive?.content ?: return

        val groupID =
            payload["group_id"]?.jsonPrimitive?.content ?: return

        if (mapViewModel.selectedGroup.value?.id != groupID) return

        removeMemberLocation(userID)
    }

    private fun handleUserWentOutside(payload: JsonObject) {
        val user = payload["user"]?.jsonObject

        if (user == null) {
            println("❌ [MapSocketManager] Missing user in user_went_outside data: $payload")
            return
        }

        val userID = user["id"]?.jsonPrimitive?.content

        if (userID == null) {
            println("❌ [MapSocketManager] Missing user id: $user")
            return
        }

        val member = mapViewModel.selectedGroup.value
            ?.members
            ?.firstOrNull { it.id == userID }

        if (member == null) {
            println("❌ [MapSocketManager] User $userID not found in selected group's members")
            return
        }

        println("✅ [MapSocketManager] User went outside: ${member.fullName}")
        onUserWentOutside(userID, member.fullName)
    }
}