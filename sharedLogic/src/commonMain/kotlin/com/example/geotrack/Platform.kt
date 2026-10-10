package com.example.geotrack

interface Platform {
    val name: String
}

expect fun getPlatform(): Platform