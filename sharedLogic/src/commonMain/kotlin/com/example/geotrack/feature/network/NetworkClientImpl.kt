package com.example.geotrack.feature.network

import io.ktor.client.HttpClient
import io.ktor.client.request.HttpRequestBuilder
import io.ktor.client.request.request
import io.ktor.client.statement.HttpResponse

class NetworkClientImpl(
    private val baseURL: String
) : NetworkClient {

    private val client = HttpClient()

    override suspend fun request(
        endpoint: String,
        builder: HttpRequestBuilder.() -> Unit
    ): HttpResponse {
        return client.request("$baseURL$endpoint", builder)
    }
}