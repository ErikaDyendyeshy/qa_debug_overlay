import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:qa_debug_overlay/qa_debug_overlay.dart';

/// Example application demonstrating the Debug Overlay
/// 
/// Super simple - no initialization needed!
/// Just wrap your app and add the interceptor.
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Debug Overlay Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return DebugOverlayWrapper(child: child ?? const HomePage());
      },
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Dio _dio;
  bool _isLoading = false;
  String _result = '';

  @override
  void initState() {
    super.initState();
    
    _dio = Dio(BaseOptions(
      baseUrl: 'https://jsonplaceholder.typicode.com',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'User-Agent': 'Flutter Debug Overlay Demo',
        'Accept': 'application/json',
        // Fake token so the "Auth token" copy action has something to copy.
        'Authorization': 'Bearer demo-token-123',
      },
    ));

    _dio.interceptors.add(DebugInterceptor());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Debug Overlay Demo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '🐞 Debug Overlay Example',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Tap the floating bug button to see network logs!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            const Text(
              'Test API Requests:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildRequestButton(
              'GET Posts',
              () => _makeRequest('GET', '/posts'),
              Colors.blue,
            ),
            const SizedBox(height: 8),
            _buildRequestButton(
              'GET Single Post',
              () => _makeRequest('GET', '/posts/1'),
              Colors.green,
            ),
            const SizedBox(height: 8),
            _buildRequestButton(
              'GET Users',
              () => _makeRequest('GET', '/users'),
              Colors.orange,
            ),
            const SizedBox(height: 8),
            _buildRequestButton(
              'POST New Post',
              () => _makeRequest(
                'POST',
                '/posts',
                data: {
                  'title': 'Debug Overlay Test',
                  'body': 'This is a test post from Flutter Debug Overlay',
                  'userId': 1,
                },
              ),
              Colors.purple,
            ),
            const SizedBox(height: 8),
            _buildRequestButton(
              'PUT Update Post',
              () => _makeRequest(
                'PUT',
                '/posts/1',
                data: {
                  'id': 1,
                  'title': 'Updated Post Title',
                  'body': 'Updated post body',
                  'userId': 1,
                },
              ),
              Colors.indigo,
            ),
            const SizedBox(height: 8),
            _buildRequestButton(
              'DELETE Post',
              () => _makeRequest('DELETE', '/posts/1'),
              Colors.red,
            ),
            const SizedBox(height: 8),
            _buildRequestButton(
              '404 Error Test',
              () => _makeRequest('GET', '/posts/999999'),
              Colors.red[800]!,
            ),
            const SizedBox(height: 8),
            _buildRequestButton(
              'Network Error Test',
              () => _makeRequest('GET', 'https://nonexistent.invalid/ping'),
              Colors.blueGrey,
            ),
            const SizedBox(height: 32),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_result.isNotEmpty) ...[
              const Text(
                'Last Response:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _result,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRequestButton(
    String label,
    VoidCallback onPressed,
    Color color,
  ) {
    return ElevatedButton(
      onPressed: _isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Text(label),
    );
  }

  Future<void> _makeRequest(
    String method,
    String path, {
    dynamic data,
  }) async {
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      Response response;
      
      switch (method) {
        case 'GET':
          response = await _dio.get(path);
          break;
        case 'POST':
          response = await _dio.post(path, data: data);
          break;
        case 'PUT':
          response = await _dio.put(path, data: data);
          break;
        case 'DELETE':
          response = await _dio.delete(path);
          break;
        default:
          throw Exception('Unsupported method: $method');
      }

      final preview = response.data.toString();
      setState(() {
        _result = 'Status: ${response.statusCode}\n'
            'URL: ${response.requestOptions.uri}\n'
            'Data: ${preview.length > 150 ? '${preview.substring(0, 150)}...' : preview}';
      });
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
