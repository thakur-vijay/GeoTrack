package com.example.geotrack.feature.network

import com.example.geotrack.feature.realtime.SocketManager
import io.ktor.client.HttpClient
import io.ktor.client.plugins.websocket.WebSockets
import io.ktor.client.request.HttpRequestBuilder
import io.ktor.client.request.request
import io.ktor.client.statement.HttpResponse

class NetworkClientImpl(
    private val baseURL: String
) : NetworkClient {

    private val client = HttpClient {
        install(WebSockets)
    }

    val socketManager: SocketManager by lazy {
        SocketManager(
            httpClient = client,
            socketURL = baseURL
                .replaceFirst("https://", "wss://")
                .replaceFirst("http://", "ws://")
                .trimEnd('/') + "/ws"
        )
    }

    override suspend fun request(
        endpoint: String,
        builder: HttpRequestBuilder.() -> Unit
    ): HttpResponse {
        return client.request("$baseURL$endpoint", builder)
    }
}