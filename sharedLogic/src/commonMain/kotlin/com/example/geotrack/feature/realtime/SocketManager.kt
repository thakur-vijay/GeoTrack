package com.example.geotrack.feature.realtime

import io.ktor.client.HttpClient
import io.ktor.client.plugins.websocket.webSocketSession
import io.ktor.http.HttpHeaders
import io.ktor.websocket.CloseReason
import io.ktor.websocket.Frame
import io.ktor.websocket.WebSocketSession
import io.ktor.websocket.close
import io.ktor.websocket.readText
import io.ktor.websocket.send
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class SocketManager(
    private val httpClient: HttpClient,
    private val socketURL: String
) {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val connectionMutex = Mutex()
    private val sendMutex = Mutex()

    private var session: WebSocketSession? = null
    private var receiveJob: Job? = null

    private val _isConnected = MutableStateFlow(false)
    val isConnected: StateFlow<Boolean> = _isConnected.asStateFlow()

    private val _receivedEvents = MutableSharedFlow<String>(
        extraBufferCapacity = 64
    )
    val receivedEvents: SharedFlow<String> = _receivedEvents.asSharedFlow()

    private val _connectionErrors = MutableSharedFlow<String>(
        extraBufferCapacity = 16
    )
    val connectionErrors: SharedFlow<String> = _connectionErrors.asSharedFlow()

    suspend fun connect(accessToken: String) {
        println("🔌 [SocketManager] Connecting to: $socketURL")
        println("🔐 [SocketManager] Access token available: ${accessToken.isNotEmpty()}")

        connectionMutex.withLock {
            if (_isConnected.value && session != null) {
                println("ℹ️ [SocketManager] Already connected")
                return
            }

            try {
                println("⏳ [SocketManager] Opening WebSocket connection...")

                val newSession = httpClient.webSocketSession(
                    urlString = socketURL
                ) {
                    headers.append(
                        HttpHeaders.Authorization,
                        "Bearer $accessToken"
                    )
                }

                session = newSession
                _isConnected.value = true

                println("✅ [SocketManager] WebSocket connected successfully")

                receiveJob?.cancel()
                receiveJob = scope.launch {
                    receiveEvents(newSession)
                }
            } catch (exception: CancellationException) {
                println("⚠️ [SocketManager] Connection cancelled")
                throw exception
            } catch (exception: Exception) {
                _isConnected.value = false
                session = null

                println("❌ [SocketManager] Connection failed: ${exception.message}")
                exception.printStackTrace()

                _connectionErrors.emit(
                    exception.message ?: "WebSocket connection failed"
                )
            }
        }
    }

    private suspend fun receiveEvents(webSocketSession: WebSocketSession) {
        println("👂 [SocketManager] Listening for incoming events...")

        try {
            for (frame in webSocketSession.incoming) {
                when (frame) {
                    is Frame.Text -> {
                        val event = frame.readText()
                        println("📩 [SocketManager] Event received: $event")
                        _receivedEvents.emit(event)
                    }

                    is Frame.Close -> {
                        println("🔌 [SocketManager] Server closed connection")
                        break
                    }

                    else -> {
                        println("ℹ️ [SocketManager] Non-text frame received: ${frame.frameType}")
                    }
                }
            }

            println("ℹ️ [SocketManager] Receive loop ended")
        } catch (exception: CancellationException) {
            println("⚠️ [SocketManager] Receive loop cancelled")
            throw exception
        } catch (exception: Exception) {
            println("❌ [SocketManager] Receive error: ${exception.message}")
            exception.printStackTrace()

            _connectionErrors.emit(
                exception.message ?: "WebSocket receive failed"
            )
        } finally {
            connectionMutex.withLock {
                if (session === webSocketSession) {
                    session = null
                    _isConnected.value = false
                    println("🔴 [SocketManager] Connection marked as disconnected")
                }
            }
        }
    }

    suspend fun sendEvent(event: String): Boolean {
        println("📤 [SocketManager] Sending event: $event")

        return sendMutex.withLock {
            val currentSession = session

            if (currentSession == null || !_isConnected.value) {
                println("❌ [SocketManager] Send failed: Not connected")
                return@withLock false
            }

            try {
                currentSession.send(Frame.Text(event))
                println("✅ [SocketManager] Event sent successfully")
                true
            } catch (exception: CancellationException) {
                println("⚠️ [SocketManager] Send cancelled")
                throw exception
            } catch (exception: Exception) {
                println("❌ [SocketManager] Send error: ${exception.message}")
                exception.printStackTrace()

                _connectionErrors.emit(
                    exception.message ?: "WebSocket send failed"
                )
                false
            }
        }
    }

    suspend fun disconnect() {
        println("🔌 [SocketManager] Disconnect requested")

        connectionMutex.withLock {
            receiveJob?.cancel()
            receiveJob = null

            val currentSession = session
            session = null
            _isConnected.value = false

            try {
                currentSession?.close(
                    CloseReason(
                        CloseReason.Codes.NORMAL,
                        "Client disconnected"
                    )
                )

                println("✅ [SocketManager] Disconnected")
            } catch (exception: CancellationException) {
                throw exception
            } catch (exception: Exception) {
                println("⚠️ [SocketManager] Disconnect error: ${exception.message}")
            }
        }
    }

    fun clear() {
        println("🧹 [SocketManager] Clearing manager")

        scope.launch {
            disconnect()
            scope.cancel()
        }
    }

    fun watchEvents(onEvent: (String) -> Unit) {
        println("👀 [SocketManager] Event observer registered")

        scope.launch {
            receivedEvents.collect { event ->
                println("📨 [SocketManager] Delivering event to observer")
                onEvent(event)
            }
        }
    }
}