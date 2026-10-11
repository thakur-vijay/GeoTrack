package com.example.geotrack.feature.map

import androidx.lifecycle.ViewModel
import com.example.geotrack.feature.groups.Group
import com.example.geotrack.feature.groups.GroupViewModel
import com.example.geotrack.feature.regions.SafeRegionViewModel
import com.example.geotrack.feature.regions.SafeRegion
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.merge
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.stateIn

data class MapCoordinate(
    val latitude: Double,
    val longitude: Double
)

data class SafeRegionResult(

    val region: SafeRegion?,

    val center: MapCoordinate?

)

data class GroupID(
    val id: String? = null
)

class MapViewModel(
    private val groupViewModel: GroupViewModel,
    private val safeRegionViewModel: SafeRegionViewModel
) : ViewModel() {

    // MARK: - Groups

    private val _groups = MutableStateFlow<List<Any>>(emptyList())
    val groups: StateFlow<List<Any>> = _groups.asStateFlow()

    // MARK: - Safe Regions

    private val _safeRegions = MutableStateFlow<List<Any>>(emptyList())
    val safeRegions: StateFlow<List<Any>> = _safeRegions.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _isLoadingRegions = MutableStateFlow(false)
    val isLoadingRegions: StateFlow<Boolean> =
        _isLoadingRegions.asStateFlow()

    private val _hasFetchedRegions = MutableStateFlow(false)
    val hasFetchedRegions: StateFlow<Boolean> =
        _hasFetchedRegions.asStateFlow()

    // MARK: - Error

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    // MARK: - Presentation State

    private val _showCreateGroup = MutableStateFlow(false)
    val showCreateGroup: StateFlow<Boolean> =
        _showCreateGroup.asStateFlow()

    private val _showManageGroup = MutableStateFlow(false)
    val showManageGroup: StateFlow<Boolean> =
        _showManageGroup.asStateFlow()

    private val _showCreateRegion = MutableStateFlow(false)
    val showCreateRegion: StateFlow<Boolean> =
        _showCreateRegion.asStateFlow()

    // MARK: - Safe Region Selection

    private val _selectedCoordinate =
        MutableStateFlow<MapCoordinate?>(null)

    val selectedCoordinate: StateFlow<MapCoordinate?> =
        _selectedCoordinate.asStateFlow()

    private val _selectedRadius = MutableStateFlow(200)
    val selectedRadius: StateFlow<Int> =
        _selectedRadius.asStateFlow()

    // MARK: - Selected Group

    private val _selectedGroupID = MutableStateFlow(GroupID())

    val selectedGroupID: StateFlow<GroupID> =

        _selectedGroupID.asStateFlow()
    // MARK: - State Updates

    fun setGroups(value: List<Any>) {
        _groups.value = value
    }

    fun setSafeRegions(value: List<Any>) {
        _safeRegions.value = value
    }

    fun setLoading(value: Boolean) {
        _isLoading.value = value
    }

    fun setLoadingRegions(value: Boolean) {
        _isLoadingRegions.value = value
    }

    fun setHasFetchedRegions(value: Boolean) {
        _hasFetchedRegions.value = value
    }

    fun setError(message: String?) {
        _errorMessage.value = message
    }

    fun setShowCreateGroup(value: Boolean) {
        _showCreateGroup.value = value
    }

    fun setShowManageGroup(value: Boolean) {
        _showManageGroup.value = value
    }

    fun setShowCreateRegion(value: Boolean) {
        _showCreateRegion.value = value
    }

    fun setSelectedCoordinate(value: MapCoordinate?) {
        _selectedCoordinate.value = value
    }

    fun setSelectedRadius(value: Int) {
        _selectedRadius.value = value
    }

    fun setSelectedGroupID(value: GroupID) {
        _selectedGroupID.value = value
    }

    val hasSafeRegion: Boolean
        get() = _safeRegions.value.isNotEmpty()

    val selectedGroup = combine(
        _groups,
        _selectedGroupID
    ) { groups, selectedGroupID ->
        groups.filterIsInstance<Group>()
            .firstOrNull { it.id == selectedGroupID.id }
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.Eagerly,
        initialValue = null
    )

    fun canCreateSafeRegion(userId: String?): Boolean {
        val group = selectedGroup.value ?: return false

        return group.createdBy == userId &&
                _hasFetchedRegions.value &&
                !hasSafeRegion &&
                !_isLoadingRegions.value
    }

    suspend fun fetchGroups(accessToken: String): Boolean {
        if (_isLoading.value) return false

        _isLoading.value = true

        return try {
            val result = groupViewModel.fetchGroups(accessToken)

            if (result.sessionExpired) return true

            val fetchedGroups = result.data
                ?.filterIsInstance<Group>()
                ?: emptyList()

            _groups.value = fetchedGroups

            if (fetchedGroups.isEmpty()) {
                _selectedGroupID.value = GroupID()
                _safeRegions.value = emptyList()
                _hasFetchedRegions.value = false
                _errorMessage.value = result.error
                return false
            }

            if (fetchedGroups.none { it.id == _selectedGroupID.value.id }) {
                _selectedGroupID.value = GroupID(
                    id = fetchedGroups.first().id
                )
            }

            false
        } catch (error: Exception) {
            _errorMessage.value = error.message
            false
        } finally {
            _isLoading.value = false
        }
    }
    fun onGroupCreated(createdGroup: Group) {
        _groups.value = _groups.value + createdGroup
        _selectedGroupID.value = GroupID(id = createdGroup.id)
    }

    suspend fun handleSelectedGroupChanged(
        groupID: String?,
        accessToken: String
    ): SafeRegionResult {
        setSelectedCoordinate(null)

        if (groupID == null) {
            _safeRegions.value = emptyList()
            _hasFetchedRegions.value = false
            return SafeRegionResult(region = null, center = null)
        }

        _isLoadingRegions.value = true
        _hasFetchedRegions.value = false
        _safeRegions.value = emptyList()
        _selectedCoordinate.value = null

        try {
            val result = safeRegionViewModel.fetchSafeRegionsByGroupID(
                groupID = groupID,
                accessToken = accessToken
            ) ?: run {
                _errorMessage.value = "Safe regions could not be fetched."
                return SafeRegionResult(region = null, center = null)
            }

            if (_selectedGroupID.value.id != groupID) {
                return SafeRegionResult(region = null, center = null)
            }

            _safeRegions.value = result.data
            _hasFetchedRegions.value = true

            val region = result.data.firstOrNull()
                ?: return SafeRegionResult(region = null, center = null)

            return SafeRegionResult(
                region = region,
                center = MapCoordinate(
                    latitude = region.latitude,
                    longitude = region.longitude
                )
            )
        } catch (error: Exception) {
            if (_selectedGroupID.value.id == groupID) {
                _errorMessage.value = error.message
            }

            return SafeRegionResult(region = null, center = null)
        } finally {
            _isLoadingRegions.value = false
        }
    }

    suspend fun performSaveSafeRegion(
        groupID: String,
        coordinate: MapCoordinate,
        name: String,
        radius: Int,
        accessToken: String
    ): MapCoordinate? {
        if (accessToken.isBlank()) {
            _errorMessage.value = "Please log in to create a safe region."
            return null
        }

        return try {
            val result = safeRegionViewModel.createSafeRegion(
                groupID = groupID,
                name = name,
                latitude = coordinate.latitude,
                longitude = coordinate.longitude,
                radiusMeters = radius,
                accessToken = accessToken
            ) ?: run {
                _errorMessage.value = "Safe region could not be created."
                return null
            }

            if (_selectedGroupID.value.id != groupID) {
                _showCreateRegion.value = false
                return null
            }

            _safeRegions.value = listOf(result.data)
            _hasFetchedRegions.value = true
            _selectedCoordinate.value = null
            _selectedRadius.value = radius
            _showCreateRegion.value = false

            coordinate
        } catch (error: Exception) {
            _errorMessage.value = error.message
            null
        }
    }

    fun observeState(onChange: () -> Unit) {
        viewModelScope.launch {
            merge(
                _groups.map { Unit },
                _safeRegions.map { Unit },
                _isLoading.map { Unit },
                _isLoadingRegions.map { Unit },
                _hasFetchedRegions.map { Unit },
                _errorMessage.map { Unit },
                _showCreateGroup.map { Unit },
                _showManageGroup.map { Unit },
                _showCreateRegion.map { Unit },
                _selectedCoordinate.map { Unit },
                _selectedRadius.map { Unit },
                _selectedGroupID.map { Unit }
            ).collect {
                onChange()
            }
        }
    }
}