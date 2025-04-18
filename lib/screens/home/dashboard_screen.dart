import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travelcompanion/models/user_model.dart';
import 'package:travelcompanion/services/auth_service.dart';
import 'package:travelcompanion/services/firestore_service.dart';
import 'package:travelcompanion/services/location_service.dart';
import 'package:travelcompanion/widgets/common/error_dialog.dart';
import 'package:travelcompanion/widgets/common/loading_indicator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with AutomaticKeepAliveClientMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final LocationService _locationService = LocationService();
  
  bool _isLoading = true;
  bool _isLocationLoading = false;
  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  String? _searchQuery;
  double _selectedRadius = 50; // Default radius 50km
  bool _filterByDistance = false;
  double? _currentLat;
  double? _currentLng;
  
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchFocused = false;
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      setState(() {
        _isSearchFocused = _searchFocusNode.hasFocus;
      });
    });
    _loadAllUsers();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
  
  Future<void> _loadAllUsers() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Load all users without filtering by active status
      final users = await _firestoreService.getUsers(activeOnly: false).first;
      
      setState(() {
        _allUsers = users;
        _filteredUsers = _allUsers;
        _isLoading = false;
      });
      
      // Update the user's current location
      _updateCurrentLocation();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      showErrorDialog(
        context: context,
        title: 'Could not load travelers',
        message: 'Please check your connection and try again.',
        onDismiss: () => _loadAllUsers(),
      );
    }
  }
  
  Future<void> _updateCurrentLocation() async {
    setState(() {
      _isLocationLoading = true;
    });
    
    try {
      final position = await _locationService.getCurrentPosition();
      
      if (position != null) {
        // Save current location for distance calculations
        _currentLat = position.latitude;
        _currentLng = position.longitude;
        
        // Update current user's location
        await _firestoreService.updateUserLocation(
          position.latitude,
          position.longitude,
        );
        
        // Fetch users with updated distances
        await _loadUsersWithDistances(position.latitude, position.longitude);
        
        // If distance filter is active, apply it
        if (_filterByDistance) {
          _applyDistanceFilter();
        }
      }
    } catch (e) {
      print('Error updating location: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          content: Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.location_off, color: Colors.white70),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Could not access your location. Distance information may not be accurate.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          duration: Duration(seconds: 4),
        ),
      );
    } finally {
      setState(() {
        _isLocationLoading = false;
      });
    }
  }
  
  Future<void> _loadUsersWithDistances(double lat, double lng) async {
    try {
      final usersWithDistance = await _firestoreService.getUsersNearLocation(
        lat,
        lng,
        10000, // Very large radius to get all users with distance
      );
      
      setState(() {
        _allUsers = usersWithDistance;
        _filteredUsers = _applySearchFilter(_allUsers);
      });
    } catch (e) {
      print('Error loading users with distances: $e');
    }
  }
  
  void _applyDistanceFilter() {
    if (!_filterByDistance) {
      setState(() {
        _filteredUsers = _applySearchFilter(_allUsers);
      });
      return;
    }
    
    setState(() {
      // Log current state
      print('Filtering users by distance <= ${_selectedRadius}km');
      print('Total users before filtering: ${_allUsers.length}');
      
      // Filter users who have distance calculated and within radius
      List<UserModel> usersWithinRadius = _allUsers.where((user) {
        if (user.distance == null) {
          print('User ${user.name} has no distance value');
          return false;
        }
        print('User ${user.name} has distance ${user.distance}km');
        return user.distance! <= _selectedRadius;
      }).toList();
      
      print('Users within radius: ${usersWithinRadius.length}');
      
      // Apply search filter on top of distance filter
      _filteredUsers = _applySearchFilter(usersWithinRadius);
      print('Final filtered users: ${_filteredUsers.length}');
    });
  }
  
  List<UserModel> _applySearchFilter(List<UserModel> users) {
    if (_searchQuery == null || _searchQuery!.isEmpty) {
      return users;
    }
    
    final query = _searchQuery!.toLowerCase();
    return users.where((user) {
      final name = user.name?.toLowerCase() ?? '';
      final interest = user.interest?.toLowerCase() ?? '';
      return name.contains(query) || interest.contains(query);
    }).toList();
  }
  
  void _onSearch(String query) {
    setState(() {
      _searchQuery = query.isEmpty ? null : query;
      
      if (_filterByDistance) {
        List<UserModel> usersWithinRadius = _allUsers.where((user) {
          return user.distance != null && user.distance! <= _selectedRadius;
        }).toList();
        _filteredUsers = _applySearchFilter(usersWithinRadius);
      } else {
        _filteredUsers = _applySearchFilter(_allUsers);
      }
    });
  }
  
  void _onRadiusChanged(double newRadius) {
    setState(() {
      _selectedRadius = newRadius;
    });
  }
  
  void _toggleDistanceFilter() {
    setState(() {
      _filterByDistance = !_filterByDistance;
      _applyDistanceFilter();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Color Palette
    final primaryColor = Color(0xFF3366FF); // Rich blue
    final accentColor = Color(0xFF00CCBB); // Teal
    final backgroundColor = isDark ? Color(0xFF121212) : Color(0xFFF7F9FC);
    final cardColor = isDark ? Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Color(0xFF2A2A2A);
    final subtitleColor = isDark ? Colors.white70 : Color(0xFF6E7191);
    
    return Scaffold(
      

      backgroundColor: backgroundColor,
      body: Padding(
        padding: EdgeInsets.only(bottom: 90), // Enough space for the nav bar
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              snap: false,
              stretch: true,
              backgroundColor: backgroundColor,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background gradient
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            primaryColor,
                            accentColor,
                          ],
                        ),
                      ),
                    ),
                    
                    // Pattern overlay
                    Opacity(
                      opacity: 0.1,
                      child: Image.network(
                        'https://www.transparenttextures.com/patterns/cubes.png',
                        repeat: ImageRepeat.repeat,
                      ),
                    ),
                    
                    // Content overlay with gradient
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.6),
                          ],
                        ),
                      ),
                    ),
                    
                    // Header content
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Find Your',
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.9),
                                letterSpacing: 1.5,
                              ),
                            ),
                            Text(
                              'Travel Companions',
                              style: GoogleFonts.montserrat(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(60),
                child: Container(
                  height: 60,
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      // Search Bar
                      Expanded(
                        child: Container(
                          height: 45,
                          decoration: BoxDecoration(
                            color: isDark ? Color(0xFF2A2A2A) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            style: GoogleFonts.nunito(
                              color: textColor,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search travelers...',
                              hintStyle: GoogleFonts.nunito(
                                color: subtitleColor,
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: _isSearchFocused ? primaryColor : subtitleColor,
                                size: 18,
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.clear,
                                        color: subtitleColor,
                                        size: 16,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        _onSearch('');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.only(top: 8),
                            ),
                            onChanged: _onSearch,
                            cursorColor: primaryColor,
                          ),
                        ),
                      ),
                      
                      SizedBox(width: 12),
                      
                      // Filter Button
                      Container(
                        height: 45,
                        width: 45,
                        decoration: BoxDecoration(
                          color: _filterByDistance ? primaryColor : (isDark ? Color(0xFF2A2A2A) : Colors.white),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              _showFilterDialog(context, primaryColor, accentColor, textColor, subtitleColor, backgroundColor);
                            },
                            child: Icon(
                              Icons.filter_list,
                              color: _filterByDistance ? Colors.white : subtitleColor,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Status bar showing filters & count
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 5),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (_filterByDistance)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.place,
                                  color: primaryColor,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '${_selectedRadius.toInt()} km',
                                  style: GoogleFonts.nunito(
                                    color: primaryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 4),
                                GestureDetector(
                                  onTap: _toggleDistanceFilter,
                                  child: Icon(
                                    Icons.close,
                                    color: primaryColor,
                                    size: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_isLocationLoading)
                          Padding(
                            padding: const EdgeInsets.only(left: 12.0),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      '${_filteredUsers.length} travelers',
                      style: GoogleFonts.nunito(
                        color: subtitleColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Debug information (temporary)
            if (_currentLat != null && _currentLng != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your location: ${_currentLat!.toStringAsFixed(4)}, ${_currentLng!.toStringAsFixed(4)}',
                          style: TextStyle(fontSize: 12, color: subtitleColor),
                        ),
                        // Text(
                        //   'Filter status: ${_filterByDistance ? "Active (${_selectedRadius.toInt()} km)" : "Inactive"}',
                        //   style: TextStyle(fontSize: 12, color: subtitleColor),
                        // ),
                      ],
                    ),
                  ),
                ),
              ),
            
            // Main content - Travelers list or loading
            _isLoading
                ? SliverFillRemaining(
                    child: Center(
                      child: LoadingIndicator(message: 'Finding travelers...'),
                    ),
                  )
                : _filteredUsers.isEmpty
                    ? SliverFillRemaining(
                        child: _buildEmptyState(primaryColor, textColor, subtitleColor),
                      )
                    : SliverPadding(
                        padding: EdgeInsets.fromLTRB(20, 10, 20, 30),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final user = _filteredUsers[index];
                              return _buildUserCard(
                                user,
                                primaryColor,
                                accentColor,
                                textColor,
                                subtitleColor,
                                cardColor,
                                index,
                              ).animate()
                                .fadeIn(delay: Duration(milliseconds: 50 * index), duration: Duration(milliseconds: 400))
                                .slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuad, delay: Duration(milliseconds: 50 * index), duration: Duration(milliseconds: 400));
                            },
                            childCount: _filteredUsers.length,
                          ),
                        ),
                      ),
          ],
        ),
      ),
    );
  }
  
  void _showFilterDialog(
    BuildContext context, 
    Color primaryColor, 
    Color accentColor,
    Color textColor,
    Color subtitleColor,
    Color backgroundColor,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.4,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Travelers',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: subtitleColor),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Distance filter toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter by distance',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      Switch(
                        value: _filterByDistance,
                        onChanged: (value) {
                          setModalState(() {
                            _filterByDistance = value;
                          });
                        },
                        activeColor: primaryColor,
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 8),
                  
                  // Radius selector
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Radius',
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                color: subtitleColor,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_selectedRadius.toInt()} km',
                                style: GoogleFonts.nunito(
                                  color: primaryColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: primaryColor,
                          inactiveTrackColor: primaryColor.withOpacity(0.2),
                          thumbColor: primaryColor,
                          overlayColor: primaryColor.withOpacity(0.2),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: _selectedRadius,
                          min: 5,
                          max: 500,
                          divisions: 99,
                          onChanged: (value) {
                            setModalState(() {
                              _selectedRadius = value;
                            });
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '5 km',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: subtitleColor,
                              ),
                            ),
                            Text(
                              '500 km',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  Spacer(),
                  
                  // Apply button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _applyDistanceFilter();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Apply Filters',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildEmptyState(Color accentColor, Color textColor, Color subtitleColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(
              'https://img.icons8.com/cotton/200/null/no-image.png',
              width: 120,
              height: 120,
              color: accentColor.withOpacity(0.8),
            ),
            SizedBox(height: 24),
            Text(
              _filterByDistance
                  ? 'No Travelers Within Range'
                  : 'No Travelers Found',
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              _filterByDistance
                  ? 'There are no travelers within ${_selectedRadius.toInt()} km of your location. Try increasing the radius or clearing filters.'
                  : 'No travelers match your search criteria. Try adjusting your search terms.',
              style: GoogleFonts.nunito(
                fontSize: 15,
                color: subtitleColor,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _filterByDistance 
                  ? _toggleDistanceFilter
                  : () {
                      _searchController.clear();
                      _onSearch('');
                    },
              icon: Icon(
                _filterByDistance ? Icons.public : Icons.refresh,
                size: 18,
              ),
              label: Text(
                _filterByDistance ? 'Show All Travelers' : 'Reset Search',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildUserCard(
    UserModel user, 
    Color primaryColor,
    Color accentColor,
    Color textColor,
    Color subtitleColor,
    Color cardColor,
    int index,
  ) {
    final hasValidProfilePic = user.profilePic != null && 
                              user.profilePic!.isNotEmpty && 
                              user.profilePic!.startsWith('http');
    
    final displayName = user.name ?? 'Traveler';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'T';
    
    // Alternate card colors for visual interest
    final cardGradient = index % 2 == 0
        ? [primaryColor, Color.lerp(primaryColor, accentColor, 0.5)!]
        : [accentColor, Color.lerp(accentColor, primaryColor, 0.3)!];
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Stack(
        children: [
          // Main card
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _navigateToUserProfile(user),
                  splashColor: primaryColor.withOpacity(0.1),
                  highlightColor: primaryColor.withOpacity(0.05),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar
                        Hero(
                          tag: 'profile_${user.id}',
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: cardGradient,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: cardGradient[0].withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ],
                              image: hasValidProfilePic
                                  ? DecorationImage(
                                      image: NetworkImage(user.profilePic!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: !hasValidProfilePic
                                ? Center(
                                    child: Text(
                                      initial,
                                      style: GoogleFonts.montserrat(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        SizedBox(width: 16),
                        
                        // User details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: GoogleFonts.montserrat(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              
                              // Distance badge prominently displayed
                              if (user.distance != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.place,
                                        size: 16,
                                        color: cardGradient[0],
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        '${user.distance!.toStringAsFixed(1)} kilometers away',
                                        style: GoogleFonts.nunito(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: cardGradient[0],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              
                              // Interests tag
                              if (user.interest != null && user.interest!.isNotEmpty)
                                Container(
                                  margin: EdgeInsets.only(top: 10),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cardGradient[0].withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    user.interest!,
                                    style: GoogleFonts.nunito(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: cardGradient[0],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              
                              // Bio with subtle styling
                              if (user.bio != null && user.bio!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(
                                    user.bio!,
                                    style: GoogleFonts.nunito(
                                      fontSize: 14,
                                      color: subtitleColor,
                                      height: 1.4,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                
                              // Action buttons
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    // Chat button with gradient
                                    Container(
                                      height: 36,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: cardGradient,
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: [
                                          BoxShadow(
                                            color: cardGradient[0].withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => _navigateToUserProfile(user),
                                          borderRadius: BorderRadius.circular(18),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.message_rounded,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                                SizedBox(width: 6),
                                                Text(
                                                  'Message',
                                                  style: GoogleFonts.montserrat(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _navigateToUserProfile(UserModel user) {
    // Get the current user ID
    final currentUserId = Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    
    if (currentUserId == null) {
      showErrorDialog(
        context: context,
        title: 'Not Logged In',
        message: 'You need to be logged in to chat with travelers',
      );
      return;
    }
    
    // Create a consistent chat ID
    final chatId = _getChatId(currentUserId, user.id);
    
    // Navigate with clear arguments
    Navigator.of(context).pushNamed(
      '/chat',
      arguments: {
        'user': user,
        'chatId': chatId,
      },
    );
  }
  
  String _getChatId(String currentUserId, String otherUserId) {
    final users = [currentUserId, otherUserId]..sort();
    return '${users[0]}_${users[1]}';
  }
}