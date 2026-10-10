package com.example.geotrack.feature.network

import io.ktor.client.request.HttpRequestBuilder
import io.ktor.client.statement.HttpResponse

interface NetworkClient {
    suspend fun request(
        endpoint: String,
        builder: HttpRequestBuilder.() -> Unit = {}
    ): HttpResponse
}