import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HMI Maquina Dobladora',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF1E2329),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF5F7A8D),
          secondary: Color(0xFF8EA1AE),
          surface: Color(0xFF2B323B),
          error: Color(0xFFB85B5B),
        ),
        textTheme: GoogleFonts.rajdhaniTextTheme().copyWith(
          headlineSmall: GoogleFonts.rajdhani(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFE4E8EC),
            letterSpacing: 0.8,
          ),
          titleMedium: GoogleFonts.rajdhani(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFD8DEE4),
            letterSpacing: 0.6,
          ),
          bodyMedium: GoogleFonts.rajdhani(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: const Color(0xFFC8D0D8),
            letterSpacing: 0.4,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFF2B323B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF3E4A56), width: 1.2),
          ),
        ),
      ),
      home: const HmiHomePage(),
    );
  }
}

class HmiHomePage extends StatefulWidget {
  const HmiHomePage({super.key});

  @override
  State<HmiHomePage> createState() => _HmiHomePageState();
}

class _HmiHomePageState extends State<HmiHomePage> {
  final TextEditingController _esp32Controller = TextEditingController(
    text: 'http://192.168.1.68',
  );
  bool _isSending = false;
  bool _isConnected = false;
  Timer? _connectionTimer;

  Uri _endpoint(String path) {
    final base = _esp32Controller.text.trim().replaceFirst(RegExp(r'/$'), '');
    return Uri.parse('$base$path');
  }

  @override
  void dispose() {
    _connectionTimer?.cancel();
    _esp32Controller.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    await _sendConnectionRequest(
      path: '/api/connect',
      buttonLabel: 'CONECTAR',
      successMessage: 'Conexion establecida con el ESP32.',
    );
  }

  Future<void> _disconnect() async {
    _connectionTimer?.cancel();
    await _sendConnectionRequest(
      path: '/api/disconnect',
      buttonLabel: 'DESCONECTAR',
      successMessage: 'Conexion cerrada con el ESP32.',
      disconnectOnSuccess: true,
    );
  }

  Future<void> _sendConnectionRequest({
    required String path,
    required String buttonLabel,
    required String successMessage,
    bool disconnectOnSuccess = false,
  }) async {
    if (_isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      final body = jsonEncode({'type': 'connection', 'button': buttonLabel});
      final response = await http.post(
        _endpoint(path),
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': utf8.encode(body).length.toString(),
        },
        body: body,
      ).timeout(const Duration(seconds: 5));

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _isConnected = !disconnectOnSuccess;
        });
        if (disconnectOnSuccess) {
          _connectionTimer?.cancel();
        } else {
          _startConnectionHeartbeat();
        }
        _showResultDialog('Conexion', successMessage);
      } else {
        setState(() {
          _isConnected = false;
        });
        _showResultDialog(
          'Conexion rechazada',
          'El ESP32 respondio con codigo ${response.statusCode}.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isConnected = false;
      });
      _showResultDialog(
        'Fallo de conexion',
        'No se pudo establecer comunicacion con el ESP32.\n\n$error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _startConnectionHeartbeat() {
    _connectionTimer?.cancel();
    _connectionTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final response = await http.get(_endpoint('/api/state'))
            .timeout(const Duration(seconds: 3));
        if (!mounted) return;
        setState(() {
          _isConnected = response.statusCode >= 200 && response.statusCode < 300;
        });
      } catch (_) {
        if (mounted) {
          setState(() {
            _isConnected = false;
          });
        }
      }
    });
  }

  Future<void> _sendCommand(String buttonLabel, String command) async {
    if (!_isConnected || _isSending) {
      _showResultDialog(
        'Conexion requerida',
        'Presiona CONECTAR antes de enviar comandos.',
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final body = jsonEncode({
        'type': 'command',
        'command': command,
        'button': buttonLabel,
      });
      final response = await http.post(
        _endpoint('/api/command'),
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': utf8.encode(body).length.toString(),
        },
        body: body,
      ).timeout(const Duration(seconds: 5));

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showPressedDialog(context, buttonLabel);
      } else {
        setState(() {
          _isConnected = false;
        });
        _showResultDialog(
          'Error de comunicación',
          'ESP32 respondió con código ${response.statusCode}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnected = false;
      });
      _showResultDialog(
        'Fallo de red',
        'No se pudo contactar al ESP32. Verifica la IP y la conexión Wi‑Fi.\n\nError: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _showPressedDialog(BuildContext context, String option) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A323B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFF495867)),
          ),
          title: Text(
            'Accion detectada',
            style: Theme.of(dialogContext).textTheme.titleMedium,
          ),
          content: Text(
            'Se presiono: $option',
            style: Theme.of(dialogContext).textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showResultDialog(String title, String message) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A323B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFF495867)),
          ),
          title: Text(
            title,
            style: Theme.of(dialogContext).textTheme.titleMedium,
          ),
          content: Text(
            message,
            style: Theme.of(dialogContext).textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF252C34),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MAQUINA DOBLADORA AUTOMATICA',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'HMI - INTERFAZ DE USUARIO',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF93A5B5),
                    fontSize: 13,
                  ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isConnected
                    ? const Color(0xFF33404C)
                    : const Color(0xFF3A2B2B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isConnected
                      ? const Color(0xFF546574)
                      : const Color(0xFF8F4F4F),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.wifi,
                    size: 16,
                    color: _isConnected
                        ? const Color(0xFF9AB7C9)
                        : const Color(0xFFEB8E8E),
                  ),
                  const SizedBox(width: 6),
                  Text(_isConnected ? 'CONECTADA' : 'DESCONECTADA'),
                ],
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _statusPanel(context),
          const SizedBox(height: 18),
          _operationPanel(context),
          const SizedBox(height: 18),
          _palletPanel(context),
        ],
      ),
    );
  }

  Widget _statusPanel(BuildContext context) {
    return Card(
      child: Container(
        constraints: const BoxConstraints(minHeight: 220),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, 'Estado de la Maquina'),
            const SizedBox(height: 12),
            _statusRow(context, 'Estado', 'IDLE / LISTA'),
            _statusRow(context, 'Ciclo actual', 'STANDARD_FOLDING'),
            _statusRow(context, 'Etapa', '2 / 4'),
            _statusRow(context, 'Progreso', '50 %'),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              minHeight: 10,
              value: 0.5,
              color: const Color(0xFF8CA5B5),
              backgroundColor: const Color(0xFF394652),
              borderRadius: BorderRadius.circular(20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _operationPanel(BuildContext context) {
    return Card(
      child: Container(
        constraints: const BoxConstraints(minHeight: 250),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, 'Operacion y Seguridad'),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _actionButton(
                  context,
                  'INICIAR',
                  Icons.play_arrow,
                  'INICIAR',
                  onPressed: _isSending ? null : () => _sendCommand('INICIAR', 'start_machine'),
                ),
                _actionButton(
                  context,
                  'DETENER',
                  Icons.stop,
                  'DETENER',
                  onPressed: _isSending ? null : () => _sendCommand('DETENER', 'stop_machine'),
                ),
                _actionButton(
                  context,
                  'RESET',
                  Icons.replay,
                  'RESET',
                  onPressed: _isSending ? null : () => _sendCommand('RESET', 'reset_machine'),
                ),
                _actionButton(
                  context,
                  'MODO MANUAL',
                  Icons.precision_manufacturing,
                  'MODO MANUAL',
                  onPressed: _isSending ? null : () => _sendCommand('MODO MANUAL', 'manual_mode'),
                ),
                _actionButton(
                  context,
                  'PARO EMERGENCIA',
                  Icons.warning_amber,
                  'PARO EMERGENCIA',
                  onPressed: _isSending ? null : () => _sendCommand('PARO EMERGENCIA', 'emergency_stop'),
                ),
                _actionButton(
                  context,
                  _isConnected ? 'DESCONECTAR' : 'CONECTAR',
                  _isConnected ? Icons.wifi_off : Icons.wifi,
                  _isConnected ? 'DESCONECTAR' : 'CONECTAR',
                  onPressed: _isSending
                      ? null
                      : (_isConnected ? _disconnect : _connect),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _esp32Controller,
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: InputDecoration(
                labelText: 'ESP32 URL base',
                labelStyle: const TextStyle(color: Color(0xFFB7C4CF)),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF536474)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF8CA5B5)),
                ),
                filled: true,
                fillColor: const Color(0xFF262E36),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _palletPanel(BuildContext context) {
    const palletLabels = <String>['P1°', 'P2°', 'P3°', 'P4°', 'P5°'];

    return Card(
      child: Container(
        constraints: const BoxConstraints(minHeight: 220),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, 'Modo Manual'),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: palletLabels
                  .map(
                    (label) => _actionButton(
                      context,
                      label,
                      Icons.sync_alt,
                      'Paleta $label',
                      onPressed: _isSending
                          ? null
                          : () => _sendCommand(
                                label.replaceAll('°', ''),
                                'pallet_${label.replaceAll('°', '').toLowerCase()}',
                              ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }

  Widget _statusRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF98A6B2),
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFE2E8EE),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    BuildContext context,
    String label,
    IconData icon,
    String pressedValue, {
    VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed ?? () => _showPressedDialog(context, pressedValue),
      icon: Icon(icon, size: 18, color: const Color(0xFFB7C4CF)),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(176, 56),
        foregroundColor: const Color(0xFFE2E8EE),
        side: const BorderSide(color: Color(0xFF536474)),
        backgroundColor: const Color(0xFF313A44),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
