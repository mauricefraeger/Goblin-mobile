import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:location/location.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:math';

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
        actions: [
          IconButton(
            icon: const Icon(Icons.offline_pin),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => OfflineMapManagerPage()),
              );
            },
          ),
        ],
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
  bool _isOfflineMode = false;
  LatLngBounds? _selectedRegion; // Dies ist die Maplibre-Version, also keine Änderung nötig

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
    
    // Add region selection functionality
    controller.addListener(() async {
      // When the map is idle, update the selected region
      if (controller.isCameraMoving == false) {
        // Get visible region
        final visibleRegion = await controller.getVisibleRegion();
        
        setState(() {
          _selectedRegion = visibleRegion; // Dies ist bereits ein LatLngBounds-Objekt von Maplibre
        });
      }
    });
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
        
        if (_isOfflineMode)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.offline_bolt, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text('OFFLINE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
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

class TileStorage {
  static Future<Directory> get _tilesDir async {
    final directory = await getApplicationDocumentsDirectory();
    final tilesDir = Directory('${directory.path}/map_tiles');
    if (!await tilesDir.exists()) {
      await tilesDir.create(recursive: true);
    }
    return tilesDir;
  }
  
  static Future<File> _getTileFile(String styleKey, int z, int x, int y) async {
    final dir = await _tilesDir;
    final stylePath = '$styleKey/$z/$x';
    final styleDir = Directory('${dir.path}/$stylePath');
    if (!await styleDir.exists()) {
      await styleDir.create(recursive: true);
    }
    return File('${styleDir.path}/$y.png');
  }
  
  static Future<void> saveTile(String styleKey, int z, int x, int y, Uint8List bytes) async {
    final file = await _getTileFile(styleKey, z, x, y);
    await file.writeAsBytes(bytes);
  }
  
  static Future<Uint8List?> getTile(String styleKey, int z, int x, int y) async {
    final file = await _getTileFile(styleKey, z, x, y);
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }
}

class TileDownloader {
  final String baseUrl;
  final String styleKey;
  
  TileDownloader({required this.baseUrl, required this.styleKey});
  
  Future<void> downloadRegion({
    required CustomLatLngBounds bounds, // Ändere den Typ zu CustomLatLngBounds
    required int minZoom,
    required int maxZoom,
    required Function(double) onProgress,
  }) async {
    int totalTiles = 0;
    int downloadedTiles = 0;
    
    // Calculate total tiles to download
    for (int z = minZoom; z <= maxZoom; z++) {
      final northwest = _getTileCoordinates(bounds.northwest, z);
      final southeast = _getTileCoordinates(bounds.southeast, z);
      
      final xCount = southeast.x - northwest.x + 1;
      final yCount = southeast.y - northwest.y + 1;
      totalTiles += xCount * yCount;
    }
    
    // Download tiles
    for (int z = minZoom; z <= maxZoom; z++) {
      final northwest = _getTileCoordinates(bounds.northwest, z);
      final southeast = _getTileCoordinates(bounds.southeast, z);
      
      for (int x = northwest.x; x <= southeast.x; x++) {
        for (int y = northwest.y; y <= southeast.y; y++) {
          await _downloadTile(z, x, y);
          downloadedTiles++;
          onProgress(downloadedTiles / totalTiles);
        }
      }
    }
  }
  
  Future<void> _downloadTile(int z, int x, int y) async {
    try {
      // Handle different URL structures for different styles
      String url;
      if (baseUrl.contains('maptiler.com')) {
        // MapTiler uses this format
        url = '$baseUrl/$z/$x/$y.png?key=ilF7e6KPtrXikZN22Uya';
      } else if (baseUrl.contains('localhost:8787')) {
        // Your local server might use a different format
        // Extract the style name from the URL
        final styleName = baseUrl.split('/').last;
        url = 'http://localhost:8787/data/$styleName/$z/$x/$y.png';
      } else {
        url = '$baseUrl/$z/$x/$y.png';
      }
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        await TileStorage.saveTile(styleKey, z, x, y, response.bodyBytes);
      }
    } catch (e) {
      print('Error downloading tile z:$z, x:$x, y:$y - $e');
    }
  }
  
  TileCoordinates _getTileCoordinates(LatLng latLng, int zoom) {
    final n = pow(2, zoom);
    final x = ((latLng.longitude + 180) / 360 * n).floor();
    final latRad = latLng.latitude * pi / 180;
    final y = ((1 - log(tan(latRad) + 1 / cos(latRad)) / pi) / 2 * n).floor();
    return TileCoordinates(x: x, y: y);
  }
}

class TileCoordinates {
  final int x;
  final int y;
  
  TileCoordinates({required this.x, required this.y});
}

// Umbenennen der benutzerdefinierten LatLngBounds-Klasse, um Konflikte zu vermeiden
class CustomLatLngBounds {
  final LatLng northwest;
  final LatLng southeast;
  
  CustomLatLngBounds({required this.northwest, required this.southeast});
}

class HybridTileProvider {
  final String baseUrl;
  final String styleKey;
  
  HybridTileProvider({required this.baseUrl, required this.styleKey});
  
  Future<Uint8List> getTile(int z, int x, int y) async {
    // First check local storage
    final localTile = await TileStorage.getTile(styleKey, z, x, y);
    if (localTile != null) {
      return localTile;
    }
    
    // If not available locally and online, download from server
    if (await _hasInternetConnection()) {
      try {
        final url = '$baseUrl/$z/$x/$y.png';
        final response = await http.get(Uri.parse(url));
        
        if (response.statusCode == 200) {
          // Save for future offline use
          await TileStorage.saveTile(styleKey, z, x, y, response.bodyBytes);
          return response.bodyBytes;
        }
      } catch (e) {
        print('Error downloading tile: $e');
      }
    }
    
    // Return placeholder tile if all else fails
    return _getPlaceholderTile();
  }
  
  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }
  
  Uint8List _getPlaceholderTile() {
    // Return a simple gray tile
    // In a real app, create a nicer looking placeholder
    return Uint8List.fromList(List.filled(256 * 256 * 4, 200));
  }
}

class OfflineMapManagerPage extends StatefulWidget {
  @override
  _OfflineMapManagerPageState createState() => _OfflineMapManagerPageState();
}

class _OfflineMapManagerPageState extends State<OfflineMapManagerPage> {
  MaplibreMapController? mapController; // Add this line
  LatLngBounds? _selectedRegion; // Dies ist die Maplibre-Version
  int _minZoom = 5;
  int _maxZoom = 14;
  bool _isDownloading = false;
  double _downloadProgress = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Offline Karten')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MaplibreMap(
                  styleString: mapStyles['MapTiler Streets']!,
                  initialCameraPosition: CameraPosition(
                    target: const LatLng(48.1351, 11.5820),
                    zoom: 5.0,
                  ),
                  onMapCreated: _onMapCreated,
                ),
                if (_selectedRegion != null)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: RegionSelectionPainter(
                        CustomLatLngBounds(
                          northwest: _selectedRegion!.northeast, // Anpassen der Attributnamen
                          southeast: _selectedRegion!.southwest, // Anpassen der Attributnamen
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton.small(
                    onPressed: () {
                      // Reset selection
                      setState(() {
                        _selectedRegion = null;
                      });
                    },
                    child: Icon(Icons.clear),
                  ),
                ),
              ],
            ),
          ),
          _buildDownloadPanel(),
        ],
      ),
    );
  }
  
  Widget _buildDownloadPanel() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Zoom-Level zum Herunterladen:'),
          Row(
            children: [
              Text('$_minZoom'),
              Expanded(
                child: RangeSlider(
                  values: RangeValues(_minZoom.toDouble(), _maxZoom.toDouble()),
                  min: 0,
                  max: 19,
                  divisions: 19,
                  labels: RangeLabels('$_minZoom', '$_maxZoom'),
                  onChanged: (values) {
                    setState(() {
                      _minZoom = values.start.round();
                      _maxZoom = values.end.round();
                    });
                  },
                ),
              ),
              Text('$_maxZoom'),
            ],
          ),
          Text('Geschätzte Größe: ${_estimateDownloadSize()} MB'),
          SizedBox(height: 16),
          if (_isDownloading)
            Column(
              children: [
                LinearProgressIndicator(value: _downloadProgress),
                SizedBox(height: 8),
                Text('${(_downloadProgress * 100).toStringAsFixed(1)}%'),
              ],
            )
          else
            ElevatedButton(
              onPressed: _selectedRegion != null ? _downloadSelectedRegion : null,
              child: Text('Ausgewählte Region herunterladen'),
            ),
        ],
      ),
    );
  }
  
  void _onMapCreated(MaplibreMapController controller) {
    // Setup region selection logic
    mapController = controller;
    
    // Add region selection functionality
    controller.addListener(() async {
      // When the map is idle, update the selected region
      if (controller.isCameraMoving == false) {
        // Get visible region
        final visibleRegion = await controller.getVisibleRegion();
        
        setState(() {
          _selectedRegion = visibleRegion; // Dies ist bereits ein LatLngBounds-Objekt von Maplibre
        });
      }
    });
  }
  
  String _estimateDownloadSize() {
    if (_selectedRegion == null) return '0';
    
    // Very rough estimate - actual calculation would depend on your data
    int totalTiles = 0;
    for (int z = _minZoom; z <= _maxZoom; z++) {
      // Calculate tiles for this zoom level
      final factor = pow(4, z - _minZoom);
      totalTiles += 10 * factor.toInt(); // Assuming 10 tiles at minimum zoom
    }
    
    // Assuming average tile size of 20KB
    return (totalTiles * 20 / 1024).toStringAsFixed(1);
  }
  
  void _downloadSelectedRegion() async {
    if (_selectedRegion == null) return;
    
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });
    
    // For each style, download the region
    for (final entry in mapStyles.entries) {
      final downloader = TileDownloader(
        baseUrl: entry.value.replaceAll('/style.json', ''),
        styleKey: entry.key,
      );
      
      await downloader.downloadRegion(
        bounds: CustomLatLngBounds(
          northwest: _selectedRegion!.northeast, // Anpassen der Attributnamen
          southeast: _selectedRegion!.southwest, // Anpassen der Attributnamen
        ),
        minZoom: _minZoom,
        maxZoom: _maxZoom,
        onProgress: (progress) {
          setState(() {
            _downloadProgress = progress;
          });
        },
      );
    }
    
    setState(() {
      _isDownloading = false;
    });
  }
}

// Aktualisiere den RegionSelectionPainter, um CustomLatLngBounds zu verwenden
class RegionSelectionPainter extends CustomPainter {
  final CustomLatLngBounds region;
  
  RegionSelectionPainter(this.region);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    
    final border = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    // Convert lat/lng to screen coordinates
    // This is a simplified approach and might need more accurate calculation
    final double left = (region.northwest.longitude + 180) / 360 * size.width;
    final double right = (region.southeast.longitude + 180) / 360 * size.width;
    final double top = (90 - region.northwest.latitude) / 180 * size.height;
    final double bottom = (90 - region.southeast.latitude) / 180 * size.height;
    
    final rect = Rect.fromLTRB(left, top, right, bottom);
    
    canvas.drawRect(rect, paint);
    canvas.drawRect(rect, border);
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
