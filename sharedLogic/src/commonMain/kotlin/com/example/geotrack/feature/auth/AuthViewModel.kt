package com.example.geotrack.feature.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.geotrack.feature.auth.domain.entities.SignupData
import com.example.geotrack.feature.auth.domain.entities.SignupResponse
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
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.int
import kotlinx.serialization.json.put
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

data class AuthUiState(
    val isLoading: Boolean = false,
    val error: String? = null
)

data class LogoutResponse(
    val statusCode: Int,
    val message: String
)

class AuthViewModel(
    private val networkClient: NetworkClient
) : ViewModel() {

    private val _uiState = MutableStateFlow(AuthUiState())
    val uiState: StateFlow<AuthUiState> = _uiState.asStateFlow()

    suspend fun signUp(
        name: String,
        email: String,
        password: String
    ): SignupResponse? {
        return executeAuthRequest(
            endpoint = "/auth/signup",
            name = name,
            email = email,
            password = password
        )
    }

    suspend fun login(
        email: String,
        password: String
    ): SignupResponse? {
        return executeAuthRequest(
            endpoint = "/auth/login",
            email = email,
            password = password
        )
    }

    suspend fun logout(accessToken: String, groupId: String): Boolean {
        return try {
            val response = networkClient.request("/auth/logout?group_id=$groupId") {
                method = HttpMethod.Post
                header(HttpHeaders.Authorization, "Bearer $accessToken")
            }

            if (!response.status.isSuccess()) {
                _uiState.value = AuthUiState(
                    error = "Logout failed (${response.status.value})"
                )
                false
            } else {
                _uiState.value = AuthUiState()
                true
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            _uiState.value = AuthUiState(
                error = e.message ?: "Logout failed"
            )
            false
        }
    }
    private suspend fun executeAuthRequest(
        endpoint: String,
        email: String,
        password: String,
        name: String? = null
    ): SignupResponse? {
        _uiState.value = AuthUiState(isLoading = true)

        return try {
            val requestBody = buildJsonObject {
                if (name != null) put("full_name", name)
                put("email", email)
                put("password", password)
            }.toString()

            val response = networkClient.request(endpoint = endpoint) {
                method = HttpMethod.Post
                contentType(ContentType.Application.Json)
                setBody(requestBody)
            }

            val responseBody = response.bodyAsText()

            if (!response.status.isSuccess()) {
                val message = try {
                    Json.parseToJsonElement(responseBody)
                        .jsonObject["message"]
                        ?.jsonPrimitive
                        ?.content
                } catch (_: Exception) {
                    null
                }

                _uiState.value = AuthUiState(
                    error = message ?: "Request failed (${response.status.value})"
                )
                return null
            }

            val root = Json.parseToJsonElement(responseBody).jsonObject
            val data = root.getValue("data").jsonObject
            val userJson = data.getValue("user").jsonObject

            val user = User(
                id = userJson.getValue("id").jsonPrimitive.content,
                fullName = userJson.getValue("full_name").jsonPrimitive.content,
                email = userJson.getValue("email").jsonPrimitive.content,
                createdAt = userJson.getValue("created_at").jsonPrimitive.content,
                updatedAt = userJson.getValue("updated_at").jsonPrimitive.content
            )

            val result = SignupResponse(
                statusCode = root.getValue("status_code").jsonPrimitive.int,
                message = root.getValue("message").jsonPrimitive.content,
                data = SignupData(
                    user = user,
                    accessToken = data.getValue("access_token").jsonPrimitive.content,
                    refreshToken = data.getValue("refresh_token").jsonPrimitive.content
                )
            )

            _uiState.value = AuthUiState()
            result

        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            _uiState.value = AuthUiState(
                error = e.message ?: "Authentication failed. Please try again."
            )
            null
        } finally {
            _uiState.value = _uiState.value.copy(isLoading = false)
        }
    }

    fun observeState(onStateChanged: (AuthUiState) -> Unit) {
        viewModelScope.launch {
            uiState.collect { state ->
                onStateChanged(state)
            }
        }
    }
}