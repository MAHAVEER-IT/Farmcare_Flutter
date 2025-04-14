import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

// Disease Point class definition
class DiseasePoint {
  final LatLng location;
  final String diseaseName;
  final String cropType;
  final double intensity;
  final int caseCount;
  final String placeName;
  final bool isPlantDisease;
  final DateTime reportDate;
  final String notes;

  DiseasePoint({
    required this.location,
    required this.diseaseName,
    required this.cropType,
    required this.intensity,
    required this.caseCount,
    required this.placeName,
    required this.isPlantDisease,
    required this.reportDate,
    this.notes = '',
  });
}

class HeatmapPageMap extends StatefulWidget {
  const HeatmapPageMap({Key? key}) : super(key: key);

  @override
  State<HeatmapPageMap> createState() => _HeatmapPageStateMap();
}

class _HeatmapPageStateMap extends State<HeatmapPageMap> {
  MapController _mapController = MapController();

  // Place name state variable
  String _currentPlaceName = "";
  LatLng? _currentLocation;
  List<DiseasePoint> _diseasePoints = [];

  // Updated disease data points to include disease type (plant/animal)
  final List<DiseasePoint> _diseasePointsStatic = [
    DiseasePoint(
      location: LatLng(37.7749, -122.4194),
      diseaseName: "Leaf Spot",
      cropType: "Tomato",
      intensity: 0.8,
      caseCount: 12,
      placeName: "San Francisco, CA",
      isPlantDisease: true,
      reportDate: DateTime.now(),
    ),
    DiseasePoint(
      location: LatLng(37.7850, -122.4100),
      diseaseName: "Foot and Mouth",
      cropType: "Cattle",
      intensity: 0.5,
      caseCount: 7,
      placeName: "Fisherman's Wharf, SF",
      isPlantDisease: false,
      reportDate: DateTime.now(),
    ),
    DiseasePoint(
      location: LatLng(37.7800, -122.4300),
      diseaseName: "Early Blight",
      cropType: "Potato",
      intensity: 0.9,
      caseCount: 15,
      placeName: "Golden Gate Park, SF",
      isPlantDisease: true,
      reportDate: DateTime.now(),
    ),
    DiseasePoint(
      location: LatLng(37.7700, -122.4250),
      diseaseName: "Avian Flu",
      cropType: "Poultry",
      intensity: 0.4,
      caseCount: 55,
      placeName: "Mission District, SF",
      isPlantDisease: false,
      reportDate: DateTime.now(),
    ),
  ];

  // Simplified filter options
  bool _showPlantDiseases =
      true; // true for plant diseases, false for animal diseases
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;

  // Disease types for filter
  final List<String> _diseaseTypes = [
    'All Diseases',
    'Leaf Spot',
    'Early Blight',
    'Foot Rot',
    'Rust',
    'Powdery Mildew'
  ];

  // Crop types for filter
  final List<String> _cropTypes = [
    'All Crops',
    'Tomato',
    'Potato',
    'Rice',
    'Wheat',
    'Cotton'
  ];

  // Timeframe options
  final List<String> _timeframes = [
    'Today',
    'Last 7 Days',
    'Last 30 Days',
    'This Season'
  ];

  // Add state variables for tracking card position
  late Size _screenSize;
  late Offset _cardPosition;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    // Load static disease points for demo
    _diseasePoints = List.from(_diseasePointsStatic);
    // Initialize card position after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _screenSize = MediaQuery.of(context).size;
      setState(() {
        _cardPosition =
            Offset(_screenSize.width - 200, _screenSize.height - 150);
      });
    });
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get place name
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          _currentPlaceName =
              "${placemarks.first.locality}, ${placemarks.first.administrativeArea}";
        }
        _isLoading = false;
      });

      // Move map to current location
      _mapController.move(_currentLocation!, 13.0);
    } catch (e) {
      print('Error getting location: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    }
  }

  void _addDiseasePoint(DiseasePoint point) {
    setState(() {
      _diseasePoints.add(point);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Disease Heatmap'),
        backgroundColor: Colors.green[700],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getCurrentLocation,
          ),
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.green),
                  SizedBox(height: 16),
                  Text('Loading map data...',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : Column(
              children: [
                _buildFilterBar(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.grey[100],
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.green[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _currentPlaceName.isEmpty
                            ? 'Loading location...'
                            : _currentPlaceName,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      _buildZoneLegend(),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _currentLocation ?? LatLng(0, 0),
                          initialZoom: 13.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                            subdomains: ['a', 'b', 'c'],
                          ),
                          CircleLayer(
                            circles: _getCircleMarkers(),
                          ),
                          if (_currentLocation != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _currentLocation!,
                                  width: 40.0,
                                  height: 40.0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.7),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(
                                      Icons.my_location,
                                      color: Colors.white,
                                      size: 24.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: _diseasePoints
                                .where((point) =>
                                    point.isPlantDisease ==
                                        _showPlantDiseases &&
                                    point.reportDate.year ==
                                        _selectedDate.year &&
                                    point.reportDate.month ==
                                        _selectedDate.month)
                                .map((point) => Marker(
                                      point: point.location,
                                      width: 60.0,
                                      height: 60.0,
                                      child: GestureDetector(
                                        onTap: () =>
                                            _showPointDetails(context, point),
                                        child: Column(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: _getMarkerColor(
                                                        point.caseCount)
                                                    .withOpacity(0.9),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black26,
                                                    blurRadius: 3,
                                                    offset: Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Icon(
                                                point.isPlantDisease
                                                    ? Icons.local_florist
                                                    : Icons.pets,
                                                color: Colors.white,
                                                size: 24.0,
                                              ),
                                            ),
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 4, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withOpacity(0.6),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '${point.caseCount}',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                      Positioned(
                        left: _cardPosition.dx,
                        top: _cardPosition.dy,
                        child: Draggable(
                          feedback: Material(
                            color: Colors.transparent,
                            child: Card(
                              elevation: 8,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Opacity(
                                opacity: 0.9,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Disease Status',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                          Icon(Icons.drag_indicator,
                                              size: 16, color: Colors.grey),
                                        ],
                                      ),
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          SizedBox(width: 4),
                                          Text('Red Zone (50+ cases)'),
                                        ],
                                      ),
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: Colors.amber,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          SizedBox(width: 4),
                                          Text('Yellow Zone (<50 cases)'),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          childWhenDragging: SizedBox(),
                          onDragStarted: () {
                            setState(() {
                              _isDragging = true;
                            });
                          },
                          onDragEnd: (details) {
                            setState(() {
                              _isDragging = false;
                              _cardPosition =
                                  _getBoundedPosition(details.offset);
                            });
                          },
                          child: Card(
                            elevation: _isDragging ? 8 : 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Disease Status',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Icon(Icons.drag_indicator,
                                          size: 16, color: Colors.grey),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Text('Red Zone (50+ cases)'),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: Colors.amber,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Text('Yellow Zone (<50 cases)'),
                                    ],
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUploadDialog(context),
        backgroundColor: Colors.green[700],
        label: const Text('Report Disease'),
        icon: const Icon(Icons.add_location),
      ),
    );
  }

  Widget _buildZoneLegend() {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Red Zone',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        SizedBox(width: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.amber,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Yellow Zone',
            style: TextStyle(color: Colors.black, fontSize: 12),
          ),
        ),
      ],
    );
  }

  // Update the circle markers based on new filters
  List<CircleMarker> _getCircleMarkers() {
    final filteredPoints = _diseasePoints
        .where((point) =>
            point.isPlantDisease == _showPlantDiseases &&
            point.reportDate.year == _selectedDate.year &&
            point.reportDate.month == _selectedDate.month)
        .toList();

    return filteredPoints.map((point) {
      // Use the case count to determine zone color (red or yellow)
      Color circleColor = _getZoneColor(point.caseCount);

      // Scale radius based on case count
      double radius = 100 + (point.caseCount * 5);
      if (radius > 400) radius = 400;

      return CircleMarker(
        point: point.location,
        color: circleColor.withOpacity(0.2),
        borderColor: circleColor.withOpacity(0.7),
        borderStrokeWidth: 2.0,
        radius: radius,
      );
    }).toList();
  }

  // New method to determine zone color based on case count
  Color _getZoneColor(int caseCount) {
    // Red zone if cases >= 50, otherwise yellow zone
    return caseCount >= 50 ? Colors.red : Colors.amber;
  }

  // Updated to use case count instead of intensity
  Color _getMarkerColor(int caseCount) {
    return caseCount >= 50 ? Colors.red : Colors.amber;
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Plant Disease'),
                      icon: Icon(Icons.local_florist),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Animal Disease'),
                      icon: Icon(Icons.pets),
                    ),
                  ],
                  selected: {_showPlantDiseases},
                  onSelectionChanged: (Set<bool> newSelection) {
                    setState(() {
                      _showPlantDiseases = newSelection.first;
                    });
                  },
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.resolveWith<Color>(
                      (Set<MaterialState> states) {
                        if (states.contains(MaterialState.selected)) {
                          return Colors.green.shade100;
                        }
                        return Colors.transparent;
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: Colors.green.shade700,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null && picked != _selectedDate) {
                      setState(() {
                        _selectedDate = picked;
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    elevation: 1,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showUploadDialog(BuildContext context) {
    String diseaseName = '';
    String cropOrAnimalType = '';
    int caseCount = 1;
    String notes = '';
    LatLng? selectedLocation = _currentLocation;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            _showPlantDiseases
                ? 'Report Plant Disease'
                : 'Report Animal Disease',
            style: TextStyle(color: Colors.green[700]),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Disease Name',
                    hintText: _showPlantDiseases
                        ? 'e.g., Leaf Blight'
                        : 'e.g., Foot and Mouth',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: Colors.green.shade700, width: 2),
                    ),
                  ),
                  onChanged: (value) => diseaseName = value,
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    labelText: _showPlantDiseases ? 'Crop Type' : 'Animal Type',
                    hintText:
                        _showPlantDiseases ? 'e.g., Rice' : 'e.g., Cattle',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: Colors.green.shade700, width: 2),
                    ),
                  ),
                  onChanged: (value) => cropOrAnimalType = value,
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Number of Cases',
                    hintText: 'Enter number of affected plants/animals',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: Colors.green.shade700, width: 2),
                    ),
                    helperText: 'Cases ≥ 50 will be marked as Red Zone',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => caseCount = int.tryParse(value) ?? 1,
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Add any additional information',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: Colors.green.shade700, width: 2),
                    ),
                  ),
                  maxLines: 3,
                  onChanged: (value) => notes = value,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.my_location),
                  label: const Text('Use Current Location'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: () async {
                    await _getCurrentLocation();
                    selectedLocation = _currentLocation;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Current location set'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text('Submit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
              ),
              onPressed: () {
                if (diseaseName.isEmpty ||
                    cropOrAnimalType.isEmpty ||
                    selectedLocation == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please fill all required fields')),
                  );
                  return;
                }

                // Calculate intensity based on case count
                double intensity = caseCount >= 50 ? 0.9 : caseCount / 60.0;
                if (intensity > 1.0) intensity = 1.0;

                final newPoint = DiseasePoint(
                  location: selectedLocation!,
                  diseaseName: diseaseName,
                  cropType: cropOrAnimalType,
                  intensity: intensity,
                  caseCount: caseCount,
                  placeName: _currentPlaceName,
                  isPlantDisease: _showPlantDiseases,
                  notes: notes,
                  reportDate: _selectedDate,
                );

                _addDiseasePoint(newPoint);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Disease report submitted successfully'),
                      ],
                    ),
                    backgroundColor:
                        caseCount >= 50 ? Colors.red : Colors.amber,
                  ),
                );
              },
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }

  // Enhanced disease point details with improved UI
  void _showPointDetails(BuildContext context, DiseasePoint point) {
    // Determine if this is a red or yellow zone
    final bool isRedZone = point.caseCount >= 50;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isRedZone ? Colors.red : Colors.amber,
                shape: BoxShape.circle,
              ),
              child: Icon(
                point.isPlantDisease ? Icons.local_florist : Icons.pets,
                color: Colors.white,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    point.diseaseName,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    isRedZone ? 'RED ZONE' : 'YELLOW ZONE',
                    style: TextStyle(
                      color: isRedZone ? Colors.red : Colors.amber.shade800,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 0,
              color: Colors.grey.shade100,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 16, color: Colors.grey[700]),
                        SizedBox(width: 8),
                        Expanded(child: Text('Location: ${point.placeName}')),
                      ],
                    ),
                    Divider(),
                    Row(
                      children: [
                        Icon(
                          point.isPlantDisease ? Icons.grass : Icons.pets,
                          size: 16,
                          color: Colors.grey[700],
                        ),
                        SizedBox(width: 8),
                        Text(point.isPlantDisease
                            ? 'Crop: ${point.cropType}'
                            : 'Animal: ${point.cropType}'),
                      ],
                    ),
                    Divider(),
                    Row(
                      children: [
                        Icon(Icons.warning_amber,
                            size: 16,
                            color: isRedZone ? Colors.red : Colors.amber),
                        SizedBox(width: 8),
                        Text(
                          'Cases: ${point.caseCount}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                isRedZone ? Colors.red : Colors.amber.shade800,
                          ),
                        ),
                      ],
                    ),
                    Divider(),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 16, color: Colors.grey[700]),
                        SizedBox(width: 8),
                        Text(
                            'Report Date: ${point.reportDate.day}/${point.reportDate.month}/${point.reportDate.year}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (point.notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Notes:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(point.notes),
            ],
            SizedBox(height: 16),
            Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isRedZone ? Colors.red.shade50 : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isRedZone ? Colors.red : Colors.amber,
                    width: 1,
                  ),
                ),
                child: Text(
                  isRedZone
                      ? 'High Risk Area - Take Precautions'
                      : 'Moderate Risk Area - Monitor Situation',
                  style: TextStyle(
                    color:
                        isRedZone ? Colors.red.shade900 : Colors.amber.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.share),
            label: Text('Share'),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Sharing disease information...')),
              );
            },
          ),
          ElevatedButton(
            child: const Text('Close'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.green[700]),
            SizedBox(width: 8),
            Text('Disease Zone Information'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.red.shade50,
              margin: EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            "R",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'RED ZONE (50+ cases)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'About Disease Zones',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Disease zones are determined by the number of reported cases:',
                            style: TextStyle(fontSize: 14),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '• Red Zone: 50 or more cases\n• Yellow Zone: Less than 50 cases',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add method to keep card within bounds
  Offset _getBoundedPosition(Offset position) {
    final cardWidth = 200.0; // Approximate card width
    final cardHeight = 120.0; // Approximate card height

    double dx = position.dx;
    double dy = position.dy;

    // Constrain x position
    dx = dx.clamp(0, _screenSize.width - cardWidth);
    // Constrain y position
    dy = dy.clamp(0, _screenSize.height - cardHeight);

    return Offset(dx, dy);
  }
}
