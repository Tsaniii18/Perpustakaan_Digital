import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class BookReaderScreen extends StatefulWidget {
  static const routeName = '/book-reader';
  const BookReaderScreen({Key? key}) : super(key: key);

  @override
  _BookReaderScreenState createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _title = '';
  String? _url;
  double _fontSize = 18;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    _title = args['title'] ?? 'Baca Buku';
    _url = args['url'];
    
    if (_url != null && (Platform.isAndroid || Platform.isIOS)) {
      _initWebView();
    }
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) => setState(() => _isLoading = true),
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
            _injectCustomCSS();
          },
          onWebResourceError: (WebResourceError error) {
            print('Web resource error: ${error.description}');
            setState(() {
              _hasError = true;
              _isLoading = false;
            });
            _showErrorSnackbar(error);
          },
        ),
      );
    
    try {
      _controller!.loadRequest(Uri.parse(_url!));
    } catch (e) {
      print('Error loading URL: $e');
      setState(() => _hasError = true);
    }
  }

  void _showErrorSnackbar(WebResourceError error) {
    String message = 'Terjadi kesalahan saat memuat buku.';
    
    // Customize message based on error
    if (error.description.contains('ERR_CLEARTEXT_NOT_PERMITTED')) {
      message = 'Koneksi HTTP diblokir. Coba buka di browser eksternal.';
    } else if (error.description.contains('ERR_NAME_NOT_RESOLVED')) {
      message = 'Server tidak ditemukan. Periksa koneksi internet Anda.';
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: 'Buka di Browser',
            onPressed: _openInBrowser,
          ),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  Future<void> _openInBrowser() async {
    if (_url == null) return;
    
    try {
      final Uri url = Uri.parse(_url!);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showMessage('Tidak dapat membuka URL di browser');
      }
    } catch (e) {
      _showMessage('Error: $e');
    }
  }
  
  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message))
    );
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Ukuran Font'),
        children: [
          _fontSizeOption(ctx, 'Kecil', 14),
          _fontSizeOption(ctx, 'Sedang', 18),
          _fontSizeOption(ctx, 'Besar', 22),
          _fontSizeOption(ctx, 'Sangat Besar', 26),
        ],
      ),
    );
  }
  
  Widget _fontSizeOption(BuildContext context, String label, double size) {
    return SimpleDialogOption(
      onPressed: () {
        _changeFontSize(size);
        Navigator.pop(context);
      },
      child: Text(label),
    );
  }

  void _changeFontSize(double size) {
    setState(() => _fontSize = size);
    _controller?.runJavaScript('document.body.style.fontSize = "${size}px";');
  }

  void _injectCustomCSS() {
    _controller?.runJavaScript('''
      var style = document.createElement('style');
      style.textContent = `
        body {
          padding: 20px;
          line-height: 1.6;
          font-family: Arial, sans-serif;
          max-width: 800px;
          margin: 0 auto;
          font-size: ${_fontSize}px;
          color: #333;
          background-color: #f8f8f8;
        }
        p { margin-bottom: 16px; }
        h1, h2, h3, h4, h5, h6 { 
          margin-top: 24px;
          margin-bottom: 16px;
          color: #222;
        }
        img {
          max-width: 100%;
          height: auto;
          display: block;
          margin: 0 auto;
        }
        @media (prefers-color-scheme: dark) {
          body { background-color: #222; color: #eee; }
          h1, h2, h3, h4, h5, h6 { color: #fff; }
          a { color: #6699ff; }
        }
      `;
      document.head.appendChild(style);
    ''');
  }

  void _reloadWebView() {
    setState(() {
      _hasError = false;
      _isLoading = true;
    });
    _controller?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          if (Platform.isAndroid || Platform.isIOS) ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _reloadWebView,
            ),
            IconButton(
              icon: const Icon(Icons.text_fields),
              onPressed: _showFontSizeDialog,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: _openInBrowser,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Handle different cases
    if (_url == null) {
      return const Center(child: Text('URL buku tidak ditemukan'));
    }
    
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return _buildDesktopView();
    }
    
    if (_hasError) {
      return _buildErrorView();
    }
    
    return Stack(
      children: [
        if (_controller != null) WebViewWidget(controller: _controller!),
        if (_isLoading)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 80, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Terjadi kesalahan saat memuat buku',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Coba Lagi'),
            onPressed: _reloadWebView,
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Buka di Browser'),
            onPressed: _openInBrowser,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book_rounded, size: 100, color: Colors.blue),
          const SizedBox(height: 20),
          Text(
            _title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          const Text(
            'Aplikasi ini akan membuka buku di browser eksternal pada platform desktop.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Buka di Browser'),
            onPressed: _openInBrowser,
          ),
        ],
      ),
    );
  }
}