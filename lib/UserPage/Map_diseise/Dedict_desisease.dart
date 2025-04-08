import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class HeatmapPageMap extends StatefulWidget {
  const HeatmapPageMap({Key? key}) : super(key: key);

  @override
  State<HeatmapPageMap> createState() => _HeatmapPageStateMap();
}

class _HeatmapPageStateMap extends State<HeatmapPageMap> {
  // Map controller
  MapController _mapController = MapController();

  // Place name state variable
  String _currentPlaceName = "";

  // Simulated disease data points for the heatmap
  final List<DiseasePoint> _diseasePoints = [
    DiseasePoint(
      location: LatLng(37.7749, -122.4194),
      diseaseName: "Leaf Spot",
      cropType: "Tomato",
      intensity: 0.8,
      caseCount: 12,
      placeName: "San Francisco, CA", // Added place name
    ),
    DiseasePoint(
      location: LatLng(37.7850, -122.4100),
      diseaseName: "Leaf Spot",
      cropType: "Tomato",
      intensity: 0.5,
      caseCount: 7,
      placeName: "Fisherman's Wharf, SF", // Added place name
    ),
    DiseasePoint(
      location: LatLng(37.7800, -122.4300),
      diseaseName: "Early Blight",
      cropType: "Potato",
      intensity: 0.9,
      caseCount: 15,
      placeName: "Golden Gate Park, SF", // Added place name
    ),
    DiseasePoint(
      location: LatLng(37.7700, -122.4250),
      diseaseName: "Foot Rot",
      cropType: "Rice",
      intensity: 0.4,
      caseCount: 5,
      placeName: "Mission District, SF", // Added place name
    ),
  ];

  // Filter options
  String _selectedDisease = 'All Diseases';
  String _selectedCrop = 'All Crops';
  String _selectedTimeframe = 'Last 7 Days';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Disease Heatmap'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              _showNotificationAlert(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: () {
              _showInfoDialog(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(37.7749, -122.4194),
                    initialZoom: 13.0,
                    onTap: (tapPosition, point) {
                      _getLocationName(point);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: ['a', 'b', 'c'],
                      maxZoom: 19,
                      userAgentPackageName: 'com.example.app',
                      tileProvider: NetworkTileProvider(),
                    ),
                    // Circle markers for disease points - FIXED: Reduced opacity and size
                    CircleLayer(
                      circles: _getCircleMarkers(),
                    ),
                    // Location markers
                    MarkerLayer(
                      markers: _diseasePoints
                          .where((point) =>
                              (_selectedDisease == 'All Diseases' ||
                                  point.diseaseName == _selectedDisease) &&
                              (_selectedCrop == 'All Crops' ||
                                  point.cropType == _selectedCrop))
                          .map((point) {
                        return Marker(
                          point: point.location,
                          width: 40.0,
                          height: 40.0,
                          child: GestureDetector(
                            onTap: () {
                              _showPointDetails(context, point);
                            },
                            child: Icon(
                              Icons.location_on,
                              color: _getMarkerColor(point.intensity),
                              size: 40.0,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                // Place name indicator
                if (_currentPlaceName.isNotEmpty)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _currentPlaceName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 100,
                  right: 16,
                  child: _buildLegend(),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: _buildRiskMeter(0.7), // High risk example
                ),
                // Add map controls
                Positioned(
                  bottom: 200,
                  right: 16,
                  child: Column(
                    children: [
                      FloatingActionButton(
                        heroTag: "zoom_in",
                        mini: true,
                        child: const Icon(Icons.add),
                        onPressed: () {
                          final currentZoom = _mapController.camera.zoom;
                          _mapController.move(
                              _mapController.camera.center, currentZoom + 1);
                        },
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        heroTag: "zoom_out",
                        mini: true,
                        child: const Icon(Icons.remove),
                        onPressed: () {
                          final currentZoom = _mapController.camera.zoom;
                          _mapController.move(
                              _mapController.camera.center, currentZoom - 1);
                        },
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        heroTag: "my_location",
                        mini: true,
                        child: const Icon(Icons.my_location),
                        onPressed: () {
                          // Would need location plugin to implement
                          // For now just center on default location
                          _mapController.move(LatLng(37.7749, -122.4194),
                              _mapController.camera.zoom);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildBottomPanel(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add_a_photo),
        onPressed: () {
          _showUploadDialog(context);
        },
      ),
    );
  }

  // FIXED: Improved circle markers to prevent overlapping by adjusting opacity and Z-ordering
  List<CircleMarker> _getCircleMarkers() {
    // First sort by intensity so higher intensity circles appear on top
    final filteredPoints = _diseasePoints
        .where((point) =>
            (_selectedDisease == 'All Diseases' ||
                point.diseaseName == _selectedDisease) &&
            (_selectedCrop == 'All Crops' || point.cropType == _selectedCrop))
        .toList();

    // Sort so smaller circles appear first (at bottom)
    filteredPoints.sort((a, b) => a.intensity.compareTo(b.intensity));

    return filteredPoints.map((point) {
      // Color based on intensity
      Color circleColor = _getHeatColor(point.intensity);

      // Scale circle size based on case count but limit maximum size
      double radius = 100 + (point.caseCount * 15);
      if (radius > 400) radius = 400;

      return CircleMarker(
        point: point.location,
        color: circleColor.withOpacity(0.3), // FIXED: Reduced opacity
        borderColor:
            circleColor.withOpacity(0.6), // FIXED: More transparent border
        borderStrokeWidth: 1.5, // FIXED: Thinner border
        radius: radius,
      );
    }).toList();
  }

  Color _getHeatColor(double intensity) {
    if (intensity > 0.7) {
      return Colors.red;
    } else if (intensity > 0.4) {
      return Colors.orange;
    } else {
      return Colors.yellow;
    }
  }

  Color _getMarkerColor(double intensity) {
    if (intensity > 0.7) {
      return Colors.red;
    } else if (intensity > 0.4) {
      return Colors.orange;
    } else {
      return Colors.amber;
    }
  }

  // NEW: Method to get location name from coordinates
  Future<void> _getLocationName(LatLng point) async {
    try {
      // In a real implementation, this would use the geocoding package
      // For this demo, we'll simulate the lookup
      String placeName = "";

      // Find the closest known point
      double minDistance = double.infinity;

      for (var diseasePoint in _diseasePoints) {
        final location = diseasePoint.location;
        final distance = _calculateDistance(point, location);

        if (distance < minDistance) {
          minDistance = distance;
          placeName = diseasePoint.placeName;
        }
      }

      // If we're too far from any known point, generate a generic name
      if (minDistance > 0.02) {
        // Roughly 2km
        placeName =
            "Location (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})";
      }

      setState(() {
        _currentPlaceName = placeName;
      });

      // Show the place name briefly, then hide it after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _currentPlaceName = "";
          });
        }
      });
    } catch (e) {
      print("Error getting location name: $e");
    }
  }

  // Helper method to calculate rough distance between points
  double _calculateDistance(LatLng p1, LatLng p2) {
    // Calculate squared distance
    double squaredDistance =
        (p1.latitude - p2.latitude) * (p1.latitude - p2.latitude) +
            (p1.longitude - p2.longitude) * (p1.longitude - p2.longitude);

    // Return the square root using dart:math
    return sqrt(squaredDistance);
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Disease',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8),
              ),
              value: _selectedDisease,
              items: _diseaseTypes
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDisease = value!;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Crop',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8),
              ),
              value: _selectedCrop,
              items: _cropTypes
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCrop = value!;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Timeframe',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8),
              ),
              value: _selectedTimeframe,
              items: _timeframes
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedTimeframe = value!;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Disease Activity',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                    width: 20, height: 20, color: Colors.red.withOpacity(0.3)),
                const SizedBox(width: 4),
                const Text('High (>10 cases)'),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                    width: 20,
                    height: 20,
                    color: Colors.orange.withOpacity(0.3)),
                const SizedBox(width: 4),
                const Text('Medium (5-10 cases)'),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                    width: 20,
                    height: 20,
                    color: Colors.yellow.withOpacity(0.3)),
                const SizedBox(width: 4),
                const Text('Low (<5 cases)'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskMeter(double riskLevel) {
    Color riskColor;
    String riskText;

    if (riskLevel > 0.7) {
      riskColor = Colors.red;
      riskText = 'High Risk';
    } else if (riskLevel > 0.4) {
      riskColor = Colors.orange;
      riskText = 'Medium Risk';
    } else {
      riskColor = Colors.green;
      riskText = 'Low Risk';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Current Risk Level',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Container(
              width: 150,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [
                    Colors.green,
                    Colors.yellow,
                    Colors.orange,
                    Colors.red
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 150 * riskLevel - 5,
                    top: 0,
                    child: Container(
                      width: 10,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              riskText,
              style: TextStyle(
                color: riskColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    // Get the most significant disease point (highest case count)
    if (_diseasePoints.isEmpty) {
      return const SizedBox();
    }

    final sortedPoints = [..._diseasePoints]
      ..sort((a, b) => b.caseCount.compareTo(a.caseCount));
    final mostSignificant = sortedPoints.first;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.warning, color: Colors.red),
              const SizedBox(width: 8),
              Text(
                '${mostSignificant.diseaseName} Alert',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${mostSignificant.caseCount} cases of ${mostSignificant.diseaseName} reported in ${mostSignificant.cropType} within 10km.',
          ),
          const SizedBox(height: 4),
          const Text(
            'Recommendation: Apply fungicide within 24 hours to prevent spread.',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.navigation),
                label: const Text('Route Planner'),
                onPressed: () {
                  // Route planner functionality
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.info_outline),
                label: const Text('Prevention Guide'),
                onPressed: () {
                  // Show prevention guide
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showUploadDialog(BuildContext context) {
    String selectedDisease = 'Leaf Spot';
    String selectedCrop = 'Tomato';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Report Disease Case'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'Upload a picture of the infected plant/animal or select details below:'),
                const SizedBox(height: 16),
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(Icons.add_photo_alternate, size: 50),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Disease Type'),
                  value: selectedDisease,
                  items: _diseaseTypes
                      .where((type) => type != 'All Diseases')
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          ))
                      .toList(),
                  onChanged: (value) {
                    selectedDisease = value!;
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  decoration:
                      const InputDecoration(labelText: 'Crop/Animal Type'),
                  value: selectedCrop,
                  items: _cropTypes
                      .where((type) => type != 'All Crops')
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          ))
                      .toList(),
                  onChanged: (value) {
                    selectedCrop = value!;
                  },
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('Use my current location'),
                  value: true,
                  onChanged: (value) {},
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Upload'),
              onPressed: () {
                // Handle the upload logic
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Disease report uploaded successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showNotificationAlert(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Disease Alerts'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.warning, color: Colors.red),
                title: const Text('Early Blight Alert'),
                subtitle:
                    const Text('15 new cases in your area within 24 hours'),
                trailing: const Text('1h ago'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.warning, color: Colors.orange),
                title: const Text('Leaf Spot Alert'),
                subtitle: const Text('7 new cases in nearby tomato farms'),
                trailing: const Text('5h ago'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.warning, color: Colors.yellow),
                title: const Text('Foot Rot Update'),
                subtitle: const Text('Decreasing trend in your region'),
                trailing: const Text('1d ago'),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('View All'),
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate to notifications page
              },
            ),
          ],
        );
      },
    );
  }

  // FIXED: Modified to include place name
  void _showPointDetails(BuildContext context, DiseasePoint point) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${point.diseaseName} Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Location: ${point.placeName}'), // Added place name
              Text('Crop Type: ${point.cropType}'),
              Text('Reported Cases: ${point.caseCount}'),
              Text('Severity: ${(point.intensity * 100).toInt()}%'),
              const SizedBox(height: 10),
              const Text('Common Symptoms:'),
              const Text('• Yellow/brown spots on leaves'),
              const Text('• Wilting of plant parts'),
              const Text('• Reduced yield potential'),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Treatment Guide'),
              onPressed: () {
                Navigator.of(context).pop();
                // Show treatment guide
              },
            ),
          ],
        );
      },
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('About Community Disease Heatmap'),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Community Disease Heatmap adds real-time intelligence to help you see where and how plant or animal diseases are spreading. This is super useful for prevention, planning, and awareness.',
                ),
                SizedBox(height: 16),
                Text('Features:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('• View disease hotspots in real-time'),
                Text('• Upload disease cases with photos'),
                Text('• Receive alerts for nearby threats'),
                Text('• Filter by disease type, crop and time period'),
                Text('• Access prevention guides and recommendations'),
                SizedBox(height: 16),
                Text('Map data © OpenStreetMap contributors'),
                Text('App Version: 1.0.0'),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

// Updated DiseasePoint class to include place name
class DiseasePoint {
  final LatLng location;
  final String diseaseName;
  final String cropType;
  final double intensity; // 0.0 to 1.0
  final int caseCount; // Number of reported cases
  final String placeName; // Added place name field

  DiseasePoint({
    required this.location,
    required this.diseaseName,
    required this.cropType,
    required this.intensity,
    required this.caseCount,
    this.placeName = "", // Default empty string
  });
}
