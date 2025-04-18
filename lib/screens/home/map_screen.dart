import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:travelcompanion/models/user_model.dart';
import 'package:travelcompanion/services/auth_service.dart';
import 'package:travelcompanion/services/firestore_service.dart';
import 'package:travelcompanion/services/location_service.dart';
import 'package:travelcompanion/widgets/common/error_dialog.dart';
import 'package:travelcompanion/widgets/common/loading_indicator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with AutomaticKeepAliveClientMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final LocationService _locationService = LocationService();
  
  final MapController _mapController = MapController();
  List<Marker> _markers = [];
  LatLng? _currentPosition;
  bool _isLoading = true;
  bool _loadingUsers = false;
  List<UserModel> _nearbyUsers = [];
  List<UserModel> _allUsers = [];
  UserModel? _selectedUser;
  bool _showAllUsers = false;
  double _selectedRadius = 50; // Default radius 50km
  
  Timer? _locationUpdateTimer;
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    print("MapScreen: initializing");
    _initializeMap();
    
    // Set up periodic location updates
    _locationUpdateTimer = Timer.periodic(Duration(minutes: 2), (timer) {
      print("MapScreen: scheduled location update triggered");
      _updateUserLocation();
    });
  }
  
  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    print("MapScreen: disposed, timer canceled");
    super.dispose();
  }
  
  Future<void> _initializeMap() async {
    print("MapScreen: _initializeMap called");
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get current location
      final position = await _locationService.getCurrentPosition();
      print("MapScreen: Got position from location service: $position");
      
      if (position != null) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
        });
        print("MapScreen: Current position set to ${position.latitude}, ${position.longitude}");
        
        // Update current user's location in Firestore
        await _firestoreService.updateUserLocation(
          position.latitude,
          position.longitude,
        );
        print("MapScreen: Updated user location in Firestore");
        
        // Load nearby users
        await _loadNearbyUsers();
      } else {
        // Use default location if we can't get current location
        setState(() {
          _currentPosition = LatLng(0, 0); // Default to 0,0 (null island)
        });
        print("MapScreen: Could not get current location, defaulting to 0,0");
        throw 'Could not get current location';
      }
    } catch (e) {
      print("MapScreen: Error initializing map: $e");
      showErrorDialog(
        context: context,
        title: 'Location Error',
        message: 'Could not initialize map: $e',
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _updateUserLocation() async {
    print("MapScreen: _updateUserLocation called");
    try {
      final position = await _locationService.getCurrentPosition();
      
      if (position != null) {
        print("MapScreen: New position: ${position.latitude}, ${position.longitude}");
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
        });
        
        // Update current user's location in Firestore
        await _firestoreService.updateUserLocation(
          position.latitude,
          position.longitude,
        );
        print("MapScreen: Updated user location in Firestore");
        
        // Move map to current position if not in "show all users" mode
        if (!_showAllUsers && _currentPosition != null) {
          _mapController.moveAndRotate(_currentPosition!, 13.0, 0);
          print("MapScreen: Moved map to current position");
        }
        
        // Refresh nearby users
        await _loadNearbyUsers();
      }
    } catch (e) {
      print("MapScreen: Error updating location: $e");
    }
  }
  
  Future<void> _loadNearbyUsers() async {
    print("MapScreen: _loadNearbyUsers called with radius $_selectedRadius km");
    if (_currentPosition == null) {
      print("MapScreen: Current position is null, cannot load nearby users");
      return;
    }
    
    setState(() {
      _loadingUsers = true;
    });
    
    try {
      // Get nearby users with selected radius
      final nearbyUsers = await _firestoreService.getUsersNearLocation(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _selectedRadius, // radius in km
      );
      
      print("MapScreen: Found ${nearbyUsers.length} nearby users within $_selectedRadius km");
      
      setState(() {
        _nearbyUsers = nearbyUsers;
        _showAllUsers = false;
        _loadingUsers = false;
      });
      
      _updateMarkers();
    } catch (e) {
      print("MapScreen: Error loading nearby users: $e");
      setState(() {
        _loadingUsers = false;
      });
    }
  }
  
  Future<void> _loadAllUsers() async {
    print("MapScreen: _loadAllUsers called");
    
    setState(() {
      _loadingUsers = true;
    });
    
    try {
      // Get all users
      final users = await _firestoreService.getUsers(activeOnly: false).first;
      
      print("MapScreen: Loaded ${users.length} total users");
      
      setState(() {
        _allUsers = users;
        _showAllUsers = true;
        _loadingUsers = false;
      });
      
      _updateMarkers();
      
      // Auto-zoom to fit all markers
      _fitAllMarkers();
    } catch (e) {
      print("MapScreen: Error loading all users: $e");
      setState(() {
        _loadingUsers = false;
      });
    }
  }
  
  void _fitAllMarkers() {
    print("MapScreen: _fitAllMarkers called");
    if (_markers.length <= 1 || _currentPosition == null) {
      print("MapScreen: Not enough markers to fit");
      return;
    }
    
    // Collect all points
    final points = _markers.map((marker) => marker.point).toList();
    
    // Find bounds
    var south = points[0].latitude;
    var north = points[0].latitude;
    var west = points[0].longitude;
    var east = points[0].longitude;
    
    for (var point in points) {
      south = point.latitude < south ? point.latitude : south;
      north = point.latitude > north ? point.latitude : north;
      west = point.longitude < west ? point.longitude : west;
      east = point.longitude > east ? point.longitude : east;
    }
    
    // Add padding
    final latPadding = (north - south) * 0.15;
    final lngPadding = (east - west) * 0.15;
    
    // Create bounds
    final southWest = LatLng(south - latPadding, west - lngPadding);
    final northEast = LatLng(north + latPadding, east + lngPadding);
    
    // Calculate center and zoom
    final centerLat = (south + north) / 2;
    final centerLng = (west + east) / 2;
    final center = LatLng(centerLat, centerLng);
    
    // Calculate appropriate zoom level
    final latZoom = _fitZoomForLatitude(south - latPadding, north + latPadding);
    final lngZoom = _fitZoomForLongitude(west - lngPadding, east + lngPadding);
    final zoom = math.min(latZoom, lngZoom);
    
    print("MapScreen: Fitting to center: $center with zoom: $zoom");
    
    // Move map to center with calculated zoom
    _mapController.moveAndRotate(center, zoom, 0);
  }
  
  double _fitZoomForLatitude(double south, double north) {
    const mapHeight = 300.0; // Approximate visible map height in pixels
    final latDiff = north - south;
    
    // Approx pixels per degree at equator at zoom 0 is 156543.03392
    final resolution = 156543.03392 * math.cos(south * math.pi / 180);
    final zoom = math.log(360 * mapHeight / (latDiff * resolution)) / math.ln2;
    
    return zoom;
  }
  
  double _fitZoomForLongitude(double west, double east) {
    const mapWidth = 300.0; // Approximate visible map width in pixels
    final lngDiff = east - west;
    
    // Approx pixels per degree at equator at zoom 0 is 156543.03392
    final resolution = 156543.03392;
    final zoom = math.log(360 * mapWidth / (lngDiff * resolution)) / math.ln2;
    
    return zoom;
  }
  
  void _updateMarkers() {
    print("MapScreen: _updateMarkers called");
    if (_currentPosition == null) {
      print("MapScreen: Current position is null, cannot update markers");
      return;
    }
    
    final newMarkers = <Marker>[];
    
    // Add marker for current user
    newMarkers.add(
      Marker(
        width: 60.0,
        height: 60.0,
        point: _currentPosition!,
        child: Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Container(
                margin: EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Color(0xFF3366FF),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'You',
                style: GoogleFonts.nunito(
                  color: Color(0xFF3366FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    
    // Add markers for nearby users (or all users)
    final usersToShow = _showAllUsers ? _allUsers : _nearbyUsers;
    
    print("MapScreen: Adding ${usersToShow.length} user markers to map");
    
    for (final user in usersToShow) {
      if (user.latitude != null && user.longitude != null) {
        // Calculate user's distance if not already set
        final distance = calculateDistance(
          _currentPosition!.latitude, 
          _currentPosition!.longitude,
          user.latitude!, 
          user.longitude!
        );
        
        final markerColor = _getColorForUser(user);
        
        newMarkers.add(
          Marker(
            width: 56.0,
            height: 56.0,
            point: LatLng(user.latitude!, user.longitude!),
            child: GestureDetector(
              onTap: () {
                print("MapScreen: User marker tapped: ${user.name}");
                setState(() {
                  _selectedUser = user;
                });
              },
              child: Column(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Container(
                      margin: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: markerColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.only(top: 2),
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '${distance.toStringAsFixed(1)} km',
                      style: GoogleFonts.nunito(
                        color: markerColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
    
    setState(() {
      _markers = newMarkers;
    });
  }
  
  // Helper to get color based on user's distance
  Color _getColorForUser(UserModel user) {
    if (user.distance == null) return Color(0xFF00CCBB);
    
    if (user.distance! <= 10) {
      return Color(0xFF4CAF50); // Green - very close
    } else if (user.distance! <= 25) {
      return Color(0xFF00CCBB); // Teal - close
    } else if (user.distance! <= 50) {
      return Color(0xFF3366FF); // Blue - medium
    } else if (user.distance! <= 100) {
      return Color(0xFFF57C00); // Orange - far
    } else {
      return Color(0xFFE91E63); // Pink - very far
    }
  }
  
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // Radius of the earth in km
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = 
      math.sin(dLat/2) * math.sin(dLat/2) +
      math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) * 
      math.sin(dLon/2) * math.sin(dLon/2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a));
    final d = R * c; // Distance in km
    return d;
  }
  
  double _deg2rad(double deg) {
    return deg * (math.pi/180);
  }
  
  void _toggleUserView() {
    print("MapScreen: _toggleUserView called, current state: $_showAllUsers");
    
    if (_showAllUsers) {
      // Switching to nearby view
      _loadNearbyUsers();
    } else {
      // Switching to all users view
      _loadAllUsers();
    }
  }
  
  void _onRadiusChanged(double newRadius) {
    print("MapScreen: Radius changed from $_selectedRadius to $newRadius");
    setState(() {
      _selectedRadius = newRadius;
    });
    
    // Reload nearby users with new radius
    if (!_showAllUsers) {
      _loadNearbyUsers();
    }
  }
  
  void _openUserProfile(UserModel user) {
    print("MapScreen: Opening profile for user: ${user.name}");
    // Navigate to user profile or chat
    Navigator.of(context).pushNamed(
      '/chat',
      arguments: {
        'user': user,
        'chatId': _getChatId(user.id),
      },
    );
  }
  
  String _getChatId(String otherUserId) {
    final currentUserId = Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    
    if (currentUserId == null) return '';
    
    // Create a consistent chat ID by sorting user IDs
    final users = [currentUserId, otherUserId]..sort();
    return '${users[0]}_${users[1]}';
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    // Colors
    final primaryColor = Color(0xFF3366FF);
    final accentColor = Color(0xFF00CCBB);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Color(0xFF121212) : Color(0xFFF7F9FC);
    final textColor = isDark ? Colors.white : Color(0xFF2A2A2A);
    final subtitleColor = isDark ? Colors.white70 : Color(0xFF6E7191);
    
    return Padding(
      padding: EdgeInsets.only(bottom: 90), // Enough space for the nav bar
      // padding: const EdgeInsets.all(8.0),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: _isLoading
            ? Center(child: LoadingIndicator(message: 'Loading map...'))
            : _currentPosition == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_off,
                          size: 64,
                          color: subtitleColor,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Location not available',
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Please enable location services and try again',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            color: subtitleColor,
                          ),
                        ),
                        SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _initializeMap,
                          child: Text(
                            'Retry',
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Stack(
                    children: [
                      // Map layer
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _currentPosition!,
                          initialZoom: 13.0,
                          minZoom: 3.0,
                          maxZoom: 18.0,
                          onTap: (_, position) {
                            // Clear selected user when tapping the map
                            setState(() {
                              _selectedUser = null;
                            });
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                            subdomains: ['a', 'b', 'c'],
                            userAgentPackageName: 'com.example.travelcompanion',
                          ),
                          
                          // Distance circles (only in nearby mode)
                          if (!_showAllUsers && _currentPosition != null)
                            CircleLayer(
                              circles: [
                                CircleMarker(
                                  point: _currentPosition!,
                                  radius: _selectedRadius * 1000, // Convert to meters
                                  color: primaryColor.withOpacity(0.1),
                                  borderColor: primaryColor.withOpacity(0.7),
                                  borderStrokeWidth: 2,
                                  useRadiusInMeter: true,
                                ),
                              ],
                            ),
                          
                          // User markers
                          MarkerLayer(markers: _markers),
                        ],
                      ),
                      
                      // App Bar
                      SafeArea(
                        child: Container(
                          height: 60,
                          margin: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                color: Colors.white.withOpacity(0.9),
                                child: Row(
                                  children: [
                                    Container(
                                      height: 36,
                                      width: 36,
                                      decoration: BoxDecoration(
                                        color: primaryColor.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _showAllUsers ? Icons.public : Icons.near_me,
                                        color: primaryColor,
                                        size: 18,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            _showAllUsers ? 'All Travelers' : 'Nearby Travelers',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: textColor,
                                            ),
                                          ),
                                          Text(
                                            _showAllUsers
                                                ? 'Showing ${_allUsers.length} travelers'
                                                : 'Within ${_selectedRadius.toInt()} km (${_nearbyUsers.length} found)',
                                            style: GoogleFonts.nunito(
                                              fontSize: 12,
                                              color: subtitleColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_loadingUsers)
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                                        ),
                                      ),
                                    SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(
                                        Icons.refresh,
                                        color: primaryColor,
                                      ),
                                      tooltip: 'Refresh',
                                      onPressed: _showAllUsers ? _loadAllUsers : _loadNearbyUsers,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // Control panel
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Map Controls',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _toggleUserView,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            _showAllUsers ? Icons.near_me : Icons.public,
                                            size: 16,
                                            color: primaryColor,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            _showAllUsers ? 'Show Nearby' : 'Show All',
                                            style: GoogleFonts.nunito(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: primaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              SizedBox(height: 16),
                              
                              // Radius selector (only shown in nearby mode)
                              if (!_showAllUsers)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Distance Radius',
                                          style: GoogleFonts.nunito(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: textColor,
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: primaryColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${_selectedRadius.toInt()} km',
                                            style: GoogleFonts.nunito(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: primaryColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
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
                                        onChanged: _onRadiusChanged,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
                              
                              // Map control buttons
                              SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildControlButton(
                                    icon: Icons.my_location,
                                    label: 'My Location',
                                    color: primaryColor,
                                    onTap: () {
                                      if (_currentPosition != null) {
                                        _mapController.moveAndRotate(_currentPosition!, 13.0, 0);
                                      }
                                    },
                                  ),
                                  _buildControlButton(
                                    icon: Icons.zoom_in,
                                    label: 'Zoom In',
                                    color: accentColor,
                                    onTap: () {
                                      final currentZoom = _mapController.camera.zoom;
                                      _mapController.moveAndRotate(
                                        _mapController.camera.center,
                                        currentZoom + 1,
                                        0,
                                      );
                                    },
                                  ),
                                  _buildControlButton(
                                    icon: Icons.zoom_out,
                                    label: 'Zoom Out',
                                    color: accentColor,
                                    onTap: () {
                                      final currentZoom = _mapController.camera.zoom;
                                      _mapController.moveAndRotate(
                                        _mapController.camera.center,
                                        currentZoom - 1,
                                        0,
                                      );
                                    },
                                  ),
                                  _buildControlButton(
                                    icon: Icons.fit_screen,
                                    label: 'Fit All',
                                    color: primaryColor,
                                    onTap: _fitAllMarkers,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Selected user card
                      if (_selectedUser != null)
                        Positioned(
                          top: 90,
                          left: 16,
                          right: 16,
                          child: _buildUserCard(_selectedUser!, primaryColor, textColor, subtitleColor, accentColor),
                        ),
                    ],
                  ),
      ),
    );
  }
  
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 20,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildUserCard(
    UserModel user, 
    Color primaryColor,
    Color textColor,
    Color subtitleColor,
    Color accentColor,
  ) {
    final hasValidProfilePic = user.profilePic != null && 
                              user.profilePic!.isNotEmpty && 
                              user.profilePic!.startsWith('http');
    
    final displayName = user.name ?? 'Traveler';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'T';
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
            onTap: () => _openUserProfile(user),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Hero(
                    tag: 'profile_${user.id}',
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            primaryColor,
                            accentColor,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
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
                                  fontSize: 24,
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
                        ),
                        if (user.distance != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.place,
                                  size: 14,
                                  color: primaryColor,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '${user.distance!.toStringAsFixed(1)} kilometers away',
                                  style: GoogleFonts.nunito(
                                    fontSize: 13,
                                    color: primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (user.interest != null && user.interest!.isNotEmpty)
                          Container(
                            margin: EdgeInsets.only(top: 8),
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              user.interest!,
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        
                        SizedBox(height: 8),
                        
                        ElevatedButton.icon(
                          onPressed: () => _openUserProfile(user),
                          icon: Icon(
                            Icons.chat_bubble_outline,
                            size: 16,
                          ),
                          label: Text(
                            'Send Message',
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: Size(0, 36),
                            textStyle: TextStyle(fontSize: 12),
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
    );
  }
}