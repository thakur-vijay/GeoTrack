package com.example.geotrack.feature.regions

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.geotrack.feature.network.NetworkClient
import io.ktor.client.request.*
import io.ktor.client.statement.*
import io.ktor.http.*
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.double
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

data class SafeRegion(
    val id: String,
    val userID: String,
    val groupID: String,
    val name: String,
    val latitude: Double,
    val longitude: Double,
    val radiusMeters: Int,
    val createdAt: String,
    val updatedAt: String
)

data class SafeRegionResponse(
    val statusCode: Int,
    val message: String,
    val data: SafeRegion
)

data class SafeRegionsResponse(
    val statusCode: Int,
    val message: String,
    val data: List<SafeRegion>
)

data class SafeRegionsUiState(
    val isLoading: Boolean = false,
    val error: String? = null,
    val isSessionExpired: Boolean = false
)

class SafeRegionViewModel(
    private val networkClient: NetworkClient
) : ViewModel() {

    private val _uiState = MutableStateFlow(SafeRegionsUiState())
    val uiState: StateFlow<SafeRegionsUiState> = _uiState.asStateFlow()

    private fun log(message: String) {
        println("[SafeRegionViewModel] $message")
    }

    // MARK: - Create Safe Region

    suspend fun createSafeRegion(
        groupID: String,
        name: String,
        latitude: Double,
        longitude: Double,
        radiusMeters: Int,
        accessToken: String
    ): SafeRegionResponse? {
        log("createSafeRegion() started")
        return executeRequest("createSafeRegion") {
            val response = networkClient.request("/safe-regions") {
                method = HttpMethod.Post
                header(HttpHeaders.Authorization, "Bearer $accessToken")
                contentType(ContentType.Application.Json)

                setBody(
                    """
                    {
                        "group_id": ${nameJson(groupID)},
                        "name": ${nameJson(name)},
                        "latitude": $latitude,
                        "longitude": $longitude,
                        "radius_meters": $radiusMeters
                    }
                    """.trimIndent()
                )
            }

            val body = response.bodyAsText()
            log("Create response: ${response.status.value}")

            if (!handleErrorStatus(response.status, body)) {
                return@executeRequest null
            }

            val root = Json.parseToJsonElement(body).jsonObject
            val data = root.getValue("data").jsonObject

            SafeRegionResponse(
                statusCode = root.getValue("status_code").jsonPrimitive.int,
                message = root.getValue("message").jsonPrimitive.content,
                data = parseSafeRegion(data)
            )
        }
    }

    // MARK: - Fetch Safe Region By ID

    suspend fun fetchSafeRegion(
        id: String,
        accessToken: String
    ): SafeRegionResponse? {
        log("fetchSafeRegion() started. ID: $id")

        return executeRequest("fetchSafeRegion") {
            val response = networkClient.request("/safe-regions/$id") {
                method = HttpMethod.Get
                header(HttpHeaders.Authorization, "Bearer $accessToken")
            }

            val body = response.bodyAsText()
            log("Fetch by ID response: ${response.status.value}")

            if (!handleErrorStatus(response.status, body)) {
                return@executeRequest null
            }

            val root = Json.parseToJsonElement(body).jsonObject

            SafeRegionResponse(
                statusCode = root.getValue("status_code").jsonPrimitive.int,
                message = root.getValue("message").jsonPrimitive.content,
                data = parseSafeRegion(root.getValue("data").jsonObject)
            )
        }
    }

    // MARK: - Update Safe Region

    suspend fun updateSafeRegion(
        id: String,
        accessToken: String,
        groupID: String? = null,
        name: String? = null,
        latitude: Double? = null,
        longitude: Double? = null,
        radiusMeters: Int? = null
    ): SafeRegionResponse? {
        log("updateSafeRegion() started. ID: $id")

        return executeRequest("updateSafeRegion") {
            val fields = mutableListOf<String>()

            groupID?.let {
                fields.add("\"group_id\": ${nameJson(it)}")
            }
            name?.let {
                fields.add("\"name\": ${nameJson(it)}")
            }
            latitude?.let {
                fields.add("\"latitude\": $it")
            }
            longitude?.let {
                fields.add("\"longitude\": $it")
            }
            radiusMeters?.let {
                fields.add("\"radius_meters\": $it")
            }

            require(fields.isNotEmpty()) {
                "At least one field must be provided for update."
            }

            val requestBody = "{${fields.joinToString(",")}}"

            val response = networkClient.request("/safe-regions/$id") {
                method = HttpMethod.Put
                header(HttpHeaders.Authorization, "Bearer $accessToken")
                contentType(ContentType.Application.Json)
                setBody(requestBody)
            }

            val body = response.bodyAsText()
            log("Update response: ${response.status.value}")

            if (!handleErrorStatus(response.status, body)) {
                return@executeRequest null
            }

            val root = Json.parseToJsonElement(body).jsonObject

            SafeRegionResponse(
                statusCode = root.getValue("status_code").jsonPrimitive.int,
                message = root.getValue("message").jsonPrimitive.content,
                data = parseSafeRegion(root.getValue("data").jsonObject)
            )
        }
    }

    suspend fun fetchSafeRegionsByGroupID(
        groupID: String,
        accessToken: String
    ): SafeRegionsResponse? {
        log("fetchSafeRegionsByGroupID() started. Group ID: $groupID")

        return executeRequest("fetchSafeRegionsByGroupID") {
            val response = networkClient.request("/groups/$groupID/safe-regions") {
                method = HttpMethod.Get
                header(HttpHeaders.Authorization, "Bearer $accessToken")
            }

            val body = response.bodyAsText()
            log("Response status: ${response.status.value}")

            if (!handleErrorStatus(response.status, body)) {
                return@executeRequest null
            }

            val root = Json.parseToJsonElement(body).jsonObject
            val regionsJson = root.getValue("data").jsonArray

            SafeRegionsResponse(
                statusCode = root.getValue("status_code").jsonPrimitive.int,
                message = root.getValue("message").jsonPrimitive.content,
                data = regionsJson.map { item ->
                    parseSafeRegion(item.jsonObject)
                }
            )
        }
    }

    // MARK: - Delete Safe Region

    suspend fun deleteSafeRegion(
        id: String,
        accessToken: String
    ): Boolean {
        log("deleteSafeRegion() started. ID: $id")

        return executeRequest("deleteSafeRegion") {
            val response = networkClient.request("/safe-regions/$id") {
                method = HttpMethod.Delete
                header(HttpHeaders.Authorization, "Bearer $accessToken")
            }

            val body = response.bodyAsText()
            log("Delete response: ${response.status.value}")

            if (!handleErrorStatus(response.status, body)) {
                return@executeRequest false
            }

            true
        } ?: false
    }

    // MARK: - Shared Request Handling

    private suspend fun <T> executeRequest(
        operation: String,
        request: suspend () -> T
    ): T? {
        log("$operation started")
        _uiState.value = SafeRegionsUiState(isLoading = true)

        return try {
            request().also {
                _uiState.value = SafeRegionsUiState()
            }
        } catch (e: CancellationException) {
            log("$operation cancelled")
            throw e
        } catch (e: Exception) {
            val message = e.message ?: "Request failed"
            log("$operation exception: ${e::class.simpleName}: $message")
            log("Exception details: ${e.stackTraceToString()}")

            _uiState.value = _uiState.value.copy(error = message)
            null
        } finally {
            _uiState.value = _uiState.value.copy(isLoading = false)
            log("$operation finished")
        }
    }

    // MARK: - HTTP Error Handling

    private fun handleErrorStatus(
        status: HttpStatusCode,
        body: String
    ): Boolean {
        if (status.isSuccess()) return true

        val isSessionExpired = status == HttpStatusCode.Unauthorized
        val message = if (isSessionExpired) {
            "Session expired. Please login again."
        } else {
            extractErrorMessage(body)
                ?: "Request failed: ${status.value}"
        }

        log("ERROR ${status.value}: $message")

        _uiState.value = SafeRegionsUiState(
            error = message,
            isSessionExpired = isSessionExpired
        )

        return false
    }

    private fun extractErrorMessage(body: String): String? {
        return try {
            val root = Json.parseToJsonElement(body).jsonObject
            root["message"]?.jsonPrimitive?.content
                ?: root["error"]?.jsonPrimitive?.content
        } catch (_: Exception) {
            null
        }
    }

    // MARK: - JSON Parsing

    private fun parseSafeRegion(
        json: kotlinx.serialization.json.JsonObject
    ): SafeRegion {
        return SafeRegion(
            id = json.getValue("id").jsonPrimitive.content,
            userID = json.getValue("user_id").jsonPrimitive.content,
            groupID = json.getValue("group_id").jsonPrimitive.content,
            name = json.getValue("name").jsonPrimitive.content,
            latitude = json.getValue("latitude").jsonPrimitive.double,
            longitude = json.getValue("longitude").jsonPrimitive.double,
            radiusMeters = json.getValue("radius_meters").jsonPrimitive.int,
            createdAt = json.getValue("created_at").jsonPrimitive.content,
            updatedAt = json.getValue("updated_at").jsonPrimitive.content
        )
    }

    private fun nameJson(value: String): String {
        return kotlinx.serialization.json.JsonPrimitive(value).toString()
    }

    fun observeState(
        onStateChanged: (SafeRegionsUiState) -> Unit
    ) {
        viewModelScope.launch {
            uiState.collect { state ->
                onStateChanged(state)
            }
        }
    }
}