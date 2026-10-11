package com.example.geotrack.feature.groups

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.geotrack.feature.auth.domain.entities.User
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
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put

// MARK: - Models

data class Group(
    val id: String,
    val name: String,
    val members: List<User>,
    val createdBy: String,
    val createdAt: String,
    val updatedAt: String
)

// Every API result includes sessionExpired.
data class GroupResult<T>(
    val statusCode: Int,
    val message: String,
    val data: T?,
    val sessionExpired: Boolean = false,
    val error: String? = null
)

// MARK: - UI State

data class GroupUiState(
    val isLoading: Boolean = false,
    val error: String? = null,
    val sessionExpired: Boolean = false
)

// MARK: - ViewModel

class GroupViewModel(
    private val networkClient: NetworkClient
) : ViewModel() {

    private val _uiState = MutableStateFlow(GroupUiState())
    val uiState: StateFlow<GroupUiState> = _uiState.asStateFlow()

    private fun log(message: String) {
        println("[GroupViewModel] $message")
    }

    // MARK: Fetch Groups

    suspend fun fetchGroups(
        accessToken: String
    ): GroupResult<List<Group>> {
        return executeRequest {
            val response = networkClient.request("/groups") {
                method = HttpMethod.Get
                header(HttpHeaders.Authorization, "Bearer $accessToken")
            }

            val body = response.bodyAsText()
            log("fetchGroups status: ${response.status.value}")
            log("fetchGroups body: $body")

            if (!response.status.isSuccess()) {
                return@executeRequest failure<List<Group>>(
                    statusCode = response.status.value,
                    body = body
                )
            }

            val root = Json.parseToJsonElement(body).jsonObject
            val groups = root.getValue("data")
                .jsonArray
                .map { parseGroup(it.jsonObject) }

            GroupResult(
                statusCode = root.getValue("status_code").jsonPrimitive.int,
                message = root.getValue("message").jsonPrimitive.content,
                data = groups
            )
        }
    }

    // MARK: Create Group

    suspend fun createGroup(
        name: String,
        accessToken: String
    ): GroupResult<Group> {
        return executeRequest {
            val requestBody = buildJsonObject {
                put("name", name)
            }.toString()

            val response = networkClient.request("/groups") {
                method = HttpMethod.Post
                header(HttpHeaders.Authorization, "Bearer $accessToken")
                contentType(ContentType.Application.Json)
                setBody(requestBody)
            }

            val body = response.bodyAsText()
            log("createGroup status: ${response.status.value}")
            log("createGroup body: $body")

            if (!response.status.isSuccess()) {
                return@executeRequest failure<Group>(
                    statusCode = response.status.value,
                    body = body
                )
            }

            val root = Json.parseToJsonElement(body).jsonObject

            GroupResult(
                statusCode = root.getValue("status_code").jsonPrimitive.int,
                message = root.getValue("message").jsonPrimitive.content,
                data = parseGroup(root.getValue("data").jsonObject)
            )
        }
    }

    // MARK: Fetch Single Group

    suspend fun fetchGroup(
        groupID: String,
        accessToken: String
    ): GroupResult<Group> {
        return executeRequest {
            val response = networkClient.request("/groups/$groupID") {
                method = HttpMethod.Get
                header(HttpHeaders.Authorization, "Bearer $accessToken")
            }

            val body = response.bodyAsText()
            log("fetchGroup status: ${response.status.value}")
            log("fetchGroup body: $body")

            if (!response.status.isSuccess()) {
                return@executeRequest failure<Group>(
                    statusCode = response.status.value,
                    body = body
                )
            }

            val root = Json.parseToJsonElement(body).jsonObject

            GroupResult(
                statusCode = root.getValue("status_code").jsonPrimitive.int,
                message = root.getValue("message").jsonPrimitive.content,
                data = parseGroup(root.getValue("data").jsonObject)
            )
        }
    }

    // MARK: Add Member

    suspend fun addMember(
        groupID: String,
        userID: String,
        accessToken: String
    ): GroupResult<Boolean> {
        return executeRequest {
            val requestBody = buildJsonObject {
                put("user_id", userID)
            }.toString()

            val response = networkClient.request("/groups/$groupID/members") {
                method = HttpMethod.Post
                header(HttpHeaders.Authorization, "Bearer $accessToken")
                contentType(ContentType.Application.Json)
                setBody(requestBody)
            }

            val body = response.bodyAsText()
            log("addMember status: ${response.status.value}")
            log("addMember body: $body")

            if (!response.status.isSuccess()) {
                return@executeRequest failure<Boolean>(
                    statusCode = response.status.value,
                    body = body
                )
            }

            val root = Json.parseToJsonElement(body).jsonObject

            GroupResult(
                statusCode = root.getValue("status_code").jsonPrimitive.int,
                message = root.getValue("message").jsonPrimitive.content,
                data = true
            )
        }
    }

    // MARK: Parse Group

    private fun parseGroup(json: JsonObject): Group {
        val members = json.getValue("members")
            .jsonArray
            .map { memberElement ->
                val member = memberElement.jsonObject

                User(
                    id = member.getValue("id").jsonPrimitive.content,
                    fullName = member.getValue("full_name").jsonPrimitive.content,
                    email = member.getValue("email").jsonPrimitive.content,
                    isOnline = member["is_online"]?.jsonPrimitive?.booleanOrNull ?: false,
                    createdAt = member.getValue("created_at").jsonPrimitive.content,
                    updatedAt = member.getValue("updated_at").jsonPrimitive.content
                )
            }

        return Group(
            id = json.getValue("id").jsonPrimitive.content,
            name = json.getValue("name").jsonPrimitive.content,
            members = members,
            createdBy = json.getValue("created_by").jsonPrimitive.content,
            createdAt = json.getValue("created_at").jsonPrimitive.content,
            updatedAt = json.getValue("updated_at").jsonPrimitive.content
        )
    }

    // MARK: Error Handling

    private fun <T> failure(
        statusCode: Int,
        body: String
    ): GroupResult<T> {
        val message = try {
            Json.parseToJsonElement(body)
                .jsonObject["message"]
                ?.jsonPrimitive
                ?.content
        } catch (_: Exception) {
            null
        } ?: "Request failed ($statusCode)"

        val expired = statusCode == HttpStatusCode.Unauthorized.value

        _uiState.value = GroupUiState(
            error = message,
            sessionExpired = expired
        )

        return GroupResult(
            statusCode = statusCode,
            message = message,
            data = null,
            sessionExpired = expired,
            error = message
        )
    }

    private suspend fun <T : Any> executeRequest(
        request: suspend () -> GroupResult<T>
    ): GroupResult<T> {
        _uiState.value = GroupUiState(isLoading = true)

        return try {
            request()
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            val message = e.message ?: "Something went wrong"

            log("Exception: ${e::class.simpleName}: $message")

            _uiState.value = GroupUiState(
                error = message,
                sessionExpired = false
            )

            GroupResult(
                statusCode = 0,
                message = message,
                data = null,
                sessionExpired = false,
                error = message
            )
        } finally {
            _uiState.value = _uiState.value.copy(isLoading = false)
        }
    }

    // MARK: Fetch Users Not In Group

    suspend fun fetchUsers(
        groupID: String,
        accessToken: String
    ): GroupResult<List<User>> {
        return executeRequest {
            val response = networkClient.request("/groups/$groupID/users") {
                method = HttpMethod.Get
                header(HttpHeaders.Authorization, "Bearer $accessToken")
            }

            val body = response.bodyAsText()
            log("fetchUsers status: ${response.status.value}")
            log("fetchUsers body: $body")

            if (!response.status.isSuccess()) {
                return@executeRequest failure<List<User>>(
                    statusCode = response.status.value,
                    body = body
                )
            }

            val root = Json.parseToJsonElement(body).jsonObject

            val users = root.getValue("data")
                .jsonArray
                .map { element ->
                    val user = element.jsonObject

                    User(
                        id = user.getValue("id").jsonPrimitive.content,
                        fullName = user.getValue("full_name").jsonPrimitive.content,
                        email = user.getValue("email").jsonPrimitive.content,
                        createdAt = user.getValue("created_at").jsonPrimitive.content,
                        updatedAt = user.getValue("updated_at").jsonPrimitive.content
                    )
                }

            GroupResult(
                statusCode = root.getValue("status_code").jsonPrimitive.int,
                message = root.getValue("message").jsonPrimitive.content,
                data = users
            )
        }
    }

    // MARK: Observe State

    fun observeState(onStateChanged: (GroupUiState) -> Unit) {
        viewModelScope.launch {
            uiState.collect { state ->
                onStateChanged(state)
            }
        }
    }
}