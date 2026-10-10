package com.example.geotrack.feature.users

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
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
data class UserResponse(
    val statusCode: Int,
    val message: String,
    val data: User
)

data class UsersUiState(
    val isLoading: Boolean = false,
    val error: String? = null
)

class UsersViewModel(
    private val networkClient: NetworkClient
) : ViewModel() {

    private val _uiState = MutableStateFlow(UsersUiState())
    val uiState: StateFlow<UsersUiState> = _uiState.asStateFlow()

    private fun log(message: String) {
        println("[UsersViewModel] $message")
    }

    suspend fun getUser(
        id: String,
        accessToken: String
    ): UserResponse? {
        log("getUser() started. User ID: $id")
        log("Access token available: ${accessToken.isNotBlank()}")

        _uiState.value = UsersUiState(isLoading = true)

        return try {
            log("Sending GET request to /users/$id")

            val response = networkClient.request("/users/$id") {
                method = HttpMethod.Get
                header(HttpHeaders.Authorization, "Bearer $accessToken")
            }

            val responseBody = response.bodyAsText()

            log("Response status: ${response.status.value}")
            log("Response body: $responseBody")

            if (response.status == HttpStatusCode.Unauthorized) {
                val message = "Session expired. Please login again."
                log("ERROR: Unauthorized (401)")

                _uiState.value = UsersUiState(error = message)
                return null
            }

            if (!response.status.isSuccess()) {
                val message = "Request failed: ${response.status.value}"
                log("ERROR: $message")
                _uiState.value = UsersUiState(error = message)
                return null
            }

            log("Parsing response JSON")

            val root = Json.parseToJsonElement(responseBody).jsonObject
            val userJson = root
                .getValue("data")
                .jsonObject

            val result = UserResponse(
                statusCode = root.getValue("status_code").jsonPrimitive.int,
                message = root.getValue("message").jsonPrimitive.content,
                data = User(
                    id = userJson.getValue("id").jsonPrimitive.content,
                    fullName = userJson.getValue("full_name").jsonPrimitive.content,
                    email = userJson.getValue("email").jsonPrimitive.content,
                    createdAt = userJson.getValue("created_at").jsonPrimitive.content,
                    updatedAt = userJson.getValue("updated_at").jsonPrimitive.content
                )
            )

            log("User parsed successfully: ${result.data.id}")
            _uiState.value = UsersUiState()

            result

        } catch (e: CancellationException) {
            log("Request cancelled")
            throw e
        } catch (e: Exception) {
            val message = e.message ?: "Request failed"

            log("EXCEPTION: ${e::class.simpleName}: $message")
            log("Exception details: ${e.stackTraceToString()}")

            _uiState.value = UsersUiState(error = message)
            null
        } finally {
            _uiState.value = _uiState.value.copy(isLoading = false)
            log("getUser() finished")
        }
    }

    fun observeState(onStateChanged: (UsersUiState) -> Unit) {
        viewModelScope.launch {
            uiState.collect { state ->
                onStateChanged(state)
            }
        }
    }
}