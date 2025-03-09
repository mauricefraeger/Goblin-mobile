import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:location/location.dart';

// Map style URLs
const Map<String, String> mapStyles = {
  'MapTiler Streets': 'https://api.maptiler.com/maps/streets-v2/style.json?key=ilF7e6KPtrXikZN22Uya',
  'OSM+KI': 'http://localhost:8787/styles/ZGeoBw-OpenStreetMap/style.json',
  'Grau': 'http://localhost:8787/styles/D.Garp/style.json',
  'Liberty+KI': 'http://localhost:8787/styles/osm-liberty-3D/style.json',
  'MF-1024': 'http://localhost:8787/styles/mf-1024/style.json',
  'Dark Matter': 'http://localhost:8787/styles/dark-matter/style.json',
};

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GOBLIN'),
      ),
      body: const MapView(),
    );
  }
}

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State createState() => MapViewState();
}

class MapViewState extends State<MapView> {
  MaplibreMapController? mapController;
  Location location = Location();
  LocationData? _currentLocation;
  bool _serviceEnabled = false;
  PermissionStatus? _permissionStatus;
  String _currentStyle = 'MapTiler Streets'; // Default style
  bool _isStyleLoading = false;

  @override
  void initState() {
    super.initState();
    _initLocationService();
  }

  Future<void> _initLocationService() async {
    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    _permissionStatus = await location.hasPermission();
    if (_permissionStatus == PermissionStatus.denied) {
      _permissionStatus = await location.requestPermission();
      if (_permissionStatus != PermissionStatus.granted) {
        return;
      }
    }

    _currentLocation = await location.getLocation();
    location.onLocationChanged.listen((LocationData newLocation) {
      setState(() {
        _currentLocation = newLocation;
        if (mapController != null && _currentLocation != null) {
          _animateToCurrentLocation();
        }
      });
    });
  }

  void _animateToCurrentLocation() {
    if (_currentLocation != null && mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
          14.0,
        ),
      );
    }
  }

  void _onMapCreated(MaplibreMapController controller) {
    mapController = controller;
    if (_currentLocation != null) {
      _animateToCurrentLocation();
    }
  }

  // Instead of using _changeMapStyle which relies on setStyleString,
  // we'll recreate the map with a different style
  void _changeMapStyle(String styleName) {
    if (_currentStyle == styleName || _isStyleLoading) return;
    
    setState(() {
      _currentStyle = styleName;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MaplibreMap(
          styleString: mapStyles[_currentStyle]!,
          myLocationEnabled: true,
          initialCameraPosition: CameraPosition(
            target: _currentLocation != null
                ? LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!)
                : const LatLng(48.1351, 11.5820), // Default to Munich
            zoom: 14.0,
          ),
          onMapCreated: _onMapCreated,
          trackCameraPosition: true,
        ),
        
        // Map style selector
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: PopupMenuButton<String>(
                onSelected: _changeMapStyle,
                itemBuilder: (BuildContext context) {
                  return mapStyles.keys.map((String style) {
                    return PopupMenuItem<String>(
                      value: style,
                      child: Row(
                        children: [
                          if (_currentStyle == style)
                            const Icon(Icons.check, color: Colors.green)
                          else
                            const SizedBox(width: 24),
                          const SizedBox(width: 8),
                          Text(style),
                        ],
                      ),
                    );
                  }).toList();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.layers),
                      const SizedBox(width: 8),
                      Text(_currentStyle),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        
        // My location button
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: "locationButton",
            onPressed: _animateToCurrentLocation,
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }
}
