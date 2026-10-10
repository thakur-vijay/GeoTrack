package com.example.geotrack.feature.auth.domain.entities

data class User(
    val id: String,
    val fullName: String,
    val email: String,
    val createdAt: String,
    val updatedAt: String
)