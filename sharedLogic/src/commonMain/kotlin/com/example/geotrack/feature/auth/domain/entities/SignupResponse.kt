package com.example.geotrack.feature.auth.domain.entities

data class SignupResponse(
val statusCode: Int,
val message: String,
val data: SignupData
)

data class SignupData(
val user: User,
val accessToken: String,
val refreshToken: String
)